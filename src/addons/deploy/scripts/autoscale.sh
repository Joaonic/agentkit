#!/usr/bin/env bash
# deploy/scripts/autoscale.sh — Horizontal auto-scaling for Docker Swarm.
# Reads deploy/autoscale.yml, collects CPU/mem via `docker stats`, and
# executes `docker service scale` within configured bounds + cooldowns.
#
# Issue: #223 | Epic: #204
#
# Dependencies: bash ≥ 4, bc, yq (or python3-yaml fallback), docker CLI.
#
# Usage:
#   ./autoscale.sh              # normal mode
#   ./autoscale.sh --dry-run    # print decisions without executing scale
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
CONFIG="${AUTOSCALE_CONFIG:-/home/ubuntu/wp/your-app/deploy/autoscale.yml}"
STATE_DIR="${AUTOSCALE_STATE_DIR:-/var/lib/app-autoscale}"
STACK="${STACK_NAME:-app}"
DRY_RUN=false
MAX_SAMPLES=20

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) echo "[autoscale] unknown flag: $arg" >&2; exit 1 ;;
  esac
done

mkdir -p "$STATE_DIR"

# ---------------------------------------------------------------------------
# Kill-switch: $STATE_DIR/disabled → exit cleanly
# ---------------------------------------------------------------------------
if [[ -f "${STATE_DIR}/disabled" ]]; then
  echo '{"level":"info","msg":"autoscale disabled via kill-switch","file":"'"${STATE_DIR}/disabled"'"}' >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# YAML parser — prefer yq, fallback to python3
# ---------------------------------------------------------------------------
parse_yaml_services() {
  local file="$1"
  if command -v yq &>/dev/null; then
    yq -r '.services | keys[]' "$file"
  elif command -v python3 &>/dev/null; then
    python3 -c "
import yaml, sys
with open('$file') as f:
    cfg = yaml.safe_load(f)
for svc in cfg.get('services', {}):
    print(svc)
"
  else
    echo "[autoscale] ERROR: neither yq nor python3+pyyaml available" >&2
    exit 1
  fi
}

get_yaml_value() {
  local file="$1" svc="$2" key="$3"
  if command -v yq &>/dev/null; then
    yq -r ".services.${svc}.${key}" "$file"
  else
    python3 -c "
import yaml, sys
with open('$file') as f:
    cfg = yaml.safe_load(f)
print(cfg['services']['$svc']['$key'])
"
  fi
}

# ---------------------------------------------------------------------------
# Stateful service blacklist — never auto-scale these
# ---------------------------------------------------------------------------
STATEFUL_BLACKLIST=(
  postgres redis nginx
  langfuse-clickhouse langfuse-minio langfuse-web langfuse-worker
  grafana pgadmin redisinsight
  tempo loki promtail
)

is_blacklisted() {
  local svc="$1"
  for bl in "${STATEFUL_BLACKLIST[@]}"; do
    if [[ "$svc" == "$bl" ]]; then
      return 0
    fi
  done
  return 1
}

# ---------------------------------------------------------------------------
# Validate config
# ---------------------------------------------------------------------------
if [[ ! -f "$CONFIG" ]]; then
  echo "[autoscale] ERROR: config file not found: $CONFIG" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Collect CPU/mem averages for a Swarm service
# ---------------------------------------------------------------------------
get_service_metrics() {
  local full_svc="$1"
  local cpu_sum=0 mem_sum=0 count=0

  # List running task IDs for this service
  local task_ids
  task_ids=$(docker service ps "$full_svc" \
    --filter "desired-state=running" \
    --format '{{.ID}}' 2>/dev/null | head -n "$MAX_SAMPLES") || true

  if [[ -z "$task_ids" ]]; then
    echo "0 0 0"
    return
  fi

  for task_id in $task_ids; do
    # Resolve task → container ID on this node
    local container_id
    container_id=$(docker inspect --format '{{.Status.ContainerStatus.ContainerID}}' "$task_id" 2>/dev/null) || continue
    [[ -z "$container_id" ]] && continue

    # docker stats --no-stream for this container
    local stats_line
    stats_line=$(docker stats --no-stream --format '{{.CPUPerc}} {{.MemPerc}}' "$container_id" 2>/dev/null) || continue
    [[ -z "$stats_line" ]] && continue

    local cpu_pct mem_pct
    cpu_pct=$(echo "$stats_line" | awk '{gsub(/%/,""); print $1}')
    mem_pct=$(echo "$stats_line" | awk '{gsub(/%/,""); print $2}')

    cpu_sum=$(echo "$cpu_sum + $cpu_pct" | bc)
    mem_sum=$(echo "$mem_sum + $mem_pct" | bc)
    count=$((count + 1))
  done

  if (( count == 0 )); then
    echo "0 0 0"
    return
  fi

  local cpu_avg mem_avg
  cpu_avg=$(echo "scale=1; $cpu_sum / $count" | bc)
  mem_avg=$(echo "scale=1; $mem_sum / $count" | bc)
  echo "$cpu_avg $mem_avg $count"
}

# ---------------------------------------------------------------------------
# Get current replica count
# ---------------------------------------------------------------------------
get_current_replicas() {
  local full_svc="$1"
  docker service inspect --format '{{.Spec.Mode.Replicated.Replicas}}' "$full_svc" 2>/dev/null || echo "0"
}

# ---------------------------------------------------------------------------
# Check if any tasks are unhealthy (> 50% unhealthy blocks scale-down)
# ---------------------------------------------------------------------------
has_unhealthy_majority() {
  local full_svc="$1"
  local total=0 unhealthy=0

  while IFS= read -r state; do
    total=$((total + 1))
    case "$state" in
      Failed*|Rejected*|Shutdown*) unhealthy=$((unhealthy + 1)) ;;
    esac
  done < <(docker service ps "$full_svc" --filter "desired-state=running" --format '{{.CurrentState}}' 2>/dev/null)

  if (( total == 0 )); then
    return 1
  fi

  # More than 50% unhealthy
  if (( unhealthy * 2 > total )); then
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# Cooldown check — returns 0 (true) if still in cooldown
# ---------------------------------------------------------------------------
in_cooldown() {
  local svc="$1" direction="$2" cooldown_sec="$3"
  local last_file="${STATE_DIR}/${svc}.last_scale_${direction}"

  if [[ ! -f "$last_file" ]]; then
    return 1
  fi

  local last_ts now_ts diff
  last_ts=$(cat "$last_file")
  now_ts=$(date +%s)
  diff=$((now_ts - last_ts))

  if (( diff < cooldown_sec )); then
    return 0
  fi
  return 1
}

record_scale() {
  local svc="$1" direction="$2"
  date +%s > "${STATE_DIR}/${svc}.last_scale_${direction}"
}

# ---------------------------------------------------------------------------
# JSON log helper
# ---------------------------------------------------------------------------
log_json() {
  local svc="$1" current="$2" cpu_avg="$3" mem_avg="$4" decision="$5" new_replicas="$6" reason="$7"
  printf '{"ts":"%s","svc":"%s","replicas_current":%s,"cpu_avg":%.1f,"mem_avg":%.1f,"decision":"%s","replicas_new":%s,"reason":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$svc" "$current" "$cpu_avg" "$mem_avg" "$decision" "$new_replicas" "$reason" >&2
}

# ---------------------------------------------------------------------------
# Compare floats: returns 0 if $1 > $2
# ---------------------------------------------------------------------------
float_gt() {
  echo "$1 $2" | awk '{exit ($1 > $2) ? 0 : 1}'
}

float_lt() {
  echo "$1 $2" | awk '{exit ($1 < $2) ? 0 : 1}'
}

# ---------------------------------------------------------------------------
# Main loop — iterate over configured services
# ---------------------------------------------------------------------------
services=$(parse_yaml_services "$CONFIG")

for svc in $services; do
  # Validate against blacklist
  if is_blacklisted "$svc"; then
    echo "[autoscale] ERROR: service '$svc' is stateful/blacklisted — remove from $CONFIG" >&2
    exit 1
  fi

  full_svc="${STACK}_${svc}"

  # Check service exists in Swarm
  if ! docker service inspect "$full_svc" &>/dev/null; then
    log_json "$svc" 0 0 0 "skip" 0 "service_not_found"
    continue
  fi

  # Read config
  min_replicas=$(get_yaml_value "$CONFIG" "$svc" "min_replicas")
  max_replicas=$(get_yaml_value "$CONFIG" "$svc" "max_replicas")
  scale_up_cpu=$(get_yaml_value "$CONFIG" "$svc" "scale_up_cpu_pct")
  scale_up_mem=$(get_yaml_value "$CONFIG" "$svc" "scale_up_mem_pct")
  scale_down_cpu=$(get_yaml_value "$CONFIG" "$svc" "scale_down_cpu_pct")
  scale_down_mem=$(get_yaml_value "$CONFIG" "$svc" "scale_down_mem_pct")
  cooldown_up=$(get_yaml_value "$CONFIG" "$svc" "cooldown_up_seconds")
  cooldown_down=$(get_yaml_value "$CONFIG" "$svc" "cooldown_down_seconds")
  step=$(get_yaml_value "$CONFIG" "$svc" "step")

  current=$(get_current_replicas "$full_svc")

  # Collect metrics
  read -r cpu_avg mem_avg sample_count <<< "$(get_service_metrics "$full_svc")"

  if (( sample_count == 0 )); then
    log_json "$svc" "$current" 0 0 "skip" "$current" "no_running_tasks"
    continue
  fi

  # Decide: scale up, scale down, or hold
  decision="hold"
  new_replicas="$current"
  reason="within_thresholds"

  # Scale UP check: CPU > threshold OR Mem > threshold
  if float_gt "$cpu_avg" "$scale_up_cpu" || float_gt "$mem_avg" "$scale_up_mem"; then
    desired=$((current + step))
    if (( desired > max_replicas )); then
      desired=$max_replicas
    fi
    if (( desired != current )); then
      if in_cooldown "$svc" "up" "$cooldown_up"; then
        decision="hold"
        reason="cooldown_up_active"
      else
        decision="scale_up"
        new_replicas=$desired
        if float_gt "$cpu_avg" "$scale_up_cpu"; then
          reason="cpu_avg=${cpu_avg}%>threshold=${scale_up_cpu}%"
        else
          reason="mem_avg=${mem_avg}%>threshold=${scale_up_mem}%"
        fi
      fi
    else
      reason="at_max_replicas"
    fi

  # Scale DOWN check: CPU < threshold AND Mem < threshold
  elif float_lt "$cpu_avg" "$scale_down_cpu" && float_lt "$mem_avg" "$scale_down_mem"; then
    desired=$((current - step))
    if (( desired < min_replicas )); then
      desired=$min_replicas
    fi
    if (( desired != current )); then
      # Safety: do not scale down if unhealthy majority
      if has_unhealthy_majority "$full_svc"; then
        decision="hold"
        reason="unhealthy_majority_detected"
      elif in_cooldown "$svc" "down" "$cooldown_down"; then
        decision="hold"
        reason="cooldown_down_active"
      else
        decision="scale_down"
        new_replicas=$desired
        reason="cpu_avg=${cpu_avg}%<threshold=${scale_down_cpu}%,mem_avg=${mem_avg}%<threshold=${scale_down_mem}%"
      fi
    else
      reason="at_min_replicas"
    fi
  fi

  log_json "$svc" "$current" "$cpu_avg" "$mem_avg" "$decision" "$new_replicas" "$reason"

  # Execute scale (idempotent: only if changed)
  if [[ "$decision" == "scale_up" || "$decision" == "scale_down" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[autoscale] DRY-RUN: would scale ${full_svc} from ${current} to ${new_replicas}" >&2
    else
      docker service scale "${full_svc}=${new_replicas}" --detach
      direction="${decision#scale_}"
      record_scale "$svc" "$direction"
    fi
  fi
done
