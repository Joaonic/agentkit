#!/usr/bin/env bash
# sequential-merge.sh — Single copilot agent that merges all eligible open MRs
# in optimal order via squash, handling rebases, CI checks, and cleanup.
#
# Flow:
#   1. Agent analyzes all open MRs (with linked issues + green CI)
#   2. Determines optimal merge order (least conflicts first, dependencies)
#   3. Squash-merges each MR sequentially, rebasing when needed
#   4. All merges except the last use [skip ci] in squash + merge commit messages
#   5. Waits for CI green on the final merge
#   6. Cleans up: worktrees, local branches, remote branches
#
# Usage:
#   ./scripts/sequential-merge.sh              # merge all eligible MRs
#   DRY_RUN=1 ./scripts/sequential-merge.sh    # print command without executing
#
# Environment variables (optional):
#   COPILOT_MODEL     — model to use (default: claude-opus-4.6)
#   COPILOT_EFFORT    — reasoning effort (default: high)
#   REPO_ROOT         — path to main repo (default: $HOME/yo/org)
#   SUBPROJECT        — subproject path relative to REPO_ROOT for glab context
#   LOG_DIR           — log base directory (default: $HOME/.copilot/logs)
#   DRY_RUN           — set to 1 to print command without executing

set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────────────
COPILOT_MODEL="${COPILOT_MODEL:-claude-opus-4.6}"
COPILOT_EFFORT="${COPILOT_EFFORT:-high}"
REPO_ROOT="${REPO_ROOT:-$HOME/yo/org}"
SUBPROJECT="${SUBPROJECT:-}"
LOG_DIR="${LOG_DIR:-$HOME/.copilot/logs}"
DRY_RUN="${DRY_RUN:-0}"

# ── Helpers ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${CYAN}[merge]${NC} $*"; }
ok()   { echo -e "${GREEN}[  ok ]${NC} $*"; }
warn() { echo -e "${YELLOW}[ warn]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

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

# ── Collect submodule paths ───────────────────────────────────────────────────
# If SUBPROJECT is set, only scan that one; otherwise scan ALL submodules + root.
SUBMODULE_PATHS=()
if [[ -n "$SUBPROJECT" ]]; then
  SUBMODULE_PATHS=("$SUBPROJECT")
else
  # Parse all submodule paths from .gitmodules
  if [[ -f "${REPO_ROOT}/.gitmodules" ]]; then
    while IFS= read -r sm_path; do
      SUBMODULE_PATHS+=("$sm_path")
    done < <(git config -f "${REPO_ROOT}/.gitmodules" --get-regexp 'submodule\..*\.path' | awk '{print $2}')
  fi
  # Also include the root repo itself (it may have its own MRs)
  SUBMODULE_PATHS=("." "${SUBMODULE_PATHS[@]}")
fi

# ── Pre-flight: list eligible MRs across ALL projects ────────────────────────
log "Scanning ${#SUBMODULE_PATHS[@]} project(s) for open MRs..."

ALL_MR_SUMMARY=""
TOTAL_COUNT=0

for SM_PATH in "${SUBMODULE_PATHS[@]}"; do
  SM_DIR="${REPO_ROOT}/${SM_PATH}"
  [[ -d "$SM_DIR/.git" || -f "$SM_DIR/.git" ]] || continue

  MR_JSON=$(cd "$SM_DIR" && glab mr list --output json 2>/dev/null) || continue
  [[ -z "$MR_JSON" || "$MR_JSON" == "[]" || "$MR_JSON" == "null" ]] && continue

  # Filter: not draft/WIP
  ELIGIBLE=$(echo "$MR_JSON" | jq '[.[] | select((.work_in_progress // .draft // false) == false)]')
  SM_COUNT=$(echo "$ELIGIBLE" | jq 'length')
  [[ "$SM_COUNT" -eq 0 ]] && continue

  SM_SUMMARY=$(echo "$ELIGIBLE" | jq -r --arg proj "$SM_PATH" '.[] | "[\($proj)] MR !\(.iid) — \(.title) (branch: \(.source_branch))"')

  ALL_MR_SUMMARY+="${SM_SUMMARY}"$'\n'
  TOTAL_COUNT=$((TOTAL_COUNT + SM_COUNT))
done

# Trim trailing newline
ALL_MR_SUMMARY=$(echo "$ALL_MR_SUMMARY" | sed '/^$/d')

if [[ "$TOTAL_COUNT" -eq 0 ]]; then
  warn "No eligible MRs found across any project."
  exit 0
fi

MR_SUMMARY="$ALL_MR_SUMMARY"
COUNT="$TOTAL_COUNT"

log "Eligible MRs: $COUNT"
echo "$MR_SUMMARY" | while IFS= read -r line; do echo "       ↳ $line"; done
echo ""

# ── Build log paths ──────────────────────────────────────────────────────────
MERGE_LOG="${LOG_DIR}/sequential-merge"
MAIN_LOG="${LOG_DIR}/sequential-merge.log"
mkdir -p "$MERGE_LOG" "$(dirname "$MAIN_LOG")"

# ── Build the copilot prompt ─────────────────────────────────────────────────
PROMPT="Use glab CLI for GitLab ops, never MCP for VCS.

TASK: Sequentially squash-merge all eligible open MRs into main in optimal order.
IMPORTANT: MRs come from MULTIPLE projects (submodules). Each MR line is prefixed with [project/path].
You MUST cd into the correct submodule directory before running ANY glab command for that MR.

ELIGIBLE MRs (format: [project] MR !N — title (branch: name)):
${MR_SUMMARY}

REPO_ROOT=${REPO_ROOT}
To run glab for a given MR, always: cd \${REPO_ROOT}/<project_path> && glab ...
Example: for [apps/my-service] MR !5, run: cd ${REPO_ROOT}/apps/my-service && glab mr view 5

INSTRUCTIONS — follow exactly:

1. ANALYSIS PHASE:
   - For each MR above, cd into its project directory and run: glab mr view <N> --output json
   - Check CI status for each branch: glab ci list --ref <source_branch> (look at the latest pipeline status)
   - Get linked closing issues: glab api '/projects/:id/merge_requests/<N>/closes_issues'
   - Only include MRs where the latest pipeline is SUCCESS. Skip MRs with failed/pending CI — list them at the end as skipped.
   - Determine the optimal merge order: fewest conflicts first, then smallest diff, then dependencies (if MR B touches files modified by MR A, merge A first).
   - When ordering across projects, independent projects can be merged in any order; prioritize by smallest diff.
   - Print the planned merge order before starting.

2. SEQUENTIAL MERGE PHASE:
   - There are N MRs to merge (possibly across different projects). For MRs 1 through N-1 (all except the last), BOTH the squash-message AND merge-message MUST include '[skip ci]' at the end of the first line.
   - For the LAST MR (Nth), do NOT add '[skip ci]' — this is the one that triggers CI.
   - For each MR in order (remember to cd into its project directory for ALL glab commands):
     a. Ensure the MR branch is up to date with main. If behind, rebase onto main:
        - PROJECT_DIR='${REPO_ROOT}/<project_path>'   # from the [project] prefix
        - cd \$PROJECT_DIR && git fetch origin main
        - git worktree add /tmp/org-merge-<project_slug>-<N> <source_branch> 2>/dev/null || (cd /tmp/org-merge-<project_slug>-<N> && git pull)
        - cd /tmp/org-merge-<project_slug>-<N> && git rebase origin/main
        - If conflicts: resolve them. Then: git push --force-with-lease origin <source_branch>
     b. CRITICAL REBASE RULE: NEVER lose code from main during conflict resolution. Both sides of every conflict MUST be preserved — the new feature code AND the existing main code. Do NOT accept 'ours' or 'theirs' globally; inspect and merge each hunk individually. After resolution, verify: git diff origin/main..HEAD -- <conflicted files>. If ANY code from main disappeared, the resolution is WRONG — fix immediately.
     c. MANDATORY CI WAIT (every MR, every rebase — no exceptions):
        After ANY rebase or force-push, you MUST wait for ALL CI checks to pass before proceeding to merge.
        Poll: glab ci list --ref <source_branch> (check the latest pipeline's status field)
        DO NOT proceed to step (d) until the pipeline status is 'success'.
        If the pipeline fails or is cancelled, diagnose with:
          glab ci trace <job-id>  (use glab ci list to find job ids)
        Fix the root cause, push, and wait for the NEW pipeline.
        NEVER re-run a failed pipeline without fixing the code.
     d. ONLY AFTER CI is SUCCESS — Squash merge (run from the project directory):
        cd \$PROJECT_DIR && glab mr merge <N> --squash --squash-message '<commit message>' --message '<commit message>' --remove-source-branch --yes
        CRITICAL: GitLab squash merge creates TWO commits (squash + merge commit), BOTH trigger CI independently.
        You MUST pass the SAME message to BOTH --squash-message AND --message flags.
        - For MRs 1..N-1: message format: 'feat(#ISSUE): MR title [skip ci]' (or fix/chore as appropriate)
        - For MR N (last): message format: 'feat(#ISSUE): MR title' (NO skip ci)
     e. After merge, pull main in that project: cd \$PROJECT_DIR && git pull origin main
     f. Verify merge succeeded: cd \$PROJECT_DIR && glab mr view <N> --output json | jq .state (should be 'merged')

3. FINAL CI WAIT:
   - After the last merge (no [skip ci]), wait for CI on main in THAT project.
   - cd into the project directory and poll: glab ci list --ref main (check the latest pipeline status)
   - If the pipeline fails:
     a. Find the failing job: glab ci list --ref main and look for failed jobs
     b. Read logs: glab ci trace <job-id>
     c. Fix the root cause in code, push the fix to main (via a new MR or direct push if allowed).
     d. Wait for the new pipeline to complete.
   - Repeat for each project that had [skip ci] merges — those need a final CI trigger.
     If a project had only [skip ci] merges (no last-merge without skip ci), push an empty commit
     or trigger a new pipeline on main: cd \$PROJECT_DIR && glab ci run --branch main

4. CLEANUP PHASE:
   After all merges are done:
   a. Remove all local worktrees for the merged branches:
      - Check /tmp/org-merge-* paths
      - For each project that had merges: git -C \$PROJECT_DIR worktree list --porcelain
      - Remove: git -C \$PROJECT_DIR worktree remove <path> --force
   b. Delete local branches in each project: git -C \$PROJECT_DIR branch -D <branch> (ignore errors if not exists)
   c. Prune stale remote refs per project: git -C \$PROJECT_DIR fetch --prune

5. SYNC ALL TOUCHED REPOS TO MAIN:
   CRITICAL — after all merges and cleanup, you MUST leave every touched repo on main and up to date.
   For EVERY project that had at least one MR merged:
     a. cd \$PROJECT_DIR
     b. git checkout main
     c. git pull origin main --rebase
     d. Verify: git --no-pager log --oneline -3  (confirm the squash commit(s) are visible)
   Also update the root monorepo to reflect new submodule SHAs:
     a. cd ${REPO_ROOT}
     b. For each touched submodule path: git add <submodule_path>
     c. If there are staged submodule pointer changes:
        git commit -m 'chore: update submodule refs after merge wave'
        git push origin main
     d. git pull origin main --rebase  (ensure root is up to date)

6. FINAL REPORT:
   Print a summary:
   - Merged MRs (in order): project, MR number, title, squash commit SHA
   - Skipped MRs (CI not passing): project, MR number, reason
   - Cleanup: worktrees removed, branches deleted
   - Repo sync: list each project synced to main with latest commit SHA
   - CI status on main per project after final merge"

# ── Launch ───────────────────────────────────────────────────────────────────
log "Launching sequential merge agent..."
log "Model: $COPILOT_MODEL | Effort: $COPILOT_EFFORT"
log "Log dir: $MERGE_LOG"
echo ""

# Save prompt for reference
echo "$PROMPT" > "${MERGE_LOG}/prompt.txt"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[DRY_RUN] copilot --model $COPILOT_MODEL --reasoning-effort $COPILOT_EFFORT --allow-all-tools \\"
  echo "  --add-dir $HOME/yo --add-dir /tmp --disable-builtin-mcps \\"
  echo "  --log-dir $MERGE_LOG --log-level info \\"
  echo "  -p \"<prompt with $COUNT MRs>\""
  echo ""
  echo "[DRY_RUN] Full prompt:"
  echo "─────────────────────────────────────────"
  echo "$PROMPT"
  echo "─────────────────────────────────────────"
  ok "Dry run complete"
  exit 0
fi

cd "$REPO_ROOT"

copilot \
  --model "$COPILOT_MODEL" \
  --reasoning-effort "$COPILOT_EFFORT" \
  --allow-all-tools \
  --add-dir "$HOME/yo" \
  --add-dir /tmp \
  --disable-builtin-mcps \
  --log-dir "$MERGE_LOG" \
  --log-level info \
  -p "$PROMPT" \
  2>&1 | tee "$MAIN_LOG"

EXIT_CODE=${PIPESTATUS[0]}

echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
  ok "Sequential merge agent completed successfully"
else
  err "Sequential merge agent exited with code $EXIT_CODE"
fi

log "Log: $MAIN_LOG"
log "Copilot logs: $MERGE_LOG/"

exit "$EXIT_CODE"
