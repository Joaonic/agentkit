#!/usr/bin/env bash
# deploy/scripts/pre-migration-check.sh — Pre-migration validation for Compose→Swarm.
# Épico: #204 | Issue: #213
#
# Validates that all prerequisites are met before starting the migration.
# Run this on the VPS BEFORE stopping Compose:
#   cd deploy && ./scripts/pre-migration-check.sh
#
# Exit 0 = all checks pass. Exit 1 = at least one check failed.
set -euo pipefail

pass=0
fail=0
warn=0

check_pass() { echo "  ✅ $1"; pass=$((pass + 1)); }
check_fail() { echo "  ❌ $1"; fail=$((fail + 1)); }
check_warn() { echo "  ⚠️  $1"; warn=$((warn + 1)); }

echo "============================================"
echo " Pre-migration check — Compose → Swarm"
echo " $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "============================================"
echo ""

# -----------------------------------------------------------------------
# 1. Environment file
# -----------------------------------------------------------------------
echo "[1/9] Environment file"
if [[ -f .env ]]; then
  check_pass ".env exists"
else
  check_fail ".env not found in deploy/ — aborting remaining checks."
  echo ""
  echo "Result: 0 pass, 1 fail"
  exit 1
fi

set -a
# shellcheck source=/dev/null
source .env
set +a

# -----------------------------------------------------------------------
# 2. Docker Engine
# -----------------------------------------------------------------------
echo ""
echo "[2/9] Docker Engine"
if command -v docker >/dev/null 2>&1; then
  docker_version="$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'unknown')"
  check_pass "Docker Engine installed (${docker_version})"
else
  check_fail "Docker Engine not found"
fi

# Swarm should NOT be active yet (we're checking pre-migration state).
swarm_state="$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo 'unknown')"
if [[ "${swarm_state}" == "inactive" ]]; then
  check_pass "Swarm is inactive (expected — will be initialized during migration)"
elif [[ "${swarm_state}" == "active" ]]; then
  check_warn "Swarm is already active — if re-running, this is OK"
else
  check_fail "Cannot determine Swarm state: ${swarm_state}"
fi

# -----------------------------------------------------------------------
# 3. Compose stack state
# -----------------------------------------------------------------------
echo ""
echo "[3/9] Current Compose stack"
if docker compose version >/dev/null 2>&1; then
  check_pass "Docker Compose plugin available"
else
  check_warn "Docker Compose plugin not found — OK if already migrated"
fi

running_containers="$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l | tr -d ' ')"
echo "     Running containers: ${running_containers}"

# -----------------------------------------------------------------------
# 4. Named volumes exist
# -----------------------------------------------------------------------
echo ""
echo "[4/9] Named volumes"
REQUIRED_VOLUMES=(
  your_app_agent_prod_postgres_data
  your_app_agent_prod_redis_data
  your_app_agent_prod_grafana_data
)

OPTIONAL_VOLUMES=(
  your_app_agent_prod_tempo_data
  your_app_agent_prod_loki_data
  your_app_agent_prod_pgadmin_data
  your_app_agent_prod_redisinsight_data
  your_app_agent_prod_langfuse_clickhouse_data
  your_app_agent_prod_langfuse_clickhouse_logs
  your_app_agent_prod_langfuse_minio_data
)

for vol in "${REQUIRED_VOLUMES[@]}"; do
  if docker volume inspect "${vol}" >/dev/null 2>&1; then
    check_pass "Volume ${vol}"
  else
    check_fail "Volume ${vol} MISSING — data loss risk!"
  fi
done

for vol in "${OPTIONAL_VOLUMES[@]}"; do
  if docker volume inspect "${vol}" >/dev/null 2>&1; then
    check_pass "Volume ${vol}"
  else
    check_warn "Volume ${vol} not found (optional)"
  fi
done

# -----------------------------------------------------------------------
# 5. Backups
# -----------------------------------------------------------------------
echo ""
echo "[5/9] Backups"
backup_dir="${BACKUP_DIR:-./backups/postgres}"
latest_pg_backup="$(find "${backup_dir}" -maxdepth 1 -name 'postgres-*.dump' -type f 2>/dev/null | sort -r | head -n 1)"
if [[ -n "${latest_pg_backup}" && -s "${latest_pg_backup}" ]]; then
  backup_age_sec="$(( $(date +%s) - $(stat -c %Y "${latest_pg_backup}" 2>/dev/null || stat -f %m "${latest_pg_backup}" 2>/dev/null || echo 0) ))"
  backup_age_hours="$(( backup_age_sec / 3600 ))"
  check_pass "Postgres backup found: $(basename "${latest_pg_backup}") (${backup_age_hours}h ago)"
  if (( backup_age_hours > 1 )); then
    check_warn "Backup is older than 1 hour — consider running ./scripts/backup-postgres.sh"
  fi
else
  check_fail "No Postgres backup found in ${backup_dir} — run ./scripts/backup-postgres.sh first!"
fi

# Check volume snapshots
vol_backup_dir="${VOL_BACKUP_DIR:-./backups/volumes}"
if [[ -d "${vol_backup_dir}" ]]; then
  vol_snapshot_count="$(find "${vol_backup_dir}" -name '*.tar.gz' -type f 2>/dev/null | wc -l | tr -d ' ')"
  if (( vol_snapshot_count > 0 )); then
    check_pass "Volume snapshots found: ${vol_snapshot_count} archive(s) in ${vol_backup_dir}"
  else
    check_fail "Volume snapshot dir exists but no .tar.gz files — run ./scripts/snapshot-volumes.sh"
  fi
else
  check_fail "No volume snapshots found — run ./scripts/snapshot-volumes.sh first!"
fi

# -----------------------------------------------------------------------
# 6. Disk space
# -----------------------------------------------------------------------
echo ""
echo "[6/9] Disk space"
# Docker data root
docker_root="$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || echo '/var/lib/docker')"
avail_kb="$(df -k "${docker_root}" 2>/dev/null | awk 'NR==2{print $4}')"
if [[ -n "${avail_kb}" ]]; then
  avail_gb="$(( avail_kb / 1048576 ))"
  if (( avail_gb >= 10 )); then
    check_pass "Disk space: ${avail_gb} GB available on ${docker_root}"
  elif (( avail_gb >= 5 )); then
    check_warn "Disk space: only ${avail_gb} GB available on ${docker_root}"
  else
    check_fail "Disk space: only ${avail_gb} GB available on ${docker_root} — need at least 5 GB"
  fi
else
  check_warn "Could not determine disk space"
fi

# -----------------------------------------------------------------------
# 7. Required scripts and files
# -----------------------------------------------------------------------
echo ""
echo "[7/9] Required files"
required_files=(
  stack.yml
  scripts/bootstrap.sh
  scripts/deploy.sh
  scripts/healthcheck.sh
  scripts/rollback.sh
  scripts/validate-env.sh
  scripts/backup-postgres.sh
  scripts/restore-postgres.sh
  scripts/snapshot-volumes.sh
  scripts/smoke-test.sh
  scripts/lib/migrations.sh
  scripts/lib/secrets.sh
)

for f in "${required_files[@]}"; do
  if [[ -f "${f}" ]]; then
    check_pass "${f}"
  else
    check_fail "${f} MISSING"
  fi
done

# -----------------------------------------------------------------------
# 8. Network interfaces
# -----------------------------------------------------------------------
echo ""
echo "[8/9] Network"
primary_ip="$(hostname -I 2>/dev/null | awk '{print $1}' || echo '')"
if [[ -n "${primary_ip}" ]]; then
  check_pass "Primary IP: ${primary_ip} (will be used for swarm init --advertise-addr)"
else
  check_warn "Could not detect primary IP address"
fi

# Check required ports are not in use by non-Docker processes
for port in 2377 7946 4789; do
  if ss -tlnp 2>/dev/null | grep -q ":${port} " || netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
    check_warn "Port ${port} already in use (expected if Swarm is already active)"
  else
    check_pass "Port ${port} available (Swarm)"
  fi
done

# -----------------------------------------------------------------------
# 9. Environment validation
# -----------------------------------------------------------------------
echo ""
echo "[9/9] Environment validation"
if ./scripts/validate-env.sh >/dev/null 2>&1; then
  check_pass "validate-env.sh passed"
else
  check_fail "validate-env.sh failed — fix .env before migrating!"
fi

# Secrets directory
secrets_dir="${SECRETS_DIR:-/home/ubuntu/wp/your-app/secrets}"
if [[ -d "${secrets_dir}" ]]; then
  secret_count="$(find "${secrets_dir}" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
  check_pass "Secrets dir: ${secrets_dir} (${secret_count} files)"
else
  check_warn "Secrets dir ${secrets_dir} not found — secrets mode disabled"
fi

# API image pullable
image="${API_IMAGE:-}:${API_IMAGE_TAG:-}"
if [[ -n "${API_IMAGE:-}" && -n "${API_IMAGE_TAG:-}" ]]; then
  if docker image inspect "${image}" >/dev/null 2>&1; then
    check_pass "API image available locally: ${image}"
  else
    echo "     Pulling API image: ${image} …"
    if docker pull "${image}" >/dev/null 2>&1; then
      check_pass "API image pulled: ${image}"
    else
      check_fail "Cannot pull API image: ${image}"
    fi
  fi
else
  check_fail "API_IMAGE or API_IMAGE_TAG not set in .env"
fi

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------
echo ""
echo "============================================"
echo " Results: ${pass} pass, ${warn} warnings, ${fail} FAILED"
echo "============================================"

if (( fail > 0 )); then
  echo ""
  echo "⛔ Pre-migration check FAILED. Fix the issues above before proceeding."
  exit 1
fi

if (( warn > 0 )); then
  echo ""
  echo "⚠️  Pre-migration check passed with warnings. Review them before proceeding."
  exit 0
fi

echo ""
echo "✅ All pre-migration checks passed. Ready to migrate!"
