#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/secrets.sh
source "${SCRIPT_DIR}/lib/secrets.sh"

if [[ $# -ne 1 ]]; then
  echo "Uso: ./scripts/rollback.sh <tag>"
  exit 1
fi

if [[ ! -f .env ]]; then
  echo ".env não encontrado no diretório deploy/."
  exit 1
fi

./scripts/validate-env.sh

# Load secrets into shell env (needed for YAML interpolation).
load_secrets_env

STACK_NAME="${STACK_NAME:-app}"

if ! docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -q 'active'; then
  echo "[rollback] Docker Swarm não está ativo. Execute: docker swarm init"
  exit 1
fi

rollback_tag="$1"
cp .env .env.bak
sed -i "s/^API_IMAGE_TAG=.*/API_IMAGE_TAG=${rollback_tag}/" .env

set -a
# shellcheck source=/dev/null
source .env
set +a

image="${API_IMAGE}:${API_IMAGE_TAG}"
echo "[rollback] serviços: ${STACK_NAME}_api ${STACK_NAME}_worker tag=${rollback_tag}"

APP_UPDATE_MONITOR="${APP_UPDATE_MONITOR:-30s}"
APP_ROLLBACK_MONITOR="${APP_ROLLBACK_MONITOR:-30s}"

if docker service inspect "${STACK_NAME}_api" >/dev/null 2>&1 && docker service inspect "${STACK_NAME}_worker" >/dev/null 2>&1; then
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
  docker stack deploy -c stack.yml "${STACK_NAME}"
fi

# ---------------------------------------------------------------------------
# Cleanup stopped containers from the stack after rollback
# ---------------------------------------------------------------------------
echo "[rollback] pruning stopped containers for stack ${STACK_NAME}"
docker container prune -f \
  --filter "label=com.docker.stack.namespace=${STACK_NAME}" \
  2>/dev/null || true
echo "[rollback] cleanup done."
