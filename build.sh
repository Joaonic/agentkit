#!/usr/bin/env bash
# build.sh — Build distributable packages for AgentKit
# Produces 4 zip files in dist/:
#   agentkit-free-github.zip
#   agentkit-free-gitlab.zip
#   agentkit-pro-github.zip
#   agentkit-pro-gitlab.zip
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/src"
MANIFESTS="$SCRIPT_DIR/manifests"
DIST="$SCRIPT_DIR/dist"

rm -rf "$DIST"
mkdir -p "$DIST"

# ── Helper: read manifest (skip comments and blank lines) ────────────────────
read_manifest() {
  grep -v '^#' "$1" | grep -v '^$' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
}

# ── Build a single package ───────────────────────────────────────────────────
# Usage: build_package <tier> <provider>
#   tier: free | pro
#   provider: github | gitlab
build_package() {
  local TIER="$1"
  local PROVIDER="$2"
  local PKG_NAME="agentkit-${TIER}-${PROVIDER}"
  local PKG_DIR="$DIST/$PKG_NAME"

  echo "━━━ Building $PKG_NAME ━━━"

  rm -rf "$PKG_DIR"
  mkdir -p "$PKG_DIR/.cursor/rules" "$PKG_DIR/.cursor/skills" "$PKG_DIR/.cursor/agents"
  mkdir -p "$PKG_DIR/scripts" "$PKG_DIR/docs/governance/workflow"

  # ── 1. Copy skills ──────────────────────────────────────────────────────────
  # Free skills always included
  while IFS= read -r skill; do
    [[ -z "$skill" ]] && continue
    if [[ -d "$SRC/core/skills/$skill" ]]; then
      cp -r "$SRC/core/skills/$skill" "$PKG_DIR/.cursor/skills/"
    fi
  done < <(read_manifest "$MANIFESTS/free-skills.txt")

  # Pro skills if pro tier
  if [[ "$TIER" == "pro" ]]; then
    while IFS= read -r skill; do
      [[ -z "$skill" ]] && continue
      if [[ -d "$SRC/core/skills/$skill" ]]; then
        cp -r "$SRC/core/skills/$skill" "$PKG_DIR/.cursor/skills/"
      fi
    done < <(read_manifest "$MANIFESTS/pro-skills.txt")
  fi

  # ── 2. Copy rules ──────────────────────────────────────────────────────────
  while IFS= read -r rule; do
    [[ -z "$rule" ]] && continue
    if [[ -f "$SRC/core/rules/$rule" ]]; then
      cp "$SRC/core/rules/$rule" "$PKG_DIR/.cursor/rules/"
    fi
  done < <(read_manifest "$MANIFESTS/free-rules.txt")

  if [[ "$TIER" == "pro" ]]; then
    while IFS= read -r rule; do
      [[ -z "$rule" ]] && continue
      if [[ -f "$SRC/core/rules/$rule" ]]; then
        cp "$SRC/core/rules/$rule" "$PKG_DIR/.cursor/rules/"
      fi
    done < <(read_manifest "$MANIFESTS/pro-rules.txt")
  fi

  # ── 3. Copy agents ─────────────────────────────────────────────────────────
  while IFS= read -r agent; do
    [[ -z "$agent" ]] && continue
    if [[ -f "$SRC/core/agents/$agent" ]]; then
      cp "$SRC/core/agents/$agent" "$PKG_DIR/.cursor/agents/"
    fi
  done < <(read_manifest "$MANIFESTS/free-agents.txt")

  if [[ "$TIER" == "pro" ]]; then
    while IFS= read -r agent; do
      [[ -z "$agent" ]] && continue
      if [[ -f "$SRC/core/agents/$agent" ]]; then
        cp "$SRC/core/agents/$agent" "$PKG_DIR/.cursor/agents/"
      fi
    done < <(read_manifest "$MANIFESTS/pro-agents.txt")
  fi

  # ── 4. Copy scripts (provider-specific) ────────────────────────────────────
  if [[ "$TIER" == "pro" ]]; then
    cp "$SRC/$PROVIDER/scripts/"*.sh "$PKG_DIR/scripts/" 2>/dev/null || true
    chmod +x "$PKG_DIR/scripts/"*.sh 2>/dev/null || true
  fi

  # ── 5. Copy governance docs (pro only) ─────────────────────────────────────
  if [[ "$TIER" == "pro" ]]; then
    cp "$SRC/core/docs/governance/"*.md "$PKG_DIR/docs/governance/" 2>/dev/null || true
    cp "$SRC/core/docs/governance/workflow/"*.md "$PKG_DIR/docs/governance/workflow/" 2>/dev/null || true
  fi

  # ── 6. Provider-specific overlays ──────────────────────────────────────────
  if [[ "$PROVIDER" == "github" ]]; then
    mkdir -p "$PKG_DIR/.github"
    # Create copilot-instructions.md
    cat > "$PKG_DIR/.github/copilot-instructions.md" << 'COPILOT'
# AgentKit — GitHub Copilot Instructions

This project uses the AgentKit governance framework.
Skills, rules, and agents are in `.cursor/` and work with Cursor, Copilot, and any AI agent.

## Quick Reference

- **Skills:** `.cursor/skills/<name>/SKILL.md` — executable workflows
- **Rules:** `.cursor/rules/<name>.mdc` — always-on guardrails
- **Agents:** `.cursor/agents/<name>.md` — specialized personas

## Mandatory Gates

1. **Planning** — No implementation without clear scope (use `new-plan` skill)
2. **TDD** — Behavior changes require failing-first tests (use `tdd-workflow` skill)
3. **Review** — No completion without technical review (use `review-open-pr` skill)
4. **Validation** — No completion without posttask evidence (use `posttask` skill)

## VCS

This project uses **GitHub** (`gh` CLI) for issues, PRs, and CI.
Commits follow semantic format: `type(scope): description`
COPILOT
    # Symlink skills for Copilot
    ln -sf ../.cursor/skills "$PKG_DIR/.github/skills" 2>/dev/null || true
  fi

  # Copy VCS-specific rule overlay
  if [[ -f "$SRC/$PROVIDER/rules/06-vcs-policy.mdc" ]]; then
    cp "$SRC/$PROVIDER/rules/06-vcs-policy.mdc" "$PKG_DIR/.cursor/rules/"
  fi

  # ── 7. Create AGENTS.md ────────────────────────────────────────────────────
  local SKILL_COUNT RULE_COUNT AGENT_COUNT
  SKILL_COUNT=$(ls -d "$PKG_DIR/.cursor/skills/"*/ 2>/dev/null | wc -l | tr -d ' ')
  RULE_COUNT=$(ls "$PKG_DIR/.cursor/rules/"*.mdc 2>/dev/null | wc -l | tr -d ' ')
  AGENT_COUNT=$(ls "$PKG_DIR/.cursor/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')

  local TIER_UPPER PROVIDER_UPPER
  TIER_UPPER="$(echo "$TIER" | tr '[:lower:]' '[:upper:]')"
  PROVIDER_UPPER="$(echo "$PROVIDER" | tr '[:lower:]' '[:upper:]')"

  cat > "$PKG_DIR/AGENTS.md" << AGENTS
# AgentKit — AI Engineering Governance Framework

> **Tier:** ${TIER_UPPER}
> **VCS:** ${PROVIDER_UPPER} (\`$([ "$PROVIDER" = "github" ] && echo "gh" || echo "glab")\` CLI)
> **Assets:** ${SKILL_COUNT} skills, ${RULE_COUNT} rules, ${AGENT_COUNT} agents

## Quality Gates (mandatory)

1. **Planning** — No implementation with ambiguous scope
2. **TDD** — Behavior changes require failing-first tests
3. **Review** — No completion without technical review
4. **Validation** — No completion without posttask evidence
5. **Documentation** — Changes require doc synchronization

## Skills

Executable workflows in \`.cursor/skills/<name>/SKILL.md\`.
Run a skill by referencing it in your AI agent conversation.

## Rules

Always-on guardrails in \`.cursor/rules/<name>.mdc\`.
Automatically loaded by Cursor based on glob patterns.

## Agents

Specialized personas in \`.cursor/agents/<name>.md\`.
Each agent has domain expertise and enforces relevant standards.

## Getting Started

See [docs/getting-started.md](docs/getting-started.md) or visit https://github.com/Joaonic/agentkit
AGENTS

  # ── 8. Zip ─────────────────────────────────────────────────────────────────
  (cd "$DIST" && zip -qr "${PKG_NAME}.zip" "$PKG_NAME")
  local ZIP_SIZE
  ZIP_SIZE=$(du -sh "$DIST/${PKG_NAME}.zip" | awk '{print $1}')

  echo "  ✓ $PKG_NAME: ${SKILL_COUNT} skills, ${RULE_COUNT} rules, ${AGENT_COUNT} agents → ${ZIP_SIZE}"
  echo ""
}

# ── Main ─────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║        AgentKit — Building Packages              ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

build_package "free" "github"
build_package "free" "gitlab"
build_package "pro" "github"
build_package "pro" "gitlab"

echo "━━━ Build Summary ━━━"
ls -lh "$DIST/"*.zip
echo ""
echo "All packages in: $DIST/"
