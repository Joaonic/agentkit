---
name: plan-to-issues
description: Sincronizar planos do repositório com issues GitLab (ou GitHub na exceção your-github-project) agent-ready; usar ao criar, atualizar, auditar ou implementar planos em `.cursor/plans/**`, `docs/superpowers/plans/**` ou equivalentes — dedupe, QA package, bloco de arquitetura, labels/milestone e auditoria pós-publicação.
---

# Plan to Issues

Transformar planos locais em **issues executáveis por agentes** no tracker do projeto.

## Invariantes

1. A issue no tracker é o **contrato operacional** da implementação.
2. O plano local explica intenção, contexto e decomposição; a issue deve conter escopo executável, critérios, harness, riscos, testes e referências.
3. Não criar documentação transitória de QA em `docs/` salvo pedido explícito do usuário.
4. Não criar issue sem antes checar duplicatas por fingerprint, path do plano, título canônico e objetivo.
5. Não iniciar implementação de plano sem issue pareada, worktree dedicado e MR pareado conforme `docs/governance/cursor/workflow.md` e `workflow/02-implementation.md`.
6. Não hardcodar números ou títulos de milestones. Resolver sempre contra dados do tracker (`glab api "groups/your-org/milestones?state=active"`).

## Fontes obrigatórias

Antes de criar, atualizar ou auditar issues, ler:

- `AGENTS.md`
- `docs/governance/cursor/workflow.md`
- `docs/governance/cursor/workflow/02-implementation.md`
- `.cursor/rules/02-plans-require-tracked-issues.mdc`
- `.cursor/agents/project-manager.md`
- `.cursor/skills/qa-issue-spec/SKILL.md`
- o plano ou documento fonte informado pelo usuário

Carregar também, quando aplicável:

- `.cursor/skills/plan-to-issues/references/issue-body-template.md`
- `.cursor/skills/plan-to-issues/references/architecture-block-template.md`
- `.cursor/skills/plan-to-issues/references/issue-audit-checklist.md`

## Ferramentas permitidas

- **GitLab (default):** somente `glab` CLI (e `glab api` quando necessário).
- **Exceção:** `web/your-github-project` — `gh` ou MCP GitHub conforme política do subprojeto.

Nunca tratar uma secção markdown no repo como substituto da issue no tracker.

## Fluxo obrigatório

### 0. Classificar o input

Classificar como:

- plano único
- milestone com vários planos
- issue existente a normalizar
- auditoria de plano sem issue
- auditoria de issue duplicada ou incoerente

Extrair:

- path do plano
- título canônico
- milestone candidata
- domínio
- tipo de trabalho
- prioridade
- estimate (se houver)
- dependências
- riscos
- files ou áreas citadas
- sinais de arquitetura ou refactor

### 0b. Architecture and Skill Selection Gate (BLOQUEIO)

Antes de criar ou atualizar a issue:

1. Inventariar skills relevantes ao escopo. Consultar `docs/governance/cursor/workflow/08-skills-by-context.md` e `AGENTS.md`.
2. Selecionar **skills obrigatórias** para implementação. Mínimo: 1 skill de domínio + `tdd-workflow` quando código mudar.
3. Para **arquitetura, refactor estrutural ou novo design pattern**, declarar obrigatoriamente no body:
   - Pattern escolhido (primário e secundários)
   - Justificativa
   - Alternativas rejeitadas com trade-offs
   - Skills obrigatórias (ex.: skill `design-pattern-*` + validação)
   - Boundaries afetados (domain/application/infrastructure/api/adapters/in)
   - DoD arquitetural mensurável
4. Se houver **dúvida entre padrões**, registrar opções e trade-offs na issue e alinhar com o utilizador antes de marcar ready.
5. Se não houver skills suficientes declaradas, aplicar label `needs-research` (ou equivalente) e **não** marcar como pronta para execução autónoma.

Para issues de arquitetura/refactor, usar `references/architecture-block-template.md` como bloco obrigatório no body.

### 1. Preflight de duplicidade

Antes de criar qualquer issue, procurar issues abertas e fechadas por:

1. fingerprint do plano
2. path relativo do plano
3. título canônico normalizado
4. código de milestone / código funcional no título, se existir
5. objetivo resumido
6. issues com corpo muito parecido e título diferente

Comandos de referência (GitLab):

```bash
glab issue list --all --search "<plan-path-or-key>" --output json
glab issue list --all --search "<canonical-title>" --output json
```

Se houver match claro: **atualizar** a issue existente. Não criar nova.

Se houver duplicatas óbvias: parar e reportar issue canônica sugerida, duplicadas, proposta de consolidação.

### 2. Resolver milestone, labels e parent

**Milestone**

- Listar milestones abertas: `glab api "groups/your-org/milestones?state=active"`
- Atribuir apenas título que exista no projeto. Se a milestone do plano não existir, usar label `needs-research` e registar a dúvida no body.

**Kanban (workflow):** ao criar issues para trabalho iminente, usar label de estágio `To-Do`. Durante `implement-plan` / `subagent-driven-development`, os agentes **devem** avançar as labels Kanban do GitLab (`To-Do`, `Awaiting Feedback`, `In Progress`, `Code Review`, `Testing`, `Done`, `Deployment`, `Acceptance Testing`) conforme o progresso real — uma de cada vez, sem acumular estágios; ver `.cursor/skills/implement-plan/SKILL.md` (secção *Labels Kanban*).

**Labels obrigatórias (vocabulário real do projeto GitLab — usar exactamente estes nomes)**

- Tipo, exactamente uma: `Bug`, `New Feature`, `Enhancements`, `epic`, `Refactoring`, `Research`, `Maintenance`
- Prioridade, exactamente uma: `Critical Priority`, `High Priority`, `Medium Priority`, `Low Priority` (para bloqueio total de outros épicos: `Blocker`)
- Área, uma ou mais: `area::backend`, `area::web`, `area::infra`, `area::security`, `area::billing`
- Módulo (quando aplicável): `my-service`, `my-analyzer`, `your-web-app`, `my-billing`, `frontend`, `keycloak`, `security-oauth`
- Domínio (quando aplicável): `DevOps`, `Infrastructure`, `Integrations`, `Libraries`, `Analytics`, `Performance`, `Security Issues`, `Documentation`, `Design`

**Labels condicionais**

- `Blocked` quando dependências impedem início
- `needs-research` quando requisitos, milestone, pattern ou dependências não estão resolvidos

**Parent / épico**

- Se existir épico aberto, declarar `Parent (epic):` com URL ou `#iid`.
- Caso contrário `Parent (epic): none` com breve nota.

### 3. Decidir issue simples vs épico

**Issue simples** quando:

- entrega atómica
- até ~6 SP (se usarem SP)
- no máximo 3 frentes técnicas
- um MR coerente fecha o escopo

**Épico + sub-issues** quando:

- mais de 6 SP ou várias subentregas independentes
- várias frentes com MRs independentes
- dependências internas exigem ordem explícita

Para múltiplas issues:

1. criar ou atualizar o épico primeiro
2. aguardar conclusão
3. criar ou atualizar **uma** sub-issue de cada vez (sem paralelismo neste fluxo)
4. `Parent (epic)` com `#iid` ou URL

### 4. Gerar QA package

Executar fluxo da skill `qa-issue-spec` antes de publicar o body final.

### 5. Montar o body da issue

Usar `references/issue-body-template.md` como base.

Obrigatório incluir:

- fingerprint / metadata de rastreio do plano
- source plan path
- prioridade e parent
- objetivo, contexto de negócio (quando aplicável)
- comportamento actual vs desejado
- escopo / fora de escopo
- requisitos funcionais e não-funcionais relevantes
- acceptance scenarios
- technical context e áreas prováveis
- constraints e contracts (API, eventos, Flyway)
- edge cases
- **verification harness** com comandos concretos (`./mvnw …`, `yarn …`)
- required tests
- skills obrigatórias
- QA package (body ou comentário único ligado no topo)
- relationships e referências
- done definition

Para arquitetura/refactor/pattern novo: incluir bloco de `architecture-block-template.md`.

### 6. Criar ou atualizar via tracker

**GitLab**

```bash
glab issue create --title "<title>" --description "$(cat /tmp/agentic-issue-body.md)" --label "<labels>"
glab issue update <iid> --title "<title>" --description "$(cat /tmp/agentic-issue-body.md)" --label "<labels>"
```

Validar UTF-8 do ficheiro antes (`file --mime-encoding`). Para corpos muito grandes, usar `glab api` com JSON escapado correctamente ou dividir em comentário único + resumo no body.

**your-github-project (GitHub)**

```bash
gh issue create --title "..." --body-file /tmp/agentic-issue-body.md ...
```

### 7. Verificação pós-publicação

```bash
glab issue view <iid> --output json
```

Confirmar: fingerprint, plan path, labels/milestone, parent, critérios testáveis, harness real, skills declaradas, bloco de arquitetura quando obrigatório, QA package acessível.

Corrigir qualquer falha antes de reportar sucesso.

## Regras para implementação posterior

Quando a issue for usada por `implement-plan`:

1. Investigador faz **fetch completo** da issue — body, comentários, labels, milestone, assignees, MRs vinculados e issues relacionadas:
   ```bash
   # GitLab (default)
   glab issue view <N> --output json
   glab issue view <N> --comments
   glab api "projects/:id/issues/<N>/related_merge_requests" 2>/dev/null || true
   glab api "projects/:id/issues/<N>/links" 2>/dev/null || true
   # Exceção web/your-github-project (GitHub):
   # gh issue view <N> --json number,title,body,state,labels,milestone,assignees,url,comments
   ```
2. Decisões de escopo/arquitetura devem ficar registadas em comentário na issue.
3. Após abrir MR, comentar link do MR na issue.
4. Antes de concluir, mapear critérios a commits ou actualizar checklist no body.
5. MR deve usar `Closes #n` / `Fixes #n` / `Refs #n` conforme o estado real.

## Proibições

- Não criar issue sem preflight de duplicidade.
- Não criar múltiplas issues em paralelo neste fluxo.
- Não publicar QA package só em docs transitórios.
- Não deixar body com título de uma feature e escopo de outra.
- Não inventar milestones sem confirmar no GitLab.
- Não substituir issue por markdown local isolado.
- Não remover critérios de aceite para “caber” no body.
- Não declarar sucesso sem reler a issue publicada.
## Disciplina de issues — zero débito, zero bypass

As issues criadas por este fluxo **devem** incluir a seguinte política no body (secção "Implementation Constraints" ou equivalente) para que subagents de `implement-plan` a cumpram:

- **Zero bypass:** proibido `--no-verify`, `-DskipTests` em entregas finais, `@SuppressWarnings` sem justificativa, `eslint-disable` sem motivo real, `// @ts-ignore` sem issue.
- **Zero deprecated:** usar sempre APIs actuais. Se deprecated for a única opção, escalar — não usar "por enquanto".
- **Zero gambiarras:** hardcoded values, `Thread.sleep()` como solução de timing, catch genérico que engole excepções, stubs sem issue de tracking — tudo é **BLOQUEIO** na review.
- **Zero warnings novos:** compiler, lint, deprecation warnings introduzidos pelo MR são bloqueantes.
- **Stubs/TODOs só com issue:** cada stub deve referenciar issue aberta (`// TODO(#N): ...`), mesmo milestone, path não atingível em produção.

Quando a issue inclui acceptance criteria ou verification harness, estes **devem validar** que a implementação não contém bypass, deprecated, ou warnings — não apenas que a funcionalidade "funciona".
## Relatório final

Responder com:

- issue criada ou actualizada + URL
- plano fonte
- labels e milestone aplicadas
- parent e relationships
- onde ficou o QA package
- duplicados encontrados e acção tomada
- pendências ou `needs-research`
