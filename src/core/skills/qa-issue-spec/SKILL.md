---
name: qa-issue-spec
description: Build a complete QA package from a GitLab issue (default), GitHub issue (your-github-project exception), Linear ticket, bug report, or feature request — scenarios, functional spec, acceptance criteria, Gherkin, regression coverage, risks, test data, and open questions before implementation or QA execution.
---

# QA Issue Spec

Produce a complete, execution-ready QA package for a single issue.

Treat the issue as the source of truth, then enrich it with repository evidence and linked context. Read the issue title, body, comments, linked files, related code, existing tests, flags, migrations, schemas, and nearby modules before drafting the output.

Do not stop at a short checklist. Deliver a full package that a QA engineer, developer, or product manager can use immediately.

## Operating principles

- Distinguish clearly between:
  - **explicit facts** from the issue or codebase
  - **inferred behavior** based on context
  - **unknowns** that need confirmation
- Do not invent product rules silently. When a rule is missing, state the assumption.
- Prefer risk-based coverage over exhaustive noise.
- Favor concrete system behavior over generic QA advice.
- Reuse repository terminology exactly as found in the issue and codebase.
- When existing tests already cover part of the behavior, call that out and avoid duplicating them blindly.

## Workflow

Follow this sequence.

### 1. Understand the issue

**Fetch completo obrigatório — comandos (GitLab default):**

```bash
# 1. Body completo + metadata (labels, milestone, assignees, state, dates, web_url)
glab issue view <N> --output json

# 2. Todos os comentários/notas (decisões, feedback, mudanças de scope)
glab issue view <N> --comments

# 3. MRs já vinculados à issue (contexto de implementação existente)
glab api "projects/:id/issues/<N>/related_merge_requests" 2>/dev/null || true

# 4. Issues relacionadas (parent, blocker, linked — entender fronteiras)
glab api "projects/:id/issues/<N>/links" 2>/dev/null || true
```

**Exceção `web/your-github-project` (GitHub):**

```bash
gh issue view <N> --json number,title,body,state,labels,milestone,assignees,url,comments
gh api "repos/{owner}/{repo}/issues/<N>/timeline" --jq '.[] | select(.event=="cross-referenced")' 2>/dev/null || true
```

**Campos obrigatórios a consumir:**

| Campo | Uso no QA package |
|-------|-------------------|
| `description` (body) | Requisitos, AC, user stories, contexto |
| `notes` / comments | Decisões de scope, feedback, esclarecimentos |
| `labels` | Prioridade (determina p0/p1/p2), tipo (bug vs feature), área |
| `milestone` | Ciclo de entrega, timeline |
| `assignees` | Contacto para open questions |
| `related MRs` | Implementação já feita (ajustar QA ao que existe) |
| `linked issues` | Parent/blocker — entender scope e fronteiras |
| `source_plan` | Se presente no body, ler plano para contexto completo |

A partir do fetch completo, extrair e normalizar:

- problem or requested capability
- user or system outcome
- in-scope behavior
- out-of-scope behavior
- dependencies and touched areas
- likely data entities, endpoints, screens, jobs, flags, permissions, and integrations

If the issue is a bug, identify:

- current behavior
- expected behavior
- likely reproduction conditions
- regression surface

If the issue is a feature or enhancement, identify:

- user flow changes
- state transitions
- contract changes
- backward compatibility concerns

### 2. Inspect implementation context

Before writing scenarios, inspect nearby repository context when available:

- affected modules and entrypoints
- API contracts and DTOs
- database models, migrations, and validations
- UI states and form constraints
- permission checks and feature flags
- observability hooks, logging, analytics, and side effects
- existing automated tests and adjacent regressions

If code access is unavailable, continue with the issue alone and state that limitation.

### 3. Build the QA package

Always generate the sections below in this order.

### 4. Publish target (mandatory)

Default destination for the QA package is the **tracker issue** itself (GitLab via `glab`; GitHub only for `web/your-github-project`), not repository docs:

- Prefer updating the issue **description/body** with the full QA package.
- If the body is too large, publish the full package in a **single issue comment/note** and keep a short summary in the body linking to that comment.
- Do **not** create transient QA markdown files under `docs/` (or elsewhere in the repo) unless the user explicitly requests a file artifact.
- When `plan-to-issues` is the caller, this publish step must happen before creating/updating final labels/milestone state.

### 5. Integridade UTF-8 na publicação (obrigatório — BLOQUEIO)

Toda escrita no tracker **deve** garantir codificação UTF-8 válida.

**Regras:**

1. Escrever conteúdo longo num ficheiro temporário; validar encoding antes de publicar.
   ```bash
   printf '%s' "$BODY" > /tmp/qa-body.md
   file --mime-encoding /tmp/qa-body.md   # utf-8 ou us-ascii
   glab issue update <IID> --description "$(cat /tmp/qa-body.md)"
   ```
   Para corpos muito grandes ou caracteres problemáticos no shell, preferir `glab api` com JSON ou `glab issue note` para o pacote completo e um resumo curto no body.
   **Exceção `web/your-github-project` (GitHub):** usar `gh issue edit <N> --body-file /tmp/qa-body.md`.
2. **Validar encoding antes de publicar:** executar `file --mime-encoding <ficheiro>` — se não for `utf-8` ou `us-ascii`, reescrever antes de prosseguir.
3. **Heredocs:** usar `cat <<'EOF'` (quotes no delimitador) para evitar expansão de variáveis que introduza bytes inválidos.
4. **Detecção de corrupção:** se ao ler issue existente o body contiver sequências como `â€"`, `Ã©`, `Ã£` — reportar corrupção ao usuário e não propagar conteúdo corrompido.
5. **Checklist pré-publicação:** conteúdo em ficheiro temporário ✓ | `file --mime-encoding` confirma UTF-8 ✓ | sem mojibake visível ✓

## Output format

### 1. Issue summary

State the issue in 2 to 5 bullets:

- objective
- impacted area
- primary actor or system
- main change or defect
- notable dependencies

### 2. Scope

Create two bullet lists:

- **in scope**
- **out of scope**

If out-of-scope is not explicit, infer a conservative boundary and mark it as inferred.

### 3. Assumptions and unknowns

Use two lists:

- **assumptions used to draft this qa package**
- **open questions needing product or engineering confirmation**

Only ask questions that materially change implementation or test coverage.

### 4. Functional spec for QA

Write a compact spec with these subsections when relevant:

- actors
- preconditions
- trigger
- main flow
- alternate flows
- failure paths
- postconditions
- persistence and side effects
- permissions and visibility
- observability expectations

Keep this concrete and tied to the issue.

### 5. Acceptance criteria

Write numbered acceptance criteria.

Rules:

- make each criterion testable
- separate positive and negative behavior
- include empty, invalid, duplicate, unauthorized, boundary, and failure behavior when relevant
- include state persistence and idempotency when relevant

### 6. Test scenario matrix

Create a markdown table with these columns exactly:

| id  | priority | area | scenario type | scenario | preconditions | steps | expected result |
| --- | -------- | ---- | ------------- | -------- | ------------- | ----- | --------------- |

Rules for the matrix:

- use ids like `QA-001`, `QA-002`
- use priorities `p0`, `p1`, `p2`
- scenario types may include `happy path`, `alternate`, `negative`, `boundary`, `permission`, `integration`, `regression`, `data integrity`, `resilience`, `accessibility`, `localization`
- steps must be concise but executable
- expected result must be observable

Minimum coverage categories to consider when relevant:

- happy path
- validation and invalid input
- boundary values
- duplicate or idempotent actions
- permission and role behavior
- empty state and missing data
- loading, retry, timeout, and downstream failure
- persistence and refresh behavior
- analytics, logs, emails, webhooks, background jobs, or side effects
- regression around adjacent flows

### 7. BDD scenarios

Write 3 to 8 Gherkin scenarios for the most important flows.

Rules:

- prioritize business-critical behavior
- cover at least one success case and one failure or validation case
- use domain terms from the issue
- keep them implementation-agnostic

Template:

```gherkin
Scenario: <title>
  Given <context>
  And <additional context>
  When <action>
  Then <expected outcome>
  And <additional observable result>
```

### 8. Regression checklist

Create a short checklist grouped by impacted surface, for example:

- related screens
- related endpoints
- shared components
- background jobs
- notifications
- permissions
- reporting or analytics

Only include surfaces with a plausible blast radius.

### 9. Non-functional checks

List only the relevant items among:

- performance
- security
- accessibility
- localization
- observability
- compatibility
- concurrency
- data migration

For each selected item, write the concrete risk to verify.

### 10. Test data and environment needs

List the minimum setup required:

- accounts and roles
- seed data
- feature flags
- third-party stubs or mocks
- environment conditions
- devices, browsers, or platforms

### 11. Automation recommendations

Split into:

- **automate now**
- **manual only for now**

Recommend automation for stable, critical, repeatable coverage. Explain briefly why.

## Coverage rules by issue type

### Bug

Add these where possible:

- reproduction scenario for the current bug
- proof that the fix works
- proof that nearby legacy behavior still works
- proof that the same defect does not occur in sibling flows

### Feature

Add these where possible:

- first-time flow
- repeat usage flow
- zero-data and partial-data states
- permission and visibility matrix
- rollback or cancellation behavior

### Enhancement or refactor

Add these where possible:

- unchanged contract expectations
- backward compatibility checks
- smoke regression for critical path
- observability and supportability checks

## Prioritization rubric

Use this heuristic:

- **p0**: broken core journey, money movement, auth, permissions, destructive actions, irreversible state, contractual data
- **p1**: important flow, common alternate path, major validation, key integration, common regression risk
- **p2**: low-frequency edge case, cosmetic detail, secondary workflow

## Quality bar

A strong output must be:

- specific to the issue, not generic
- directly executable by QA
- clear about assumptions
- balanced between breadth and signal
- concise where possible, but never shallow

## Do not do this

- do not return only generic test ideas
- do not output a spec without scenarios
- do not output scenarios without expected results
- do not collapse all coverage into one huge checklist
- do not hide uncertainty
- do not ask the user for missing details before first drafting from available evidence

## Integration with plan-to-issues

When called by `plan-to-issues`, the output must be compatible with the "QA Package" section of `.cursor/skills/plan-to-issues/references/issue-body-template.md`.

Rules for agent-ready issues:

- The test scenario matrix must always use full columns: id, priority, area, scenario type, scenario, preconditions, steps, expected result.
- Abbreviated or summarized matrices are prohibited in agent-ready issues.
- Always include "Automation recommendations" even if the answer is "manual only for now".
- Always include "Contract and harness gaps" when the issue does not have testable commands in its verification harness.
- If the body is too large, publish the full QA package in a single comment and insert a link in the body.

## Reference files

Use these bundled references when they help:

- `references/qa-package-template.md` for the default output skeleton
- `references/coverage-checklist.md` for additional coverage prompts when the issue is complex or touches multiple surfaces
- `.cursor/skills/plan-to-issues/references/issue-body-template.md` for the canonical issue body format in this repository
