#!/usr/bin/env bash
# build.sh — Build the free AgentKit package for distribution
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/src"
DIST="$SCRIPT_DIR/dist"

rm -rf "$DIST"
mkdir -p "$DIST/agentkit/.cursor/rules" "$DIST/agentkit/.cursor/skills" "$DIST/agentkit/.cursor/agents"
mkdir -p "$DIST/agentkit/docs"

# Copy free skills
for skill in "$SRC/core/skills/"*/; do
  [[ -d "$skill" ]] && cp -r "$skill" "$DIST/agentkit/.cursor/skills/"
done

# Copy free rules
cp "$SRC/core/rules/"*.mdc "$DIST/agentkit/.cursor/rules/" 2>/dev/null || true

# Copy free agents
cp "$SRC/core/agents/"*.md "$DIST/agentkit/.cursor/agents/" 2>/dev/null || true

# Copy docs
cp -r "$SRC/core/docs/"* "$DIST/agentkit/docs/" 2>/dev/null || true

# Copy install script
cp "$SCRIPT_DIR/install.sh" "$DIST/agentkit/"

SKILL_COUNT=$(ls -d "$DIST/agentkit/.cursor/skills/"*/ 2>/dev/null | wc -l | tr -d ' ')
RULE_COUNT=$(ls "$DIST/agentkit/.cursor/rules/"*.mdc 2>/dev/null | wc -l | tr -d ' ')
AGENT_COUNT=$(ls "$DIST/agentkit/.cursor/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')

echo "✓ Built: dist/agentkit/ (${SKILL_COUNT} skills, ${RULE_COUNT} rules, ${AGENT_COUNT} agents)"
echo ""
echo "To install into a project: cp -r dist/agentkit/.cursor /path/to/your/project/"
