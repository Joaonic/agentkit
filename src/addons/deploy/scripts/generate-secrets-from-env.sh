#!/usr/bin/env bash
# generate-secrets-from-env.sh
# Creates secret files from deploy/.env values for all managed Docker secrets.
#
# Usage:
#   cd deploy
#   ./scripts/generate-secrets-from-env.sh
#
# Optional:
#   SECRETS_DIR=/home/ubuntu/wp/your-app/secrets ./scripts/generate-secrets-from-env.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/secrets.sh
source "${SCRIPT_DIR}/lib/secrets.sh"

if [[ ! -f .env ]]; then
  echo "[secrets-from-env] .env not found in deploy/."
  exit 1
fi

set -a
# shellcheck source=/dev/null
source .env
set +a

# Secrets that are optional (empty = not yet configured; aligns with validate-env.sh).
OPTIONAL_SECRETS=(stripe_secret_key stripe_webhook_secret mail_auth_pass vapid_public_key vapid_private_key vapid_subject)

_is_optional_secret() {
  local name="$1"
  for opt in "${OPTIONAL_SECRETS[@]}"; do
    [[ "${name}" == "${opt}" ]] && return 0
  done
  return 1
}

ensure_secrets_dir

missing=()
created=0
skipped=0

for secret_name in "${MANAGED_SECRETS[@]}"; do
  env_key="$(echo "${secret_name}" | tr '[:lower:]' '[:upper:]')"
  secret_value="${!env_key:-}"

  if [[ -z "${secret_value}" ]]; then
    if _is_optional_secret "${secret_name}"; then
      skipped=$((skipped + 1))
      continue
    fi
    missing+=("${secret_name} (env ${env_key})")
    skipped=$((skipped + 1))
    continue
  fi

  secret_file="${SECRETS_DIR}/${secret_name}"
  umask 077
  # Remove existing read-only file before writing (chmod 400 blocks overwrites).
  rm -f "${secret_file}"
  printf '%s' "${secret_value}" > "${secret_file}"
  chmod 400 "${secret_file}"
  created=$((created + 1))
done

echo "[secrets-from-env] created/updated: ${created}"
echo "[secrets-from-env] skipped (missing/optional env): ${skipped}"
echo "[secrets-from-env] target dir: ${SECRETS_DIR}"

if (( ${#missing[@]} > 0 )); then
  echo "[secrets-from-env] Missing values in .env for:"
  for item in "${missing[@]}"; do
    echo "  - ${item}"
  done
  echo "[secrets-from-env] Fill the missing env keys and run again."
  exit 1
fi

echo "[secrets-from-env] All managed secrets were generated successfully."
