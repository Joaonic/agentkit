# AgentKit — AI Engineering Governance Toolkit

> Turn AI coding agents into disciplined engineers.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

**[Português](README.pt.md)** · **[Getting Started](docs/en/getting-started.md)** · **[Skills Catalog](docs/en/skills-catalog.md)** · **[Get Pro →](#pricing)**

---

## The Problem

AI coding agents generate code fast. But without governance, you get:

- No tests, no review, no validation
- Deprecated APIs, broken imports, scope creep
- Code that works in demo but breaks in production
- Agents that ignore your architecture and conventions

## The Solution

AgentKit is a **governance framework** — skills, rules, agents, and pipeline scripts — that enforces engineering discipline on any AI coding agent. It doesn't generate code; it makes your agent generate *good* code.

```bash
# One-liner install
curl -sL https://raw.githubusercontent.com/Joaonic/agentkit/main/install.sh | bash
```

## What's Inside

| Asset | Free | Pro | Description |
|-------|------|-----|-------------|
| **Skills** | 14 | 67 | Executable step-by-step workflows |
| **Rules** | 10 | 51 | Always-on guardrails (auto-loaded by Cursor) |
| **Agents** | 4 | 11 | Specialized personas with domain expertise |
| **Pipeline Scripts** | — | 4 | Autonomous implement → review → merge loop |
| **Design Patterns** | — | 22 | All GoF patterns as executable skills |
| **DB Workbenches** | — | 3 | Postgres, Redis, MongoDB, Elasticsearch |
| **Workflow Docs** | — | 8 phases | Complete governance system documentation |
| **Quality Gates** | 2 | 5 | Mandatory checkpoints before completion |

## How It Works

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────┐
│  PLAN        │────▶│  IMPLEMENT   │────▶│  REVIEW      │────▶│  MERGE   │
│  new-plan    │     │  TDD-first   │     │  code-review │     │  posttask │
│  qa-spec     │     │  worktrees   │     │  ux-review   │     │  verify  │
└─────────────┘     └──────────────┘     └──────────────┘     └──────────┘
     Gate 1              Gate 2              Gate 3            Gates 4 & 5
```

**5 Mandatory Quality Gates:**
1. **Planning** — No implementation without clear scope and acceptance criteria
2. **TDD** — Behavior changes require failing-first tests
3. **Review** — No completion without findings-first technical review
4. **Validation** — No completion without command-level posttask evidence
5. **Documentation** — Changes require doc synchronization

## Quick Start

### Option 1: One-liner install

```bash
# Auto-detects GitHub/GitLab, installs free tier
curl -sL https://raw.githubusercontent.com/Joaonic/agentkit/main/install.sh | bash

# Explicit provider and tier
curl -sL https://raw.githubusercontent.com/Joaonic/agentkit/main/install.sh | bash -s -- --provider github --tier free
```

### Option 2: Clone and install

```bash
git clone https://github.com/Joaonic/agentkit.git
cd your-project
../agentkit/install.sh --provider github --tier free
```

### Option 3: Manual copy

```bash
# Copy the package contents into your project root
cp -r agentkit-free-github/.cursor your-project/
cp -r agentkit-free-github/.github your-project/  # GitHub only
cp agentkit-free-github/AGENTS.md your-project/
```

## Works With

| Tool | How |
|------|-----|
| **Cursor** | Native `.cursor/rules/` + `.cursor/skills/` |
| **GitHub Copilot** | `.github/copilot-instructions.md` + `.github/skills/` |
| **Windsurf** | Via `.windsurfrules` (adapt rules manually) |
| **Cline** | Via `.clinerules` (adapt rules manually) |
| **Any CLI agent** | `copilot-cli`, `aider`, etc. — reads AGENTS.md |

## VCS Support

| Provider | CLI | Commands |
|----------|-----|----------|
| **GitHub** | `gh` | `gh issue create`, `gh pr create`, `gh pr merge` |
| **GitLab** | `glab` | `glab issue create`, `glab mr create`, `glab mr merge` |

Auto-detected based on your project (`.github/` → GitHub, `.gitlab-ci.yml` → GitLab, remote URL).

### GitHub Setup

```bash
brew install gh          # macOS
gh auth login            # Login via browser
gh auth status           # Verify
```

### GitLab Setup

```bash
brew install glab        # macOS
glab auth login          # Login via browser
glab auth status         # Verify
```

## Skills Catalog

### Free Tier (14 skills)

| Category | Skills |
|----------|--------|
| **Planning** | `new-plan`, `implement-plan` |
| **Quality** | `tdd-workflow`, `posttask`, `posttask-workspace-lint`, `qa-issue-spec` |
| **Build & Test** | `run-tests`, `run-build`, `lint-fix` |
| **Review** | `review-open-pr` |
| **Meta** | `add-skill`, `bootstrap`, `bootstrap-governance`, `new-adr` |

### Pro Tier (+53 skills)

| Category | Skills |
|----------|--------|
| **Planning** | `create-milestone`, `executing-plans-parallel`, `plan-to-issues`, `prioritize-roadmap`, `prioritize-github-roadmap`, `prioritize-gitlab-roadmap` |
| **Audit** | `code-audit`, `code-audit-architecture-consistency`, `docs-audit`, `docs-audit-sync` |
| **Testing** | `e2e`, `ux-review` |
| **Backend (Java)** | `new-use-case`, `new-adapter`, `new-api-resource`, `db-migrate`, `gen-api` |
| **Backend (NestJS)** | `backend-hexagonal-nestjs`, `openapi-orval-nextauth` |
| **Frontend** | `new-feature`, `new-widget`, `new-ui-component`, `frontend-design` |
| **Infrastructure** | `postgres-workbench`, `redis-workbench`, `elasticsearch-workbench`, `mongo-workbench` |
| **AI/ML** | `ai-guardrails-and-redaction`, `ai-router-executor-pattern` |
| **Design Patterns** | All 22 GoF: `abstract-factory`, `adapter`, `bridge`, `builder`, `chain-of-responsibility`, `command`, `composite`, `decorator`, `facade`, `factory-method`, `flyweight`, `iterator`, `mediator`, `memento`, `observer`, `prototype`, `proxy`, `singleton`, `state`, `strategy`, `template-method`, `visitor` |
| **Platform** | `add-mcp`, `saas-mvp-bootstrap` |

### Pro Tier — Pipeline Scripts (4)

| Script | What it does |
|--------|-------------|
| `pipeline.sh` | Full autonomous loop: PRIORITIZE → IMPLEMENT → REVIEW → MERGE in waves |
| `parallel-implement.sh` | N agents implementing issues in parallel via git worktrees |
| `parallel-review.sh` | Review all open MRs/PRs concurrently |
| `sequential-merge.sh` | Smart merge chain with rebase ordering |

## Rules Reference

### Free Tier (10 rules)

| Rule | Purpose |
|------|---------|
| `00-governance` | Governance baseline |
| `01-investigation-before-implementation` | Investigate before coding |
| `03-review-gate` | No completion without review |
| `04-tdd-mandatory` | TDD for behavior changes |
| `06-vcs-policy` | VCS conventions |
| `09-file-operations` | Safe file operations |
| `25-clean-code` | Clean code standards |
| `26-incremental-changes` | Small, focused changes |
| `27-commit-messages` | Semantic commit format |
| `30-posttask` | Mandatory final validation |

### Pro Tier (+41 rules)

**Java/Spring Boot:** hexagonal architecture, clean code, layering, DTO design, MapStruct, Flyway, PostgreSQL, specifications, tenant isolation

**TypeScript/NestJS:** hexagonal architecture, AI orchestration, TDD, enums, database safety

**Frontend:** Feature-Sliced Design, Next.js, React, TypeScript

**Security & Observability:** data security, observability, redaction

**Process:** plans, docs, UX, changelog, MCP

**Monorepo:** submodule governance, merge/squash/CI-skip

## Agents

### Free Tier (4 agents)

| Agent | Role |
|-------|------|
| `backend` | Backend implementation, APIs, persistence, integrations |
| `frontend` | UI, routing, state management, typed API consumption |
| `code-reviewer` | Findings-first technical review gate |
| `verifier` | Validation gate — posttask execution and evidence |

### Pro Tier (+7 agents)

| Agent | Role |
|-------|------|
| `arch` | Architecture decisions, boundary validation, ADRs |
| `ai-orchestrator` | AI/LLM orchestration, prompt contracts, model routing |
| `code-audit` | Repository-wide quality auditor |
| `docs` | Documentation governance |
| `docs-audit` | Documentation quality auditor, staleness detection |
| `project-manager` | Issue/milestone orchestration, plan-to-issue sync |
| `ux-reviewer` | UX quality gate for user-facing flows |

## Pricing

| Tier | Price | What you get |
|------|-------|-------------|
| **Free** | $0 | 14 skills, 10 rules, 4 agents — essential governance |
| **Pro** | $79 | 67 skills, 51 rules, 11 agents, full pipeline, workflow docs |
| **Team** | $199 | Pro + 1 year updates + priority GitHub Issues support |
| **Enterprise** | $499/yr | Team + 2h setup consultancy + SLA |

**[Get AgentKit Pro →](https://your-lemonsqueezy-link.com)**

## Why AgentKit?

| Feature | AgentKit | Devin | Cursor | Codegen | Sweep |
|---------|----------|-------|--------|---------|-------|
| Governance framework | ✅ | ❌ | ❌ | ❌ | ❌ |
| Quality gates | 5 | 0 | 0 | 0 | 0 |
| TDD enforcement | ✅ | ❌ | ❌ | ❌ | ❌ |
| Multi-agent review chain | ✅ | ❌ | ❌ | ❌ | ❌ |
| Parallel via worktrees | ✅ | ❌ | ❌ | ❌ | ❌ |
| Autonomous pipeline loop | ✅ | ❌ | ❌ | ❌ | ❌ |
| Monorepo-aware | ✅ | ❌ | Partial | ❌ | ❌ |
| 22 GoF design patterns | ✅ | ❌ | ❌ | ❌ | ❌ |
| GitHub + GitLab | ✅ | GitHub | ❌ | GitHub | GitHub |
| Open source core | ✅ | ❌ | ❌ | ❌ | ✅ |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on creating skills, rules, and agents.

## License

MIT — see [LICENSE](LICENSE) for details.

The free tier is fully open source. Pro tier is distributed as a paid package.
