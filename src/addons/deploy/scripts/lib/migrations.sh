#!/usr/bin/env bash
# deploy/scripts/lib/migrations.sh
# Runs Prisma migrations via `docker run` — Swarm-compatible.
# Source this file and call run_migrations.
# Épico: #204 | Issue: #208

set -euo pipefail

# Prisma migrate deploy command executed inside the API image.
PRISMA_MIGRATE_CMD="node /app/node_modules/prisma/build/index.js migrate deploy --config /app/packages/db/prisma.config.ts"

# ---------------------------------------------------------------------------
# _resolve_migrate_network — determine which Docker network to attach to.
# Priority: MIGRATE_NETWORK env var → STACK_NAME_internal → fallback app_internal.
# ---------------------------------------------------------------------------
_resolve_migrate_network() {
  if [[ -n "${MIGRATE_NETWORK:-}" ]]; then
    echo "${MIGRATE_NETWORK}"
    return
  fi
  local stack="${STACK_NAME:-app}"
  echo "${stack}_internal"
}

# ---------------------------------------------------------------------------
# _resolve_migrate_postgres_host — canonical Postgres hostname for Swarm.
# Priority: MIGRATE_POSTGRES_HOST env var → STACK_NAME_postgres.
#
# Why this matters:
# - In Swarm stacks, the service canonical name is "<stack>_<service>".
# - For one-shot `docker run` helpers, relying on short aliases may be brittle.
# ---------------------------------------------------------------------------
_resolve_migrate_postgres_host() {
  if [[ -n "${MIGRATE_POSTGRES_HOST:-}" ]]; then
    echo "${MIGRATE_POSTGRES_HOST}"
    return
  fi
  local stack="${STACK_NAME:-app}"
  echo "${stack}_postgres"
}

# ---------------------------------------------------------------------------
# ensure_network — guarantee the target network exists.
# In Swarm mode, creates an attachable overlay if missing.
# ---------------------------------------------------------------------------
ensure_network() {
  local net="$1"
  if docker network inspect "${net}" >/dev/null 2>&1; then
    return 0
  fi
  # Network missing — create overlay only if Docker Swarm is active.
  if docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -q 'active'; then
    echo "[migrate] creating overlay network ${net} (attachable)…"
    docker network create -d overlay --attachable "${net}"
  else
    echo "[migrate] ERROR: network '${net}' not found and Docker is not in Swarm mode." >&2
    echo "[migrate] Ensure Swarm is initialized and the stack is deployed first." >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# run_migrations — ensure the network, run prisma migrate deploy.
# Exits non-zero on failure so `set -e` in the caller aborts the deploy.
# ---------------------------------------------------------------------------
run_migrations() {
  local image="${API_IMAGE:?API_IMAGE must be set}:${API_IMAGE_TAG:?API_IMAGE_TAG must be set}"
  local env_file="${DEPLOY_ENV_FILE:-.env}"
  local postgres_image="${PGVECTOR_IMAGE:-pgvector/pgvector:pg18-trixie}"
  local postgres_host
  local network
  postgres_host="$(_resolve_migrate_postgres_host)"
  network="$(_resolve_migrate_network)"

  echo "[migrate] image=${image} network=${network} postgres_host=${postgres_host} env_file=${env_file}"

  ensure_network "${network}"

  # Use a single injected POSTGRES_PASSWORD env var for helper containers.
  # Mounting all local secret files can cause permission mismatches inside
  # containers (notably after image/user changes during migrations).
  local postgres_password="${POSTGRES_PASSWORD:-}"
  if [[ -z "${postgres_password}" ]]; then
    local secrets_dir="${SECRETS_DIR:-/home/ubuntu/wp/your-app/secrets}"
    if [[ -f "${secrets_dir}/postgres_password" ]]; then
      postgres_password="$(tr -d '\n' < "${secrets_dir}/postgres_password")"
    fi
  fi
  if [[ -z "${postgres_password}" ]]; then
    echo "[migrate] POSTGRES_PASSWORD not found in env or secrets directory." >&2
    return 1
  fi

  # Fresh stack deployments may need some time until postgres is resolvable and ready.
  local ready_timeout_sec="${MIGRATE_POSTGRES_READY_TIMEOUT_SEC:-240}"
  local ready_poll_sec="${MIGRATE_POSTGRES_READY_POLL_SEC:-5}"
  local deadline=$(( $(date +%s) + ready_timeout_sec ))
  local attempt=1

  echo "[migrate] waiting for postgres connectivity on ${network}…"
  while true; do
    if docker run --rm \
      --network "${network}" \
      --env-file "${env_file}" \
      -e POSTGRES_HOST="${postgres_host}" \
      -e POSTGRES_PASSWORD="${postgres_password}" \
      "${postgres_image}" \
      sh -euc '
        if [ -z "${POSTGRES_PASSWORD:-}" ]; then
          echo "[migrate] POSTGRES_PASSWORD missing while waiting for postgres." >&2
          exit 1
        fi
        _dsn="postgresql://${POSTGRES_USER:-postgres}:${POSTGRES_PASSWORD}@${POSTGRES_HOST:-postgres}:${POSTGRES_PORT:-5432}/postgres"
        psql "${_dsn}" -v ON_ERROR_STOP=1 -tAc "SELECT 1" >/dev/null
      ' >/dev/null 2>&1; then
      echo "[migrate] postgres is reachable."
      break
    fi

    if (( $(date +%s) >= deadline )); then
      echo "[migrate] timeout waiting postgres connectivity after ${ready_timeout_sec}s." >&2
      docker run --rm \
        --network "${network}" \
        --env-file "${env_file}" \
        -e POSTGRES_HOST="${postgres_host}" \
        -e POSTGRES_PASSWORD="${postgres_password}" \
        "${postgres_image}" \
        sh -euc '
          _dsn="postgresql://${POSTGRES_USER:-postgres}:${POSTGRES_PASSWORD:-missing}@${POSTGRES_HOST:-postgres}:${POSTGRES_PORT:-5432}/postgres"
          psql "${_dsn}" -v ON_ERROR_STOP=1 -tAc "SELECT 1"
        ' || true
      return 1
    fi

    echo "[migrate] postgres not ready yet (attempt ${attempt}); retrying in ${ready_poll_sec}s…"
    attempt=$((attempt + 1))
    sleep "${ready_poll_sec}"
  done

  # Legacy volumes skip docker-entrypoint-initdb.d scripts. Ensure Langfuse DB exists
  # so langfuse-web/worker do not crash-loop after Compose->Swarm migration.
  echo "[migrate] ensuring langfuse database exists…"
  local langfuse_attempt=1
  local langfuse_max_retries=5
  local langfuse_retry_delay=5
  while true; do
    if docker run --rm \
      --network "${network}" \
      --env-file "${env_file}" \
      -e POSTGRES_HOST="${postgres_host}" \
      -e POSTGRES_PASSWORD="${postgres_password}" \
      "${postgres_image}" \
      sh -euc '
        if [ -z "${POSTGRES_PASSWORD:-}" ]; then
          echo "[migrate] POSTGRES_PASSWORD missing; cannot ensure langfuse database." >&2
          exit 1
        fi

        _dsn="postgresql://${POSTGRES_USER:-postgres}:${POSTGRES_PASSWORD}@${POSTGRES_HOST:-postgres}:${POSTGRES_PORT:-5432}/postgres"
        _exists="$(psql "${_dsn}" -v ON_ERROR_STOP=1 -tAc "SELECT 1 FROM pg_database WHERE datname=\$\$langfuse\$\$")"
        if printf "%s" "${_exists}" | grep -q 1; then
          echo "[migrate] langfuse database already exists."
        else
          psql "${_dsn}" -v ON_ERROR_STOP=1 -c "CREATE DATABASE langfuse"
          echo "[migrate] created database langfuse."
        fi
      '; then
      break
    fi
    if (( langfuse_attempt >= langfuse_max_retries )); then
      echo "[migrate] failed to ensure langfuse database after ${langfuse_max_retries} attempts." >&2
      return 1
    fi
    echo "[migrate] langfuse DB check failed (attempt ${langfuse_attempt}/${langfuse_max_retries}); retrying in ${langfuse_retry_delay}s…"
    langfuse_attempt=$((langfuse_attempt + 1))
    sleep "${langfuse_retry_delay}"
  done

  echo "[migrate] running prisma migrate deploy…"
  docker run --rm \
    --entrypoint sh \
    --network "${network}" \
    --env-file "${env_file}" \
    -e POSTGRES_HOST="${postgres_host}" \
    -e POSTGRES_PASSWORD="${postgres_password}" \
    "${image}" \
    -lc "${PRISMA_MIGRATE_CMD}"

  echo "[migrate] migrations applied successfully."
}
