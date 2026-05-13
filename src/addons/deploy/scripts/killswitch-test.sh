#!/usr/bin/env bash
# deploy/scripts/killswitch-test.sh — Validate Swarm HA failover
#
# Usage:
#   ./killswitch-test.sh --test manager   # Test manager failover
#   ./killswitch-test.sh --test worker    # Test worker failover
#   ./killswitch-test.sh --test all       # Test both (sequential)
#
# Prerequisites:
#   - Multi-node Swarm cluster running (≥ 3 managers, ≥ 2 workers)
#   - SSH access to all nodes (ssh keys configured)
#   - Must be run FROM a manager node (or machine with docker access to swarm)
#   - API_HEALTH_URL environment variable set (default: http://localhost:3001/health/ready)
#
# Issues: #217, #219 | Runbook: docs/operations/runbooks/docker-swarm-multinode.md §9

set -euo pipefail

# --- Configuration ---
API_HEALTH_URL="${API_HEALTH_URL:-http://localhost:3001/health/ready}"
MANAGER_FAILOVER_TIMEOUT=30    # seconds — acceptance criteria
WORKER_RESCHEDULE_TIMEOUT=60   # seconds — acceptance criteria
RECOVERY_WAIT=120              # seconds — wait for node to rejoin after restart

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[FAIL]${NC} $*"; }

# --- Helpers ---

get_nodes_by_role() {
  local role="$1"
  docker node ls --filter "role=$role" --format '{{.Hostname}}' 2>/dev/null
}

get_non_leader_manager() {
  docker node ls --filter "role=manager" --format '{{.Hostname}} {{.ManagerStatus}}' | \
    grep -v "Leader" | head -1 | awk '{print $1}'
}

get_first_worker() {
  docker node ls --filter "role=worker" --format '{{.Hostname}}' | head -1
}

check_health() {
  curl -sf --max-time 5 "$API_HEALTH_URL" > /dev/null 2>&1
}

wait_for_health() {
  local timeout="$1"
  local start elapsed
  start=$(date +%s)
  while true; do
    elapsed=$(( $(date +%s) - start ))
    if [ "$elapsed" -ge "$timeout" ]; then
      return 1
    fi
    if check_health; then
      echo "$elapsed"
      return 0
    fi
    sleep 1
  done
}

count_running_tasks() {
  local service="$1"
  docker service ps "$service" --filter "desired-state=running" --format '{{.ID}}' | wc -l | tr -d ' '
}

# --- Test: Manager Failover ---

test_manager_failover() {
  info "=== TEST: Manager Failover (acceptance: < ${MANAGER_FAILOVER_TIMEOUT}s) ==="

  local managers
  managers=$(get_nodes_by_role manager | wc -l | tr -d ' ')
  if [ "$managers" -lt 3 ]; then
    error "Need at least 3 managers for failover test. Found: $managers"
    return 1
  fi

  local target
  target=$(get_non_leader_manager)
  if [ -z "$target" ]; then
    error "Could not find a non-leader manager to stop."
    return 1
  fi

  info "Target node: $target (non-leader manager)"
  info "Pre-test: verifying API health..."
  if ! check_health; then
    error "API not healthy before test. Aborting."
    return 1
  fi
  info "API healthy. Stopping Docker on $target..."

  # Stop docker on the target node
  ssh "deploy@$target" "sudo systemctl stop docker" || {
    error "Failed to stop docker on $target"
    return 1
  }

  info "Docker stopped on $target. Waiting for cluster to detect..."
  sleep 5

  # Check node status
  local node_status
  node_status=$(docker node ls --format '{{.Hostname}} {{.Status}}' | grep "$target" | awk '{print $2}')
  info "Node $target status: $node_status"

  # Verify API still healthy
  info "Verifying API remains healthy..."
  local recovery_time
  if recovery_time=$(wait_for_health "$MANAGER_FAILOVER_TIMEOUT"); then
    info "✅ API healthy after ${recovery_time}s (< ${MANAGER_FAILOVER_TIMEOUT}s threshold)"
  else
    error "❌ API not healthy within ${MANAGER_FAILOVER_TIMEOUT}s after manager stop"
    # Still try to recover
    warn "Restoring node $target..."
    ssh "deploy@$target" "sudo systemctl start docker" || true
    return 1
  fi

  # Check quorum
  local ready_managers
  ready_managers=$(docker node ls --filter "role=manager" --format '{{.Status}}' | grep -c "Ready" || true)
  info "Managers ready: $ready_managers / $managers"

  # Restore
  info "Restoring Docker on $target..."
  ssh "deploy@$target" "sudo systemctl start docker"
  info "Waiting ${RECOVERY_WAIT}s for node to rejoin..."
  sleep "$RECOVERY_WAIT"

  # Verify full cluster health
  local final_ready
  final_ready=$(docker node ls --filter "role=manager" --format '{{.Status}}' | grep -c "Ready" || true)
  if [ "$final_ready" -eq "$managers" ]; then
    info "✅ All $managers managers back to Ready state"
  else
    warn "Only $final_ready / $managers managers ready after recovery"
  fi

  info "=== Manager Failover Test: PASSED ==="
  return 0
}

# --- Test: Worker Failover ---

test_worker_failover() {
  info "=== TEST: Worker Failover (acceptance: tasks rescheduled < ${WORKER_RESCHEDULE_TIMEOUT}s) ==="

  local workers
  workers=$(get_nodes_by_role worker | wc -l | tr -d ' ')
  if [ "$workers" -lt 2 ]; then
    error "Need at least 2 workers for failover test. Found: $workers"
    return 1
  fi

  local target
  target=$(get_first_worker)
  if [ -z "$target" ]; then
    error "Could not find a worker to stop."
    return 1
  fi

  info "Target node: $target"

  # Get initial task count on the API service
  local service_name="app_api"
  local initial_tasks
  initial_tasks=$(count_running_tasks "$service_name")
  info "API service running tasks before test: $initial_tasks"

  # Count tasks on target node
  local tasks_on_target
  tasks_on_target=$(docker service ps "$service_name" --filter "node=$target" --filter "desired-state=running" --format '{{.ID}}' | wc -l | tr -d ' ')
  info "Tasks on $target: $tasks_on_target"

  info "Pre-test: verifying API health..."
  if ! check_health; then
    error "API not healthy before test. Aborting."
    return 1
  fi

  info "Stopping Docker on $target..."
  ssh "deploy@$target" "sudo systemctl stop docker" || {
    error "Failed to stop docker on $target"
    return 1
  }

  info "Docker stopped. Waiting for tasks to reschedule..."
  local start elapsed
  start=$(date +%s)
  local rescheduled=false

  while true; do
    elapsed=$(( $(date +%s) - start ))
    if [ "$elapsed" -ge "$WORKER_RESCHEDULE_TIMEOUT" ]; then
      break
    fi

    local current_tasks
    current_tasks=$(count_running_tasks "$service_name")
    if [ "$current_tasks" -ge "$initial_tasks" ]; then
      rescheduled=true
      break
    fi
    sleep 2
  done

  if [ "$rescheduled" = true ]; then
    info "✅ Tasks rescheduled in ${elapsed}s (< ${WORKER_RESCHEDULE_TIMEOUT}s threshold)"
  else
    error "❌ Tasks not fully rescheduled within ${WORKER_RESCHEDULE_TIMEOUT}s"
    warn "Current running tasks: $(count_running_tasks "$service_name") / $initial_tasks expected"
  fi

  # Verify API health
  if check_health; then
    info "✅ API remains healthy after worker failure"
  else
    warn "API health check failed — may need more time for tasks to start"
  fi

  # Restore
  info "Restoring Docker on $target..."
  ssh "deploy@$target" "sudo systemctl start docker"
  info "Waiting ${RECOVERY_WAIT}s for node to rejoin..."
  sleep "$RECOVERY_WAIT"

  # Verify
  local final_workers
  final_workers=$(docker node ls --filter "role=worker" --format '{{.Status}}' | grep -c "Ready" || true)
  if [ "$final_workers" -eq "$workers" ]; then
    info "✅ All $workers workers back to Ready state"
  else
    warn "Only $final_workers / $workers workers ready after recovery"
  fi

  if [ "$rescheduled" = true ]; then
    info "=== Worker Failover Test: PASSED ==="
    return 0
  else
    error "=== Worker Failover Test: FAILED ==="
    return 1
  fi
}

# --- Main ---

usage() {
  cat <<EOF
Usage: $0 --test <manager|worker|all>

Options:
  --test manager   Test manager node failover (acceptance: < 30s)
  --test worker    Test worker node failover (acceptance: tasks rescheduled < 60s)
  --test all       Run both tests sequentially

Environment:
  API_HEALTH_URL   URL to check API health (default: http://localhost:3001/health/ready)

Prerequisites:
  - Multi-node Swarm (≥ 3 managers, ≥ 2 workers)
  - SSH access: ssh deploy@<node-hostname>
  - Run from a manager node
EOF
  exit 1
}

main() {
  local test_type=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --test)
        test_type="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        ;;
      *)
        error "Unknown argument: $1"
        usage
        ;;
    esac
  done

  if [ -z "$test_type" ]; then
    usage
  fi

  info "Killswitch test started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  info "API health URL: $API_HEALTH_URL"
  echo ""

  local exit_code=0

  case "$test_type" in
    manager)
      test_manager_failover || exit_code=1
      ;;
    worker)
      test_worker_failover || exit_code=1
      ;;
    all)
      test_manager_failover || exit_code=1
      echo ""
      info "Waiting 30s between tests..."
      sleep 30
      echo ""
      test_worker_failover || exit_code=1
      ;;
    *)
      error "Unknown test type: $test_type"
      usage
      ;;
  esac

  echo ""
  if [ "$exit_code" -eq 0 ]; then
    info "🎉 All killswitch tests PASSED"
  else
    error "💥 One or more killswitch tests FAILED"
  fi

  exit "$exit_code"
}

main "$@"
