# AgentKit Add-on: CI/CD Pipeline Pack

Trunk-based CI/CD pipelines with AI-powered changelog generation and automatic semantic versioning.

## What's Included

### Pipeline Scripts (shared logic)
- `git_helpers.sh` — Git tagging, remote config, commit+push
- `change_helpers.sh` — Diff extraction between tags
- `generate_changelog.sh` — AI-powered changelog generation (OpenAI API)
- `generate-changelog.mjs` — Node.js OpenAI client with chunked summarization
- `tag_version.sh` — Auto version bump + Git tag creation with release notes

### Language-specific Version Helpers
- `java/maven_helpers.sh` — pom.xml version read/increment
- `node/node_helpers.sh` — package.json version read/increment (npm)
- `bun/bun_helpers.sh` — package.json version read/increment (bun)

### GitLab CI Templates
- `java-service.gitlab-ci.yml` — Full Java/Maven/Spring Boot pipeline
- `node-service.gitlab-ci.yml` — Full Node.js service pipeline
- `bun-service.gitlab-ci.yml` — Full Bun/TypeScript service pipeline

### GitHub Actions Workflows
- `ci.yml` — CI gate (build, test, lint) with concurrency control
- `release.yml` — Automated changelog + version bump + tag + CD trigger
- `cd-backend.yml` — Docker multi-arch build + push to GHCR

## Flow (Trunk-Based)

```
Push to main → CI (build+test+lint) → Release (changelog+version+tag) → CD (docker build+push+deploy)
```

1. **CI:** runs on every push/MR — build, test, lint
2. **Changelog:** AI generates changelog from git diff (fallback to conventional commit parsing)
3. **Version bump:** reads `[patch]`, `[minor]`, `[major]` from commit message (default: patch)
4. **Tag:** creates annotated git tag with AI-generated release notes
5. **CD:** builds Docker image on tag push, deploys via SSH

## Configuration

### Required Secrets/Variables

| Secret | Provider | Purpose |
|--------|----------|---------|
| `OPENAI_API_KEY` | Both | AI changelog generation |
| `CI_REGISTRY_*` | GitLab | Container registry auth |
| `GITHUB_TOKEN` | GitHub | GHCR push + tag creation |
| `SSH_PRIVATE_KEY` | Both | Production deploy |
| `SSH_KNOWN_HOSTS` | Both | SSH host verification |
| `REMOTE_SSH` | Both | Deploy target (user@host) |

### Version Bump Convention

Include in commit message:
- `[patch]` — default, bugfixes (1.2.3 → 1.2.4)
- `[minor]` — new features (1.2.3 → 1.3.0)
- `[major]` — breaking changes (1.2.3 → 2.0.0)

### Skip CI

Commits starting with `release:` or `doc:` skip CI to avoid loops.

## Installation

```bash
# Via agentkit installer
./install.sh --addon ci-cd

# Manual
cp -r src/addons/ci-cd/gitlab/scripts/ your-project/scripts/pipeline/
cp src/addons/ci-cd/gitlab/templates/java-service.gitlab-ci.yml your-project/.gitlab-ci.yml
# Edit variables (registry, project name, etc.)
```
