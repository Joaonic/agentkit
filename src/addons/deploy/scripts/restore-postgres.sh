#!/usr/bin/env bash
# deploy/scripts/restore-postgres.sh — Restore Postgres via Docker Swarm.
# Épico: #204 | Issue: #208
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Uso: ./scripts/restore-postgres.sh <caminho-do-backup.dump>"
  exit 1
fi

dump_file="$1"

if [[ ! -f "${dump_file}" ]]; then
  echo "[restore] Backup nao encontrado: ${dump_file}"
  exit 1
fi

if [[ ! -s "${dump_file}" ]]; then
  echo "[restore] Backup esta vazio: ${dump_file}"
  exit 1
fi

if [[ ! -f .env ]]; then
  echo "[restore] .env nao encontrado no diretorio deploy/."
  exit 1
fi

# Export env vars
set -a
# shellcheck source=/dev/null
source .env
set +a

STACK_NAME="${STACK_NAME:-app}"
postgres_user="${POSTGRES_USER}"
postgres_db="${POSTGRES_DB}"

if [[ -z "${postgres_user}" || -z "${postgres_db}" ]]; then
  echo "[restore] POSTGRES_USER e POSTGRES_DB sao obrigatorios no .env."
  exit 1
fi

# Encontrar container Postgres do Swarm stack
pg_container="$(docker ps --filter "label=com.docker.swarm.service.name=${STACK_NAME}_postgres" --format '{{.ID}}' | head -n 1)"
if [[ -z "${pg_container}" ]]; then
  echo "[restore] container postgres nao encontrado no stack ${STACK_NAME}."
  exit 1
fi

echo "[restore] iniciando restore de ${dump_file} em ${postgres_db} (container: ${pg_container})"
cat "${dump_file}" | docker exec -i "${pg_container}" \
  pg_restore -U "${postgres_user}" -d "${postgres_db}" --clean --if-exists

echo "[restore] concluido com sucesso"
