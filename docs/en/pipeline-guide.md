# Pipeline Guide (Pro)

The AgentKit pipeline is a set of 4 bash scripts that orchestrate AI coding agents to autonomously implement, review, and merge code across multiple projects.

## Architecture

```
pipeline.sh
├── parallel-implement.sh    (N workers in git worktrees)
│   └── copilot-cli agent    (per issue, per worktree)
├── parallel-review.sh       (review open MRs/PRs)
│   └── copilot-cli agent    (per MR, per worktree)
└── sequential-merge.sh      (merge MRs in order)
    └── copilot-cli agent    (rebase chain)
```

## Quick Start

```bash
# Run full pipeline on specific issues
./scripts/pipeline.sh apps/my-service:42 apps/my-service:43

# Dry run (see what would happen)
DRY_RUN=1 ./scripts/pipeline.sh apps/my-service:42

# Run with specific review mode
REVIEW_MODE=inline ./scripts/pipeline.sh apps/my-service:42
```

## Scripts

### pipeline.sh — Full orchestrator

Runs PRIORITIZE → IMPLEMENT → REVIEW → MERGE in waves.

**Environment variables:**
| Variable | Default | Description |
|----------|---------|-------------|
| `REVIEW_MODE` | `inline` | `inline` = review in implement worker; `separate` = Phase 2; `skip` = no review |
| `SKIP_MERGE` | `0` | Skip merge phase |
| `MAX_WAVES` | unlimited | Max pipeline iterations |
| `MAX_PARALLEL` | unlimited | Max parallel workers |
| `WAVE_PAUSE` | `0` | Seconds to pause between waves |
| `DRY_RUN` | `0` | Show commands without executing |
| `COPILOT_MODEL` | `claude-opus-4.6` | Model for copilot CLI |
| `COPILOT_EFFORT` | `high` | Effort level |

**Usage patterns:**
```bash
# Single project, specific issues
./scripts/pipeline.sh apps/my-service:42 apps/my-service:43

# Group mode (all projects with open issues)
SKIP_PRIORITIZE=1 ./scripts/pipeline.sh apps/my-service:42

# Auto-loop until no more issues
./scripts/pipeline.sh  # (requires prioritize-roadmap skill)
```

### parallel-implement.sh — Parallel implementation

Spawns N copilot CLI agents in parallel, each in its own git worktree.

**Key features:**
- Each issue gets an isolated worktree (no file conflicts)
- Cross-project issue routing via `ISSUE_SOURCES` JSON
- Inline review per worker (when `SKIP_REVIEW=0`)
- Configurable max parallelism

```bash
# Direct usage
ISSUE_SOURCES='{"42":"apps/my-service","43":"apps/other-service"}' \
  ./scripts/parallel-implement.sh 42 43
```

### parallel-review.sh — Parallel review

Auto-discovers open MRs/PRs and reviews them in parallel.

```bash
# Review all open MRs in current project
./scripts/parallel-review.sh

# Review specific MRs
./scripts/parallel-review.sh 5 6 7
```

### sequential-merge.sh — Smart merge chain

Merges MRs/PRs sequentially within a project (rebase chain to avoid conflicts).

```bash
# Merge all eligible MRs
SUBPROJECT=apps/my-service ./scripts/sequential-merge.sh
```

## Review Modes

| Mode | Behavior | Best for |
|------|----------|----------|
| `inline` (default) | Review runs inside each implement worker as soon as MR is created | Fastest feedback loop |
| `separate` | All implementations finish first, then all reviews run in parallel | Batch review workflows |
| `skip` | No review at all | Quick experiments, trusted changes |

## Pipeline Flow

```
Wave 1:
  ┌─ Implement issue #42 (worktree 1) ─── Review MR ─┐
  ├─ Implement issue #43 (worktree 2) ─── Review MR ─┤ (inline mode)
  └─ Implement issue #44 (worktree 3) ─── Review MR ─┘
  
  ┌─ Merge MR for #42 ─┐
  ├─ Merge MR for #43 ─┤ (parallel across projects)
  └─ Merge MR for #44 ─┘

Wave 2:
  (repeat with new issues if auto-loop enabled)
```

## Prerequisites

- `copilot` CLI installed and authenticated
- `gh` or `glab` CLI installed and authenticated
- Git configured with user.name and user.email
- Project with issues to implement
