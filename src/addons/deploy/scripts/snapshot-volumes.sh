#!/usr/bin/env bash
# deploy/scripts/snapshot-volumes.sh — Snapshot all named Docker volumes to tar.gz.
# Épico: #204 | Issue: #213
#
# Usage:
#   cd deploy && ./scripts/snapshot-volumes.sh [backup_dir]
#
# Backs up every named volume used by the app and app-mail stacks.
# Each volume is exported as <volume_name>.tar.gz in the backup directory.
# Designed to run BEFORE the Compose→Swarm migration (containers can be running
# or stopped — uses a temporary alpine container to read the volume).
set -euo pipefail

BACKUP_DIR="${1:-./backups/volumes}"
TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_DIR}/${TIMESTAMP}"

# Named volumes from stack.yml and stack-mail.yml.
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

echo "[snapshot] backup dir: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

failed=0
skipped=0
success=0

for vol in "${VOLUMES[@]}"; do
  if ! docker volume inspect "${vol}" >/dev/null 2>&1; then
    echo "[snapshot] SKIP: volume '${vol}' does not exist."
    skipped=$((skipped + 1))
    continue
  fi

  archive="${BACKUP_DIR}/${vol}.tar.gz"
  echo "[snapshot] backing up ${vol} → ${archive} …"

  if docker run --rm \
    -v "${vol}":/data:ro \
    -v "$(cd "${BACKUP_DIR}" && pwd)":/backup \
    alpine \
    tar czf "/backup/${vol}.tar.gz" -C /data .; then
    size="$(du -sh "${archive}" | awk '{print $1}')"
    echo "[snapshot] OK: ${vol} (${size})"
    success=$((success + 1))
  else
    echo "[snapshot] FAIL: ${vol}"
    failed=$((failed + 1))
  fi
done

# Mail stack uses bind mounts — snapshot if directory exists.
if [[ -f .env ]]; then
  mail_data_dir="$(awk -F= '/^MAIL_DATA_DIR=/{print $2}' .env | tail -n 1 | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")"
  if [[ -n "${mail_data_dir}" && -d "${mail_data_dir}" ]]; then
    archive="${BACKUP_DIR}/mailserver-data.tar.gz"
    echo "[snapshot] backing up mail data (${mail_data_dir}) → ${archive} …"
    if tar czf "${archive}" -C "${mail_data_dir}" .; then
      size="$(du -sh "${archive}" | awk '{print $1}')"
      echo "[snapshot] OK: mailserver-data (${size})"
      success=$((success + 1))
    else
      echo "[snapshot] FAIL: mailserver-data"
      failed=$((failed + 1))
    fi
  fi
fi

echo ""
echo "[snapshot] ======================================="
echo "[snapshot] Summary: ${success} OK, ${skipped} skipped, ${failed} FAILED"
echo "[snapshot] Backup dir: ${BACKUP_DIR}"
echo "[snapshot] ======================================="

if (( failed > 0 )); then
  exit 1
fi

echo "[snapshot] all volume snapshots completed successfully."
