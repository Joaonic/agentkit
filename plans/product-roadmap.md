# AI Engineering Governance Toolkit — Roadmap de Produto & Monetização

> **Autor:** João Tavares  
> **Data:** 2026-05-12  
> **Status:** PLANNING  
> **Nome de trabalho:** `agentkit` (ou `govkit`, `aigovkit` — definir antes de lançar)

---

## Sumário Executivo

Framework completo de governance para AI coding agents (Cursor, Copilot, Windsurf, qualquer CLI).
Transforma agentes genéricos em engenheiros disciplinados com TDD, quality gates, review mandatório, e pipeline autônomo completo.

**Nenhum concorrente oferece isso.** Devin, Codegen, Sweep, Cline — todos geram código. Nenhum tem governance.

---

## Inventário de Ativos (o que estás a vender)

| Tipo | Qtd | Descrição |
|------|-----|-----------|
| **Skills** | 58 | Workflows executáveis (planning, audit, TDD, backend, frontend, design patterns, infra workbenches) |
| **Rules** | 33 | Regras alwaysApply + contextuais (hexagonal, tenant isolation, security, observability, clean code) |
| **Agents** | 11 | Personas especializadas (backend, frontend, arch, code-reviewer, verifier, ux-reviewer, etc.) |
| **Pipeline Scripts** | 4 | Orquestração autônoma: implement → review → merge em paralelo via worktrees |
| **Workflow** | 8 fases | Sistema completo de fases com 5 quality gates obrigatórios |
| **Governance Docs** | 4 | Setup, MCP policy, workflow index, README |
| **Design Patterns** | 22 | Catálogo GoF completo com exemplos e anti-patterns |
| **Total** | **123+** | Ativos distintos |

---

## Diferencial Competitivo (porquê isto e não outro)

### O que existe no mercado
| Produto | O que faz | O que falta |
|---------|-----------|-------------|
| Devin | Gera código autonomamente | Zero governance, zero quality gates, zero review |
| Cursor | IDE com AI | Skills/rules são locais, sem framework transferível |
| Codegen | CI bot que cria PRs | Sem pipeline loop, sem TDD gate, sem review |
| Sweep | AI que resolve issues | Sem multi-agent, sem worktrees, sem governance |
| Cline | VS Code agent | Sem workflow, sem pipeline, sem monorepo awareness |

### O que nós temos que ninguém tem
1. **Pipeline autônomo loop** — PRIORITIZE → IMPLEMENT → REVIEW → MERGE em waves
2. **Paralelismo real via git worktrees** — N agentes simultâneos sem conflito
3. **5 quality gates obrigatórios** — Planning, TDD, Review, Validation, Documentation
4. **Zero-tolerance policy** — 38+ checklist items embedded nos skills
5. **Multi-agent review chain** — code-reviewer → ux-reviewer → verifier
6. **Monorepo-aware** — submodule governance, cross-project routing
7. **bootstrap-governance** — meta-skill que replica todo o framework num repo novo
8. **22 GoF design patterns** como skills executáveis
9. **Database workbenches** (Postgres + Redis) com referências operacionais
10. **Plan-to-issues pipeline** — planos viram issues agent-ready com QA package

---

## Fase 0: Preparação (Semana 1)

### 0.1 — Escolher nome e domínio

```
Sugestões:
- agentkit.dev
- govkit.dev
- aigovkit.com
- cursorkit.dev (cuidado com trademark)
- agentgov.dev
```

**Ação:** Verificar disponibilidade em Namecheap/Cloudflare e registrar.

### 0.2 — Criar conta GitHub pública

O produto vai para GitHub (não GitLab), porque:
- Maior audiência de devs
- GitHub Sponsors integrado
- Marketplace visibility
- Gumroad/LemonSqueezy integram melhor

```bash
# Se ainda não tens gh instalado:
brew install gh

# Login no GitHub:
gh auth login
# Selecionar: GitHub.com → HTTPS → Login with browser

# Verificar login:
gh auth status

# Criar o repo público:
gh repo create agentkit --public --description "AI Engineering Governance Toolkit — Skills, Rules, Agents & Pipeline for Cursor, Copilot, and any AI coding agent" --clone
cd agentkit

# Setup inicial:
git config user.email "your-email@example.com"
git config user.name "João Tavares"
```

### 0.3 — Criar conta GitLab (para suporte a glab)

```bash
# Se ainda não tens glab instalado:
brew install glab

# Login no GitLab:
glab auth login
# Selecionar: gitlab.com → Login with browser

# Verificar:
glab auth status

# (Opcional) Criar mirror no GitLab:
glab repo create agentkit --public --description "AI Engineering Governance Toolkit"
```

### 0.4 — Contas em plataformas de venda

| Plataforma | Para quê | URL |
|------------|----------|-----|
| **Lemon Squeezy** | Venda digital (melhor para devtools, zero complicação fiscal) | https://lemonsqueezy.com |
| **Gumroad** | Alternativa consolidada | https://gumroad.com |
| **GitHub Sponsors** | Revenue recorrente de community | https://github.com/sponsors |
| **Stripe** | Pagamento direto (para SaaS futuro) | https://stripe.com |

**Passos Lemon Squeezy (recomendado para começar):**
1. Criar conta em https://app.lemonsqueezy.com/register
2. Configurar store name: `agentkit` (ou nome escolhido)
3. Conectar Stripe (eles usam Stripe por baixo)
4. Configurar payout: conta bancária ou PayPal
5. Criar primeiro produto (ver Fase 1)

---

## Fase 1: Quick Revenue — Pacote Premium (Semanas 2-3)

**Meta:** Começar a vender em <2 semanas. Receita: $49-199 por licença.

### 1.1 — Estrutura do repo público (free tier)

```
agentkit/
├── README.md                    # Landing page do produto
├── LICENSE                      # MIT para o core
├── CHANGELOG.md
├── install.sh                   # Installer one-liner
├── .github/
│   ├── copilot-instructions.md  # Instrução base
│   └── skills                   # → .cursor/skills (symlink)
├── .cursor/
│   ├── rules/                   # FREE: 8-10 rules essenciais
│   │   ├── 00-governance.mdc
│   │   ├── 01-investigation.mdc
│   │   ├── 04-tdd-mandatory.mdc
│   │   ├── 06-vcs-policy.mdc
│   │   ├── 25-clean-code.mdc
│   │   ├── 26-incremental-changes.mdc
│   │   ├── 27-commit-messages.mdc
│   │   └── 30-posttask.mdc
│   ├── skills/                  # FREE: 12-15 skills essenciais
│   │   ├── new-plan/
│   │   ├── implement-plan/
│   │   ├── tdd-workflow/
│   │   ├── posttask/
│   │   ├── run-tests/
│   │   ├── run-build/
│   │   ├── lint-fix/
│   │   ├── review-open-pr/
│   │   ├── new-adr/
│   │   ├── add-skill/
│   │   └── bootstrap-governance/
│   └── agents/                  # FREE: 4 agents base
│       ├── backend.md
│       ├── frontend.md
│       ├── code-reviewer.md
│       └── verifier.md
├── scripts/                     # FREE: pipeline.sh básico
│   └── pipeline.sh              # (sem parallel, sem worktrees)
└── docs/
    ├── getting-started.md
    ├── skills-catalog.md
    ├── rules-reference.md
    └── agents-guide.md
```

### 1.2 — Estrutura do pacote premium (paid)

```
agentkit-pro/                    # Distribuído via Lemon Squeezy / Gumroad
├── README.md
├── install.sh                   # Overlay installer (merge com free)
├── .cursor/
│   ├── rules/                   # +25 rules (tudo que não está no free)
│   │   ├── 10-java-hexagonal.mdc
│   │   ├── 11-java-clean-code.mdc
│   │   ├── 12-springboot-layering.mdc
│   │   ├── 13-dto-domain-design.mdc
│   │   ├── 14-mapstruct-mapping-quality.mdc
│   │   ├── 15-database-flyway-testcontainers.mdc
│   │   ├── 16-postgresql-sql-guidelines.mdc
│   │   ├── 17-specification-query-pattern.mdc
│   │   ├── 18-tenant-isolation.mdc
│   │   ├── 20-web-nextjs.mdc
│   │   ├── 21-web-react.mdc
│   │   ├── 22-data-security.mdc
│   │   ├── 23-observability.mdc
│   │   └── ...
│   ├── skills/                  # +43 skills
│   │   ├── code-audit/
│   │   ├── code-audit-architecture-consistency/
│   │   ├── docs-audit/
│   │   ├── docs-audit-sync/
│   │   ├── qa-issue-spec/
│   │   ├── e2e/
│   │   ├── create-milestone/
│   │   ├── executing-plans-parallel/
│   │   ├── plan-to-issues/
│   │   ├── prioritize-roadmap/
│   │   ├── new-use-case/
│   │   ├── new-adapter/
│   │   ├── new-api-resource/
│   │   ├── new-feature/
│   │   ├── new-widget/
│   │   ├── new-ui-component/
│   │   ├── frontend-design/
│   │   ├── db-migrate/
│   │   ├── gen-api/
│   │   ├── postgres-workbench/
│   │   ├── redis-workbench/
│   │   ├── ux-review/
│   │   ├── posttask-workspace-lint/
│   │   ├── design-pattern-*/     # 22 GoF patterns
│   │   └── add-mcp/
│   └── agents/                  # +7 agents
│       ├── arch.md
│       ├── ai-orchestrator.md
│       ├── code-audit.md
│       ├── docs.md
│       ├── docs-audit.md
│       ├── project-manager.md
│       └── ux-reviewer.md
├── scripts/                     # Pipeline completo
│   ├── pipeline.sh              # Full loop com REVIEW_MODE, waves, etc.
│   ├── parallel-implement.sh    # Worktree parallelism
│   ├── parallel-review.sh       # Multi-MR review
│   └── sequential-merge.sh      # Smart merge chain
└── docs/
    ├── governance/
    │   ├── workflow.md
    │   └── workflow/
    │       ├── 00-overview.md
    │       ├── 01-planning.md
    │       ├── 02-implementation.md
    │       ├── 03-review.md
    │       ├── 04-skills.md
    │       ├── 05-validation.md
    │       ├── 06-documentation.md
    │       ├── 07-final-report.md
    │       └── 08-skills-by-context.md
    ├── setup.md
    └── mcp.md
```

### 1.3 — Pricing tiers

| Tier | Preço | Conteúdo |
|------|-------|----------|
| **Free** | $0 | Core: 10 rules + 15 skills + 4 agents + basic pipeline |
| **Pro** | $79 | Tudo: 33 rules + 58 skills + 11 agents + full pipeline + workflow docs |
| **Team** | $199 | Pro + 1 ano updates + priority GitHub Issues support |
| **Enterprise** | $499/yr | Team + consultoria 2h setup + SLA de updates |

### 1.4 — Criar produto no Lemon Squeezy

1. Login em https://app.lemonsqueezy.com
2. Products → New Product
3. Configurar:
   - Name: `AgentKit Pro — AI Engineering Governance Toolkit`
   - Description: (ver texto em 1.6)
   - Price: $79 (one-time)
   - Delivery: Digital download (zip)
   - License key: Enable (para controle)
4. Criar variante Team ($199)
5. Criar variante Enterprise ($499/yr — subscription)
6. Upload do zip com o pacote Pro
7. Copiar checkout link para README

### 1.5 — Criar produto no Gumroad (alternativa)

1. Login em https://gumroad.com
2. New Product → Digital Product
3. Upload zip
4. Pricing: $79 (allow higher)
5. Enable license keys
6. Publish

### 1.6 — Textos de venda (para landing page, README, e plataformas)

**Headline:**
> Stop your AI agents from writing spaghetti code.
> AgentKit is the governance framework that turns Cursor, Copilot, and any AI coding agent into a disciplined engineering team.

**Subheadline:**
> 58 skills. 33 rules. 11 agents. 4 pipeline scripts. 5 quality gates.
> TDD-first. Review-mandatory. Zero-tolerance for deprecated APIs, broken tests, and scope creep.

**Bullet points para plataformas de venda:**
- Full autonomous pipeline: PRIORITIZE → IMPLEMENT → REVIEW → MERGE in parallel waves
- Git worktree parallelism: N agents working simultaneously, zero file conflicts
- 5 mandatory quality gates: Planning, TDD, Review, Validation, Documentation
- 22 GoF design patterns as executable skills
- Database workbenches (Postgres + Redis) with production-grade references
- Plan-to-issues pipeline: plans become fully agent-executable issues with QA packages
- Multi-agent review chain: code-reviewer → ux-reviewer → verifier
- Works with Cursor, GitHub Copilot, Windsurf, Cline, and any CLI agent
- Supports GitLab (`glab`) and GitHub (`gh`) — your choice
- One-command bootstrap: `./install.sh` and your repo is governed

### 1.7 — README do repo público (landing page)

```markdown
# 🏗️ AgentKit — AI Engineering Governance Toolkit

> Turn AI coding agents into disciplined engineers.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

## The Problem

AI coding agents generate code fast. But without governance, you get:
- No tests, no review, no validation
- Deprecated APIs, broken imports, scope creep
- Code that works in demo but breaks in production

## The Solution

AgentKit is a **governance framework** — skills, rules, agents, and pipeline scripts —
that enforces engineering discipline on any AI coding agent.

| What | Free | Pro |
|------|------|-----|
| Rules | 10 | 33 |
| Skills | 15 | 58 |
| Agents | 4 | 11 |
| Pipeline | Basic | Full (parallel worktrees, waves, review modes) |
| Design Patterns | — | 22 GoF |
| Database Workbenches | — | Postgres + Redis |
| Workflow Docs | — | 8-phase system |
| Quality Gates | 2 | 5 |
| Price | $0 | $79 |

[**Get AgentKit Pro →**](https://your-lemonsqueezy-link.com)

## Quick Start

# Clone
git clone https://github.com/your-user/agentkit.git

# Install into your project
cd your-project
../agentkit/install.sh

# Or one-liner (after purchase):
curl -sL https://agentkit.dev/install | bash

## Works With

- **Cursor** (native .cursor/rules + .cursor/skills)
- **GitHub Copilot** (.github/copilot-instructions.md + skills)
- **Windsurf** (.windsurfrules)
- **Cline** (via .clinerules)
- **Any CLI agent** (copilot-cli, aider, etc.)

## VCS Support

- **GitHub** via `gh` CLI
- **GitLab** via `glab` CLI
- Auto-detected per project (configurable)

## What's Inside

### Skills (58)
Executable workflows that guide agents step-by-step:
- **Planning**: new-plan, implement-plan, create-milestone, executing-plans-parallel
- **Quality**: tdd-workflow, code-audit, posttask, e2e, qa-issue-spec
- **Backend**: new-use-case, new-adapter, new-api-resource, db-migrate
- **Frontend**: new-feature, new-widget, new-ui-component, frontend-design
- **Infra**: postgres-workbench, redis-workbench
- **Design Patterns**: All 22 GoF patterns
- **Meta**: add-skill, bootstrap-governance, add-mcp

### Rules (33)
Always-on guardrails that prevent bad practices:
- Investigation before implementation
- TDD mandatory for behavior changes
- Tenant isolation enforcement
- Data security and redaction
- Structured observability
- Clean code, incremental changes

### Agents (11)
Specialized personas for different tasks:
- backend, frontend, arch, ai-orchestrator
- code-reviewer, code-audit, verifier
- docs, docs-audit, ux-reviewer, project-manager

### Pipeline Scripts (4)
Full autonomous CI/CD via AI agents:
- parallel-implement.sh — N agents in parallel via git worktrees
- parallel-review.sh — Review all open MRs concurrently
- sequential-merge.sh — Smart merge chain with rebase
- pipeline.sh — Complete loop: prioritize → implement → review → merge
```

---

## Fase 2: Open Source + Community (Semanas 3-6)

**Meta:** Ganhar tração, stars, e community. O free tier gera awareness para o Pro.

### 2.1 — Publicar repo público

```bash
cd agentkit

# Copiar assets free do monorepo
# (script de extração — ver 2.2)

# Commit inicial
git add -A
git commit -m "feat: initial release — AI Engineering Governance Toolkit"
git push origin main

# Criar release
gh release create v1.0.0 --title "AgentKit v1.0.0" --notes "Initial release — 10 rules, 15 skills, 4 agents, basic pipeline"
```

### 2.2 — Script de extração (sanitizar do monorepo)

Criar script que:
1. Copia skills/rules/agents do monorepo para o repo público
2. Remove referências internas (YourProject, YourApp, my-service, etc.)
3. Generaliza paths e nomes
4. Remove credenciais/URLs internas

```bash
#!/bin/bash
# extract-public.sh — extrair assets públicos do monorepo
set -euo pipefail

SRC="/path/to/source"
DST="/path/to/agentkit"

# Skills free tier
FREE_SKILLS=(new-plan implement-plan tdd-workflow posttask run-tests run-build lint-fix review-open-pr new-adr add-skill bootstrap-governance)

for skill in "${FREE_SKILLS[@]}"; do
  cp -r "$SRC/.cursor/skills/$skill" "$DST/.cursor/skills/"
done

# Rules free tier
FREE_RULES=(00-governance 01-investigation-before-implementation 04-tdd-mandatory 06-vcs-policy 25-clean-code 26-incremental-changes 27-commit-messages 30-posttask)

for rule in "${FREE_RULES[@]}"; do
  cp "$SRC/.cursor/rules/$rule.mdc" "$DST/.cursor/rules/"
done

# Agents free tier
FREE_AGENTS=(backend frontend code-reviewer verifier)

for agent in "${FREE_AGENTS[@]}"; do
  cp "$SRC/.cursor/agents/$agent.md" "$DST/.cursor/agents/"
done

echo "Extraction complete. REVIEW for internal references before publishing."
```

### 2.3 — Sanitização obrigatória

Antes de publicar, fazer grep e remover:
```bash
# Verificar referências internas
grep -rn "your-org\|your-app\|your-org\|my-service\|my-analyzer\|profiler\|your-legacy-app\|your-proxy" .cursor/ scripts/ docs/ AGENTS.md

# Verificar URLs internas
grep -rn "api\.your-org\|gitlab\.com/your-org\|localhost:8443" .cursor/ scripts/ docs/

# Verificar credenciais
grep -rn "localdevpass\|api-key\|secret\|password" .cursor/ scripts/ docs/
```

### 2.4 — Marketing channels (grátis)

| Canal | Ação | Timing |
|-------|------|--------|
| **Hacker News** | "Show HN: I built a governance framework for AI coding agents" | Dia 1 |
| **Reddit** | r/cursor, r/vscode, r/programming, r/github | Dia 1-3 |
| **X (Twitter)** | Thread: "I've been running AI agents in production for 6 months. Here's the framework that keeps them honest." | Dia 1 |
| **Dev.to** | Artigo: "Why AI Agents Need Governance (and How to Add It)" | Semana 1 |
| **Product Hunt** | Launch com screenshots e demo GIF | Semana 2 |
| **LinkedIn** | Post técnico sobre o pipeline | Dia 1-3 |
| **YouTube** | Demo video: pipeline.sh rodando implement → review → merge | Semana 2-3 |

### 2.5 — GitHub Sponsors setup

```bash
# Habilitar GitHub Sponsors:
# 1. Ir a https://github.com/sponsors/Joaonic/dashboard
# 2. Preencher perfil fiscal
# 3. Configurar tiers:

# Tiers sugeridos:
# $5/mo  — Supporter (nome no README)
# $15/mo — Backer (early access updates)
# $50/mo — Sponsor (priority issues + quarterly call)
# $200/mo — Gold Sponsor (logo no README + 1h/mo consultoria)
```

### 2.6 — Community building

1. Criar **Discussions** no GitHub repo (Settings → Features → Discussions)
2. Categorias: Q&A, Show & Tell, Ideas, Custom Skills
3. Criar template de Issue para "Skill Request"
4. Criar CONTRIBUTING.md com guia de como criar skills/rules
5. Aceitar PRs de community skills (nova categoria: `community/`)

---

## Fase 3: CLI Open Source + Premium Skills (Meses 2-4)

**Meta:** Transformar o toolkit num CLI instalável via npm/brew. Revenue: $79-199/licença + $15-50/mo subscriptions.

### 3.1 — CLI project setup

```bash
# Criar CLI como npm package
mkdir -p packages/cli
cd packages/cli
npm init -y

# package.json essencial:
{
  "name": "agentkit",
  "version": "1.0.0",
  "description": "AI Engineering Governance Toolkit CLI",
  "bin": {
    "agentkit": "./bin/agentkit.js"
  },
  "keywords": ["cursor", "copilot", "ai", "governance", "skills", "rules", "agents"],
  "license": "MIT"
}

# Tech stack do CLI:
npm install commander chalk ora inquirer
npm install -D typescript @types/node
```

### 3.2 — Comandos do CLI

```bash
# Instalação
npm install -g agentkit
# ou
brew install agentkit

# Bootstrap num projeto
agentkit init                    # Wizard interativo
agentkit init --preset java      # Preset Java/Spring Boot
agentkit init --preset nextjs    # Preset Next.js/React
agentkit init --preset fullstack # Java + Next.js

# Gestão de skills
agentkit skills list             # Listar skills instalados
agentkit skills add tdd-workflow # Adicionar skill
agentkit skills add pro          # Desbloquear pack Pro (requer license key)
agentkit skills update           # Atualizar skills para última versão

# Gestão de rules
agentkit rules list
agentkit rules add tenant-isolation
agentkit rules add pro

# Pipeline
agentkit pipeline run            # Equivalente a pipeline.sh
agentkit pipeline run --dry-run
agentkit pipeline run --review-mode=inline

# License
agentkit activate PRO-XXXX-YYYY  # Ativar license key do Lemon Squeezy

# VCS setup
agentkit vcs github              # Configurar para gh
agentkit vcs gitlab              # Configurar para glab
```

### 3.3 — License key validation

```typescript
// packages/cli/src/license.ts
import crypto from 'crypto';

const LEMON_SQUEEZY_API = 'https://api.lemonsqueezy.com/v1';

export async function validateLicense(key: string): Promise<boolean> {
  const res = await fetch(`${LEMON_SQUEEZY_API}/licenses/validate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      license_key: key,
      instance_name: crypto.createHash('sha256')
        .update(process.env.USER + process.cwd())
        .digest('hex').slice(0, 16)
    })
  });
  const data = await res.json();
  return data.valid === true;
}
```

### 3.4 — Presets por stack

| Preset | Rules | Skills | Agents |
|--------|-------|--------|--------|
| `java` | hexagonal, clean-code, flyway, mapstruct, tenant-isolation, observability | new-use-case, new-adapter, db-migrate, gen-api, postgres-workbench | backend, arch, code-reviewer, verifier |
| `nextjs` | web-nextjs, web-react, clean-code | new-feature, new-widget, new-ui-component, frontend-design | frontend, ux-reviewer, code-reviewer, verifier |
| `fullstack` | Todos os acima | Todos os acima | Todos |
| `node` | clean-code, observability, data-security | new-use-case, new-adapter, redis-workbench | backend, code-reviewer, verifier |
| `minimal` | governance, investigation, tdd, posttask | new-plan, implement-plan, tdd-workflow, posttask, run-tests | code-reviewer, verifier |

### 3.5 — Publicar no npm

```bash
cd packages/cli

# Build
npm run build

# Login no npm
npm login

# Publish
npm publish

# Verificar
npm info agentkit
```

### 3.6 — Publicar no Homebrew (macOS)

```bash
# Criar tap
gh repo create agentkit-homebrew-tap --public
cd agentkit-homebrew-tap

# Criar formula
mkdir -p Formula
cat > Formula/agentkit.rb << 'RUBY'
class Agentkit < Formula
  desc "AI Engineering Governance Toolkit CLI"
  homepage "https://github.com/Joaonic/agentkit"
  url "https://registry.npmjs.org/agentkit/-/agentkit-1.0.0.tgz"
  sha256 "HASH_HERE"
  license "MIT"

  depends_on "node"

  def install
    system "npm", "install", *std_npm_args
    bin.install_symlink Dir["#{libexec}/bin/*"]
  end

  test do
    assert_match "agentkit", shell_output("#{bin}/agentkit --version")
  end
end
RUBY

# Instruções para utilizadores:
# brew tap Joaonic/agentkit-homebrew-tap
# brew install agentkit
```

---

## Fase 4: SaaS Platform (Meses 4-8)

**Meta:** Plataforma web que conecta GitLab/GitHub e orquestra o pipeline com UI. Revenue: $29-99/mo per seat.

### 4.1 — Stack

| Componente | Escolha |
|------------|---------|
| Frontend | Next.js (App Router) |
| Backend | NestJS ou Node.js + Hono |
| Database | PostgreSQL |
| Queue | BullMQ + Redis |
| Auth | GitHub OAuth + GitLab OAuth |
| Payments | Stripe |
| Hosting | Vercel (frontend) + Railway/Fly.io (backend) |
| CI | GitHub Actions |

### 4.2 — Features MVP

1. **Connect repo** — OAuth com GitHub/GitLab, selecionar repo
2. **Dashboard** — Ver issues, MRs, pipeline status
3. **Pipeline trigger** — Botão "Run Pipeline" que executa remotamente
4. **Live logs** — WebSocket stream dos logs do pipeline
5. **Governance score** — Análise do repo: quantas rules, skills, coverage
6. **Marketplace** — Browse e install skills/rules do catálogo

### 4.3 — Pricing SaaS

| Tier | Preço | Features |
|------|-------|----------|
| **Starter** | $29/mo | 1 repo, 50 pipeline runs/mo, basic dashboard |
| **Pro** | $69/mo | 5 repos, unlimited runs, live logs, governance score |
| **Team** | $99/mo/seat | Unlimited repos, team management, priority support |
| **Enterprise** | Custom | Self-hosted, SSO, audit logs, SLA |

### 4.4 — GitHub/GitLab OAuth setup

```bash
# GitHub OAuth App:
# 1. https://github.com/settings/developers
# 2. New OAuth App
# 3. Authorization callback URL: https://agentkit.dev/api/auth/callback/github
# 4. Guardar Client ID + Secret

# GitLab OAuth App:
# 1. https://gitlab.com/-/user_settings/applications
# 2. New Application
# 3. Redirect URI: https://agentkit.dev/api/auth/callback/gitlab
# 4. Scopes: api, read_user, read_repository
# 5. Guardar Application ID + Secret
```

---

## Fase 5: Enterprise & Scale (Meses 8-12+)

### 5.1 — Features Enterprise

- **Self-hosted** — Docker image que roda on-prem
- **SSO** — SAML/OIDC integration
- **Audit logs** — Quem rodou o quê, quando, resultado
- **Custom skills** — UI para criar skills proprietários
- **Role-based access** — Admin/Developer/Viewer
- **Governance policies** — Enforce rules at org level
- **Metrics** — Code quality trends, agent efficiency, cost/issue

### 5.2 — Channels de Enterprise sales

1. **Website** — agentkit.dev com CTA "Book a Demo"
2. **Calendly** — link para demo call de 30min
3. **Case studies** — publicar métricas reais do monorepo YourProject
4. **Partnerships** — contactar Cursor, GitHub, JetBrains para marketplace listing
5. **Conference talks** — submeter talks sobre "AI Engineering Governance"

---

## Cronograma Consolidado

| Semana | Fase | Deliverable | Revenue esperado |
|--------|------|-------------|------------------|
| 1 | 0 | Domínio + contas + repo | — |
| 2 | 1 | Pacote Pro no Lemon Squeezy | Primeiras vendas |
| 3 | 1-2 | Repo público + launch HN/Reddit/PH | $500-2000/mo |
| 4-6 | 2 | Community building + conteúdo | $1000-5000/mo |
| 8-12 | 3 | CLI npm + brew | $3000-10000/mo |
| 12-16 | 3 | Premium packs + subscriptions | $5000-15000/mo |
| 16-24 | 4 | SaaS MVP | $10000-30000/mo |
| 24-36 | 5 | Enterprise | $30000+/mo |

---

## Checklist Imediato (próximas 48h)

- [ ] Escolher nome definitivo do produto
- [ ] Registrar domínio
- [ ] Criar repo GitHub público
- [ ] Criar conta Lemon Squeezy
- [ ] Extrair e sanitizar assets do monorepo (script extract-public.sh)
- [ ] Escrever README (landing page)
- [ ] Criar primeiro produto no Lemon Squeezy ($79)
- [ ] Upload zip do pacote Pro
- [ ] Publicar repo com free tier
- [ ] Escrever thread X/Twitter
- [ ] Submeter "Show HN"

---

## Documentação Necessária para o Produto

### Docs já existentes (adaptar do monorepo)
- [x] Workflow completo (8 fases)
- [x] Rules reference (33 rules documentadas nos próprios .mdc)
- [x] Skills catalog (58 skills com SKILL.md cada)
- [x] Agents guide (11 agents com .md cada)
- [x] Pipeline scripts (documentados inline)

### Docs a criar
- [ ] `docs/getting-started.md` — Quick start em 5 minutos
- [ ] `docs/installation.md` — Todos os métodos (manual, script, CLI, brew)
- [ ] `docs/configuration.md` — Como customizar rules/skills
- [ ] `docs/vcs-setup.md` — GitHub (gh) vs GitLab (glab) setup completo
- [ ] `docs/presets.md` — Presets por stack (Java, Next.js, Node, etc.)
- [ ] `docs/creating-skills.md` — Como criar skills customizados
- [ ] `docs/creating-rules.md` — Como criar rules customizadas
- [ ] `docs/pipeline-guide.md` — Pipeline scripts em detalhe
- [ ] `docs/faq.md` — Perguntas frequentes
- [ ] `docs/troubleshooting.md` — Problemas comuns
- [ ] `CONTRIBUTING.md` — Como contribuir
- [ ] `CODE_OF_CONDUCT.md`
- [ ] `SECURITY.md`

### Docs de negócio
- [ ] Pitch deck (10 slides para investors/partners)
- [ ] One-pager (para cold outreach)
- [ ] Pricing page copy
- [ ] Terms of Service
- [ ] Privacy Policy

---

## VCS Setup Detalhado (para docs/vcs-setup.md)

### GitHub Setup (`gh`)

```bash
# 1. Instalar gh CLI
brew install gh          # macOS
sudo apt install gh      # Ubuntu/Debian
winget install GitHub.cli # Windows

# 2. Login
gh auth login
# → Selecionar: GitHub.com
# → Selecionar: HTTPS
# → Selecionar: Login with a web browser
# → Copiar o código e autorizar no browser

# 3. Verificar
gh auth status
# ✓ Logged in to github.com account Joaonic

# 4. Configurar git
git config --global user.name "Seu Nome"
git config --global user.email "seu@email.com"

# 5. Testar
gh repo list --limit 3
gh issue list --repo seu-user/seu-repo

# Comandos úteis no contexto AgentKit:
gh issue create --title "..." --body "..."
gh pr create --title "..." --body "..."
gh pr merge N --squash
gh pr review N --approve
gh release create vX.Y.Z
```

### GitLab Setup (`glab`)

```bash
# 1. Instalar glab CLI
brew install glab         # macOS
sudo apt install glab     # Ubuntu/Debian (via snap ou brew)
# Windows: https://gitlab.com/gitlab-org/cli/-/releases

# 2. Login
glab auth login
# → Selecionar: gitlab.com (ou self-hosted URL)
# → Selecionar: Login with a web browser
# → Autorizar no browser

# Ou via Personal Access Token:
glab auth login --hostname gitlab.com --token glpat-XXXXX

# 3. Verificar
glab auth status
# ✓ Logged in to gitlab.com as joaonic

# 4. Testar
glab repo list --per-page 3
glab issue list

# Comandos úteis no contexto AgentKit:
glab issue create --title "..." --description "..."
glab mr create --title "..." --description "..."
glab mr merge N
glab mr approve N
glab ci list
```

### Configuração no AgentKit

```yaml
# .agentkit.yml (na raiz do projeto)
vcs:
  provider: github    # ou "gitlab"
  # Auto-detected se não configurado:
  # - Presença de .github/ → github
  # - Presença de .gitlab-ci.yml → gitlab
  # - Remote URL contém "gitlab" → gitlab

pipeline:
  review_mode: inline   # inline | separate | skip
  max_parallel: 4
  model: claude-opus-4.6
  effort: high

presets:
  - java
  - nextjs
```

---

## Riscos e Mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|-------|--------------|---------|-----------|
| Cursor muda API de skills | Média | Alto | Suportar múltiplos formatos (.cursor, .github, .windsurfrules) |
| Concorrente copia | Alta | Médio | Velocidade de execução + community + brand |
| Low conversion free→paid | Média | Alto | Conteúdo de qualidade + demo videos + testimonials |
| Burnout (solo founder) | Alta | Alto | Automatizar marketing + aceitar community PRs |
| Trademark issues com "Cursor" no nome | Baixa | Alto | Não usar "Cursor" no nome do produto |

---

## Métricas de Sucesso

| Marco | KPI | Target |
|-------|-----|--------|
| Semana 2 | Primeira venda | 1 |
| Mês 1 | GitHub stars | 500+ |
| Mês 1 | Vendas Pro | 20+ ($1,580+) |
| Mês 3 | npm downloads/semana | 200+ |
| Mês 3 | MRR (monthly recurring) | $3,000+ |
| Mês 6 | GitHub stars | 5,000+ |
| Mês 6 | MRR | $10,000+ |
| Mês 12 | MRR | $30,000+ |
| Mês 12 | Enterprise customers | 3+ |
