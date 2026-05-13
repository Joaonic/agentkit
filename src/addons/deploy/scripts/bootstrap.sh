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

chmod 600 .env
mkdir -p /home/ubuntu/wp/your-app/certs
chmod 700 /home/ubuntu/wp/your-app/certs

# Ensure secrets directory exists with proper permissions.
ensure_secrets_dir

# Load secrets into shell env (needed for YAML interpolation at deploy time).
load_secrets_env

# (Swarm) Create/recreate Docker Swarm secrets from files.
create_swarm_secrets

# Preserve one-shot restore flags passed via command env so they win over .env.
CLI_RESTORE_BEFORE_MIGRATIONS="${RESTORE_BEFORE_MIGRATIONS-__UNSET__}"
CLI_RESTORE_SNAPSHOT_DIR="${RESTORE_SNAPSHOT_DIR-__UNSET__}"
CLI_RESTORE_POSTGRES_DUMP_FILE="${RESTORE_POSTGRES_DUMP_FILE-__UNSET__}"
CLI_RESTORE_SKIP_POSTGRES_DUMP_RESTORE="${RESTORE_SKIP_POSTGRES_DUMP_RESTORE-__UNSET__}"
CLI_RESTORE_SKIP_MAIL_DATA="${RESTORE_SKIP_MAIL_DATA-__UNSET__}"
CLI_RESTORE_WAIT_TIMEOUT_SEC="${RESTORE_WAIT_TIMEOUT_SEC-__UNSET__}"

# Export env vars so run_migrations() can read API_IMAGE / API_IMAGE_TAG.
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

is_truthy() {
  local value
  value="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')"
  [[ "${value}" == "1" || "${value}" == "true" || "${value}" == "yes" ]]
}

mail_enabled="$(awk -F= '/^MAIL_ENABLED=/{print tolower($2)}' .env | tail -n 1)"
is_mail_enabled() {
  [[ "${mail_enabled}" == "1" || "${mail_enabled}" == "true" || "${mail_enabled}" == "yes" ]]
}

STACK_NAME="${STACK_NAME:-app}"
MAIL_STACK_NAME="${MAIL_STACK_NAME:-app-mail}"

if ! docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -q 'active'; then
  echo "[bootstrap] Docker Swarm não está ativo. Execute: docker swarm init"
  exit 1
fi

did_restore_before_migrations="false"
if is_truthy "${RESTORE_BEFORE_MIGRATIONS:-false}"; then
  if [[ -z "${RESTORE_SNAPSHOT_DIR:-}" ]]; then
    echo "[bootstrap] RESTORE_BEFORE_MIGRATIONS=true, mas RESTORE_SNAPSHOT_DIR não foi definido."
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

  echo "[bootstrap] restoring backup data before migrations..."
  ./scripts/restore-all-before-migrations.sh "${restore_args[@]}"
  did_restore_before_migrations="true"
fi

# Do not pre-create stack-managed networks here.
# `docker stack deploy` owns lifecycle for `app_internal` and `your_app_agent_prod_public`.
# Pre-creating them manually can cause "network with name ... already exists" conflicts.

if is_mail_enabled; then
  mail_data_dir="$(awk -F= '/^MAIL_DATA_DIR=/{print $2}' .env | tail -n 1)"
  mkdir -p \
    "${mail_data_dir}/mail-data" \
    "${mail_data_dir}/mail-state" \
    "${mail_data_dir}/mail-logs" \
    "${mail_data_dir}/config" \
    "${mail_data_dir}/webmail"
fi

if [[ "${did_restore_before_migrations}" != "true" ]]; then
  # Only deploy the initial stack if this is a fresh install (no existing services).
  # For existing stacks, the services are already running; deploying twice causes
  # "update out of sequence" errors when the second deploy fires while the first
  # is still reconciling.
  if ! docker service inspect "${STACK_NAME}_postgres" >/dev/null 2>&1; then
    echo "[bootstrap] fresh install detected — deploying stack for the first time…"
    docker stack deploy --with-registry-auth -c stack.yml "${STACK_NAME}"
  fi
fi

# Wait for postgres and redis to become healthy before running migrations.
# The first stack deploy may restart stateful services (stop-first), so
# migrations must wait until they are fully ready.
_wait_service_healthy() {
  local svc="$1"
  local timeout_sec="${2:-120}"
  local poll_sec=5
  local deadline=$(( $(date +%s) + timeout_sec ))
  echo "[bootstrap] waiting for ${svc} to become healthy…"
  while true; do
    local running_healthy=0
    local desired
    desired="$(docker service inspect "${svc}" --format '{{.Spec.Mode.Replicated.Replicas}}' 2>/dev/null || echo 0)"
    if [[ "${desired}" == "0" ]]; then
      echo "[bootstrap] ${svc} has 0 desired replicas — skipping."
      return 0
    fi
    while IFS= read -r state; do
      if [[ "${state}" == Running* ]]; then
        running_healthy=$(( running_healthy + 1 ))
      fi
    done < <(docker service ps "${svc}" \
               --filter "desired-state=running" \
               --format '{{.CurrentState}}' 2>/dev/null)
    if (( running_healthy >= desired )); then
      echo "[bootstrap] ${svc}: ${running_healthy}/${desired} running ✓"
      return 0
    fi
    if (( $(date +%s) >= deadline )); then
      echo "[bootstrap] timeout waiting for ${svc} (${timeout_sec}s)." >&2
      return 1
    fi
    sleep "${poll_sec}"
  done
}

_wait_service_healthy "${STACK_NAME}_postgres" 120
_wait_service_healthy "${STACK_NAME}_redis" 60

# Migrations run via `docker run` (Swarm-compatible, no `docker compose run`).
run_migrations

# Retry stack deploy to handle transient "update out of sequence" errors.
# These occur when Swarm is still reconciling a previous update.
_stack_deploy_with_retry() {
  local max_attempts=5
  local delay=10
  local attempt=1
  while true; do
    if docker stack deploy --with-registry-auth -c stack.yml "${STACK_NAME}" 2>&1; then
      return 0
    fi
    if (( attempt >= max_attempts )); then
      echo "[bootstrap] stack deploy failed after ${max_attempts} attempts." >&2
      return 1
    fi
    echo "[bootstrap] stack deploy attempt ${attempt}/${max_attempts} failed; retrying in ${delay}s…"
    attempt=$((attempt + 1))
    sleep "${delay}"
  done
}

_stack_deploy_with_retry

if is_mail_enabled; then
  docker stack deploy --with-registry-auth -c stack-mail.yml "${MAIL_STACK_NAME}"
else
  docker stack rm "${MAIL_STACK_NAME}" 2>/dev/null || true
fi
