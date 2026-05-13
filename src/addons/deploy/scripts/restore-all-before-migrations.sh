#!/usr/bin/env bash
# deploy/scripts/restore-all-before-migrations.sh
# Restores stack data from snapshots/dumps BEFORE running migrations.
#
# Usage:
#   ./scripts/restore-all-before-migrations.sh --snapshot-dir ./backups/volumes/<timestamp>
#   ./scripts/restore-all-before-migrations.sh --snapshot-dir ./backups/volumes/<timestamp> --postgres-dump ./backups/postgres/postgres-YYYYMMDD-HHMMSS.dump
#
# Notes:
# - Removes the current stacks to stop writes before restoring volumes.
# - Restores all named volumes from the snapshot directory.
# - Re-deploys stack.yml, waits for Postgres, restores Postgres dump (unless skipped).

set -euo pipefail

usage() {
  cat <<'EOF'
Uso:
  ./scripts/restore-all-before-migrations.sh --snapshot-dir <dir> [--postgres-dump <file>] [--skip-postgres-restore] [--skip-mail-restore]

Opções:
  --snapshot-dir <dir>       Diretório com arquivos <volume>.tar.gz (obrigatório)
  --postgres-dump <file>     Dump postgres-*.dump para restaurar (opcional; usa o mais recente em BACKUP_DIR por padrão)
  --skip-postgres-restore    Não executar restore-postgres.sh
  --skip-mail-restore        Não restaurar bind mount de mail (mailserver-data.tar.gz)
EOF
}

is_truthy() {
  local value
  value="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')"
  [[ "${value}" == "1" || "${value}" == "true" || "${value}" == "yes" ]]
}

wait_for_stack_containers_to_stop() {
  local stack_name="$1"
  local timeout_sec="$2"
  local deadline=$(( $(date +%s) + timeout_sec ))

  while true; do
    local count
    count="$(docker ps --filter "label=com.docker.stack.namespace=${stack_name}" --format '{{.ID}}' | wc -l | tr -d ' ')"
    if [[ "${count}" == "0" ]]; then
      return 0
    fi
    if (( $(date +%s) >= deadline )); then
      echo "[restore-all] timeout waiting stack '${stack_name}' containers to stop."
      return 1
    fi
    echo "[restore-all] waiting stack '${stack_name}' to stop (${count} container(s) still running)..."
    sleep 5
  done
}

restore_volume_archive() {
  local snapshot_dir="$1"
  local volume_name="$2"

  if ! docker volume inspect "${volume_name}" >/dev/null 2>&1; then
    docker volume create "${volume_name}" >/dev/null
  fi

  echo "[restore-all] restoring ${volume_name} from ${snapshot_dir}/${volume_name}.tar.gz..."
  docker run --rm \
    -v "${volume_name}":/data \
    -v "${snapshot_dir}":/backup:ro \
    alpine \
    sh -lc "rm -rf /data/* /data/.[!.]* /data/..?* 2>/dev/null || true; tar xzf /backup/${volume_name}.tar.gz -C /data"
}

wait_for_postgres_ready() {
  local stack_name="$1"
  local postgres_user="$2"
  local postgres_db="$3"
  local timeout_sec="$4"
  local deadline=$(( $(date +%s) + timeout_sec ))

  while true; do
    local pg_container
    pg_container="$(docker ps --filter "label=com.docker.swarm.service.name=${stack_name}_postgres" --format '{{.ID}}' | head -n 1)"

    if [[ -n "${pg_container}" ]] && docker exec -i "${pg_container}" pg_isready -U "${postgres_user}" -d "${postgres_db}" >/dev/null 2>&1; then
      echo "[restore-all] postgres is ready (${pg_container})."
      return 0
    fi

    if (( $(date +%s) >= deadline )); then
      echo "[restore-all] timeout waiting for postgres readiness."
      return 1
    fi

    echo "[restore-all] waiting postgres readiness..."
    sleep 5
  done
}

if [[ ! -f .env ]]; then
  echo "[restore-all] .env não encontrado no diretório deploy/."
  exit 1
fi

bash ./scripts/normalize-swarm-hosts-env.sh --env-file .env

./scripts/validate-env.sh

snapshot_dir=""
postgres_dump=""
skip_postgres_restore="false"
skip_mail_restore="false"

if is_truthy "${RESTORE_SKIP_MAIL_DATA:-false}"; then
  skip_mail_restore="true"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --snapshot-dir)
      snapshot_dir="${2:-}"
      shift 2
      ;;
    --postgres-dump)
      postgres_dump="${2:-}"
      shift 2
      ;;
    --skip-postgres-restore)
      skip_postgres_restore="true"
      shift
      ;;
    --skip-mail-restore)
      skip_mail_restore="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[restore-all] argumento inválido: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "${snapshot_dir}" ]]; then
  echo "[restore-all] --snapshot-dir é obrigatório."
  usage
  exit 1
fi

if [[ ! -d "${snapshot_dir}" ]]; then
  echo "[restore-all] diretório de snapshot não encontrado: ${snapshot_dir}"
  exit 1
fi

# Preserve one-shot MAIL_DATA_DIR passed via command env so it wins over .env.
CLI_MAIL_DATA_DIR="${MAIL_DATA_DIR-__UNSET__}"

# shellcheck source=/dev/null
set -a && source .env && set +a

if [[ "${CLI_MAIL_DATA_DIR}" != "__UNSET__" ]]; then
  MAIL_DATA_DIR="${CLI_MAIL_DATA_DIR}"
fi

STACK_NAME="${STACK_NAME:-app}"
MAIL_STACK_NAME="${MAIL_STACK_NAME:-app-mail}"
postgres_user="${POSTGRES_USER}"
postgres_db="${POSTGRES_DB}"
restore_wait_timeout="${RESTORE_WAIT_TIMEOUT_SEC:-300}"

if ! docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -q 'active'; then
  echo "[restore-all] Docker Swarm não está ativo. Execute: docker swarm init"
  exit 1
fi

if [[ "${skip_postgres_restore}" != "true" && -z "${postgres_dump}" ]]; then
  backup_dir="${BACKUP_DIR:-./backups/postgres}"
  postgres_dump="$(find "${backup_dir}" -maxdepth 1 -type f -name 'postgres-*.dump' 2>/dev/null | sort | tail -n 1 || true)"
fi

if [[ "${skip_postgres_restore}" != "true" ]]; then
  if [[ -z "${postgres_dump}" ]]; then
    echo "[restore-all] dump Postgres não informado e nenhum backup encontrado em BACKUP_DIR."
    exit 1
  fi
  if [[ ! -f "${postgres_dump}" || ! -s "${postgres_dump}" ]]; then
    echo "[restore-all] dump Postgres inválido: ${postgres_dump}"
    exit 1
  fi
fi

VOLUMES=(
  your_app_agent_prod_postgres_data
  your_app_agent_prod_redis_data
  your_app_agent_prod_tempo_data
  your_app_agent_prod_loki_data
  your_app_agent_prod_grafana_data
  your_app_agent_prod_prometheus_data
  your_app_agent_prod_alertmanager_data
  your_app_agent_prod_pgadmin_data
  your_app_agent_prod_redisinsight_data
  your_app_agent_prod_langfuse_clickhouse_data
  your_app_agent_prod_langfuse_clickhouse_logs
  your_app_agent_prod_langfuse_minio_data
)

CRITICAL_DB_VOLUMES=(
  your_app_agent_prod_postgres_data
  your_app_agent_prod_redis_data
  your_app_agent_prod_langfuse_clickhouse_data
  your_app_agent_prod_langfuse_minio_data
)

echo "[restore-all] removing stacks ${STACK_NAME} and ${MAIL_STACK_NAME} to stop writes..."
docker stack rm "${STACK_NAME}" >/dev/null 2>&1 || true
docker stack rm "${MAIL_STACK_NAME}" >/dev/null 2>&1 || true

wait_for_stack_containers_to_stop "${STACK_NAME}" "${restore_wait_timeout}"
wait_for_stack_containers_to_stop "${MAIL_STACK_NAME}" "${restore_wait_timeout}" || true

for vol in "${VOLUMES[@]}"; do
  archive="${snapshot_dir}/${vol}.tar.gz"
  if [[ ! -f "${archive}" ]]; then
    if printf '%s\n' "${CRITICAL_DB_VOLUMES[@]}" | grep -qx "${vol}"; then
      echo "[restore-all] missing REQUIRED DB archive: ${archive}"
      exit 1
    fi
    echo "[restore-all] warning: optional archive missing, skipping ${vol}"
    continue
  fi
  restore_volume_archive "${snapshot_dir}" "${vol}"
done

mail_archive="${snapshot_dir}/mailserver-data.tar.gz"
if [[ -f "${mail_archive}" ]]; then
  if [[ "${skip_mail_restore}" == "true" ]]; then
    echo "[restore-all] skipping mail restore (--skip-mail-restore)."
  else
    mail_data_dir="${MAIL_DATA_DIR:-}"
    if [[ -n "${mail_data_dir}" ]]; then
      if [[ "${mail_data_dir}" == "/" ]]; then
        echo "[restore-all] refusing to restore mail data into '/'. Check MAIL_DATA_DIR."
        exit 1
      fi
      echo "[restore-all] restoring mail bind mount into ${mail_data_dir}..."

      # Use a root container so host ownership/permissions do not block restore.
      docker run --rm \
        -v "${mail_data_dir}":/mail \
        -v "${snapshot_dir}":/backup:ro \
        alpine \
        sh -euc 'rm -rf /mail/* /mail/.[!.]* /mail/..?* 2>/dev/null || true; tar xzf /backup/mailserver-data.tar.gz -C /mail'
    else
      echo "[restore-all] MAIL_DATA_DIR vazio; skipping mail restore."
    fi
  fi
fi

echo "[restore-all] re-deploying ${STACK_NAME} (pre-migrations)..."
docker stack deploy -c stack.yml "${STACK_NAME}"

wait_for_postgres_ready "${STACK_NAME}" "${postgres_user}" "${postgres_db}" "${restore_wait_timeout}"

if [[ "${skip_postgres_restore}" != "true" ]]; then
  echo "[restore-all] restoring Postgres dump: ${postgres_dump}"
  ./scripts/restore-postgres.sh "${postgres_dump}"
fi

echo "[restore-all] restore completed. You can now run migrations and deploy application updates."
