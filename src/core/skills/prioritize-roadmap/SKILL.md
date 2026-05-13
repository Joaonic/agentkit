---
name: prioritize-roadmap
description: Prioritize backlog using objective scoring, dependency critical path, and execution-wave planning.
---

# Prioritize Roadmap

## Inputs

- open issues
- milestone structure
- dependency map
- delivery constraints

## Fetch completo de issues (obrigatório antes de priorizar)

O agente **deve** buscar **todos** os campos de cada issue candidata — não apenas título e body.

**1. Listar issues abertas (GitLab default):**

```bash
# Todas as abertas do projeto (open é o default, não precisa de --state)
glab issue list --per-page 100 --output json

# Todas (abertas + fechadas)
glab issue list --all --per-page 100 --output json

# Por milestone específica
glab issue list --milestone "<milestone>" --per-page 100 --output json

# Por label de área/módulo
glab issue list --label "area::backend" --per-page 100 --output json
```

**Exceção `web/your-github-project` (GitHub):**

```bash
gh issue list --state open --json number,title,body,state,labels,milestone,assignees,url --limit 200
```

**2. Para cada issue candidata, fetch completo:**

```bash
# Body + metadata (labels, milestone, assignees, state, dates)
glab issue view <N> --output json

# Comentários (decisões, feedback, mudanças de scope)
glab issue view <N> --comments

# MRs vinculados (trabalho já em curso)
glab api "projects/:id/issues/<N>/related_merge_requests" 2>/dev/null || true

# Issues relacionadas (dependências, blockers)
glab api "projects/:id/issues/<N>/links" 2>/dev/null || true
```

**3. Milestones:**

```bash
glab api "groups/your-org/milestones?state=active"
```

**Campos obrigatórios a usar na priorização:**

| Campo | Uso na priorização |
|-------|-------------------|
| `description` (body) | Scope, AC, complexidade estimada |
| `notes` / comments | Decisões de scope, feedback, ajustes de prioridade |
| `labels` | Prioridade actual, tipo, área, `Blocked`, `needs-research` |
| `milestone` | Ciclo de entrega, agrupamento temporal |
| `assignees` | Capacidade da equipa, carga por pessoa |
| `related MRs` | Estado de implementação (já começado? draft? mergeado?) |
| `linked issues` | Dependências — input obrigatório para critical path |
| `created_at` / `updated_at` | Idade da issue, actividade recente |

**Não** priorizar com base apenas em títulos ou lista superficial.

## Mandatory Method

1. collect candidate issues
2. score each item:
- impact
- urgency
- dependency criticality
- implementation risk
3. identify critical path blockers
4. group work into execution waves
5. flag missing specs/QA packages

## Wave Guidance

- Wave 1: blockers and prerequisite items
- Wave 2: high-impact independent items
- Wave 3: optimization and low-criticality items

## Output

Table columns:
- issue id
- score
- blocker status
- proposed wave
- rationale
- dependency notes
