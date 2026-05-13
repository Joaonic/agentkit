#!/usr/bin/env bash
# parallel-implement.sh — Run implement-plan + review-open-pr for multiple GitLab
# issues in parallel using copilot CLI. Each issue gets its own git worktree.
#
# Usage:
#   ./scripts/parallel-implement.sh 42 55 60
#   COPILOT_MODEL=claude-opus-4.6 ./scripts/parallel-implement.sh 42 55
#
# Environment variables (optional):
#   COPILOT_MODEL     — model to use (default: claude-opus-4.6)
#   COPILOT_EFFORT    — reasoning effort (default: high)
#   REPO_ROOT         — path to main repo (default: $HOME/yo/org)
#   SUBPROJECT        — subproject path relative to REPO_ROOT for glab context
#                       (single-project mode — all issues are from this project)
#   ISSUE_SOURCES     — JSON map of issue# → project path for cross-project issues
#                       e.g. '{"85":"org","19":"web/your-web-app"}'
#                       When set, SUBPROJECT is ignored. Each issue is read from
#                       its source project, but implementation may target any submodule.
#   WT_PREFIX         — worktree path prefix (default: $HOME/yo/org-wt-)
#   LOG_DIR           — log base directory (default: $HOME/.copilot/logs)
#   SKIP_REVIEW       — set to 1 to skip the review phase
#   DRY_RUN           — set to 1 to print commands without executing

set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────────────
COPILOT_MODEL="${COPILOT_MODEL:-claude-opus-4.6}"
COPILOT_EFFORT="${COPILOT_EFFORT:-high}"
REPO_ROOT="${REPO_ROOT:-$HOME/yo/org}"
SUBPROJECT="${SUBPROJECT:-}"
ISSUE_SOURCES="${ISSUE_SOURCES:-}"
WT_PREFIX="${WT_PREFIX:-$HOME/yo/org-wt-}"
LOG_DIR="${LOG_DIR:-$HOME/.copilot/logs}"
SKIP_REVIEW="${SKIP_REVIEW:-0}"
DRY_RUN="${DRY_RUN:-0}"

# ── Helpers ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${CYAN}[parallel]${NC} $*"; }
ok()   { echo -e "${GREEN}[  ok  ]${NC} $*"; }
warn() { echo -e "${YELLOW}[ warn ]${NC} $*"; }
err()  { echo -e "${RED}[ERROR ]${NC} $*" >&2; }

# ── Validate inputs ─────────────────────────────────────────────────────────
if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <issue_number> [issue_number ...]"
  echo ""
  echo "Examples:"
  echo "  $0 42 55 60             # implement + review 3 issues in parallel"
  echo "  SKIP_REVIEW=1 $0 42    # implement only, skip review"
  echo "  DRY_RUN=1 $0 42 55     # print commands without executing"
  exit 1
fi

ISSUES=("$@")

for N in "${ISSUES[@]}"; do
  if ! [[ "$N" =~ ^[0-9]+$ ]]; then
    err "Invalid issue number: $N"
    exit 1
  fi
done

# Check prerequisites
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

# Resolve glab working directory for a given issue number.
# Priority: ISSUE_SOURCES (per-issue) > SUBPROJECT (global) > root
resolve_glab_dir() {
  local ISSUE_NUM="$1"
  if [[ -n "$ISSUE_SOURCES" ]]; then
    local SRC
    SRC=$(echo "$ISSUE_SOURCES" | jq -r --arg n "$ISSUE_NUM" '.[$n] // empty' 2>/dev/null || echo "")
    if [[ -n "$SRC" ]]; then
      # Derive root project from remote URL
      local ROOT_PROJ
      ROOT_PROJ=$(git -C "$REPO_ROOT" config remote.origin.url 2>/dev/null \
        | sed -E 's|.*[:/][^/]+/(.+)\.git$|\1|' 2>/dev/null || echo "")
      if [[ "$SRC" == "$ROOT_PROJ" || "$SRC" == "" ]]; then
        echo "$REPO_ROOT"
      else
        echo "${REPO_ROOT}/${SRC}"
      fi
      return
    fi
  fi
  if [[ -n "$SUBPROJECT" ]]; then
    echo "${REPO_ROOT}/${SUBPROJECT}"
  else
    echo "$REPO_ROOT"
  fi
}

# Legacy global GLAB_DIR (used for pre-flight only)
if [[ -n "$SUBPROJECT" ]]; then
  GLAB_DIR="${REPO_ROOT}/${SUBPROJECT}"
else
  GLAB_DIR="$REPO_ROOT"
fi

# ── Per-issue worker function ────────────────────────────────────────────────
run_issue() {
  local N="$1"
  local WT="${WT_PREFIX}${N}"
  local IMPL_LOG="${LOG_DIR}/impl-${N}"
  local REVIEW_LOG="${LOG_DIR}/review-${N}"
  local ISSUE_LOG="${LOG_DIR}/issue-${N}.log"

  mkdir -p "$IMPL_LOG" "$REVIEW_LOG" "$(dirname "$ISSUE_LOG")"

  exec > >(sed "s/^/$(printf '\033[0;35m[#%s]\033[0m ' "$N")/" | tee -a "$ISSUE_LOG") 2>&1

  log "Starting..."

  # ── 1. Fetch issue metadata to build branch name ──────────────────────────
  local ISSUE_GLAB_DIR
  ISSUE_GLAB_DIR=$(resolve_glab_dir "$N")

  local ISSUE_TITLE
  ISSUE_TITLE=$(cd "$ISSUE_GLAB_DIR" && glab issue view "$N" --output json 2>/dev/null | jq -r '.title' || echo "")

  if [[ -z "$ISSUE_TITLE" ]]; then
    err "Could not fetch issue #${N}. Does it exist and do you have access?"
    return 1
  fi

  # Slugify: lowercase, replace non-alnum with dash, trim dashes, max 50 chars
  local SLUG
  SLUG=$(echo "$ISSUE_TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//' | cut -c1-50)

  local BRANCH="feat/${N}-${SLUG}"

  log "Issue title: $ISSUE_TITLE"
  log "Branch: $BRANCH"
  log "Worktree: $WT"

  # ── 2. Create worktree ────────────────────────────────────────────────────
  if [[ -d "$WT" ]]; then
    warn "Worktree already exists at $WT — reusing"
    cd "$WT"
    git pull --rebase origin main 2>/dev/null || true
  else
    log "Creating worktree..."
    git -C "$REPO_ROOT" worktree add "$WT" -b "$BRANCH" origin/main 2>/dev/null || \
      git -C "$REPO_ROOT" worktree add "$WT" "$BRANCH" 2>/dev/null || {
        err "Failed to create worktree"
        return 1
      }
    cd "$WT"
  fi

  # Initialize submodules so the agent has access to all repos
  log "Initializing submodules..."
  git -C "$WT" submodule update --init --recursive --quiet 2>/dev/null || \
    warn "Some submodules failed to init (non-fatal)"

  # ── 3. Build glab context instructions for the prompt ─────────────────────
  local GLAB_CONTEXT=""
  local ISSUE_SOURCE_PROJ=""
  if [[ -n "$ISSUE_SOURCES" ]]; then
    ISSUE_SOURCE_PROJ=$(echo "$ISSUE_SOURCES" | jq -r --arg n "$N" '.[$n] // empty' 2>/dev/null || echo "")
  fi

  if [[ -n "$ISSUE_SOURCE_PROJ" ]]; then
    # Derive root project name for comparison
    local _ROOT_PROJ
    _ROOT_PROJ=$(git -C "$REPO_ROOT" config remote.origin.url 2>/dev/null \
      | sed -E 's|.*[:/][^/]+/(.+)\.git$|\1|' 2>/dev/null || echo "")
    if [[ "$ISSUE_SOURCE_PROJ" == "$_ROOT_PROJ" ]]; then
      GLAB_CONTEXT="The issue lives in the ROOT repo (${ISSUE_SOURCE_PROJ}). To read it: cd ${WT} && glab issue view ${N}."
    else
      GLAB_CONTEXT="The issue lives in the ${ISSUE_SOURCE_PROJ} project. To read it: cd ${WT}/${ISSUE_SOURCE_PROJ} && glab issue view ${N}."
    fi
    GLAB_CONTEXT="${GLAB_CONTEXT} \
IMPORTANT: The issue may describe work that targets a DIFFERENT submodule than where it was filed. \
Read the issue description carefully to determine which submodule(s) to change. \
This monorepo has submodules in apps/, web/, infra/, libraries/. Each has its own git remote, branches, and CI. \
When creating the branch and MR, do it in the TARGET submodule's git repo (cd into it, create branch, push, glab mr create)."
  elif [[ -n "$SUBPROJECT" ]]; then
    GLAB_CONTEXT="To read the issue: cd ${WT}/${SUBPROJECT} && glab issue view ${N}. \
Create the MR in the ${SUBPROJECT} project."
  else
    GLAB_CONTEXT="To read the issue: cd ${WT} && glab issue view ${N}."
  fi

  # ── 4. Phase 1: Implement ─────────────────────────────────────────────────
  local IMPL_PROMPT
  IMPL_PROMPT="Use glab CLI for GitLab ops, never MCP for VCS. \
Issue #${N} is the source of truth — read its description AND all comments. \
${GLAB_CONTEXT} \
Use the implement-plan skill: investigate the issue, create or locate the plan, then implement with TDD. \
Follow the skill workflow: investigation → TDD → implementation → code-review → posttask. \
When researching APIs or libraries (Spring Boot, React, Next.js, Flyway, JPA, etc.), ALWAYS use context7 MCP \
(mcp_context7_resolve-library-id + mcp_context7_query-docs) to get current documentation. Do NOT rely on training data alone. \
Stack: Java 21 / Spring Boot 3 (Maven) for backend modules, TypeScript / React / Next.js (Yarn) for web modules. \
Use ./mvnw for Java builds (e.g. ./mvnw test, ./mvnw package -DskipTests). Use yarn for web. \
MONOREPO: This workspace is a monorepo with git submodules. Each submodule (apps/*, web/*, infra/*, libraries/*) has its own \
git remote, branches, and CI pipeline. When you determine which submodule to change: \
1. cd into the submodule directory within this worktree \
2. Create a branch there: git checkout -b ${BRANCH} \
3. Make your changes, commit and push to that submodule's remote \
4. Create the MR in that submodule: cd <submodule> && glab mr create --source-branch ${BRANCH} --target-branch main \
   --title '<type>(#${N}): <title>' --description 'Closes <project>#${N}\n\n<body>' --assignee @me \
5. If the issue is in a different project than where you implement, use cross-project reference in Closes: \
   e.g. 'Closes your-org/monorepo#${N}' \
Push all changes and ensure CI passes. \
CI RULES (MANDATORY): \
1. CI RED is BLOCKING — do NOT proceed with any pipeline stage failing. Fix the code first. \
2. GitLab CI uses fail-fast: one job fails → subsequent jobs may be cancelled. The REAL failure is in the failed job's log. \
3. To diagnose: glab ci list --ref ${BRANCH} to find the latest pipeline, then glab ci trace <job-id> or glab ci get -p <pipeline-id>. \
4. Fix the root cause in code, push, then wait for the NEW pipeline. NEVER re-run a failed pipeline without fixing the code. \
5. NEVER skip broken tests, lint errors, or build failures — every problem is blocking. \
REBASE RULES (MANDATORY): \
1. When rebasing onto main, NEVER lose code that already existed in main. The rebase ADDS main — it does NOT overwrite. \
2. During conflict resolution, BOTH sides must be preserved. Do NOT accept 'ours' or 'theirs' globally — inspect each hunk individually. \
3. After rebase, verify: git diff origin/main..HEAD -- <conflicted files>. If ANY functionality from main disappeared, it is WRONG — fix immediately."

  log "Phase 1 — IMPLEMENT"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY_RUN] copilot --model $COPILOT_MODEL --reasoning-effort $COPILOT_EFFORT --allow-all-tools \\"
    echo "  --add-dir $HOME/yo --add-dir /tmp --disable-builtin-mcps \\"
    echo "  --log-dir $IMPL_LOG --log-level info \\"
    echo "  -p \"<IMPL_PROMPT>\""
  else
    copilot \
      --model "$COPILOT_MODEL" \
      --reasoning-effort "$COPILOT_EFFORT" \
      --allow-all-tools \
      --add-dir "$HOME/yo" \
      --add-dir /tmp \
      --disable-builtin-mcps \
      --log-dir "$IMPL_LOG" \
      --log-level info \
      -p "$IMPL_PROMPT"
  fi

  local IMPL_EXIT=$?
  if [[ $IMPL_EXIT -ne 0 ]]; then
    err "Implementation phase exited with code $IMPL_EXIT"
  fi
  ok "Phase 1 (implement) finished (exit=$IMPL_EXIT)"

  # ── 4. Phase 2: Review ────────────────────────────────────────────────────
  if [[ "$SKIP_REVIEW" == "1" ]]; then
    warn "Skipping review phase (SKIP_REVIEW=1)"
    ok "Done (implement only)"
    return 0
  fi

  local REVIEW_PROMPT
  REVIEW_PROMPT="Use glab CLI for GitLab ops, never MCP for VCS. \
Run the review-open-pr skill for the MR on branch ${BRANCH}. \
Issue #${N} is the source of truth — read its description AND all comments. \
${GLAB_CONTEXT} \
Find the open MR with: glab mr list --source-branch ${BRANCH} (run from the submodule where the MR was created). \
ZERO TOLERANCE POLICY: There is NO 'approved with reservations' or 'non-blocking issues'. \
Every problem found in scope (code, tests, UX, docs, accessibility) is BLOCKING and MUST be resolved. \
If the MR touches web/**, run the full UX review checklist from the ux-review skill — UX issues are BLOCKING. \
When validating implementations, use context7 MCP (mcp_context7_resolve-library-id + mcp_context7_query-docs) \
to verify against current official documentation. \
Fix ALL issues found in this worktree, push fixes, and wait for the CI pipeline to re-run. \
Do NOT merge the MR. Only stop when CI is fully GREEN and ZERO problems remain in scope. \
Leave the MR open and ready for human merge. \
CI RULES (MANDATORY): \
1. CI RED is BLOCKING — do NOT approve or stop with any pipeline failing. Fix the code first. \
2. To diagnose failures: glab ci list --ref ${BRANCH}, then glab ci trace <job-id> for the failing job. \
3. Fix the root cause in code, push, then wait for the NEW pipeline. NEVER re-run without a fix. \
REBASE RULES (MANDATORY): \
1. When rebasing onto main, NEVER lose code from main. Both sides of every conflict MUST be preserved. \
2. After rebase, verify: git diff origin/main..HEAD -- <conflicted files>. Code loss is BLOCKING."

  log "Phase 2 — REVIEW"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY_RUN] copilot --model $COPILOT_MODEL --reasoning-effort $COPILOT_EFFORT --allow-all-tools \\"
    echo "  --add-dir $HOME/yo --add-dir /tmp --disable-builtin-mcps \\"
    echo "  --log-dir $REVIEW_LOG --log-level info \\"
    echo "  -p \"<REVIEW_PROMPT>\""
  else
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
  fi

  local REVIEW_EXIT=$?
  if [[ $REVIEW_EXIT -ne 0 ]]; then
    err "Review phase exited with code $REVIEW_EXIT"
  fi
  ok "Phase 2 (review) finished (exit=$REVIEW_EXIT)"
  ok "Done"
}

# ── Main: launch all issues in parallel ──────────────────────────────────────
log "Launching ${#ISSUES[@]} issue(s) in parallel: ${ISSUES[*]}"
log "Model: $COPILOT_MODEL | Effort: $COPILOT_EFFORT | Review: $([ "$SKIP_REVIEW" = "1" ] && echo "skip" || echo "yes")"
echo ""

log "Pre-fetching origin/main..."
git -C "$REPO_ROOT" fetch origin main --quiet
ok "Refs up to date"
echo ""

# Trap Ctrl+C / SIGTERM to kill all child processes
cleanup() {
  echo ""
  warn "Signal received — killing all workers..."
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
PID_ISSUES=()

for N in "${ISSUES[@]}"; do
  run_issue "$N" &
  PID=$!
  PIDS+=("$PID")
  PID_ISSUES+=("$N")
  log "Spawned PID $PID for issue #${N}"
done

echo ""
log "All ${#PIDS[@]} workers spawned. Waiting for completion..."
echo ""

FAILURES=0

for i in "${!PIDS[@]}"; do
  PID="${PIDS[$i]}"
  N="${PID_ISSUES[$i]}"
  if wait "$PID"; then
    ok "#${N} (PID $PID): SUCCESS"
  else
    err "#${N} (PID $PID): FAILED"
    ((FAILURES++)) || true
  fi
done

echo ""
log "═══════════════════════════════════════════════════"
if [[ $FAILURES -eq 0 ]]; then
  ok "All ${#ISSUES[@]} issues completed successfully"
else
  err "$FAILURES of ${#ISSUES[@]} issues had failures"
fi
log "═══════════════════════════════════════════════════"
log "Logs: $LOG_DIR/issue-*.log"
log "Worktrees: ${WT_PREFIX}*"

exit "$FAILURES"
