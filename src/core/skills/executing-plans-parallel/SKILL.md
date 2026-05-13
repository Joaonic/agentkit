---
name: executing-plans-parallel
description: Wrapper para executar planos em paralelo quando houver grupos de tasks independentes, combinando superpowers:executing-plans, superpowers:dispatching-parallel-agents e tdd-workflow.
---

# Executing Plans Parallel

## Visão geral

Use esta skill quando você tiver **um plano já escrito** (ex.: em `docs/plans/*.plan.md`) e houver **2+ grupos de tasks claramente independentes** (backend, frontend, shared, docs) que podem ser executados em paralelo sem compartilhar arquivos nem depender de ordem.

**Ideia central:** manter toda a disciplina de `superpowers:executing-plans` + `tdd-workflow`, mas dividir o plano em blocos e despachar **subagentes em paralelo** usando `superpowers:dispatching-parallel-agents`, cada um responsável por um domínio.

## Pré‑requisitos

- Plano existente com tasks já definidas.
- `implement-plan` como skill de entrada.
- **`docs/governance/cursor/workflow.md`** e **`workflow/02-implementation.md`**: cada frente paralela deve ter **worktree próprio**, **issue rastreada** (`glab` por defeito; `web/your-github-project` usa `gh`) e **MR/PR** alinhado; dentro de cada frente usar **`superpowers:subagent-driven-development`** por task (evitar vários implementadores na mesma worktree). Em GitLab, **actualizar labels Kanban** na issue (`To-Do` → `In Progress` → `Code Review` → …) conforme `.cursor/skills/implement-plan/SKILL.md` (*Labels Kanban*).
- Skills:
  - `superpowers:executing-plans`
  - `superpowers:dispatching-parallel-agents`
  - `tdd-workflow`

## Quando usar (e quando NÃO usar)

Use esta skill quando:

- O plano tem **2+ grupos de tasks** que:
  - Atuam em domínios diferentes (ex.: `apps/<serviço>/**` backend Spring Boot, `web/<app>/**` frontend Yarn, `libraries/**`, `infra/**`, `docs/**`).
  - Não modificam os **mesmos arquivos** nem diretórios fortemente acoplados.
  - Não dependem claramente da conclusão de outro grupo (sem “Task 2 depende da refator de Task 1”).

Não use em modo paralelo quando:

- As tasks compartilham arquivos ou módulos centrais.
- O plano descreve dependência explícita de ordem entre tasks.
- Você não consegue ter certeza razoável de independência → neste caso, **cair para fluxo sequencial** de `superpowers:executing-plans`.

## Processo

### 1. Anunciar e carregar plano

1. Anuncie: “Estou usando a skill `executing-plans-parallel` para implementar este plano com subagentes em paralelo quando seguro.”
2. Leia o arquivo de plano completo.
3. Aplique o passo de revisão inicial de `superpowers:executing-plans`:
   - Entender objetivo, escopo e constraints.
   - Identificar dúvidas críticas; se houver, alinhar antes de executar.
### 1b. Fetch completo das issues associadas ao plano

Antes de dividir em grupos ou despachar subagentes, o agente pai **deve** consumir **todos** os campos de cada issue referenciada no plano:

**GitLab (default):**

```bash
# Body + metadata (labels, milestone, assignees, state, dates)
glab issue view <N> --output json

# Comentários (decisões, feedback, mudanças de scope)
glab issue view <N> --comments

# MRs já vinculados (trabalho existente, branches abertas)
glab api "projects/:id/issues/<N>/related_merge_requests" 2>/dev/null || true

# Issues relacionadas (dependências, blockers — crítico para decidir paralelismo)
glab api "projects/:id/issues/<N>/links" 2>/dev/null || true
```

**Exceção `web/your-github-project` (GitHub):**

```bash
gh issue view <N> --json number,title,body,state,labels,milestone,assignees,url,comments
gh api "repos/{owner}/{repo}/issues/<N>/timeline" --jq '.[] | select(.event=="cross-referenced")' 2>/dev/null || true
```

**Usar linked issues para validar independência entre grupos** — se uma issue do grupo A depende de issue do grupo B, **não** são parallelizáveis.

Ao despachar subagentes (passo 3), incluir no prompt: "Fetch completo obrigatório por issue: `glab issue view <N> --output json`, `glab issue view <N> --comments`, MRs vinculados e issues relacionadas. Não considerar a issue lida sem comentários, labels, milestone e linked issues."
### 2. Identificar grupos de tasks independentes

1. Liste todas as tasks do plano.
2. Para cada task, derive um **domínio principal** com base em `Files:` ou caminhos:
   - Paths em `apps/**` típicos de backend Java (`**/src/main/java/**`) → `backend`.
   - Paths em `web/**` (frontends Next/React, etc.) → `frontend`.
   - Paths em `libraries/**` (libs Java partilhadas) → `shared`.
   - Paths em `infra/**`, `deploy/**` quando infra própria do trabalho → `infra` (usar `generalPurpose` ou agentes especializados conforme contexto).
   - Paths em `docs/**` → `docs`.
3. Agrupe tasks por domínio.
4. Para cada par de grupos, verifique:
   - Se há arquivos ou diretórios em comum.
   - Se o plano explicita dependência entre tasks de grupos diferentes.
5. Se não houver pelo menos **2 grupos claramente independentes**, volte para o fluxo **sequencial**:
   - Use somente `superpowers:executing-plans` + `tdd-workflow` em um único agente.

### 3. Preparar subagentes por domínio

Quando houver 2+ grupos independentes:

1. Invoque a skill `superpowers:dispatching-parallel-agents` para orientar a divisão.
2. Para cada grupo/domínio, crie um subagente usando o `Task` tool:
   - `backend` → `subagent_type: "backend"`
   - `frontend` → `subagent_type: "frontend"`
   - `shared` → `subagent_type: "generalPurpose"` ou `backend`/`frontend`, conforme domínio predominante.
   - `docs` → `subagent_type: "docs"`
3. No `prompt` de cada subagente, inclua:
   - Caminho do plano.
   - Lista exata das tasks atribuídas àquele domínio.
   - Instruções para:
     - Invocar `superpowers:executing-plans` **limitado ao seu subconjunto de tasks**.
     - Seguir estritamente `tdd-workflow` para cada task (testes → falha → implementação → testes verdes).
     - Respeitar escopo estrito: não tocar em arquivos de outros domínios.
     - Produzir um resumo final do que foi feito, incluindo verificação local (tests/build/lint relevantes ao domínio).

### 4. Despachar e aguardar em paralelo

1. Dispare todos os subagentes em paralelo (múltiplos `Task` tool calls com `run_in_background` quando apropriado).
2. Não sintetize resultados parciais; aguarde todos os subagentes retornarem.
3. Ao receber os resultados:
   - Leia cada resumo.
   - Verifique se não houve conflito de arquivos (ex.: mudanças no mesmo arquivo em domínios diferentes).

### 5. Verificação global e integração

1. Após todos os subagentes concluírem:
   - Rode as verificações globais definidas no plano (suítes de testes, build, lint relevantes).
2. Se detectar conflitos ou falhas:
   - Pare a execução paralela.
   - Trate os conflitos de forma explícita (em nova etapa sequencial), sem criar novos subagentes até resolver.

### 6. Finalização

1. Consolidar o que foi implementado:
   - Tasks concluídas por domínio.
   - Tasks ainda pendentes (por bloqueio ou decisão explícita).
2. Seguir o passo final da `superpowers:executing-plans`:
   - Invocar a skill `superpowers:finishing-a-development-branch` quando todas as tasks do plano estiverem concluídas ou explicitamente marcadas como pending conforme regras do repositório.
3. Produzir relatório final na conversa conforme skill `implement-plan` e `docs/governance/cursor/workflow.md`:
   - Destacar que parte do plano foi executada em paralelo.
   - Apontar qualquer risco residual decorrente da paralelização (se houver).

## Lembretes importantes

- **TDD continua obrigatório** em todas as tasks, mesmo quando executadas por subagentes em paralelo.
- Paralelizar **não** é obrigatório; quando houver dúvida sobre independência, prefira o fluxo sequencial.
- Sempre respeitar escopo estrito de mudança definido pelo usuário e pelo plano.
- **Rebase/merge de main NUNCA pode perder código:** ao integrar `main` na branch de trabalho, ambos os lados do conflito devem ser preservados. O código novo da feature entra **sem sobrescrever** o que já existia em main. Após rebase, verificar com `git diff origin/main..HEAD -- <ficheiros com conflito>` que nenhuma funcionalidade foi perdida. Se algo de main desapareceu, corrigir imediatamente antes de avançar.
- **Merge sequencial com [skip ci] (rule `41-merge-squash-skip-ci.mdc`):** quando o plano resultar em múltiplos MRs a serem mergeados sequencialmente na `main` do mesmo repositório, usar **squash merge** com `[skip ci]` em todos os merges intermédios. Só o **último merge** dispara o CI/CD completo. Reescrever a mensagem de cada merge com formato semântico (`tipo(#issue): descrição`). **GitLab gera DOIS commits** no squash merge (squash + merge commit) — usar **ambas as flags** (`--squash-message` e `--message`) com a mesma mensagem incluindo `[skip ci]` nos intermédios. Exemplo: `glab mr merge <IID> --squash --squash-message "feat(#42): desc [skip ci]" --message "feat(#42): desc [skip ci]" --yes`. Instruir subagentes que façam merge a seguir esta regra.
- **Integridade UTF-8:** instruir subagentes que criem issues/MRs a usar ficheiros temporários validados (`file --mime-encoding`), preferir `glab` com APIs adequadas para corpos grandes, e seguir `06-vcs-policy.mdc` para GitHub na pasta your-github-project.
