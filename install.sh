#!/usr/bin/env bash
# install.sh — Install AgentKit governance framework into your project
#
# Usage:
#   # Interactive mode (detects VCS, asks tier):
#   curl -sL https://raw.githubusercontent.com/Joaonic/agentkit/main/install.sh | bash
#
#   # Direct mode:
#   ./install.sh                              # Auto-detect everything
#   ./install.sh --provider github --tier pro  # Explicit
#   ./install.sh --provider gitlab --tier free
#   ./install.sh --preset java                 # Stack preset
#   ./install.sh --preset nextjs
#   ./install.sh --preset fullstack
#   ./install.sh --preset minimal
#
set -euo pipefail

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${BLUE}[agentkit]${NC} $*"; }
ok()   { echo -e "${GREEN}[agentkit]${NC} $*"; }
warn() { echo -e "${YELLOW}[agentkit]${NC} $*"; }
err()  { echo -e "${RED}[agentkit]${NC} $*"; }

# ── Defaults ─────────────────────────────────────────────────────────────────
PROVIDER=""
TIER="free"
PRESET=""
AGENTKIT_REPO="https://github.com/Joaonic/agentkit"
AGENTKIT_BRANCH="main"
FORCE=0

# ── Parse args ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider)  PROVIDER="$2"; shift 2 ;;
    --tier)      TIER="$2"; shift 2 ;;
    --preset)    PRESET="$2"; shift 2 ;;
    --force)     FORCE=1; shift ;;
    --help|-h)
      echo "Usage: install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --provider github|gitlab   VCS provider (auto-detected if omitted)"
      echo "  --tier free|pro            Package tier (default: free)"
      echo "  --preset NAME              Stack preset: java, nextjs, node, fullstack, minimal"
      echo "  --force                    Overwrite existing files"
      echo "  -h, --help                 Show this help"
      exit 0 ;;
    *) err "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Detect VCS provider ─────────────────────────────────────────────────────
detect_provider() {
  if [[ -n "$PROVIDER" ]]; then return; fi

  if [[ -f ".gitlab-ci.yml" ]]; then
    PROVIDER="gitlab"
  elif [[ -d ".github" ]]; then
    PROVIDER="github"
  elif git remote -v 2>/dev/null | grep -q "gitlab"; then
    PROVIDER="gitlab"
  elif git remote -v 2>/dev/null | grep -q "github"; then
    PROVIDER="github"
  else
    echo ""
    echo -e "${BOLD}Which VCS provider do you use?${NC}"
    echo "  1) GitHub (gh CLI)"
    echo "  2) GitLab (glab CLI)"
    echo ""
    read -rp "Choose [1/2]: " choice
    case "$choice" in
      1) PROVIDER="github" ;;
      2) PROVIDER="gitlab" ;;
      *) err "Invalid choice"; exit 1 ;;
    esac
  fi

  log "Detected VCS: $PROVIDER"
}

# ── Verify CLI tools ────────────────────────────────────────────────────────
verify_tools() {
  if [[ "$PROVIDER" == "github" ]]; then
    if ! command -v gh &>/dev/null; then
      warn "gh CLI not found. Install: brew install gh"
      warn "Then login: gh auth login"
    else
      ok "gh CLI: $(gh --version | head -1)"
    fi
  elif [[ "$PROVIDER" == "gitlab" ]]; then
    if ! command -v glab &>/dev/null; then
      warn "glab CLI not found. Install: brew install glab"
      warn "Then login: glab auth login"
    else
      ok "glab CLI: $(glab --version 2>/dev/null | head -1)"
    fi
  fi

  if ! command -v git &>/dev/null; then
    err "git not found. Install git first."
    exit 1
  fi
}

# ── Download and install ─────────────────────────────────────────────────────
install_package() {
  local PKG_NAME="agentkit-${TIER}-${PROVIDER}"
  local TMP_DIR
  TMP_DIR=$(mktemp -d)

  log "Installing AgentKit ${TIER^^} for ${PROVIDER^^}..."

  # Download the package zip
  local ZIP_URL="${AGENTKIT_REPO}/releases/latest/download/${PKG_NAME}.zip"
  log "Downloading from: $ZIP_URL"

  if command -v curl &>/dev/null; then
    curl -sL "$ZIP_URL" -o "$TMP_DIR/${PKG_NAME}.zip" || {
      warn "Release download failed. Trying git clone..."
      clone_and_install "$TMP_DIR"
      return
    }
  elif command -v wget &>/dev/null; then
    wget -q "$ZIP_URL" -O "$TMP_DIR/${PKG_NAME}.zip" || {
      warn "Release download failed. Trying git clone..."
      clone_and_install "$TMP_DIR"
      return
    }
  else
    warn "Neither curl nor wget found. Falling back to git clone..."
    clone_and_install "$TMP_DIR"
    return
  fi

  # Extract
  unzip -qo "$TMP_DIR/${PKG_NAME}.zip" -d "$TMP_DIR"

  # Copy files
  copy_files "$TMP_DIR/$PKG_NAME"

  rm -rf "$TMP_DIR"
}

clone_and_install() {
  local TMP_DIR="$1"
  local PKG_NAME="agentkit-${TIER}-${PROVIDER}"

  git clone --depth 1 --branch "$AGENTKIT_BRANCH" "$AGENTKIT_REPO" "$TMP_DIR/agentkit" 2>/dev/null

  # Build the package
  (cd "$TMP_DIR/agentkit" && bash build.sh 2>/dev/null)

  # Extract the built package
  unzip -qo "$TMP_DIR/agentkit/dist/${PKG_NAME}.zip" -d "$TMP_DIR"

  copy_files "$TMP_DIR/$PKG_NAME"
}

copy_files() {
  local SRC_DIR="$1"

  # Copy .cursor/
  if [[ -d "$SRC_DIR/.cursor" ]]; then
    if [[ -d ".cursor" ]] && [[ "$FORCE" != "1" ]]; then
      warn ".cursor/ already exists. Use --force to overwrite, or merging..."
      # Merge: copy only files that don't exist
      find "$SRC_DIR/.cursor" -type f | while read -r f; do
        local REL="${f#$SRC_DIR/}"
        if [[ ! -f "$REL" ]]; then
          mkdir -p "$(dirname "$REL")"
          cp "$f" "$REL"
          log "  + $REL"
        else
          log "  ~ $REL (exists, skipped)"
        fi
      done
    else
      cp -r "$SRC_DIR/.cursor" .
      ok "Installed .cursor/ (rules, skills, agents)"
    fi
  fi

  # Copy .github/ (if github provider)
  if [[ -d "$SRC_DIR/.github" ]]; then
    mkdir -p .github
    cp -r "$SRC_DIR/.github/"* .github/ 2>/dev/null || true
    ok "Installed .github/ (copilot-instructions, skills symlink)"
  fi

  # Copy scripts/ (pro only)
  if [[ -d "$SRC_DIR/scripts" ]] && ls "$SRC_DIR/scripts/"*.sh &>/dev/null; then
    mkdir -p scripts
    cp "$SRC_DIR/scripts/"*.sh scripts/
    chmod +x scripts/*.sh
    ok "Installed scripts/ (pipeline, parallel-implement, parallel-review, sequential-merge)"
  fi

  # Copy docs/
  if [[ -d "$SRC_DIR/docs" ]]; then
    cp -r "$SRC_DIR/docs" .
    ok "Installed docs/ (governance workflow)"
  fi

  # Copy AGENTS.md
  if [[ -f "$SRC_DIR/AGENTS.md" ]]; then
    if [[ ! -f "AGENTS.md" ]] || [[ "$FORCE" == "1" ]]; then
      cp "$SRC_DIR/AGENTS.md" .
      ok "Installed AGENTS.md"
    fi
  fi
}

# ── Summary ──────────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}  AgentKit ${TIER^^} (${PROVIDER^^}) — Installed!${NC}"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  local SKILL_COUNT RULE_COUNT AGENT_COUNT
  SKILL_COUNT=$(ls -d .cursor/skills/*/ 2>/dev/null | wc -l | tr -d ' ')
  RULE_COUNT=$(ls .cursor/rules/*.mdc 2>/dev/null | wc -l | tr -d ' ')
  AGENT_COUNT=$(ls .cursor/agents/*.md 2>/dev/null | wc -l | tr -d ' ')

  echo -e "  Skills:  ${CYAN}${SKILL_COUNT}${NC}"
  echo -e "  Rules:   ${CYAN}${RULE_COUNT}${NC}"
  echo -e "  Agents:  ${CYAN}${AGENT_COUNT}${NC}"
  echo ""

  if [[ "$TIER" == "free" ]]; then
    echo -e "  ${YELLOW}Upgrade to Pro for 67 skills, 51 rules, 11 agents,${NC}"
    echo -e "  ${YELLOW}pipeline scripts, design patterns, and CI/CD add-ons.${NC}"
    echo -e "  ${YELLOW}→ https://agentkit.lemonsqueezy.com${NC}"
  fi

  echo ""
  echo -e "  ${GREEN}Next steps:${NC}"
  echo "  1. Open your project in Cursor or VS Code with Copilot"
  echo "  2. Ask the agent to use the 'new-plan' skill"
  echo "  3. Implement with 'implement-plan' + 'tdd-workflow'"
  echo "  4. Review with 'review-open-pr'"
  echo "  5. Validate with 'posttask'"
  echo ""
}

# ── Main ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     AgentKit — AI Engineering Governance         ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""

detect_provider
verify_tools
install_package
print_summary
