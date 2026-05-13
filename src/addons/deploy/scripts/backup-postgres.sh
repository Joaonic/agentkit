#!/usr/bin/env bash
# deploy/scripts/backup-postgres.sh — Backup Postgres via Docker Swarm.
# Épico: #204 | Issue: #208
set -euo pipefail

if [[ ! -f .env ]]; then
  echo "[backup] .env nao encontrado no diretorio deploy/."
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
  echo "[backup] POSTGRES_USER e POSTGRES_DB sao obrigatorios no .env."
  exit 1
fi

backup_dir="${BACKUP_DIR:-./backups/postgres}"
retention_days="${BACKUP_RETENTION_DAYS:-7}"

if ! [[ "${retention_days}" =~ ^[0-9]+$ ]]; then
  echo "[backup] BACKUP_RETENTION_DAYS deve ser inteiro (atual: ${retention_days})."
  exit 1
fi

mkdir -p "${backup_dir}"
timestamp="$(date -u +%Y%m%d-%H%M%S)"
backup_file="${backup_dir}/postgres-${timestamp}.dump"

# Encontrar container Postgres do Swarm stack
pg_container="$(docker ps --filter "label=com.docker.swarm.service.name=${STACK_NAME}_postgres" --format '{{.ID}}' | head -n 1)"
if [[ -z "${pg_container}" ]]; then
  echo "[backup] container postgres nao encontrado no stack ${STACK_NAME}."
  exit 1
fi

echo "[backup] iniciando dump: ${backup_file} (container: ${pg_container})"
docker exec -i "${pg_container}" \
  pg_dump -U "${postgres_user}" -d "${postgres_db}" -Fc > "${backup_file}"

if [[ ! -s "${backup_file}" ]]; then
  echo "[backup] dump vazio, removendo arquivo invalido."
  rm -f "${backup_file}"
  exit 1
fi

echo "[backup] removendo backups antigos (> ${retention_days} dias)"
find "${backup_dir}" -maxdepth 1 -type f -name 'postgres-*.dump' -mtime +"${retention_days}" -delete

echo "[backup] concluido: ${backup_file}"
