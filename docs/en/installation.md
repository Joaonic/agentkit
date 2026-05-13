# Installation Guide

## Methods

### 1. One-liner install (recommended)

```bash
cd your-project
curl -sL https://raw.githubusercontent.com/Joaonic/agentkit/main/install.sh | bash
```

Options:
```bash
# Explicit provider and tier
curl -sL .../install.sh | bash -s -- --provider github --tier free
curl -sL .../install.sh | bash -s -- --provider gitlab --tier pro

# Force overwrite existing files
curl -sL .../install.sh | bash -s -- --force
```

### 2. Clone and install

```bash
git clone https://github.com/Joaonic/agentkit.git ~/agentkit
cd your-project
~/agentkit/install.sh --provider github --tier free
```

### 3. Download release zip

1. Go to [Releases](https://github.com/Joaonic/agentkit/releases)
2. Download your package (e.g., `agentkit-pro-github.zip`)
3. Extract into your project root:
   ```bash
   unzip agentkit-pro-github.zip
   cp -r agentkit-pro-github/.cursor your-project/
   cp -r agentkit-pro-github/.github your-project/
   cp agentkit-pro-github/AGENTS.md your-project/
   ```

### 4. Manual copy from source

```bash
git clone https://github.com/Joaonic/agentkit.git
cd agentkit

# Build packages
bash build.sh

# Copy desired package
cp -r dist/agentkit-free-github/* your-project/
```

## What gets installed

| Directory | Purpose |
|-----------|---------|
| `.cursor/rules/` | Always-on guardrails (auto-loaded by Cursor) |
| `.cursor/skills/` | Executable workflows (referenced in conversations) |
| `.cursor/agents/` | Specialized personas |
| `.github/` | Copilot instructions + skills symlink (GitHub only) |
| `scripts/` | Pipeline scripts (Pro only) |
| `docs/governance/` | Workflow documentation (Pro only) |
| `AGENTS.md` | Agent overview and quick reference |

## Updating

```bash
# Re-run install with --force to update all files
curl -sL .../install.sh | bash -s -- --force

# Or pull latest and rebuild
cd ~/agentkit
git pull
bash build.sh
cp -r dist/agentkit-pro-github/* your-project/
```

## Uninstalling

```bash
rm -rf .cursor/rules/ .cursor/skills/ .cursor/agents/
rm -f AGENTS.md
rm -rf scripts/pipeline.sh scripts/parallel-*.sh scripts/sequential-*.sh
rm -rf docs/governance/
# For GitHub projects:
rm -f .github/copilot-instructions.md
rm -f .github/skills  # symlink
```
