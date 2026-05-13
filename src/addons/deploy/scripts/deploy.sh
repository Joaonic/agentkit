#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/migrations.sh
source "${SCRIPT_DIR}/lib/migrations.sh"
# shellcheck source=lib/secrets.sh
source "${SCRIPT_DIR}/lib/secrets.sh"

if [[ ! -f .env ]]; then
  echo ".env não encontrado no diretório deploy/."
  exit 1
fi

bash ./scripts/normalize-swarm-hosts-env.sh --env-file .env

./scripts/validate-env.sh

deploy_scope="${DEPLOY_SCOPE:-full}"
if [[ "${deploy_scope}" != "full" && "${deploy_scope}" != "backend" ]]; then
  echo "DEPLOY_SCOPE inválido: ${deploy_scope}. Valores aceitos: full, backend"
  exit 1
fi

STACK_NAME="${STACK_NAME:-app}"
MAIL_STACK_NAME="${MAIL_STACK_NAME:-app-mail}"

if ! docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -q 'active'; then
  echo "[deploy] Docker Swarm não está ativo. Execute: docker swarm init"
  exit 1
fi

is_truthy() {
  local value
  value="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')"
  [[ "${value}" == "1" || "${value}" == "true" || "${value}" == "yes" ]]
}

# Load secrets into shell env (needed for YAML interpolation at deploy time).
load_secrets_env

# (Swarm) Recreate Docker Swarm secrets from files.
create_swarm_secrets

# Preserve one-shot restore flags passed via command env so they win over .env.
CLI_RESTORE_BEFORE_MIGRATIONS="${RESTORE_BEFORE_MIGRATIONS-__UNSET__}"
CLI_RESTORE_SNAPSHOT_DIR="${RESTORE_SNAPSHOT_DIR-__UNSET__}"
CLI_RESTORE_POSTGRES_DUMP_FILE="${RESTORE_POSTGRES_DUMP_FILE-__UNSET__}"
CLI_RESTORE_SKIP_POSTGRES_DUMP_RESTORE="${RESTORE_SKIP_POSTGRES_DUMP_RESTORE-__UNSET__}"
CLI_RESTORE_SKIP_MAIL_DATA="${RESTORE_SKIP_MAIL_DATA-__UNSET__}"
CLI_RESTORE_WAIT_TIMEOUT_SEC="${RESTORE_WAIT_TIMEOUT_SEC-__UNSET__}"

# Export API_IMAGE / API_IMAGE_TAG from .env so run_migrations() can read them.
set -a
# shellcheck source=/dev/null
source .env
set +a

if [[ "${CLI_RESTORE_BEFORE_MIGRATIONS}" != "__UNSET__" ]]; then
  RESTORE_BEFORE_MIGRATIONS="${CLI_RESTORE_BEFORE_MIGRATIONS}"
fi
if [[ "${CLI_RESTORE_SNAPSHOT_DIR}" != "__UNSET__" ]]; then
  RESTORE_SNAPSHOT_DIR="${CLI_RESTORE_SNAPSHOT_DIR}"
fi
if [[ "${CLI_RESTORE_POSTGRES_DUMP_FILE}" != "__UNSET__" ]]; then
  RESTORE_POSTGRES_DUMP_FILE="${CLI_RESTORE_POSTGRES_DUMP_FILE}"
fi
if [[ "${CLI_RESTORE_SKIP_POSTGRES_DUMP_RESTORE}" != "__UNSET__" ]]; then
  RESTORE_SKIP_POSTGRES_DUMP_RESTORE="${CLI_RESTORE_SKIP_POSTGRES_DUMP_RESTORE}"
fi
if [[ "${CLI_RESTORE_SKIP_MAIL_DATA}" != "__UNSET__" ]]; then
  RESTORE_SKIP_MAIL_DATA="${CLI_RESTORE_SKIP_MAIL_DATA}"
fi
if [[ "${CLI_RESTORE_WAIT_TIMEOUT_SEC}" != "__UNSET__" ]]; then
  RESTORE_WAIT_TIMEOUT_SEC="${CLI_RESTORE_WAIT_TIMEOUT_SEC}"
fi

if is_truthy "${RESTORE_BEFORE_MIGRATIONS:-false}"; then
  if [[ "${deploy_scope}" != "full" ]]; then
    echo "[deploy] RESTORE_BEFORE_MIGRATIONS exige DEPLOY_SCOPE=full."
    exit 1
  fi

  if [[ -z "${RESTORE_SNAPSHOT_DIR:-}" ]]; then
    echo "[deploy] RESTORE_BEFORE_MIGRATIONS=true, mas RESTORE_SNAPSHOT_DIR não foi definido."
    exit 1
  fi

  restore_args=(--snapshot-dir "${RESTORE_SNAPSHOT_DIR}")
  if [[ -n "${RESTORE_POSTGRES_DUMP_FILE:-}" ]]; then
    restore_args+=(--postgres-dump "${RESTORE_POSTGRES_DUMP_FILE}")
  fi
  if is_truthy "${RESTORE_SKIP_POSTGRES_DUMP_RESTORE:-false}"; then
    restore_args+=(--skip-postgres-restore)
  fi
  if is_truthy "${RESTORE_SKIP_MAIL_DATA:-false}"; then
    restore_args+=(--skip-mail-restore)
  fi

  echo "[deploy] restoring backup data before migrations..."
  ./scripts/restore-all-before-migrations.sh "${restore_args[@]}"
fi

# Migrations run via `docker run` (Swarm-compatible, no `docker compose run`).
# Failure here aborts the deploy before any service is updated.
run_migrations

image="${API_IMAGE}:${API_IMAGE_TAG}"
mail_enabled="$(awk -F= '/^MAIL_ENABLED=/{print tolower($2)}' .env | tail -n 1)"
is_mail_enabled() {
  [[ "${mail_enabled}" == "1" || "${mail_enabled}" == "true" || "${mail_enabled}" == "yes" ]]
}

# ---------------------------------------------------------------------------
# Shared cleanup function — prune stopped containers for the stack.
# Called after deploy success, canary rollback, and in trap on error.
# ---------------------------------------------------------------------------
cleanup_stack_containers() {
  local stack_name="$1"
  echo "[cleanup] pruning stopped containers for stack ${stack_name}"
  docker container prune -f \
    --filter "label=com.docker.stack.namespace=${stack_name}" \
    2>/dev/null || true
}

# Update monitor period — avoid the 120s Swarm verify wait.
APP_UPDATE_MONITOR="${APP_UPDATE_MONITOR:-30s}"
APP_ROLLBACK_MONITOR="${APP_ROLLBACK_MONITOR:-30s}"

if [[ "${deploy_scope}" == "backend" ]]; then
  if docker service inspect "${STACK_NAME}_api" >/dev/null 2>&1 && docker service inspect "${STACK_NAME}_worker" >/dev/null 2>&1; then
    echo "[deploy] scope=backend — updating api + worker (detached, monitor=${APP_UPDATE_MONITOR})"

    # Log current live spec for diagnostics
    echo "[deploy] live update_config before update:"
    docker service inspect "${STACK_NAME}_api" \
      --format 'api: UpdateConfig={{json .Spec.UpdateConfig}} RollbackConfig={{json .Spec.RollbackConfig}}' 2>/dev/null || true
    docker service inspect "${STACK_NAME}_worker" \
      --format 'worker: UpdateConfig={{json .Spec.UpdateConfig}} RollbackConfig={{json .Spec.RollbackConfig}}' 2>/dev/null || true

    docker service update \
      --with-registry-auth \
      --detach=true \
      --image "${image}" \
      --update-order start-first \
      --update-monitor "${APP_UPDATE_MONITOR}" \
      --update-failure-action rollback \
      --rollback-order start-first \
      --rollback-monitor "${APP_ROLLBACK_MONITOR}" \
      "${STACK_NAME}_api"

    docker service update \
      --with-registry-auth \
      --detach=true \
      --image "${image}" \
      --update-order start-first \
      --update-monitor "${APP_UPDATE_MONITOR}" \
      --update-failure-action rollback \
      --rollback-order start-first \
      --rollback-monitor "${APP_ROLLBACK_MONITOR}" \
      "${STACK_NAME}_worker"
  else
    docker stack deploy --with-registry-auth -c stack.yml "${STACK_NAME}"
  fi
else
  docker stack deploy --with-registry-auth -c stack.yml "${STACK_NAME}"

  if is_mail_enabled; then
    docker stack deploy --with-registry-auth -c stack-mail.yml "${MAIL_STACK_NAME}"
  else
    docker stack rm "${MAIL_STACK_NAME}" 2>/dev/null || true
  fi
fi

# ---------------------------------------------------------------------------
# Canary-assisted convergence check (#224)
# Wait for all critical stateless services to reach full healthy replicas
# before exiting. If any service fails to converge within CANARY_TIMEOUT
# (default 300s), trigger an explicit rollback and exit non-zero.
# ---------------------------------------------------------------------------

CANARY_TIMEOUT="${CANARY_TIMEOUT:-300}"
CANARY_POLL_INTERVAL="${CANARY_POLL_INTERVAL:-5}"
CRITICAL_SERVICES=("api" "worker")

canary_wait_healthy() {
  local svc_full="$1"

  echo "==> [canary] Waiting for ${svc_full} to converge…"

  local desired
  desired="$(docker service inspect "${svc_full}" --format '{{.Spec.Mode.Replicated.Replicas}}' 2>/dev/null || echo 0)"
  if [[ "${desired}" == "0" ]]; then
    echo "    [canary] ${svc_full} has 0 desired replicas — skipping."
    return 0
  fi

  local deadline=$(( $(date +%s) + CANARY_TIMEOUT ))

  while true; do
    local running_healthy=0
    while IFS= read -r state; do
      if [[ "${state}" == Running* ]]; then
        running_healthy=$(( running_healthy + 1 ))
      fi
    done < <(docker service ps "${svc_full}" \
               --filter "desired-state=running" \
               --format '{{.CurrentState}}' 2>/dev/null)

    if (( running_healthy >= desired )); then
      echo "    [canary] ✅ ${svc_full}: ${running_healthy}/${desired} running"
      return 0
    fi

    if (( $(date +%s) >= deadline )); then
      echo "    [canary] ❌ ${svc_full}: ${running_healthy}/${desired} after ${CANARY_TIMEOUT}s"
      docker service ps "${svc_full}" --format 'table {{.Name}}\t{{.CurrentState}}\t{{.Error}}' --no-trunc 2>/dev/null || true
      return 1
    fi

    echo "    [canary] ${svc_full}: ${running_healthy}/${desired} — waiting ${CANARY_POLL_INTERVAL}s…"
    sleep "${CANARY_POLL_INTERVAL}"
  done
}

canary_failed=0
for svc in "${CRITICAL_SERVICES[@]}"; do
  if ! canary_wait_healthy "${STACK_NAME}_${svc}"; then
    echo "[canary] FAILED — triggering explicit rollback for ${STACK_NAME}_${svc}"
    docker service rollback "${STACK_NAME}_${svc}" 2>/dev/null || true
    canary_failed=1
  fi
done

if (( canary_failed )); then
  echo "[deploy] ⛔ Canary check failed — rollback triggered. See output above."
  cleanup_stack_containers "${STACK_NAME}"
  exit 1
fi

echo "[deploy] ✅ All critical services converged."

# ---------------------------------------------------------------------------
# Cleanup stopped/completed containers & tasks from this stack
# ---------------------------------------------------------------------------
cleanup_stack_containers "${STACK_NAME}"
if is_mail_enabled; then
  cleanup_stack_containers "${MAIL_STACK_NAME}"
fi
echo "[deploy] 🧹 Cleanup done."

# Post-deploy smoke test (if available and not in CI).
if [[ "${CI:-}" != "true" && -x "${SCRIPT_DIR}/healthcheck.sh" ]]; then
  echo "[deploy] Running post-deploy healthcheck…"
  "${SCRIPT_DIR}/healthcheck.sh" --post-deploy || {
    echo "[deploy] ⚠️  Post-deploy healthcheck reported issues (non-blocking)."
  }
fi
