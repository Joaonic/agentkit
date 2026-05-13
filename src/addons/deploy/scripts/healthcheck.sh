#!/usr/bin/env bash
# deploy/scripts/healthcheck.sh — Verificação de saúde pós-deploy (Docker Swarm).
# Épico: #204 | Issue: #208
set -euo pipefail

if [[ ! -f .env ]]; then
  echo "[healthcheck] .env não encontrado no diretório deploy/."
  exit 1
fi

./scripts/validate-env.sh

# Export env vars
set -a
# shellcheck source=/dev/null
source .env
set +a

DEPLOY_SCOPE="${DEPLOY_SCOPE:-full}"
STACK_NAME="${STACK_NAME:-app}"

if [[ "${DEPLOY_SCOPE}" != "full" && "${DEPLOY_SCOPE}" != "backend" ]]; then
  echo "[healthcheck] DEPLOY_SCOPE inválido: ${DEPLOY_SCOPE}. Valores aceitos: full, backend"
  exit 1
fi

echo "[healthcheck] DEPLOY_SCOPE=${DEPLOY_SCOPE} STACK_NAME=${STACK_NAME}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Retry HTTPS — proxy/CDN pode demorar a estabilizar após deploy.
curl_retry_https() {
  local url="$1"
  local label="$2"
  local max_attempts="${3:-60}"
  local delay_sec="${4:-5}"
  local attempt=1
  local http_code curl_exit
  while (( attempt <= max_attempts )); do
    curl_exit=0
    http_code=$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 30 --max-time 120 "$url") || curl_exit=$?
    http_code=${http_code:-000}
    echo "[healthcheck] tentativa ${attempt}/${max_attempts} ${label} http_code=${http_code} curl_exit=${curl_exit} url=${url}"
    if [[ "${http_code}" =~ ^2[0-9][0-9]$ ]]; then
      echo "[healthcheck] OK ${label}"
      return 0
    fi
    if (( attempt == max_attempts )); then
      echo "[healthcheck] FALHOU após ${max_attempts} tentativas (${label}): ${url}"
      return 1
    fi
    echo "[healthcheck] aguardando ${delay_sec}s antes da próxima tentativa…"
    sleep "${delay_sec}"
    attempt=$((attempt + 1))
  done
}

# Check that a specific service has at least one running replica (when desired > 0).
check_service_replicas() {
  local svc_name="$1"
  local svc_replicas
  svc_replicas="$(docker service ls --filter "name=${svc_name}" --format '{{.Replicas}}' 2>/dev/null | head -n 1)"
  if [[ -z "${svc_replicas}" ]]; then
    echo "[healthcheck] FALHA: serviço ${svc_name} não encontrado"
    return 1
  fi
  local current="${svc_replicas%%/*}"
  local desired="${svc_replicas##*/}"
  if [[ "${desired}" != "0" && "${current}" == "0" ]]; then
    echo "[healthcheck] FALHA: serviço ${svc_name} com réplicas ${svc_replicas} (0 running)"
    return 1
  fi
  echo "[healthcheck] réplicas ${svc_name} OK (${svc_replicas})"
  return 0
}

# Check that all running tasks of a service are healthy (not Failed/Rejected).
check_service_tasks() {
  local svc_name="$1"
  local task_failed=0
  while IFS= read -r task_state; do
    if [[ "${task_state}" == Failed* ]] || [[ "${task_state}" == Rejected* ]]; then
      echo "[healthcheck] FALHA: task ${svc_name} em estado '${task_state}'"
      task_failed=1
    fi
  done < <(docker service ps "${svc_name}" --filter "desired-state=running" --format '{{.CurrentState}}' 2>/dev/null)
  if (( task_failed )); then
    return 1
  fi
  echo "[healthcheck] tasks ${svc_name} OK"
  return 0
}

# ---------------------------------------------------------------------------
# Backend-only scope — validate only api + worker, skip everything else.
# ---------------------------------------------------------------------------
if [[ "${DEPLOY_SCOPE}" == "backend" ]]; then
  echo "[healthcheck] scope=backend — validating only api + worker services"

  backend_failed=0
  check_service_replicas "${STACK_NAME}_api"    || backend_failed=1
  check_service_replicas "${STACK_NAME}_worker"  || backend_failed=1
  check_service_tasks "${STACK_NAME}_api"        || backend_failed=1
  check_service_tasks "${STACK_NAME}_worker"     || backend_failed=1

  if (( backend_failed )); then
    echo "[healthcheck] scope=backend — falha nos serviços backend."
    exit 1
  fi

  api_domain="${API_DOMAIN:-}"
  if [[ -z "${api_domain}" ]]; then
    echo "[healthcheck] ERRO: API_DOMAIN vazio"
    exit 1
  fi

  curl_retry_https "https://${api_domain}/health" "API /health"
  curl_retry_https "https://${api_domain}/health/ready" "API /health/ready"

  echo "[healthcheck] scope=backend — healthcheck concluído."
  exit 0
fi

# ---------------------------------------------------------------------------
# 1) Full scope: Verificação Swarm — réplicas e estado das tasks
# ---------------------------------------------------------------------------
echo "[healthcheck] verificando réplicas dos serviços Swarm…"

check_failed=0

while IFS=' ' read -r svc_name svc_replicas; do
  if [[ "${svc_name}" != "${STACK_NAME}_"* ]]; then
    continue
  fi
  # Serviço one-shot de migração: esperado terminar em 0/1 após concluir.
  if [[ "${svc_name}" == "${STACK_NAME}_api-migrate" ]]; then
    continue
  fi
  # Extrair current/desired (ex: "1/1" → current=1, desired=1)
  current="${svc_replicas%%/*}"
  desired="${svc_replicas##*/}"
  if [[ "${desired}" != "0" && "${current}" == "0" ]]; then
    echo "[healthcheck] FALHA: serviço ${svc_name} com réplicas ${svc_replicas} (0 running)"
    check_failed=1
  fi
done < <(docker service ls --filter "name=${STACK_NAME}_" --format '{{.Name}} {{.Replicas}}')

if (( check_failed )); then
  echo "[healthcheck] réplicas com falha detectada — abortando."
  exit 1
fi

echo "[healthcheck] réplicas OK."

# Verificar tasks do API — todas devem estar Running (não Failed/Rejected)
echo "[healthcheck] verificando tasks do serviço ${STACK_NAME}_api…"
if ! check_service_tasks "${STACK_NAME}_api"; then
  echo "[healthcheck] tasks com falha — abortando."
  exit 1
fi

# ---------------------------------------------------------------------------
# 2) Verificação HTTPS (proxy público)
# ---------------------------------------------------------------------------
api_domain="${API_DOMAIN}"
grafana_domain="${GRAFANA_DOMAIN}"
pga_domain="${PGA_DOMAIN}"
ri_domain="${RI_DOMAIN}"

if [[ -z "${api_domain}" ]]; then
  echo "[healthcheck] ERRO: API_DOMAIN vazio"
  exit 1
fi

echo "[healthcheck] API_DOMAIN=${api_domain}"

curl_retry_https "https://${api_domain}/health" "API /health"
curl_retry_https "https://${api_domain}/health/ready" "API /health/ready"

curl -fsS "https://${grafana_domain}/login" >/dev/null
curl -fsS "https://${pga_domain}" >/dev/null
curl -fsS "https://${ri_domain}" >/dev/null

# ---------------------------------------------------------------------------
# 3) Verificação mail (se ativo)
# ---------------------------------------------------------------------------
mail_enabled="$(echo "${MAIL_ENABLED:-}" | tr '[:upper:]' '[:lower:]')"
if [[ "${mail_enabled}" == "1" || "${mail_enabled}" == "true" || "${mail_enabled}" == "yes" ]]; then
  webmail_domain="${WEBMAIL_DOMAIN}"
  mail_server_host="${MAIL_SERVER_HOST}"

  curl -fsS "https://${webmail_domain}" >/dev/null
  starttls_output=$(timeout 12 openssl s_client -starttls smtp -connect "${mail_server_host}:587" -servername "${mail_server_host}" < /dev/null 2>&1 || true)
  if ! echo "${starttls_output}" | grep -q 'Verify return code: 0 (ok)'; then
    echo "[healthcheck] STARTTLS em ${mail_server_host}:587 inválido."
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# 4) Verificação host inválido (segurança reverse proxy)
# ---------------------------------------------------------------------------
http_code=$(curl -s -o /dev/null -w '%{http_code}' --resolve "invalid.local:443:127.0.0.1" https://invalid.local || true)
if [[ "$http_code" != "000" ]]; then
  echo "[healthcheck] Host inválido não foi bloqueado como esperado"
  exit 1
fi

echo "[healthcheck] todas as verificações passaram."
