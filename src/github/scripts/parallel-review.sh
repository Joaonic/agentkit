#!/usr/bin/env bash
# parallel-review.sh — Review all open MRs (with linked issues) in parallel.
# Fetches open MRs, filters out those without closing issues, then spawns
# one copilot review session per MR in its own worktree.
#
# Usage:
#   ./scripts/parallel-review.sh                  # all open MRs with linked issues
#   ./scripts/parallel-review.sh 301 305 310      # only these MR numbers
#   DRY_RUN=1 ./scripts/parallel-review.sh        # print commands without executing
#
# Environment variables (optional):
#   COPILOT_MODEL     — model to use (default: claude-opus-4.6)
#   COPILOT_EFFORT    — reasoning effort (default: high)
#   REPO_ROOT         — path to main repo (default: $HOME/yo/org)
#   SUBPROJECT        — subproject path relative to REPO_ROOT for glab context
#   GITLAB_GROUP      — GitLab group name (default: your-org)
#   WT_PREFIX         — worktree path prefix (default: $HOME/yo/org-wt-review-)
#   LOG_DIR           — log base directory (default: $HOME/.copilot/logs)
#   DRY_RUN           — set to 1 to print commands without executing
#   MAX_PARALLEL      — max concurrent reviews (default: unlimited)

set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────────────
COPILOT_MODEL="${COPILOT_MODEL:-claude-opus-4.6}"
COPILOT_EFFORT="${COPILOT_EFFORT:-high}"
REPO_ROOT="${REPO_ROOT:-$HOME/yo/org}"
SUBPROJECT="${SUBPROJECT:-}"
GITLAB_GROUP="${GITLAB_GROUP:-your-org}"
WT_PREFIX="${WT_PREFIX:-$HOME/yo/org-wt-review-}"
LOG_DIR="${LOG_DIR:-$HOME/.copilot/logs}"
DRY_RUN="${DRY_RUN:-0}"
MAX_PARALLEL="${MAX_PARALLEL:-0}"

# ── Helpers ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${CYAN}[review]${NC} $*"; }
ok()   { echo -e "${GREEN}[  ok  ]${NC} $*"; }
warn() { echo -e "${YELLOW}[ warn ]${NC} $*"; }
err()  { echo -e "${RED}[ERROR ]${NC} $*" >&2; }

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

# Resolve glab working directory (subproject or root)
if [[ -n "$SUBPROJECT" ]]; then
  GLAB_DIR="${REPO_ROOT}/${SUBPROJECT}"
else
  GLAB_DIR="$REPO_ROOT"
fi

# Auto-detect GitLab group and root project slug from remote
if [[ -z "$GITLAB_GROUP" ]]; then
  GITLAB_GROUP=$(cd "$REPO_ROOT" && git remote get-url origin 2>/dev/null \
    | sed -E 's|.*[:/]([^/]+)/[^/]+(\.git)?$|\1|')
fi
ROOT_PROJECT_SLUG=$(cd "$REPO_ROOT" && git remote get-url origin 2>/dev/null \
  | sed -E 's|.*[:/][^/]+/([^/]+)(\.git)?$|\1|')

# ── Collect MRs to review ───────────────────────────────────────────────────
if [[ $# -gt 0 ]]; then
  EXPLICIT_MRS=("$@")
  for N in "${EXPLICIT_MRS[@]}"; do
    if ! [[ "$N" =~ ^[0-9]+$ ]]; then
      err "Invalid MR number: $N"
      exit 1
    fi
  done
  log "Filtering ${#EXPLICIT_MRS[@]} explicit MR(s): ${EXPLICIT_MRS[*]}"
else
  EXPLICIT_MRS=()
fi

# Fetch all open, non-draft MRs
log "Fetching open MRs..."
if [[ -n "$SUBPROJECT" ]]; then
  # Single subproject mode: use glab mr list in that directory
  MR_JSON=$(cd "$GLAB_DIR" && glab mr list --output json 2>/dev/null)
else
  # Group-wide mode: use GitLab group API to find MRs across all repos
  log "Scanning group '${GITLAB_GROUP}' for open MRs across all repos..."
  MR_JSON=$(glab api "/groups/${GITLAB_GROUP}/merge_requests?state=opened&per_page=100" 2>/dev/null)
fi

if [[ -z "$MR_JSON" || "$MR_JSON" == "[]" || "$MR_JSON" == "null" ]]; then
  warn "No open MRs found."
  exit 0
fi

# Build arrays of eligible MRs
MR_NUMBERS=()
MR_TITLES=()
MR_BRANCHES=()
MR_SUBPROJECTS=()
SKIPPED_DRAFT=()
SKIPPED_NOT_REQUESTED=()

MR_COUNT=$(echo "$MR_JSON" | jq 'length')
for i in $(seq 0 $((MR_COUNT - 1))); do
  NUM=$(echo "$MR_JSON" | jq -r ".[$i].iid")
  TITLE=$(echo "$MR_JSON" | jq -r ".[$i].title")
  BRANCH=$(echo "$MR_JSON" | jq -r ".[$i].source_branch")
  IS_DRAFT=$(echo "$MR_JSON" | jq -r ".[$i].work_in_progress // .[$i].draft // false")

  # Resolve subproject path from group API references
  if [[ -n "$SUBPROJECT" ]]; then
    SUB="$SUBPROJECT"
  else
    REF_FULL=$(echo "$MR_JSON" | jq -r ".[$i].references.full // empty")
    # references.full = "group/path/to/project!N" → extract "path/to/project"
    SUB=$(echo "$REF_FULL" | sed -E "s|^${GITLAB_GROUP}/||; s|![0-9]+$||")
    # If the project slug matches the root repo, map to "."
    if [[ "$SUB" == "$ROOT_PROJECT_SLUG" ]]; then
      SUB="."
    fi
  fi

  # If explicit list given, skip MRs not in it
  if [[ ${#EXPLICIT_MRS[@]} -gt 0 ]]; then
    FOUND=0
    for E in "${EXPLICIT_MRS[@]}"; do
      if [[ "$E" == "$NUM" ]]; then FOUND=1; break; fi
    done
    if [[ $FOUND -eq 0 ]]; then
      SKIPPED_NOT_REQUESTED+=("MR !$NUM ($TITLE) [$SUB]")
      continue
    fi
  fi

  # Skip drafts (WIP)
  if [[ "$IS_DRAFT" == "true" ]]; then
    SKIPPED_DRAFT+=("MR !$NUM ($TITLE) [$SUB]")
    continue
  fi

  MR_NUMBERS+=("$NUM")
  MR_TITLES+=("$TITLE")
  MR_BRANCHES+=("$BRANCH")
  MR_SUBPROJECTS+=("$SUB")
done

# ── Report ──────────────────────────────────────────────────────────────────
echo ""
if [[ ${#SKIPPED_DRAFT[@]} -gt 0 ]]; then
  warn "Skipped (draft/WIP): ${#SKIPPED_DRAFT[@]}"
  for S in "${SKIPPED_DRAFT[@]}"; do echo "       ↳ $S"; done
fi

if [[ ${#MR_NUMBERS[@]} -eq 0 ]]; then
  warn "No eligible MRs to review (all skipped)."
  exit 0
fi

log "MRs to review: ${#MR_NUMBERS[@]}"
for i in "${!MR_NUMBERS[@]}"; do
  echo "       ↳ MR !${MR_NUMBERS[$i]} — ${MR_TITLES[$i]} (branch: ${MR_BRANCHES[$i]}, repo: ${MR_SUBPROJECTS[$i]})"
done
echo ""

# ── Pre-fetch main ────────────────────────────────────────────────────────────
log "Pre-fetching origin/main for all repos..."
FETCHED_REPOS=""
for i in "${!MR_SUBPROJECTS[@]}"; do
  SUB="${MR_SUBPROJECTS[$i]}"
  if ! echo "$FETCHED_REPOS" | grep -qx "$SUB"; then
    FETCHED_REPOS="${FETCHED_REPOS}
${SUB}"
    local_repo="$REPO_ROOT"
    [[ "$SUB" != "." ]] && local_repo="${REPO_ROOT}/${SUB}"
    git -C "$local_repo" fetch origin main --quiet 2>/dev/null || git -C "$local_repo" fetch origin --quiet 2>/dev/null || true
  fi
done
ok "Refs up to date"
echo ""

# ── Per-MR worker function ──────────────────────────────────────────────────
review_mr() {
  local MR_NUM="$1"
  local MR_BRANCH="$2"
  local MR_TITLE="$3"
  local MR_SUB="$4"

  # Resolve the git repo directory for this MR
  local GIT_REPO
  if [[ "$MR_SUB" == "." ]]; then
    GIT_REPO="$REPO_ROOT"
  else
    GIT_REPO="${REPO_ROOT}/${MR_SUB}"
  fi

  # Use subproject-qualified worktree prefix to avoid collisions
  local SUB_SLUG
  SUB_SLUG=$(echo "$MR_SUB" | tr '/' '-')
  local WT="${WT_PREFIX}${SUB_SLUG}-${MR_NUM}"
  local REVIEW_LOG="${LOG_DIR}/review-mr-${MR_NUM}"
  local MR_LOG="${LOG_DIR}/review-mr-${MR_NUM}.log"

  mkdir -p "$REVIEW_LOG" "$(dirname "$MR_LOG")"

  exec > >(sed "s/^/$(printf '\033[0;35m[MR!%s]\033[0m ' "$MR_NUM")/" | tee -a "$MR_LOG") 2>&1

  log "Starting review — ${MR_TITLE}"

  # ── 1. Create or reuse worktree ───────────────────────────────────────────
  local EXISTING_WT=""
  EXISTING_WT=$(git -C "$GIT_REPO" worktree list --porcelain 2>/dev/null \
    | awk -v br="$MR_BRANCH" '/^worktree /{wt=$2} /^branch refs\/heads\//{if($2=="refs/heads/"br) print wt}')

  if [[ -n "$EXISTING_WT" && -d "$EXISTING_WT" ]]; then
    WT="$EXISTING_WT"
    log "Reusing existing worktree at $WT"
    cd "$WT"
    git reset --hard "origin/$MR_BRANCH" 2>/dev/null || git pull --rebase origin "$MR_BRANCH"
  elif [[ -d "$WT" ]]; then
    warn "Worktree dir exists at $WT — updating"
    cd "$WT"
    git checkout "$MR_BRANCH" 2>/dev/null || true
    git reset --hard "origin/$MR_BRANCH"
  else
    log "Creating worktree on branch $MR_BRANCH..."
    git -C "$GIT_REPO" fetch origin "$MR_BRANCH" --quiet 2>/dev/null || true
    git -C "$GIT_REPO" worktree add "$WT" "origin/$MR_BRANCH" 2>/dev/null || {
      err "Failed to create worktree"
      return 1
    }
    cd "$WT"
    git checkout -B "$MR_BRANCH" "origin/$MR_BRANCH"
  fi

  # ── 2. Run review ─────────────────────────────────────────────────────────
  local REVIEW_PROMPT
  REVIEW_PROMPT="Use glab CLI for GitLab ops, never MCP for VCS. \
Run the review-open-pr skill for MR !${MR_NUM} on branch ${MR_BRANCH}. \
Find the MR details: glab mr view ${MR_NUM}. \
Find linked issues via: glab api '/projects/:id/merge_requests/${MR_NUM}/closes_issues'. \
Read each linked issue's full description and comments: glab issue view <N>. \
Review the full MR diff: glab mr diff ${MR_NUM}. \
ZERO TOLERANCE POLICY: There is NO 'approved with reservations' or 'non-blocking issues'. \
Every problem found in scope (code, tests, UX, docs, accessibility) is BLOCKING and MUST be resolved. \
If the MR touches web/**, run the full UX review checklist from the ux-review skill — UX issues are BLOCKING. \
When validating implementations, use context7 MCP (mcp_context7_resolve-library-id + mcp_context7_query-docs) \
to verify against current official documentation. \
Stack: Java 21 / Spring Boot 3 (Maven) for backend, TypeScript / React / Next.js (Yarn) for web. \
Fix ALL issues found in this worktree, push fixes, and wait for the CI pipeline to re-run. \
Do NOT merge the MR. Only stop when CI is fully GREEN and ZERO problems remain in scope. \
Leave the MR open and ready for human merge. \
CI RULES (MANDATORY): \
1. CI RED is BLOCKING — do NOT approve or stop with any pipeline failing. Fix the code first. \
2. To diagnose failures: glab ci list --ref ${MR_BRANCH}, then glab ci trace <job-id> for the failing job. \
3. Fix the root cause in code, push, then wait for the NEW pipeline. NEVER re-run without a fix. \
REBASE RULES (MANDATORY): \
1. When rebasing onto main, NEVER lose code from main. Both sides of every conflict MUST be preserved. \
2. After rebase, verify: git diff origin/main..HEAD -- <conflicted files>. Code loss is BLOCKING."

  log "Launching copilot review..."
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY_RUN] copilot --model $COPILOT_MODEL --reasoning-effort $COPILOT_EFFORT --allow-all-tools \\"
    echo "  --add-dir $HOME/yo --add-dir /tmp --disable-builtin-mcps \\"
    echo "  --log-dir $REVIEW_LOG --log-level info \\"
    echo "  -p \"<REVIEW_PROMPT>\""
    ok "Dry run — done"
    return 0
  fi

  copilot \
    --model "$COPILOT_MODEL" \
    --reasoning-effort "$COPILOT_EFFORT" \
    --allow-all-tools \
    --add-dir "$HOME/yo" \
    --add-dir /tmp \
    --disable-builtin-mcps \
    --log-dir "$REVIEW_LOG" \
    --log-level info \
    -p "$REVIEW_PROMPT"

  local EXIT_CODE=$?
  if [[ $EXIT_CODE -ne 0 ]]; then
    err "Review agent exited with code $EXIT_CODE"
  fi
  ok "Done (exit=$EXIT_CODE)"
}

# ── Main: launch all MRs in parallel ─────────────────────────────────────────
log "Launching ${#MR_NUMBERS[@]} MR review(s) in parallel"
log "Model: $COPILOT_MODEL | Effort: $COPILOT_EFFORT"
echo ""

# Trap Ctrl+C / SIGTERM
cleanup() {
  echo ""
  warn "Signal received — killing all review workers..."
  for PID in "${PIDS[@]}"; do
    kill -TERM "$PID" 2>/dev/null || true
  done
  pkill -TERM -P $$ 2>/dev/null || true
  sleep 1
  for PID in "${PIDS[@]}"; do
    kill -9 "$PID" 2>/dev/null || true
  done
  pkill -9 -P $$ 2>/dev/null || true
  warn "All workers stopped."
  exit 130
}
trap cleanup INT TERM

PIDS=()
PID_MRS=()
ACTIVE=0

# Pre-fetch MR branches
log "Pre-fetching MR branches..."
for i in "${!MR_BRANCHES[@]}"; do
  local_repo="$REPO_ROOT"
  [[ "${MR_SUBPROJECTS[$i]}" != "." ]] && local_repo="${REPO_ROOT}/${MR_SUBPROJECTS[$i]}"
  git -C "$local_repo" fetch origin "${MR_BRANCHES[$i]}" --quiet 2>/dev/null || true
done
ok "Refs up to date"
echo ""

for i in "${!MR_NUMBERS[@]}"; do
  # Throttle if MAX_PARALLEL is set
  if [[ "$MAX_PARALLEL" -gt 0 ]]; then
    while [[ $ACTIVE -ge $MAX_PARALLEL ]]; do
      wait -n 2>/dev/null && ((ACTIVE--)) || true
    done
  fi

  N="${MR_NUMBERS[$i]}"
  BR="${MR_BRANCHES[$i]}"
  TI="${MR_TITLES[$i]}"
  SUB="${MR_SUBPROJECTS[$i]}"

  review_mr "$N" "$BR" "$TI" "$SUB" &
  PID=$!
  PIDS+=("$PID")
  PID_MRS+=("$N")
  ((ACTIVE++)) || true
  log "Spawned PID $PID for MR !${N}"
done

echo ""
log "All ${#PIDS[@]} review workers spawned. Waiting for completion..."
echo ""

FAILURES=0

for i in "${!PIDS[@]}"; do
  PID="${PIDS[$i]}"
  N="${PID_MRS[$i]}"
  if wait "$PID"; then
    ok "!${N} (PID $PID): SUCCESS"
  else
    err "!${N} (PID $PID): FAILED"
    ((FAILURES++)) || true
  fi
done

echo ""
log "═══════════════════════════════════════════════════"
if [[ $FAILURES -eq 0 ]]; then
  ok "All ${#MR_NUMBERS[@]} MR reviews completed successfully"
else
  err "$FAILURES of ${#MR_NUMBERS[@]} MR reviews had failures"
fi
log "═══════════════════════════════════════════════════"
log "Logs: $LOG_DIR/review-mr-*.log"
log "Worktrees: ${WT_PREFIX}*"

exit "$FAILURES"
