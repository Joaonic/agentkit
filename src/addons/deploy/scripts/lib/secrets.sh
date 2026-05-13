#!/usr/bin/env bash
# deploy/scripts/lib/secrets.sh
# Helper functions for Docker secrets management.
# Source this file in bootstrap.sh / deploy.sh.

set -euo pipefail

# Default secrets directory on the VPS.
SECRETS_DIR="${SECRETS_DIR:-/home/ubuntu/wp/your-app/secrets}"

# All secret names managed by this project (file name = Docker secret name).
MANAGED_SECRETS=(
  postgres_password
  redis_password
  meta_app_secret
  meta_access_token
  meta_verify_token
  meta_token_encryption_key
  shopify_api_secret
  openai_api_key
  stripe_secret_key
  stripe_webhook_secret
  langfuse_encryption_key
  langfuse_nextauth_secret
  langfuse_salt
  grafana_admin_password
  pgadmin_default_password
  langfuse_clickhouse_password
  langfuse_minio_password
  smtp_pass
  mail_auth_pass
  vapid_public_key
  vapid_private_key
  vapid_subject
)

# ---------------------------------------------------------------------------
# load_secrets_env — export secret files into the current shell environment.
# This is needed so that docker compose / docker stack deploy can interpolate
# ${VAR} references in YAML (e.g. POSTGRES_USER is still in .env, but
# POSTGRES_PASSWORD comes from the secret file).
# ---------------------------------------------------------------------------
load_secrets_env() {
  if [[ ! -d "${SECRETS_DIR}" ]]; then
    echo "[secrets] SECRETS_DIR=${SECRETS_DIR} not found — skipping secret loading."
    echo "[secrets] Falling back to .env for all values (legacy mode)."
    return 0
  fi

  local count=0
  for secret_file in "${SECRETS_DIR}"/*; do
    [[ -f "${secret_file}" ]] || continue
    local name
    name="$(basename "${secret_file}" | tr '[:lower:]' '[:upper:]')"
    local value
    value="$(tr -d '\n' < "${secret_file}")"
    export "${name}"="${value}"
    count=$((count + 1))
  done

  echo "[secrets] loaded ${count} secret(s) from ${SECRETS_DIR} into environment."
}

# ---------------------------------------------------------------------------
# ensure_secrets_dir — create the secrets directory with proper permissions.
# ---------------------------------------------------------------------------
ensure_secrets_dir() {
  if [[ ! -d "${SECRETS_DIR}" ]]; then
    echo "[secrets] creating ${SECRETS_DIR} (mode 0700, root only)."
    mkdir -p "${SECRETS_DIR}"
    chmod 700 "${SECRETS_DIR}"
  fi
}

# ---------------------------------------------------------------------------
# create_swarm_secrets — (re)create Docker Swarm secrets from files.
# Idempotent by default: keeps existing secrets and creates only missing ones.
#
# Optional force mode:
#   SECRETS_RECREATE_EXISTING=true ./scripts/deploy.sh
# In force mode, tries to remove and recreate existing secrets.
# If a secret is currently in use and cannot be removed, it is skipped with warning.
# Only runs if Docker is in Swarm mode.
# ---------------------------------------------------------------------------
create_swarm_secrets() {
  if ! docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -q 'active'; then
    echo "[secrets] Docker is not in Swarm mode — skipping docker secret create."
    return 0
  fi

  if [[ ! -d "${SECRETS_DIR}" ]]; then
    echo "[secrets] SECRETS_DIR=${SECRETS_DIR} not found — cannot create Swarm secrets."
    return 1
  fi

  local recreate_existing
  recreate_existing="$(echo "${SECRETS_RECREATE_EXISTING:-false}" | tr '[:upper:]' '[:lower:]')"

  local created=0
  local kept_existing=0
  local recreated=0
  local skipped_in_use=0
  for secret_name in "${MANAGED_SECRETS[@]}"; do
    local secret_file="${SECRETS_DIR}/${secret_name}"
    if [[ ! -f "${secret_file}" ]]; then
      continue
    fi

    if docker secret inspect "${secret_name}" >/dev/null 2>&1; then
      if [[ "${recreate_existing}" != "true" && "${recreate_existing}" != "1" && "${recreate_existing}" != "yes" ]]; then
        kept_existing=$((kept_existing + 1))
        continue
      fi

      if ! docker secret rm "${secret_name}" >/dev/null 2>&1; then
        echo "[secrets] warning: cannot recreate '${secret_name}' because it is currently in use. Keeping existing value."
        skipped_in_use=$((skipped_in_use + 1))
        continue
      fi

      docker secret create "${secret_name}" "${secret_file}" >/dev/null
      recreated=$((recreated + 1))
      continue
    fi

    docker secret create "${secret_name}" "${secret_file}" >/dev/null
    created=$((created + 1))
  done

  echo "[secrets] created: ${created}, recreated: ${recreated}, kept existing: ${kept_existing}, skipped in-use: ${skipped_in_use}."
}

# ---------------------------------------------------------------------------
# validate_secret_files — check that all required secret files exist.
# Returns 0 if all present, 1 otherwise.
# ---------------------------------------------------------------------------
validate_secret_files() {
  if [[ ! -d "${SECRETS_DIR}" ]]; then
    return 1
  fi

  local missing=()
  for secret_name in "${MANAGED_SECRETS[@]}"; do
    # mail_auth_pass is optional (only when MAIL_ENABLED)
    if [[ "${secret_name}" == "mail_auth_pass" ]]; then
      continue
    fi
    # stripe secrets are optional (empty = not configured yet)
    if [[ "${secret_name}" == "stripe_secret_key" || "${secret_name}" == "stripe_webhook_secret" ]]; then
      continue
    fi
    if [[ ! -f "${SECRETS_DIR}/${secret_name}" ]]; then
      missing+=("${secret_name}")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    echo "[secrets] missing secret files in ${SECRETS_DIR}:"
    for name in "${missing[@]}"; do
      echo "  - ${name}"
    done
    return 1
  fi

  return 0
}
