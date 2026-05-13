# AgentKit — Framework de Governança para Engenharia com IA

> Transforme agentes de IA em engenheiros disciplinados.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

**[English](README.md)** · **[Começar](docs/pt/getting-started.md)** · **[Catálogo de Skills](docs/pt/skills-catalog.md)** · **[Comprar Pro →](#precos)**

---

## O Problema

Agentes de IA geram código rápido. Mas sem governança, o resultado é:

- Sem testes, sem review, sem validação
- APIs deprecated, imports quebrados, scope creep
- Código que funciona na demo mas quebra em produção
- Agentes que ignoram sua arquitetura e convenções

## A Solução

AgentKit é um **framework de governança** — skills, rules, agents e pipeline scripts — que impõe disciplina de engenharia em qualquer agente de IA. Não gera código; faz seu agente gerar código *bom*.

```bash
# Instalação em uma linha
curl -sL https://raw.githubusercontent.com/Joaonic/agentkit/main/install.sh | bash
```

## O que Inclui

| Ativo | Free | Pro | Descrição |
|-------|------|-----|-----------|
| **Skills** | 14 | 67 | Workflows executáveis passo a passo |
| **Rules** | 10 | 51 | Guardrails automáticos (carregados pelo Cursor) |
| **Agents** | 4 | 11 | Personas especializadas com expertise de domínio |
| **Pipeline Scripts** | — | 4 | Loop autônomo: implement → review → merge |
| **Design Patterns** | — | 22 | Todos os padrões GoF como skills executáveis |
| **DB Workbenches** | — | 3 | Postgres, Redis, MongoDB, Elasticsearch |
| **Workflow Docs** | — | 8 fases | Documentação completa do sistema de governança |
| **Quality Gates** | 2 | 5 | Checkpoints obrigatórios antes de concluir |

## Como Funciona

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────┐
│  PLANEAR     │────▶│  IMPLEMENTAR │────▶│  REVISAR     │────▶│  MERGE   │
│  new-plan    │     │  TDD-first   │     │  code-review │     │  posttask │
│  qa-spec     │     │  worktrees   │     │  ux-review   │     │  verify  │
└─────────────┘     └──────────────┘     └──────────────┘     └──────────┘
     Gate 1              Gate 2              Gate 3            Gates 4 & 5
```

**5 Quality Gates Obrigatórios:**
1. **Planning** — Sem implementação sem escopo claro e critérios de aceitação
2. **TDD** — Mudanças de comportamento exigem testes failing-first
3. **Review** — Sem conclusão sem revisão técnica findings-first
4. **Validação** — Sem conclusão sem evidência posttask a nível de comando
5. **Documentação** — Mudanças exigem sincronização de docs

## Quick Start

### Opção 1: Instalação em uma linha

```bash
# Auto-detecta GitHub/GitLab, instala tier free
curl -sL https://raw.githubusercontent.com/Joaonic/agentkit/main/install.sh | bash

# Provider e tier explícitos
curl -sL https://raw.githubusercontent.com/Joaonic/agentkit/main/install.sh | bash -s -- --provider github --tier free
```

### Opção 2: Clone e instale

```bash
git clone https://github.com/Joaonic/agentkit.git
cd seu-projeto
../agentkit/install.sh --provider gitlab --tier free
```

### Opção 3: Cópia manual

```bash
# Copie o conteúdo do pacote para a raiz do seu projeto
cp -r agentkit-free-github/.cursor seu-projeto/
cp -r agentkit-free-github/.github seu-projeto/  # Apenas GitHub
cp agentkit-free-github/AGENTS.md seu-projeto/
```

## Compatibilidade

| Ferramenta | Como |
|------------|------|
| **Cursor** | Nativo: `.cursor/rules/` + `.cursor/skills/` |
| **GitHub Copilot** | `.github/copilot-instructions.md` + `.github/skills/` |
| **Windsurf** | Via `.windsurfrules` (adaptar rules manualmente) |
| **Cline** | Via `.clinerules` (adaptar rules manualmente) |
| **Qualquer CLI** | `copilot-cli`, `aider`, etc. — lê AGENTS.md |

## Suporte VCS

| Provider | CLI | Comandos |
|----------|-----|----------|
| **GitHub** | `gh` | `gh issue create`, `gh pr create`, `gh pr merge` |
| **GitLab** | `glab` | `glab issue create`, `glab mr create`, `glab mr merge` |

Auto-detectado com base no projeto (`.github/` → GitHub, `.gitlab-ci.yml` → GitLab, URL do remote).

### Setup GitHub

```bash
brew install gh          # macOS
sudo apt install gh      # Ubuntu/Debian
winget install GitHub.cli # Windows

gh auth login            # Login via browser
gh auth status           # Verificar
```

### Setup GitLab

```bash
brew install glab        # macOS
sudo apt install glab    # Ubuntu/Debian

glab auth login          # Login via browser
# Ou via token: glab auth login --hostname gitlab.com --token glpat-XXXXX
glab auth status         # Verificar
```

## Catálogo de Skills

### Tier Free (14 skills)

| Categoria | Skills |
|-----------|--------|
| **Planeamento** | `new-plan`, `implement-plan` |
| **Qualidade** | `tdd-workflow`, `posttask`, `posttask-workspace-lint`, `qa-issue-spec` |
| **Build & Teste** | `run-tests`, `run-build`, `lint-fix` |
| **Review** | `review-open-pr` |
| **Meta** | `add-skill`, `bootstrap`, `bootstrap-governance`, `new-adr` |

### Tier Pro (+53 skills)

| Categoria | Skills |
|-----------|--------|
| **Planeamento** | `create-milestone`, `executing-plans-parallel`, `plan-to-issues`, `prioritize-roadmap`, `prioritize-github-roadmap`, `prioritize-gitlab-roadmap` |
| **Auditoria** | `code-audit`, `code-audit-architecture-consistency`, `docs-audit`, `docs-audit-sync` |
| **Testes** | `e2e`, `ux-review` |
| **Backend (Java)** | `new-use-case`, `new-adapter`, `new-api-resource`, `db-migrate`, `gen-api` |
| **Backend (NestJS)** | `backend-hexagonal-nestjs`, `openapi-orval-nextauth` |
| **Frontend** | `new-feature`, `new-widget`, `new-ui-component`, `frontend-design` |
| **Infraestrutura** | `postgres-workbench`, `redis-workbench`, `elasticsearch-workbench`, `mongo-workbench` |
| **IA/ML** | `ai-guardrails-and-redaction`, `ai-router-executor-pattern` |
| **Design Patterns** | Todos os 22 GoF: `abstract-factory`, `adapter`, `bridge`, `builder`, `chain-of-responsibility`, `command`, `composite`, `decorator`, `facade`, `factory-method`, `flyweight`, `iterator`, `mediator`, `memento`, `observer`, `prototype`, `proxy`, `singleton`, `state`, `strategy`, `template-method`, `visitor` |
| **Plataforma** | `add-mcp`, `saas-mvp-bootstrap` |

### Tier Pro — Pipeline Scripts (4)

| Script | O que faz |
|--------|-----------|
| `pipeline.sh` | Loop autônomo completo: PRIORITIZE → IMPLEMENT → REVIEW → MERGE em waves |
| `parallel-implement.sh` | N agentes implementando issues em paralelo via git worktrees |
| `parallel-review.sh` | Review de todos os MRs/PRs abertos concorrentemente |
| `sequential-merge.sh` | Cadeia de merge inteligente com rebase ordering |

## Preços

| Tier | Preço | O que inclui |
|------|-------|-------------|
| **Free** | $0 | 14 skills, 10 rules, 4 agents — governança essencial |
| **Pro** | $79 | 67 skills, 51 rules, 11 agents, pipeline completo, workflow docs |
| **Team** | $199 | Pro + 1 ano de updates + suporte prioritário via GitHub Issues |
| **Enterprise** | $499/ano | Team + consultoria 2h de setup + SLA |

**[Comprar AgentKit Pro →](https://your-lemonsqueezy-link.com)**

## Por que AgentKit?

| Funcionalidade | AgentKit | Devin | Cursor | Codegen | Sweep |
|----------------|----------|-------|--------|---------|-------|
| Framework de governança | ✅ | ❌ | ❌ | ❌ | ❌ |
| Quality gates | 5 | 0 | 0 | 0 | 0 |
| TDD obrigatório | ✅ | ❌ | ❌ | ❌ | ❌ |
| Review multi-agente | ✅ | ❌ | ❌ | ❌ | ❌ |
| Paralelismo via worktrees | ✅ | ❌ | ❌ | ❌ | ❌ |
| Pipeline loop autônomo | ✅ | ❌ | ❌ | ❌ | ❌ |
| Monorepo-aware | ✅ | ❌ | Parcial | ❌ | ❌ |
| 22 padrões GoF | ✅ | ❌ | ❌ | ❌ | ❌ |
| GitHub + GitLab | ✅ | GitHub | ❌ | GitHub | GitHub |
| Core open source | ✅ | ❌ | ❌ | ❌ | ✅ |

## Contribuir

Veja [CONTRIBUTING.md](CONTRIBUTING.md) para guidelines sobre criação de skills, rules e agents.

## Licença

MIT — veja [LICENSE](LICENSE) para detalhes.

O tier free é totalmente open source. O tier Pro é distribuído como pacote pago.
