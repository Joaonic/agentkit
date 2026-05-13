---
name: new-plan
description: Build an execution-ready plan with explicit scope, acceptance criteria, validation harness, dependencies, and risk controls.
---

# New Plan

## Purpose

Turn a request into a plan that can be executed without hidden assumptions.

## Required Inputs

- user request or issue link
- affected modules and stack context
- architecture and policy constraints
- delivery constraints (deadline/dependency)

## Fetch completo de issue (quando input é issue link)

Quando o input inclui uma issue do tracker, o agente **deve** consumir **todos** os campos antes de planear:

**GitLab (default):**

```bash
# 1. Body completo + metadata (labels, milestone, assignees, state, dates, web_url)
glab issue view <N> --output json

# 2. Todos os comentários/notas (decisões, feedback, mudanças de scope)
glab issue view <N> --comments

# 3. MRs já vinculados à issue (trabalho existente, branches abertas)
glab api "projects/:id/issues/<N>/related_merge_requests" 2>/dev/null || true

# 4. Issues relacionadas (parent, blocker, linked — dependências e fronteiras)
glab api "projects/:id/issues/<N>/links" 2>/dev/null || true
```

**Exceção `web/your-github-project` (GitHub):**

```bash
gh issue view <N> --json number,title,body,state,labels,milestone,assignees,url,comments
gh api "repos/{owner}/{repo}/issues/<N>/timeline" --jq '.[] | select(.event=="cross-referenced")' 2>/dev/null || true
```

**Campos obrigatórios a usar no plano:**

| Campo | Uso no plano |
|-------|-------------|
| `description` (body) | Requisitos, scope, AC — base do work breakdown |
| `notes` / comments | Decisões posteriores, mudanças de scope, contexto técnico |
| `labels` | Prioridade, tipo de trabalho, área/módulo, flags (`Blocked`, `needs-research`) |
| `milestone` | Ciclo de entrega — informar deadline/constraints |
| `assignees` | Responsável — contacto para dúvidas |
| `related MRs` | Trabalho já feito — ajustar plano ao estado real |
| `linked issues` | Dependências, bloqueadores, parent — mapear para Dependencies section |

**Não** planear com base apenas no título ou resumo verbal do utilizador quando existe issue no tracker.

## Mandatory Plan Structure

1. Objective
2. Non-objectives
3. Current-state summary
4. Work breakdown (atomic steps)
5. Acceptance criteria per step
6. Validation harness per step
7. Dependencies and blockers
8. Risks and mitigations
9. Rollout/rollback notes (if applicable)

## Step Quality Rules

- one step = one coherent observable outcome
- no vague verbs without measurable result
- each step includes objective acceptance criteria
- each step includes concrete validation command or explicit manual check

## Definition of Ready (Before Publishing)

- boundaries are explicit (in/out)
- dependencies are mapped
- architecture-sensitive changes identified
- test strategy exists for behavior changes

## Blocking Conditions

- missing non-objectives for large scope
- unknown dependencies across modules/teams
- no validation strategy for behavior changes

## Output

Create/update `.cursor/plans/<name>.plan.md` with all steps as `pending`.
