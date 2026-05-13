# VCS Setup Guide

AgentKit supports both GitHub and GitLab. The install script auto-detects your provider, but you can configure it explicitly.

## GitHub Setup

### 1. Install `gh` CLI

```bash
# macOS
brew install gh

# Ubuntu/Debian
sudo apt install gh

# Windows
winget install GitHub.cli
```

### 2. Authenticate

```bash
gh auth login
# → Select: GitHub.com
# → Select: HTTPS
# → Select: Login with a web browser
# → Copy the code and authorize in browser
```

### 3. Verify

```bash
gh auth status
# ✓ Logged in to github.com account YourUser
```

### 4. Configure git

```bash
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

### 5. Key commands

```bash
# Issues
gh issue create --title "feat: add auth" --body "Description..."
gh issue list
gh issue view 42

# Pull Requests
gh pr create --title "feat: add auth" --body "Implements #42"
gh pr list
gh pr review 5 --approve
gh pr merge 5 --squash

# Releases
gh release create v1.0.0 --title "v1.0.0" --notes "Release notes"
```

---

## GitLab Setup

### 1. Install `glab` CLI

```bash
# macOS
brew install glab

# Ubuntu/Debian (via Homebrew on Linux)
brew install glab

# Windows
# Download from: https://gitlab.com/gitlab-org/cli/-/releases
```

### 2. Authenticate

```bash
# Interactive (recommended)
glab auth login
# → Select: gitlab.com (or your self-hosted URL)
# → Select: Login with a web browser
# → Authorize in browser

# Or via Personal Access Token
glab auth login --hostname gitlab.com --token glpat-XXXXXXXXXXXXX
```

### 3. Verify

```bash
glab auth status
# ✓ Logged in to gitlab.com as your-user
```

### 4. Configure git

```bash
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

### 5. Key commands

```bash
# Issues
glab issue create --title "feat: add auth" --description "Description..."
glab issue list
glab issue view 42

# Merge Requests
glab mr create --title "feat: add auth" --description "Implements #42"
glab mr list
glab mr approve 5
glab mr merge 5

# CI
glab ci list
glab ci view
```

---

## AgentKit VCS Configuration

AgentKit auto-detects your VCS provider:

| Signal | Provider |
|--------|----------|
| `.github/` directory exists | GitHub |
| `.gitlab-ci.yml` exists | GitLab |
| Remote URL contains "gitlab" | GitLab |
| Remote URL contains "github" | GitHub |

To override, use the install flag:
```bash
./install.sh --provider gitlab
```

The VCS policy rule (`.cursor/rules/06-vcs-policy.mdc`) is provider-specific and set during installation.

## Terminology mapping

| Concept | GitHub | GitLab |
|---------|--------|--------|
| Code review request | Pull Request (PR) | Merge Request (MR) |
| CLI tool | `gh` | `glab` |
| Create review | `gh pr create` | `glab mr create` |
| Merge | `gh pr merge` | `glab mr merge` |
| CI config | `.github/workflows/` | `.gitlab-ci.yml` |
| Copilot instructions | `.github/copilot-instructions.md` | N/A (use AGENTS.md) |
