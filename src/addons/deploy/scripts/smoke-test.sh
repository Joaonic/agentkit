#!/usr/bin/env bash
# deploy/scripts/smoke-test.sh — Post-migration smoke test (Compose → Swarm).
# Épico: #204 | Issue: #213
#
# Validates the full stack after migrating to Docker Swarm:
#   1. Swarm services converged (replicas N/N)
#   2. API healthcheck (internal + HTTPS)
#   3. Postgres data integrity (row counts on critical tables)
#   4. Observability UIs (Grafana, Langfuse)
#   5. Admin tools (PgAdmin, RedisInsight)
#   6. CD pipeline readiness
#
# Usage:
#   cd deploy && ./scripts/smoke-test.sh [--skip-https] [--skip-data] [--baseline <file>]
#
# --skip-https    Skip external HTTPS checks (useful on local/staging).
# --skip-data     Skip Postgres row-count comparison.
# --baseline FILE Compare row counts against a baseline JSON file.
set -euo pipefail

SKIP_HTTPS=false
SKIP_DATA=false
BASELINE_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-https) SKIP_HTTPS=true; shift ;;
    --skip-data)  SKIP_DATA=true; shift ;;
    --baseline)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "[smoke] Error: --baseline requires a file argument"; exit 1
      fi
      BASELINE_FILE="$2"; shift 2 ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
done

if [[ ! -f .env ]]; then
  echo "[smoke] .env not found in deploy/."
  exit 1
fi

set -a
# shellcheck source=/dev/null
source .env
set +a

STACK_NAME="${STACK_NAME:-app}"
pass=0
fail=0
warn=0

check_pass() { echo "  ✅ $1"; pass=$((pass + 1)); }
check_fail() { echo "  ❌ $1"; fail=$((fail + 1)); }
check_warn() { echo "  ⚠️  $1"; warn=$((warn + 1)); }

echo "============================================"
echo " Post-migration Smoke Test"
echo " $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo " Stack: ${STACK_NAME}"
echo "============================================"
echo ""

# -----------------------------------------------------------------------
# 1. Swarm service convergence
# -----------------------------------------------------------------------
echo "[1/7] Swarm services — replicas"
while IFS=' ' read -r svc_name svc_replicas; do
  current="${svc_replicas%%/*}"
  desired="${svc_replicas##*/}"
  if [[ "${desired}" == "0" ]]; then
    check_warn "${svc_name}: ${svc_replicas} (scaled to 0)"
  elif [[ "${current}" == "${desired}" ]]; then
    check_pass "${svc_name}: ${svc_replicas}"
  else
    check_fail "${svc_name}: ${svc_replicas} (not converged)"
  fi
done < <(docker service ls --filter "name=${STACK_NAME}_" --format '{{.Name}} {{.Replicas}}')

# Also check mail stack if deployed.
mail_stack="${MAIL_STACK_NAME:-app-mail}"
mail_services="$(docker service ls --filter "name=${mail_stack}_" --format '{{.Name}} {{.Replicas}}' 2>/dev/null || true)"
if [[ -n "${mail_services}" ]]; then
  while IFS=' ' read -r svc_name svc_replicas; do
    current="${svc_replicas%%/*}"
    desired="${svc_replicas##*/}"
    if [[ "${current}" == "${desired}" ]]; then
      check_pass "${svc_name}: ${svc_replicas}"
    else
      check_fail "${svc_name}: ${svc_replicas} (not converged)"
    fi
  done <<< "${mail_services}"
fi

# -----------------------------------------------------------------------
# 2. API task health
# -----------------------------------------------------------------------
echo ""
echo "[2/7] API task state"
task_ok=0
task_bad=0
while IFS= read -r task_state; do
  if [[ "${task_state}" == Running* ]]; then
    task_ok=$((task_ok + 1))
  else
    task_bad=$((task_bad + 1))
  fi
done < <(docker service ps "${STACK_NAME}_api" --filter "desired-state=running" --format '{{.CurrentState}}' 2>/dev/null || true)

if (( task_ok > 0 && task_bad == 0 )); then
  check_pass "API tasks: ${task_ok} running, ${task_bad} failed"
elif (( task_ok > 0 )); then
  check_warn "API tasks: ${task_ok} running, ${task_bad} failed"
else
  check_fail "API tasks: no running tasks found"
fi

# -----------------------------------------------------------------------
# 3. API healthcheck (internal via Docker network)
# -----------------------------------------------------------------------
echo ""
echo "[3/7] API health (internal)"

# Find the API container
api_container="$(docker ps --filter "label=com.docker.swarm.service.name=${STACK_NAME}_api" --format '{{.ID}}' | head -n 1)"
if [[ -n "${api_container}" ]]; then
  api_port="${API_PORT:-3001}"
  health_response="$(docker exec "${api_container}" wget -qO- "http://127.0.0.1:${api_port}/health" 2>/dev/null || echo '{}')"
  if echo "${health_response}" | grep -q '"ok"'; then
    check_pass "GET /health → OK"
  else
    check_fail "GET /health → unexpected response: ${health_response}"
  fi

  if docker exec "${api_container}" wget -qO- "http://127.0.0.1:${api_port}/health/ready" >/dev/null 2>&1; then
    check_pass "GET /health/ready → OK"
  else
    check_fail "GET /health/ready → failed"
  fi
else
  check_fail "API container not found — cannot run internal healthcheck"
fi

# -----------------------------------------------------------------------
# 4. HTTPS external checks
# -----------------------------------------------------------------------
echo ""
echo "[4/7] HTTPS endpoints"
if [[ "${SKIP_HTTPS}" == "true" ]]; then
  check_warn "HTTPS checks skipped (--skip-https)"
else
  api_domain="${API_DOMAIN:-}"
  if [[ -n "${api_domain}" ]]; then
    http_code="$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 10 --max-time 30 "https://${api_domain}/health" 2>/dev/null || echo '000')"
    if [[ "${http_code}" =~ ^2[0-9][0-9]$ ]]; then
      check_pass "https://${api_domain}/health → ${http_code}"
    else
      check_fail "https://${api_domain}/health → ${http_code}"
    fi
  else
    check_warn "API_DOMAIN not set — skipping HTTPS check"
  fi

  grafana_domain="${GRAFANA_DOMAIN:-}"
  if [[ -n "${grafana_domain}" ]]; then
    http_code="$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 10 --max-time 30 "https://${grafana_domain}/login" 2>/dev/null || echo '000')"
    if [[ "${http_code}" =~ ^[23][0-9][0-9]$ ]]; then
      check_pass "https://${grafana_domain}/login → ${http_code}"
    else
      check_fail "https://${grafana_domain}/login → ${http_code}"
    fi
  fi

  langfuse_domain="${LANGFUSE_DOMAIN:-}"
  if [[ -n "${langfuse_domain}" ]]; then
    http_code="$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 10 --max-time 30 "https://${langfuse_domain}" 2>/dev/null || echo '000')"
    if [[ "${http_code}" =~ ^[23][0-9][0-9]$ ]]; then
      check_pass "https://${langfuse_domain} → ${http_code}"
    else
      check_fail "https://${langfuse_domain} → ${http_code}"
    fi
  fi
fi

# -----------------------------------------------------------------------
# 5. Postgres data integrity (row counts on critical tables)
# -----------------------------------------------------------------------
echo ""
echo "[5/7] Postgres data integrity"
if [[ "${SKIP_DATA}" == "true" ]]; then
  check_warn "Data integrity checks skipped (--skip-data)"
else
  pg_container="$(docker ps --filter "label=com.docker.swarm.service.name=${STACK_NAME}_postgres" --format '{{.ID}}' | head -n 1)"
  if [[ -z "${pg_container}" ]]; then
    check_fail "Postgres container not found"
  else
    postgres_user="${POSTGRES_USER:-postgres}"
    postgres_db="${POSTGRES_DB:-whatsapp_sales_agent}"
    critical_tables=("tenants" "conversations" "messages" "orders")

    counts_json="{"
    for table in "${critical_tables[@]}"; do
      count="$(docker exec -i "${pg_container}" psql -U "${postgres_user}" -d "${postgres_db}" -tAc "SELECT count(*) FROM \"${table}\";" 2>/dev/null || echo '-1')"
      count="$(echo "${count}" | tr -d '[:space:]')"
      if [[ "${count}" == "-1" ]]; then
        check_warn "Table ${table}: query failed (table may not exist yet)"
      else
        check_pass "Table ${table}: ${count} rows"
      fi
      counts_json="${counts_json}\"${table}\":${count},"
    done
    counts_json="${counts_json%,}}"

    # Save current counts for future comparison
    counts_file="./backups/row-counts-$(date -u +%Y%m%d-%H%M%S).json"
    mkdir -p "$(dirname "${counts_file}")"
    echo "${counts_json}" > "${counts_file}"
    echo "     Row counts saved to: ${counts_file}"

    # Compare with baseline if provided
    if [[ -n "${BASELINE_FILE}" && -f "${BASELINE_FILE}" ]]; then
      echo "     Comparing with baseline: ${BASELINE_FILE}"
      mismatch=0
      for table in "${critical_tables[@]}"; do
        baseline_count="$(grep -o "\"${table}\":[0-9]*" "${BASELINE_FILE}" 2>/dev/null | grep -o '[0-9]*$' || echo '-1')"
        current_count="$(grep -o "\"${table}\":[0-9]*" "${counts_file}" 2>/dev/null | grep -o '[0-9]*$' || echo '-1')"
        if [[ "${baseline_count}" != "-1" && "${current_count}" != "-1" ]]; then
          if [[ "${baseline_count}" == "${current_count}" ]]; then
            check_pass "Table ${table}: baseline=${baseline_count} current=${current_count} — match"
          else
            check_fail "Table ${table}: baseline=${baseline_count} current=${current_count} — MISMATCH"
            mismatch=$((mismatch + 1))
          fi
        fi
      done
      if (( mismatch > 0 )); then
        check_fail "Data mismatch detected — potential data loss!"
      fi
    fi
  fi
fi

# -----------------------------------------------------------------------
# 6. Observability & admin tools (internal healthchecks)
# -----------------------------------------------------------------------
echo ""
echo "[6/7] Internal service healthchecks"

declare -A service_checks=(
  ["grafana"]="wget -qO- http://127.0.0.1:3000/api/health"
  ["langfuse-web"]="wget -qO- http://127.0.0.1:3000/api/public/health"
  ["tempo"]="wget -qO- http://127.0.0.1:3200/ready"
  ["loki"]="wget -qO- http://127.0.0.1:3100/ready"
  ["prometheus"]="wget -qO- http://127.0.0.1:9090/-/healthy"
  ["alertmanager"]="wget -qO- http://127.0.0.1:9093/-/healthy"
  ["pgadmin"]="wget -qO- http://127.0.0.1:80/misc/ping"
)

for svc in "${!service_checks[@]}"; do
  container="$(docker ps --filter "label=com.docker.swarm.service.name=${STACK_NAME}_${svc}" --format '{{.ID}}' | head -n 1)"
  if [[ -z "${container}" ]]; then
    check_warn "${svc}: container not found (may not be deployed)"
    continue
  fi

  if docker exec "${container}" sh -c "${service_checks[${svc}]}" >/dev/null 2>&1; then
    check_pass "${svc}: internal healthcheck OK"
  else
    check_fail "${svc}: internal healthcheck FAILED"
  fi
done

# -----------------------------------------------------------------------
# 7. CD pipeline readiness
# -----------------------------------------------------------------------
echo ""
echo "[7/7] CD pipeline readiness"

# Verify deploy.sh can detect Swarm active
if docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -q 'active'; then
  check_pass "Swarm active (CD deploy.sh will work)"
else
  check_fail "Swarm not active (CD deploy.sh will fail)"
fi

# Verify GHCR login
if docker pull "${API_IMAGE:-ghcr.io/placeholder}:${API_IMAGE_TAG:-latest}" >/dev/null 2>&1; then
  check_pass "Can pull API image (GHCR auth OK)"
else
  check_warn "Cannot pull API image — may need docker login ghcr.io"
fi

# Verify stack.yml present
if [[ -f stack.yml ]]; then
  check_pass "stack.yml present"
else
  check_fail "stack.yml missing — CD will fail"
fi

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------
echo ""
echo "============================================"
echo " Smoke Test Results: ${pass} pass, ${warn} warnings, ${fail} FAILED"
echo "============================================"

if (( fail > 0 )); then
  echo ""
  echo "⛔ Smoke test FAILED. Review failures above."
  echo "   If critical, consider rollback:"
  echo "     docker stack rm ${STACK_NAME}"
  echo "     sleep 30"
  echo "     docker swarm leave --force"
  echo "     docker compose up -d"
  exit 1
fi

if (( warn > 0 )); then
  echo ""
  echo "⚠️  Smoke test passed with warnings."
  exit 0
fi

echo ""
echo "✅ All smoke tests passed. Migration successful!"
