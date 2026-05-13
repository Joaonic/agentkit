#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Uso:
  ./scripts/normalize-swarm-hosts-env.sh [--env-file .env] [--stack-name app]

Descrição:
  Reescreve no .env os apontamentos internos para nomes canônicos do Swarm
  (<stack>_<service>), substituindo aliases legados do Compose.
EOF
}

env_file=".env"
cli_stack_name="${STACK_NAME:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file)
      env_file="${2:-}"
      shift 2
      ;;
    --stack-name)
      cli_stack_name="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[normalize-env] argumento inválido: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "${env_file}" ]]; then
  echo "[normalize-env] arquivo não encontrado: ${env_file}" >&2
  exit 1
fi

read_env_var() {
  local key="$1"
  local line
  line="$(grep -E "^${key}=" "${env_file}" | tail -n 1 || true)"
  if [[ -z "${line}" ]]; then
    echo ""
    return
  fi
  echo "${line#*=}"
}

upsert_env_var() {
  local key="$1"
  local value="$2"
  local escaped
  escaped="$(printf '%s' "${value}" | sed -e 's/[\\&#]/\\&/g')"

  if grep -Eq "^${key}=" "${env_file}"; then
    sed -i -E "s#^${key}=.*#${key}=${escaped}#" "${env_file}"
  else
    printf '\n%s=%s\n' "${key}" "${value}" >> "${env_file}"
  fi
}

replace_host_in_urls() {
  local from_host="$1"
  local to_host="$2"

  # Replace host tokens in DSN/URL patterns with credentials.
  sed -i -E "s#@${from_host}:#@${to_host}:#g" "${env_file}"
  sed -i -E "s#@${from_host}/#@${to_host}/#g" "${env_file}"
}

replace_standalone_url_host() {
  local from_host="$1"
  local to_host="$2"

  # Replace host tokens in URLs without credentials (http://host:port/path).
  sed -i -E "s#://${from_host}:#://${to_host}:#g" "${env_file}"
  sed -i -E "s#://${from_host}/#://${to_host}/#g" "${env_file}"
}

stack_name="${cli_stack_name:-$(read_env_var STACK_NAME)}"
if [[ -z "${stack_name}" ]]; then
  stack_name="app"
fi

mail_stack_name="${MAIL_STACK_NAME:-$(read_env_var MAIL_STACK_NAME)}"
if [[ -z "${mail_stack_name}" ]]; then
  mail_stack_name="${stack_name}-mail"
fi

swarm_postgres_host="${stack_name}_postgres"
swarm_redis_host="${stack_name}_redis"
swarm_tempo_host="${stack_name}_tempo"
swarm_langfuse_web_host="${stack_name}_langfuse-web"
swarm_clickhouse_host="${stack_name}_langfuse-clickhouse"
swarm_langfuse_minio_host="${stack_name}_langfuse-minio"

upsert_env_var STACK_NAME "${stack_name}"
upsert_env_var MAIL_STACK_NAME "${mail_stack_name}"

# Canonical internal host vars.
upsert_env_var POSTGRES_HOST "${swarm_postgres_host}"
upsert_env_var REDIS_HOST "${swarm_redis_host}"
upsert_env_var CLICKHOUSE_HOST "${swarm_clickhouse_host}"
upsert_env_var CLICKHOUSE_URL "http://${swarm_clickhouse_host}:8123"
upsert_env_var LANGFUSE_MINIO_ENDPOINT "http://${swarm_langfuse_minio_host}:9000"
upsert_env_var LANGFUSE_INTERNAL_BASE_URL "http://${swarm_langfuse_web_host}:3000"
upsert_env_var OTEL_EXPORTER_OTLP_TRACES_ENDPOINT "http://${swarm_tempo_host}:4318/v1/traces"

# Rewrite legacy Compose host aliases in DSNs/URLs.
replace_host_in_urls "postgres" "${swarm_postgres_host}"
replace_host_in_urls "redis" "${swarm_redis_host}"
replace_standalone_url_host "tempo" "${swarm_tempo_host}"
replace_standalone_url_host "langfuse-web" "${swarm_langfuse_web_host}"
replace_standalone_url_host "langfuse-clickhouse" "${swarm_clickhouse_host}"
replace_standalone_url_host "langfuse-minio" "${swarm_langfuse_minio_host}"

echo "[normalize-env] normalized internal hosts for stack '${stack_name}' in ${env_file}."
