#!/usr/bin/env bash
# pipeline.sh — Self-looping implementation pipeline for your-org.
#
# Runs a full cycle: PRIORITIZE → IMPLEMENT → REVIEW → MERGE, then loops
# until all open issues are resolved or no more eligible work is found.
#
# Phase 0: A copilot agent reads EXECUTION_WAVES.md + open issues and outputs
#           a JSON file with ordered waves of issue numbers.
# Phase 1: parallel-implement.sh for the current wave's issues.
# Phase 2: parallel-review.sh for MRs created in Phase 1.
# Phase 3: sequential-merge.sh to squash-merge all eligible MRs.
# Loop:    Back to Phase 0 for the next wave.
#
# Usage:
#   ./scripts/pipeline.sh                         # full auto — group mode (all projects)
#   SUBPROJECT=web/your-web-app ./scripts/pipeline.sh   # single project mode
#   DRY_RUN=1 ./scripts/pipeline.sh               # print all commands
#   MAX_WAVES=2 ./scripts/pipeline.sh              # stop after 2 waves
#   SKIP_PRIORITIZE=1 ./scripts/pipeline.sh 42 55  # skip Phase 0, use given issues
#
# Modes:
#   Group mode (default):   No SUBPROJECT set. Fetches issues from ALL projects in
#                           the GitLab group. Dispatches implement/review/merge per
#                           project automatically.
#   Single-project mode:    SUBPROJECT set. Fetches issues only from that project.
#
# Environment variables (optional):
#   COPILOT_MODEL       — model (default: claude-opus-4.6)
#   COPILOT_EFFORT      — reasoning effort (default: high)
#   REPO_ROOT           — main repo path (default: $HOME/yo/org)
#   SUBPROJECT          — subproject path relative to REPO_ROOT (e.g. web/your-web-app)
#                         When unset, enters group mode (all projects in GITLAB_GROUP)
#   GITLAB_GROUP        — GitLab group name (default: your-org)
#   LOG_DIR             — log base (default: $HOME/.copilot/logs)
#   DRY_RUN             — 1 to print without executing
#   MAX_WAVES           — max waves to process (default: 0 = unlimited)
#   MAX_PARALLEL        — max concurrent workers in implement/review (passed through)
#   SKIP_REVIEW         — 1 to skip review phase (backward compat, sets REVIEW_MODE=skip)
#   REVIEW_MODE         — inline (default): review runs inside each implement worker;
#                         separate: implement skips review, Phase 2 reviews all MRs in parallel;
#                         skip: no review at all
#   SKIP_PRIORITIZE     — 1 to skip Phase 0 and use issue numbers from argv
#   SKIP_MERGE          — 1 to skip merge phase (implement + review only)
#   WAVE_PAUSE          — seconds to pause between waves for human check (default: 0)

set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────────────
COPILOT_MODEL="${COPILOT_MODEL:-claude-opus-4.6}"
COPILOT_EFFORT="${COPILOT_EFFORT:-high}"
REPO_ROOT="${REPO_ROOT:-$HOME/yo/org}"
SUBPROJECT="${SUBPROJECT:-}"
GITLAB_GROUP="${GITLAB_GROUP:-your-org}"
LOG_DIR="${LOG_DIR:-$HOME/.copilot/logs}"
DRY_RUN="${DRY_RUN:-0}"
MAX_WAVES="${MAX_WAVES:-0}"
MAX_PARALLEL="${MAX_PARALLEL:-0}"
SKIP_REVIEW="${SKIP_REVIEW:-0}"
SKIP_PRIORITIZE="${SKIP_PRIORITIZE:-0}"
SKIP_MERGE="${SKIP_MERGE:-0}"
WAVE_PAUSE="${WAVE_PAUSE:-0}"

# REVIEW_MODE controls how reviews are orchestrated:
#   inline   — each implement worker does its own review in the same shell (streaming,
#              fastest — review starts as soon as that worker's implement finishes).
#              No separate Phase 2.
#   separate — implement workers skip review; Phase 2 runs parallel-review.sh
#              for all projects in parallel.
#   skip     — no review at all.
# Backward compat: SKIP_REVIEW=1 forces REVIEW_MODE=skip.
if [[ "$SKIP_REVIEW" == "1" ]]; then
  REVIEW_MODE="skip"
else
  REVIEW_MODE="${REVIEW_MODE:-inline}"
fi
case "$REVIEW_MODE" in
  inline)   _IMPL_SKIP_REVIEW=0; _RUN_SEPARATE_REVIEW=0 ;;
  separate) _IMPL_SKIP_REVIEW=1; _RUN_SEPARATE_REVIEW=1 ;;
  skip)     _IMPL_SKIP_REVIEW=1; _RUN_SEPARATE_REVIEW=0 ;;
  *) echo "ERROR: Invalid REVIEW_MODE=$REVIEW_MODE (use: inline|separate|skip)" >&2; exit 1 ;;
esac

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PIPELINE_LOG_DIR="${LOG_DIR}/pipeline"
WAVE_JSON="${PIPELINE_LOG_DIR}/waves.json"
PIPELINE_LOG="${PIPELINE_LOG_DIR}/pipeline.log"

mkdir -p "$PIPELINE_LOG_DIR"

# ── Helpers ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

ts()   { date '+%H:%M:%S'; }
log()  { echo -e "${CYAN}[pipeline $(ts)]${NC} $*" | tee -a "$PIPELINE_LOG"; }
ok()   { echo -e "${GREEN}[  ok   $(ts)]${NC} $*" | tee -a "$PIPELINE_LOG"; }
warn() { echo -e "${YELLOW}[ warn  $(ts)]${NC} $*" | tee -a "$PIPELINE_LOG"; }
err()  { echo -e "${RED}[ERROR  $(ts)]${NC} $*" | tee -a "$PIPELINE_LOG" >&2; }
phase(){ echo -e "\n${BOLD}${MAGENTA}══════════════════════════════════════════════════════${NC}" | tee -a "$PIPELINE_LOG"
         echo -e "${BOLD}${MAGENTA}  $*${NC}" | tee -a "$PIPELINE_LOG"
         echo -e "${BOLD}${MAGENTA}══════════════════════════════════════════════════════${NC}\n" | tee -a "$PIPELINE_LOG"; }

# ── Validate prerequisites ──────────────────────────────────────────────────
for cmd in glab git copilot jq; do
  if ! command -v "$cmd" &>/dev/null; then
    err "Required command not found: $cmd"
    exit 1
  fi
done

if ! glab auth status &>/dev/null; then
  err "glab CLI not authenticated. Run: glab auth login"
  exit 1
fi

if [[ ! -d "$REPO_ROOT/.git" ]]; then
  err "REPO_ROOT=$REPO_ROOT is not a git repository"
  exit 1
fi

# Resolve the glab working directory (subproject or root)
if [[ -n "$SUBPROJECT" ]]; then
  GLAB_DIR="${REPO_ROOT}/${SUBPROJECT}"
  if [[ ! -d "$GLAB_DIR/.git" && ! -f "$GLAB_DIR/.git" ]]; then
    err "SUBPROJECT=$SUBPROJECT is not a valid git submodule at $GLAB_DIR"
    exit 1
  fi
else
  GLAB_DIR="$REPO_ROOT"
fi

# Auto-detect GitLab group from root remote URL
if [[ -z "$GITLAB_GROUP" ]]; then
  _REMOTE_URL=$(git -C "$REPO_ROOT" config remote.origin.url 2>/dev/null || echo "")
  if [[ "$_REMOTE_URL" =~ gitlab\.com[:/]([^/]+)/ ]]; then
    GITLAB_GROUP="${BASH_REMATCH[1]}"
  fi
  unset _REMOTE_URL
fi

# Derive root project slug from remote (e.g., "org" from "your-org/monorepo.git")
ROOT_PROJECT=""
if [[ -n "$GITLAB_GROUP" ]]; then
  _REMOTE_URL=$(git -C "$REPO_ROOT" config remote.origin.url 2>/dev/null || echo "")
  ROOT_PROJECT=$(echo "$_REMOTE_URL" | sed -E 's|.*[:/][^/]+/(.+)\.git$|\1|' 2>/dev/null || echo "")
  unset _REMOTE_URL
fi

# Group mode: no SUBPROJECT, group detected → fetch issues from all projects
GROUP_MODE=0
if [[ -z "$SUBPROJECT" && -n "$GITLAB_GROUP" ]]; then
  GROUP_MODE=1
fi

for script in parallel-implement.sh parallel-review.sh sequential-merge.sh; do
  if [[ ! -x "${SCRIPTS_DIR}/${script}" ]]; then
    err "Required script not found or not executable: ${SCRIPTS_DIR}/${script}"
    exit 1
  fi
done

# ── Trap: cleanup on Ctrl+C ─────────────────────────────────────────────────
cleanup() {
  echo ""
  warn "Signal received — stopping pipeline..."
  pkill -TERM -P $$ 2>/dev/null || true
  sleep 1
  pkill -9 -P $$ 2>/dev/null || true
  warn "Pipeline stopped."
  exit 130
}
trap cleanup INT TERM

# ── Phase 0: PRIORITIZE ─────────────────────────────────────────────────────
run_prioritize() {
  phase "PHASE 0 — PRIORITIZE"

  local PRIO_LOG="${PIPELINE_LOG_DIR}/prioritize"
  mkdir -p "$PRIO_LOG"

  local OPEN_ISSUES ISSUE_COUNT

  if [[ "$GROUP_MODE" == "1" ]]; then
    log "Fetching open issues from group ${GITLAB_GROUP} (all projects)..."
    OPEN_ISSUES=$(glab api "groups/${GITLAB_GROUP}/issues?state=opened&include_subgroups=true&per_page=100" 2>/dev/null \
      | jq -r --arg grp "$GITLAB_GROUP" '
          .[] |
          (.references.full | split("#")[0] | ltrimstr($grp + "/")) as $proj |
          "[\($proj)] #\(.iid): \(.title)"' 2>/dev/null || echo "")
  else
    log "Fetching open issues from ${SUBPROJECT:-root}..."
    OPEN_ISSUES=$(cd "$GLAB_DIR" && glab issue list --output json 2>/dev/null \
      | jq -r '.[] | "#\(.iid): \(.title)"' 2>/dev/null || echo "")
  fi

  if [[ -z "$OPEN_ISSUES" ]]; then
    warn "No open issues found. Nothing to prioritize."
    echo '{"waves": []}' > "$WAVE_JSON"
    return 0
  fi

  ISSUE_COUNT=$(echo "$OPEN_ISSUES" | grep -c '#' || echo "0")
  log "Found $ISSUE_COUNT open issue(s)"

  local WAVES_FILE_PATH="${REPO_ROOT}/EXECUTION_WAVES.md"
  local WAVES_CONTENT=""
  if [[ -f "$WAVES_FILE_PATH" ]]; then
    WAVES_CONTENT=$(cat "$WAVES_FILE_PATH")
  fi

  local PRIO_PROMPT
  if [[ "$GROUP_MODE" == "1" ]]; then
    PRIO_PROMPT="Use glab CLI for GitLab ops, never MCP for VCS.

TASK: Analyze the open issues from ALL projects in the group and output a prioritized execution plan as JSON.
Issues come from multiple GitLab projects. Each issue is prefixed with [project_path].

OPEN ISSUES:
${OPEN_ISSUES}

EXECUTION_WAVES.md content (current roadmap/priority guidance):
${WAVES_CONTENT:-'(no EXECUTION_WAVES.md found — use issue labels, dependencies, and complexity to prioritize)'}

INSTRUCTIONS:
1. Read each issue in detail. To view an issue in its project, cd to the submodule first:
   cd ${REPO_ROOT}/<project_path> && glab issue view <N>
   Example: cd ${REPO_ROOT}/web/your-web-app && glab issue view 19
   For the root project (${ROOT_PROJECT}): cd ${REPO_ROOT} && glab issue view <N>
2. Identify dependencies between issues — even across projects.
3. Group issues into waves where each wave contains independent issues that can be implemented in parallel.
4. Order waves by priority (critical path first, then value, then complexity).
5. Limit each wave to at most 5 issues for manageability.

OUTPUT: Write ONLY valid JSON to this exact file path: ${WAVE_JSON}
Format — each issue is an object with iid and project:
{
  \"waves\": [
    {\"wave\": 1, \"issues\": [{\"iid\": 19, \"project\": \"web/your-web-app\"}, {\"iid\": 85, \"project\": \"${ROOT_PROJECT}\"}], \"reason\": \"Critical path — security + frontend bugs\"},
    {\"wave\": 2, \"issues\": [{\"iid\": 60, \"project\": \"apps/my-service\"}], \"reason\": \"Independent feature\"}
  ]
}

CRITICAL:
- The file must contain ONLY the JSON object above. No markdown, no explanation outside JSON.
- Every issue MUST include \"project\" with the path relative to the group (e.g. \"web/your-web-app\", \"apps/my-service\", \"${ROOT_PROJECT}\").
- After writing the file, print the JSON to stdout for confirmation."
  else
    PRIO_PROMPT="Use glab CLI for GitLab ops, never MCP for VCS.

TASK: Analyze the open issues and output a prioritized execution plan as JSON.

OPEN ISSUES:
${OPEN_ISSUES}

EXECUTION_WAVES.md content (current roadmap/priority guidance):
${WAVES_CONTENT:-'(no EXECUTION_WAVES.md found — use issue labels, dependencies, and complexity to prioritize)'}

INSTRUCTIONS:
1. Read each issue in detail: glab issue view <N> (description, labels, comments).
2. Identify dependencies between issues (if issue B requires issue A to be done first).
3. Group issues into waves where each wave contains independent issues that can be implemented in parallel.
4. Order waves by priority (critical path first, then value, then complexity).
5. Limit each wave to at most 5 issues for manageability.

OUTPUT: Write ONLY valid JSON to this exact file path: ${WAVE_JSON}
Format:
{
  \"waves\": [
    {\"wave\": 1, \"issues\": [42, 55], \"reason\": \"Core auth — blocking all other features\"},
    {\"wave\": 2, \"issues\": [60, 61, 62], \"reason\": \"Independent features, high value\"}
  ]
}

CRITICAL: The file must contain ONLY the JSON object above. No markdown, no explanation text outside JSON.
After writing the file, print the JSON to stdout for confirmation."
  fi

  # Save prompt for debugging (always, even in dry-run)
  echo "$PRIO_PROMPT" > "${PRIO_LOG}/prompt.txt"

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY_RUN] copilot --model $COPILOT_MODEL --reasoning-effort $COPILOT_EFFORT ... -p \"<PRIO_PROMPT>\""
    # Write a dummy waves file for dry-run continuation
    if [[ $# -gt 0 ]]; then
      if [[ "$GROUP_MODE" == "1" ]]; then
        # In group mode, create object-format issues with root project
        local ISSUE_OBJS
        ISSUE_OBJS=$(printf ',{"iid":%s,"project":"%s"}' "$@" | sed 's/^,//')
        echo "{\"waves\": [{\"wave\": 1, \"issues\": [${ISSUE_OBJS}], \"reason\": \"DRY_RUN\"}]}" > "$WAVE_JSON"
      else
        local ISSUE_ARRAY
        ISSUE_ARRAY=$(printf '%s,' "$@" | sed 's/,$//')
        echo "{\"waves\": [{\"wave\": 1, \"issues\": [${ISSUE_ARRAY}], \"reason\": \"DRY_RUN\"}]}" > "$WAVE_JSON"
      fi
    else
      echo '{"waves": [{"wave": 1, "issues": [], "reason": "DRY_RUN"}]}' > "$WAVE_JSON"
    fi
    return 0
  fi

  cd "$REPO_ROOT"
  copilot \
    --model "$COPILOT_MODEL" \
    --reasoning-effort "$COPILOT_EFFORT" \
    --allow-all-tools \
    --add-dir "$HOME/yo" \
    --add-dir /tmp \
    --disable-builtin-mcps \
    --log-dir "$PRIO_LOG" \
    --log-level info \
    -p "$PRIO_PROMPT" \
    2>&1 | tee -a "$PIPELINE_LOG"

  local EXIT_CODE=${PIPESTATUS[0]}
  if [[ $EXIT_CODE -ne 0 ]]; then
    err "Prioritize agent exited with code $EXIT_CODE"
    return 1
  fi

  if [[ ! -f "$WAVE_JSON" ]]; then
    err "Prioritize phase did not produce waves.json at $WAVE_JSON"
    return 1
  fi

  if ! jq empty "$WAVE_JSON" 2>/dev/null; then
    err "waves.json is not valid JSON"
    cat "$WAVE_JSON" >&2
    return 1
  fi

  local WAVE_COUNT
  WAVE_COUNT=$(jq '.waves | length' "$WAVE_JSON" 2>/dev/null || echo "0")
  ok "Prioritization complete — $WAVE_COUNT wave(s) planned"

  # Print summary — handle both object and number formats
  for i in $(seq 0 $((WAVE_COUNT - 1))); do
    local WID WISSUES WREASON
    WID=$(jq -r ".waves[$i].wave // .waves[$i].id // $((i+1))" "$WAVE_JSON")
    local ISSUE_TYPE
    ISSUE_TYPE=$(jq -r ".waves[$i].issues[0] | type" "$WAVE_JSON" 2>/dev/null || echo "number")
    if [[ "$ISSUE_TYPE" == "object" ]]; then
      WISSUES=$(jq -r ".waves[$i].issues | map(\"\(.project)#\(.iid)\") | join(\", \")" "$WAVE_JSON")
    else
      WISSUES=$(jq -r ".waves[$i].issues | map(\"#\" + tostring) | join(\", \")" "$WAVE_JSON")
    fi
    WREASON=$(jq -r ".waves[$i].reason // \"—\"" "$WAVE_JSON")
    log "  Wave $WID: [$WISSUES] — $WREASON"
  done
}

# ── Helpers: resolve SUBPROJECT from a project path in waves.json ─────────────
# Maps a "project" field from waves.json to a SUBPROJECT value.
# Root project (e.g. "org") maps to "" (root repo). Others pass through as-is.
project_to_subproject() {
  local PROJ="$1"
  if [[ "$PROJ" == "$ROOT_PROJECT" || -z "$PROJ" ]]; then
    echo ""
  else
    echo "$PROJ"
  fi
}

# ── Phase 1: IMPLEMENT ───────────────────────────────────────────────────────
# In group mode, receives a JSON array of {iid, project} from the caller.
# Builds ISSUE_SOURCES map and dispatches all issues to parallel-implement.sh
# in a single call — the agent determines which submodule(s) to change.
run_implement() {
  local WAVE_NUM="$1"
  shift

  phase "PHASE 1 — IMPLEMENT (wave $WAVE_NUM)"

  local CMD="${SCRIPTS_DIR}/parallel-implement.sh"

  if [[ "$GROUP_MODE" == "1" ]]; then
    # Group mode: issues passed as JSON string (first arg)
    local ISSUES_JSON="$1"
    local ISSUE_COUNT
    ISSUE_COUNT=$(echo "$ISSUES_JSON" | jq 'length' 2>/dev/null || echo "0")

    if [[ "$ISSUE_COUNT" -eq 0 ]]; then
      warn "No issues in this wave — skipping implement"
      return 0
    fi

    # Build ISSUE_SOURCES map: {"85":"org","19":"web/your-web-app"}
    local SOURCES_MAP
    SOURCES_MAP=$(echo "$ISSUES_JSON" | jq -c 'map({(.iid|tostring): .project}) | add' 2>/dev/null || echo "{}")

    # Extract plain issue numbers
    local ISSUE_NUMS=()
    local NUM_LIST
    NUM_LIST=$(echo "$ISSUES_JSON" | jq -r '.[].iid')
    while IFS= read -r iid; do
      [[ -n "$iid" ]] && ISSUE_NUMS+=("$iid")
    done <<< "$NUM_LIST"

    log "Issues: ${ISSUE_NUMS[*]}"
    log "Sources: $SOURCES_MAP"

    if [[ "$DRY_RUN" == "1" ]]; then
      echo "[DRY_RUN] ISSUE_SOURCES='${SOURCES_MAP}' ${CMD} ${ISSUE_NUMS[*]}"
      return 0
    fi

    SKIP_REVIEW="$_IMPL_SKIP_REVIEW" \
    COPILOT_MODEL="$COPILOT_MODEL" \
    COPILOT_EFFORT="$COPILOT_EFFORT" \
    REPO_ROOT="$REPO_ROOT" \
    ISSUE_SOURCES="$SOURCES_MAP" \
    LOG_DIR="$LOG_DIR" \
    MAX_PARALLEL="$MAX_PARALLEL" \
      "$CMD" "${ISSUE_NUMS[@]}"
  else
    # Single-project mode: issues as positional args
    local ISSUE_ARGS=("$@")
    log "Issues: ${ISSUE_ARGS[*]}"

    if [[ ${#ISSUE_ARGS[@]} -eq 0 ]]; then
      warn "No issues in this wave — skipping implement"
      return 0
    fi

    if [[ "$DRY_RUN" == "1" ]]; then
      echo "[DRY_RUN] ${CMD} ${ISSUE_ARGS[*]}"
      return 0
    fi

    SKIP_REVIEW="$_IMPL_SKIP_REVIEW" \
    COPILOT_MODEL="$COPILOT_MODEL" \
    COPILOT_EFFORT="$COPILOT_EFFORT" \
    REPO_ROOT="$REPO_ROOT" \
    SUBPROJECT="$SUBPROJECT" \
    LOG_DIR="$LOG_DIR" \
    MAX_PARALLEL="$MAX_PARALLEL" \
      "$CMD" "${ISSUE_ARGS[@]}"
  fi
}

# ── Phase 2: REVIEW ──────────────────────────────────────────────────────────
# In group mode, finds projects with open MRs via the group API and dispatches
# parallel-review.sh for ALL projects in parallel (not sequentially).
run_review() {
  local WAVE_NUM="$1"

  phase "PHASE 2 — REVIEW (wave $WAVE_NUM)"

  local CMD="${SCRIPTS_DIR}/parallel-review.sh"

  if [[ "$GROUP_MODE" == "1" ]]; then
    # Find all projects with open MRs via group API
    local MR_PROJECTS
    MR_PROJECTS=$(glab api "groups/${GITLAB_GROUP}/merge_requests?state=opened&include_subgroups=true&per_page=100" 2>/dev/null \
      | jq -r --arg grp "$GITLAB_GROUP" '[.[] | .references.full | split("!")[0] | rtrimstr(" ") | ltrimstr($grp + "/")] | unique | .[]' 2>/dev/null || echo "")

    if [[ -z "$MR_PROJECTS" ]]; then
      warn "No open MRs found across group — skipping review"
      return 0
    fi

    local REVIEW_PIDS=()
    local REVIEW_PROJS=()
    local OVERALL_EXIT=0

    while IFS= read -r PROJ; do
      [[ -z "$PROJ" ]] && continue
      local SUB
      SUB=$(project_to_subproject "$PROJ")
      log "Reviewing MRs in project: $PROJ"

      if [[ "$DRY_RUN" == "1" ]]; then
        echo "[DRY_RUN] SUBPROJECT=${SUB} ${CMD}"
        continue
      fi

      COPILOT_MODEL="$COPILOT_MODEL" \
      COPILOT_EFFORT="$COPILOT_EFFORT" \
      REPO_ROOT="$REPO_ROOT" \
      SUBPROJECT="$SUB" \
      LOG_DIR="$LOG_DIR" \
      MAX_PARALLEL="$MAX_PARALLEL" \
        "$CMD" &
      REVIEW_PIDS+=($!)
      REVIEW_PROJS+=("$PROJ")
    done <<< "$MR_PROJECTS"

    log "Launched ${#REVIEW_PIDS[@]} review(s) in parallel. Waiting for completion..."

    for i in "${!REVIEW_PIDS[@]}"; do
      if wait "${REVIEW_PIDS[$i]}"; then
        ok "Review ${REVIEW_PROJS[$i]}: SUCCESS"
      else
        err "Review ${REVIEW_PROJS[$i]}: FAILED"
        OVERALL_EXIT=1
      fi
    done
    return $OVERALL_EXIT
  else
    if [[ "$DRY_RUN" == "1" ]]; then
      echo "[DRY_RUN] ${CMD}"
      return 0
    fi

    COPILOT_MODEL="$COPILOT_MODEL" \
    COPILOT_EFFORT="$COPILOT_EFFORT" \
    REPO_ROOT="$REPO_ROOT" \
    SUBPROJECT="$SUBPROJECT" \
    LOG_DIR="$LOG_DIR" \
    MAX_PARALLEL="$MAX_PARALLEL" \
      "$CMD"
  fi
}

# ── Phase 3: MERGE ────────────────────────────────────────────────────────────
# In group mode, finds projects with open MRs via the group API and dispatches
# sequential-merge.sh for ALL projects in parallel (each project merges its own
# MRs sequentially, but cross-project merges run concurrently).
run_merge() {
  local WAVE_NUM="$1"

  phase "PHASE 3 — MERGE (wave $WAVE_NUM)"

  local CMD="${SCRIPTS_DIR}/sequential-merge.sh"

  if [[ "$GROUP_MODE" == "1" ]]; then
    local MR_PROJECTS
    MR_PROJECTS=$(glab api "groups/${GITLAB_GROUP}/merge_requests?state=opened&include_subgroups=true&per_page=100" 2>/dev/null \
      | jq -r --arg grp "$GITLAB_GROUP" '[.[] | .references.full | split("!")[0] | rtrimstr(" ") | ltrimstr($grp + "/")] | unique | .[]' 2>/dev/null || echo "")

    if [[ -z "$MR_PROJECTS" ]]; then
      warn "No open MRs found across group — skipping merge"
      return 0
    fi

    local MERGE_PIDS=()
    local MERGE_PROJS=()
    local OVERALL_EXIT=0

    while IFS= read -r PROJ; do
      [[ -z "$PROJ" ]] && continue
      local SUB
      SUB=$(project_to_subproject "$PROJ")
      log "Merging MRs in project: $PROJ"

      if [[ "$DRY_RUN" == "1" ]]; then
        echo "[DRY_RUN] SUBPROJECT=${SUB} ${CMD}"
        continue
      fi

      COPILOT_MODEL="$COPILOT_MODEL" \
      COPILOT_EFFORT="$COPILOT_EFFORT" \
      REPO_ROOT="$REPO_ROOT" \
      SUBPROJECT="$SUB" \
      LOG_DIR="$LOG_DIR" \
        "$CMD" &
      MERGE_PIDS+=($!)
      MERGE_PROJS+=("$PROJ")
    done <<< "$MR_PROJECTS"

    log "Launched ${#MERGE_PIDS[@]} merge(s) in parallel. Waiting for completion..."

    for i in "${!MERGE_PIDS[@]}"; do
      if wait "${MERGE_PIDS[$i]}"; then
        ok "Merge ${MERGE_PROJS[$i]}: SUCCESS"
      else
        err "Merge ${MERGE_PROJS[$i]}: FAILED"
        OVERALL_EXIT=1
      fi
    done
    return $OVERALL_EXIT
  else
    if [[ "$DRY_RUN" == "1" ]]; then
      echo "[DRY_RUN] ${CMD}"
      return 0
    fi

    COPILOT_MODEL="$COPILOT_MODEL" \
    COPILOT_EFFORT="$COPILOT_EFFORT" \
    REPO_ROOT="$REPO_ROOT" \
    SUBPROJECT="$SUBPROJECT" \
    LOG_DIR="$LOG_DIR" \
      "$CMD"
  fi
}

# ── Main pipeline loop ────────────────────────────────────────────────────────
main() {
  echo ""
  phase "PIPELINE START"
  log "Config:"
  log "  Model:           $COPILOT_MODEL"
  log "  Effort:          $COPILOT_EFFORT"
  log "  Repo:            $REPO_ROOT"
  log "  Scripts:         $SCRIPTS_DIR"
  log "  Log dir:         $PIPELINE_LOG_DIR"
  log "  Max waves:       $([ "$MAX_WAVES" -eq 0 ] && echo "unlimited" || echo "$MAX_WAVES")"
  log "  Max parallel:    $([ "$MAX_PARALLEL" -eq 0 ] && echo "unlimited" || echo "$MAX_PARALLEL")"
  log "  Skip review:     $REVIEW_MODE"
  log "  Skip merge:      $SKIP_MERGE"
  if [[ "$GROUP_MODE" == "1" ]]; then
    log "  Mode:            GROUP (all projects in ${GITLAB_GROUP})"
    log "  Root project:    ${ROOT_PROJECT}"
  else
    log "  Mode:            SINGLE-PROJECT"
    log "  Subproject:      ${SUBPROJECT:-'(root)'}"
    log "  glab dir:        $GLAB_DIR"
  fi
  log "  Skip prioritize: $SKIP_PRIORITIZE"
  log "  Wave pause:      ${WAVE_PAUSE}s"
  log "  Dry run:         $DRY_RUN"
  echo ""

  local WAVE_NUM=0
  local TOTAL_IMPLEMENTED=0
  local START_TIME
  START_TIME=$(date +%s)

  # ── Handle SKIP_PRIORITIZE mode (manual issue list) ────────────────────────
  if [[ "$SKIP_PRIORITIZE" == "1" ]]; then
    if [[ $# -eq 0 ]]; then
      err "SKIP_PRIORITIZE=1 requires issue numbers as arguments"
      if [[ "$GROUP_MODE" == "1" ]]; then
        err "Usage: SKIP_PRIORITIZE=1 ./scripts/pipeline.sh web/your-web-app:19 85"
        err "Format: <project>:<iid> for subprojects, or plain <iid> for root project"
      else
        err "Usage: SKIP_PRIORITIZE=1 ./scripts/pipeline.sh 42 55 60"
      fi
      exit 1
    fi

    if [[ "$GROUP_MODE" == "1" ]]; then
      # Group mode: accept "project:iid" or plain "iid" (defaults to root project)
      # Validate and build object-format issues
      local ISSUE_OBJS=""
      local MANUAL_COUNT=0
      for ARG in "$@"; do
        if [[ "$ARG" =~ ^([a-zA-Z0-9/_-]+):([0-9]+)$ ]]; then
          local PROJ="${BASH_REMATCH[1]}"
          local IID="${BASH_REMATCH[2]}"
          ISSUE_OBJS="${ISSUE_OBJS},{\"iid\":${IID},\"project\":\"${PROJ}\"}"
        elif [[ "$ARG" =~ ^[0-9]+$ ]]; then
          ISSUE_OBJS="${ISSUE_OBJS},{\"iid\":${ARG},\"project\":\"${ROOT_PROJECT}\"}"
        else
          err "Invalid issue format: $ARG (expected <project>:<iid> or <iid>)"
          exit 1
        fi
        MANUAL_COUNT=$((MANUAL_COUNT + 1))
      done
      ISSUE_OBJS="${ISSUE_OBJS#,}"  # strip leading comma

      echo "{\"waves\": [{\"wave\": 1, \"issues\": [${ISSUE_OBJS}], \"reason\": \"manual\"}]}" > "$WAVE_JSON"
      log "SKIP_PRIORITIZE=1 (group mode) — $MANUAL_COUNT issue(s): $*"

      local ISSUES_JSON="[${ISSUE_OBJS}]"
      WAVE_NUM=1
      run_implement "$WAVE_NUM" "$ISSUES_JSON"
      TOTAL_IMPLEMENTED=$MANUAL_COUNT
    else
      # Single-project mode: plain numbers only
      for N in "$@"; do
        if ! [[ "$N" =~ ^[0-9]+$ ]]; then
          err "Invalid issue number: $N"
          exit 1
        fi
      done

      local MANUAL_ISSUES=("$@")
      local ISSUE_ARRAY
      ISSUE_ARRAY=$(printf '%s,' "${MANUAL_ISSUES[@]}" | sed 's/,$//')
      echo "{\"waves\": [{\"wave\": 1, \"issues\": [${ISSUE_ARRAY}], \"reason\": \"manual\"}]}" > "$WAVE_JSON"
      log "SKIP_PRIORITIZE=1 — single wave with issues: ${MANUAL_ISSUES[*]}"

      WAVE_NUM=1
      run_implement "$WAVE_NUM" "${MANUAL_ISSUES[@]}"
      TOTAL_IMPLEMENTED=${#MANUAL_ISSUES[@]}
    fi

    if [[ "$_RUN_SEPARATE_REVIEW" == "1" ]]; then
      run_review "$WAVE_NUM"
    elif [[ "$REVIEW_MODE" == "inline" ]]; then
      log "Reviews completed inline during implement phase (streaming mode)"
    fi

    if [[ "$SKIP_MERGE" == "0" ]]; then
      run_merge "$WAVE_NUM"
    fi

    phase "PIPELINE COMPLETE (manual mode)"
    log "Issues processed: $TOTAL_IMPLEMENTED"
    log "Duration: $(( $(date +%s) - START_TIME ))s"
    return 0
  fi

  # ── Auto-loop mode ─────────────────────────────────────────────────────────
  local CONSECUTIVE_EMPTY=0
  while true; do
    WAVE_NUM=$((WAVE_NUM + 1))

    # Check max waves limit
    if [[ "$MAX_WAVES" -gt 0 && "$WAVE_NUM" -gt "$MAX_WAVES" ]]; then
      log "Reached MAX_WAVES=$MAX_WAVES — stopping"
      break
    fi

    phase "WAVE $WAVE_NUM"

    # Phase 0: Prioritize — get fresh wave plan each iteration
    run_prioritize
    local PRIO_EXIT=$?

    if [[ $PRIO_EXIT -ne 0 ]]; then
      if [[ "$DRY_RUN" == "1" ]]; then
        log "Dry-run — no real issues to prioritize"
      else
        warn "Prioritize failed or no issues left — stopping pipeline"
      fi
      break
    fi

    # Validate waves.json exists and has content
    if [[ ! -f "$WAVE_JSON" ]]; then
      err "No waves.json after prioritize — stopping"
      break
    fi

    local WAVE_COUNT
    WAVE_COUNT=$(jq '.waves | length' "$WAVE_JSON" 2>/dev/null || echo "0")

    if [[ "$WAVE_COUNT" -eq 0 ]]; then
      ok "No more waves to process — all done!"
      break
    fi

    # Take only the FIRST wave (we re-prioritize after each cycle)
    local FIRST_WAVE_ISSUES_JSON FIRST_WAVE_REASON
    FIRST_WAVE_ISSUES_JSON=$(jq -r '.waves[0].issues | @json' "$WAVE_JSON")
    FIRST_WAVE_REASON=$(jq -r '.waves[0].reason // "—"' "$WAVE_JSON")

    # Detect issue format: object ({iid, project}) or plain number
    local ISSUE_FORMAT
    ISSUE_FORMAT=$(echo "$FIRST_WAVE_ISSUES_JSON" | jq -r '.[0] | type' 2>/dev/null || echo "number")

    local WAVE_ISSUE_COUNT=0

    if [[ "$ISSUE_FORMAT" == "object" ]]; then
      # Group mode: issues are objects — count and pass JSON to run_implement
      WAVE_ISSUE_COUNT=$(echo "$FIRST_WAVE_ISSUES_JSON" | jq 'length' 2>/dev/null || echo "0")

      if [[ "$WAVE_ISSUE_COUNT" -eq 0 ]]; then
        CONSECUTIVE_EMPTY=$((CONSECUTIVE_EMPTY + 1))
        warn "Wave has no issues — skipping ($CONSECUTIVE_EMPTY consecutive)"
        if [[ $CONSECUTIVE_EMPTY -ge 3 ]]; then
          warn "3 consecutive empty waves — stopping to avoid infinite loop"
          break
        fi
        continue
      fi
      CONSECUTIVE_EMPTY=0

      local ISSUE_SUMMARY
      ISSUE_SUMMARY=$(echo "$FIRST_WAVE_ISSUES_JSON" | jq -r '.[] | "\(.project)#\(.iid)"' | paste -sd ', ' -)
      log "Processing wave $WAVE_NUM ($WAVE_ISSUE_COUNT issues): $ISSUE_SUMMARY"
      log "Reason: $FIRST_WAVE_REASON"

      # Phase 1: Implement — pass JSON string
      if ! run_implement "$WAVE_NUM" "$FIRST_WAVE_ISSUES_JSON"; then
        err "Wave $WAVE_NUM — implement phase failed"
        [[ "$WAVE_PAUSE" -gt 0 ]] && { warn "Pausing ${WAVE_PAUSE}s for human check..."; sleep "$WAVE_PAUSE"; }
        continue
      fi
    else
      # Single-project mode: issues are plain numbers
      local WAVE_ISSUES=()
      local ISSUE_LIST
      ISSUE_LIST=$(echo "$FIRST_WAVE_ISSUES_JSON" | jq -r '.[]')
      while IFS= read -r line; do
        if [[ -n "$line" ]]; then
          WAVE_ISSUES+=("$line")
        fi
      done <<< "$ISSUE_LIST"

      WAVE_ISSUE_COUNT=${#WAVE_ISSUES[@]}

      if [[ $WAVE_ISSUE_COUNT -eq 0 ]]; then
        CONSECUTIVE_EMPTY=$((CONSECUTIVE_EMPTY + 1))
        warn "Wave has no issues — skipping ($CONSECUTIVE_EMPTY consecutive)"
        if [[ $CONSECUTIVE_EMPTY -ge 3 ]]; then
          warn "3 consecutive empty waves — stopping to avoid infinite loop"
          break
        fi
        continue
      fi
      CONSECUTIVE_EMPTY=0

      log "Processing wave $WAVE_NUM ($WAVE_ISSUE_COUNT issues): ${WAVE_ISSUES[*]}"
      log "Reason: $FIRST_WAVE_REASON"

      # Phase 1: Implement — pass issue numbers
      if ! run_implement "$WAVE_NUM" "${WAVE_ISSUES[@]}"; then
        err "Wave $WAVE_NUM — implement phase failed"
        [[ "$WAVE_PAUSE" -gt 0 ]] && { warn "Pausing ${WAVE_PAUSE}s for human check..."; sleep "$WAVE_PAUSE"; }
        continue
      fi
    fi
    TOTAL_IMPLEMENTED=$((TOTAL_IMPLEMENTED + WAVE_ISSUE_COUNT))

    # Phase 2: Review — only runs in "separate" mode (inline reviews are done in Phase 1)
    if [[ "$_RUN_SEPARATE_REVIEW" == "1" ]]; then
      if ! run_review "$WAVE_NUM"; then
        warn "Wave $WAVE_NUM — review phase had failures (continuing to merge eligible MRs)"
      fi
    elif [[ "$REVIEW_MODE" == "inline" ]]; then
      log "Reviews completed inline during implement phase (streaming mode)"
    fi

    # Phase 3: Merge (unless SKIP_MERGE)
    if [[ "$SKIP_MERGE" == "0" ]]; then
      if ! run_merge "$WAVE_NUM"; then
        warn "Wave $WAVE_NUM — merge phase had failures"
      fi
    fi

    # Wave complete
    ok "Wave $WAVE_NUM complete"

    # Archive the used wave plan so next prioritize starts fresh
    cp "$WAVE_JSON" "${PIPELINE_LOG_DIR}/waves-wave${WAVE_NUM}-$(date +%Y%m%d-%H%M%S).json"
    rm -f "$WAVE_JSON"

    # Pause between waves if configured
    if [[ "$WAVE_PAUSE" -gt 0 ]]; then
      warn "Pausing ${WAVE_PAUSE}s between waves (human review window)..."
      sleep "$WAVE_PAUSE"
    fi

    # Check if there are still open issues
    local REMAINING
    if [[ "$GROUP_MODE" == "1" ]]; then
      REMAINING=$(glab api "groups/${GITLAB_GROUP}/issues?state=opened&include_subgroups=true&per_page=1" 2>/dev/null \
        | jq 'length' 2>/dev/null || echo "0")
      # Group API returns at most per_page — if 1, there are more; use headers for total
      if [[ "$REMAINING" -gt 0 ]]; then
        REMAINING=$(glab api "groups/${GITLAB_GROUP}/issues?state=opened&include_subgroups=true&per_page=100" 2>/dev/null \
          | jq 'length' 2>/dev/null || echo "0")
      fi
    else
      REMAINING=$(cd "$GLAB_DIR" && glab issue list --output json 2>/dev/null \
        | jq 'length' 2>/dev/null || echo "0")
    fi

    if [[ "$REMAINING" -eq 0 ]]; then
      ok "No more open issues — pipeline complete!"
      break
    fi

    log "$REMAINING open issues remaining. Continuing to next wave..."
  done

  # ── Final report ───────────────────────────────────────────────────────────
  local DURATION=$(( $(date +%s) - START_TIME ))
  local HOURS=$((DURATION / 3600))
  local MINUTES=$(( (DURATION % 3600) / 60 ))
  local SECONDS=$((DURATION % 60))

  echo ""
  phase "PIPELINE COMPLETE"
  log "Summary:"
  log "  Waves processed:      $WAVE_NUM"
  log "  Issues implemented:   $TOTAL_IMPLEMENTED"
  log "  Duration:             ${HOURS}h ${MINUTES}m ${SECONDS}s"
  log "  Logs:                 $PIPELINE_LOG_DIR"
  echo ""

  # Archive final state
  local REPORT="${PIPELINE_LOG_DIR}/report-$(date +%Y%m%d-%H%M%S).txt"
  {
    echo "Pipeline Report — $(date)"
    echo "Mode: $([ "$GROUP_MODE" == "1" ] && echo "GROUP (${GITLAB_GROUP})" || echo "SINGLE (${SUBPROJECT:-root})")"
    echo "Waves: $WAVE_NUM"
    echo "Issues: $TOTAL_IMPLEMENTED"
    echo "Duration: ${HOURS}h ${MINUTES}m ${SECONDS}s"
    echo ""
    echo "Open issues remaining:"
    if [[ "$GROUP_MODE" == "1" ]]; then
      glab api "groups/${GITLAB_GROUP}/issues?state=opened&include_subgroups=true&per_page=100" 2>/dev/null \
        | jq -r --arg grp "$GITLAB_GROUP" '.[] |
            (.references.full | split("#")[0] | ltrimstr($grp + "/")) as $proj |
            "  [\($proj)] #\(.iid) — \(.title)"' 2>/dev/null || echo "  (could not fetch)"
    else
      (cd "$GLAB_DIR" && glab issue list --output json 2>/dev/null) \
        | jq -r '.[] | "  #\(.iid) — \(.title)"' 2>/dev/null || echo "  (could not fetch)"
    fi
    echo ""
    echo "Open MRs remaining:"
    if [[ "$GROUP_MODE" == "1" ]]; then
      glab api "groups/${GITLAB_GROUP}/merge_requests?state=opened&include_subgroups=true&per_page=100" 2>/dev/null \
        | jq -r --arg grp "$GITLAB_GROUP" '.[] |
            (.references.full | split("!")[0] | rtrimstr(" ") | ltrimstr($grp + "/")) as $proj |
            "  [\($proj)] MR !\(.iid) — \(.title)"' 2>/dev/null || echo "  (could not fetch)"
    else
      (cd "$GLAB_DIR" && glab mr list --output json 2>/dev/null) \
        | jq -r '.[] | "  MR !\(.iid) — \(.title)"' 2>/dev/null || echo "  (could not fetch)"
    fi
  } > "$REPORT"

  log "Report saved: $REPORT"
}

# ── Entry point ──────────────────────────────────────────────────────────────
main "$@"
