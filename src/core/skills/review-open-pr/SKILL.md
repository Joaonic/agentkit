---
name: review-open-pr
description: End-to-end open MR review — CI evidence, mandatory linked issue contract, full diff validation vs acceptance criteria. Uses GitLab CLI by default; GitHub for your-github-project exception.
disable-model-invocation: true
---

# review-open-pr

Analisa um **MR aberto** de ponta a ponta: **pipeline OK**, **ligação obrigatória a pelo menos uma issue** (fechar ao merge quando aplicável), e **confirmação de que o que a issue promete está implementado no código**, validado com **diff completo**. Usa **`glab`** no projeto GitLab padrão; o agente cruza texto das issues com **todo** o diff.

**Política:** todo MR deve referenciar **pelo menos uma issue** no corpo (`Closes #n`, `Fixes #n`, `Refs #n`) coerente com o escopo. Se não houver issue vinculada de forma inequívoca, o resultado é **bloqueante** até corrigir (corpo do MR ou fluxo).

**Kanban (GitLab):** ao iniciar esta revisão, garantir que a(s) issue(s) ligada(s) ao MR têm label **`Code Review`** (e não `In Progress` como estágio único). Após merge bem-sucedido e CI verde: retirar `Code Review` e aplicar **`Testing`** ou **`Done`** conforme a política da equipa; usar os nomes exactos em `.cursor/skills/implement-plan/SKILL.md` (*Labels Kanban*).

**Correções:** qualquer mudança de código, testes ou docs após a análise deve ser feita **na branch de origem do MR** (`source_branch`), preferencialmente num **git worktree** dedicado. **Proibido** corrigir em `main` ou noutra feature branch que não atualize o mesmo MR.

---

## Zero tolerância — warnings, stubs, TODOs

### Warnings são bloqueantes

**Todo** warning é bloqueante e deve ser corrigido antes de aprovar:

- **Compiler warnings** (Java `-Xlint`, TypeScript `strict`, etc.)
- **Lint warnings** (ESLint, Checkstyle, SpotBugs, PMD, etc.)
- **Deprecation warnings** — usar a API actual, não a deprecated
- **Test warnings** — testes instáveis, assertions fracas, `@Disabled` sem justificativa
- **Build warnings** — dependency convergence, plugin warnings, resource filtering

Se o warning **já existia** antes do MR (pré-existente na `target_branch`), registar como finding de severidade **Medium** mas **não bloquear** o MR actual — o MR não pode **introduzir** warnings novos. Se o MR **toca** o ficheiro que já tinha o warning, **deve** corrigi-lo (boy-scout rule).

### Stubs e TODOs — só com issue rastreada

**Proibido** aprovar MR que contenha:

- `TODO`, `FIXME`, `HACK`, `XXX`, `STUB` em código novo ou alterado
- `throw new UnsupportedOperationException()` ou equivalentes
- Métodos vazios / retornando `null` / hardcoded sem lógica real
- Comentários `// will be implemented in...` sem referência concreta

**Exceção única:** o stub/TODO é aceitável **se e só se**:
1. Existe uma **issue aberta e referenciada** explicitamente no comentário (e.g. `// TODO(#123): implement retry logic`)
2. A issue referenciada está no **mesmo milestone** ou no milestone imediatamente seguinte
3. O stub **não quebra** funcionalidade existente (i.e. o path não é atingível em produção, ou há feature flag)

Se o stub não cumprir os 3 critérios: **BLOQUEIO**.

### Compreensão exaustiva da issue

O agente **deve** consumir e cruzar **toda** a informação disponível da issue antes de validar o diff:

1. **Body completo** — ler do início ao fim, extrair TODOS os requisitos funcionais (FR-XX, AC-XX, critérios de aceite, user stories, cenários BDD/Gherkin)
2. **Todos os comentários/notas** — decisões de design, mudanças de scope, esclarecimentos do autor, feedback de reviewers anteriores, referências a outras issues
3. **Discussões no MR** — threads resolvidas e não resolvidas; pedidos de alteração
4. **Issues relacionadas** — se a issue referencia parent/child/blocker/blocked-by, ler essas issues para entender contexto e fronteiras de scope
5. **Plan source** — se existe `source_plan` no body, ler o ficheiro de plano para entender o contexto completo

Após extrair toda a informação, construir uma **checklist exaustiva** de critérios e validar **cada um** contra o diff:
- Critério presente no diff e correcto → ✅
- Critério ausente ou parcial → ❌ **BLOQUEIO** (salvo se explicitamente out-of-scope na issue ou rastreado noutra issue)
- Implementação no diff que **não** corresponde a nenhum critério da issue → 🔍 flag como scope creep (pode ser aceitável se justificado, mas deve ser sinalizado)

---

## Política de VCS

| Contexto | Ferramenta |
|----------|------------|
| Repositório GitLab (default monorepo your-org e submódulos GitLab) | `glab mr`, `glab issue`, `glab ci` |
| **`web/your-github-project`** | `gh pr`, `gh issue`, `gh run` |

---

## Pré-requisitos

- `glab` instalado e autenticado: `glab auth status` (ou equivalente no CI local).
- Raiz do repositório remoto configurado (`git remote`).
- Para your-github-project: `gh auth status`.

---

## Uso

- **MR da branch atual:** `glab mr view` (se existir MR aberto para a branch).
- **MR por IID:** `glab mr view <iid>`.
- **URL:** extrair IID ou usar `glab mr view <url>` se suportado pela versão instalada.

Se houver ambiguidade (vários MRs da mesma branch), listar candidatos com `glab mr list --source-branch <branch> --output json` (default retorna apenas abertos) e pedir confirmação ou usar o mais recente **aberto**.

---

## O que o agente faz (ordem sugerida)

### 0. Atualizar branch antes da review

**Antes** de analisar, garantir que a branch do MR está atualizada com o alvo:

```bash
HEAD_BRANCH=$(glab mr view <IID> --output json | jq -r '.source_branch')
TARGET_BRANCH=$(glab mr view <IID> --output json | jq -r '.target_branch')

git fetch origin "$HEAD_BRANCH" "$TARGET_BRANCH"
git checkout "$HEAD_BRANCH"
git pull origin "$HEAD_BRANCH"

git rebase "origin/$TARGET_BRANCH"
```

- Resolver conflitos **preservando ambos os lados** (regra de integridade após rebase).
- Push: `git push origin "$HEAD_BRANCH" --force-with-lease`.
- Verificar que não houve perda de conteúdo do alvo: `git diff "origin/$TARGET_BRANCH"..HEAD -- <paths em conflito>`.
- Só depois avançar para o passo 1.

### 1. Resolver qual MR analisar

```bash
git branch --show-current
glab mr view --output json 2>/dev/null || true
glab mr list --source-branch "$(git branch --show-current)" --output json
```

### 2. Snapshot completo do MR (JSON)

```bash
glab mr view <IID> --output json
```

Extrair e guardar:

- `title`, `description`, `state`, `draft`, `source_branch`, `target_branch`
- lista de commits / alterações quando disponível no JSON
- metadata para pipelines (branch fonte)

**Checagem obrigatória — pelo menos uma issue:**

- Ler `description` e procurar referências `#[0-9]+`, `closes`, `fixes`, `refs`.
- Se **não** houver referência clara a issue: **BLOQUEIO** — instruir a atualizar descrição do MR com `Closes #<n>` ou equivalente aceite pelo GitLab.
- Opcional: `glab api projects/:id/merge_requests/<IID>/closes_issues` para lista explícita de issues de fecho.

### 3. CI / pipelines

```bash
glab ci list --ref "$HEAD_BRANCH"
glab ci trace <job-id>   # para job falho
```

**Obrigatório:** qualquer pipeline/job falho é **bloqueante**. Jobs **cancelados** frequentemente indicam falha anterior em modo fail-fast — identificar o job que falhou primeiro e os seus logs.

**REGRA CI CANCELLED:** Um job com status `cancelled` significa que **outro job no mesmo workflow FALHOU** — o runner cancelou os restantes. O agente **NUNCA** deve reexecutar pipelines canceladas cegamente. Deve:

1. Listar pipelines/jobs da branch: `glab ci list --ref "$HEAD_BRANCH"`
2. Encontrar o job que realmente **falhou** (não o cancelado)
3. Inspecionar os logs: `glab ci trace <job-id>`
4. Diagnosticar a causa raiz, corrigir o código na branch do MR, fazer push
5. Só então esperar pelo novo pipeline

### 4. Issues — fetch completo (body + comments + metadata + links)

Para **cada** issue referenciada / em closes_issues:

```bash
# 1. Body completo + metadata (labels, milestone, assignees, state, dates, web_url)
glab issue view <N> --output json

# 2. Todos os comentários/notas (decisões, feedback, mudanças de scope)
glab issue view <N> --comments

# 3. MRs já vinculados à issue (verificar trabalho prévio/paralelo)
glab api "projects/:id/issues/<N>/related_merge_requests" 2>/dev/null || true

# 4. Issues relacionadas (parent, blocker, linked — entender fronteiras de scope)
glab api "projects/:id/issues/<N>/links" 2>/dev/null || true
```

**Exceção `web/your-github-project` (GitHub):**

```bash
gh issue view <N> --json number,title,body,state,labels,milestone,assignees,url,comments
gh api "repos/{owner}/{repo}/issues/<N>/timeline" --jq '.[] | select(.event=="cross-referenced")' 2>/dev/null || true
```

**Campos obrigatórios a extrair e usar na review:**

| Campo | Uso na review |
|-------|---------------|
| `description` (body) | Extrair TODOS os requisitos (FR-XX, AC-XX), BDD, DoD, harness |
| `notes` / comments | Decisões posteriores ao body **sobrepõem** o body original |
| `labels` | Verificar prioridade, tipo, estágio Kanban, flags (`Blocked`, `needs-research`) |
| `milestone` | Confirmar que MR entrega no ciclo esperado |
| `assignees` | Identificar responsável para dúvidas |
| `state` | Verificar que a issue ainda está aberta |
| `related MRs` | Verificar se há outros MRs a fechar a mesma issue (conflito) |
| `linked issues` | Ler parent/child/blocker para entender fronteiras de scope e dependências |
| `source_plan` | Se existe no body, ler o ficheiro de plano para contexto completo |

**Leitura exaustiva obrigatória:**

- Ler o body **inteiro** — não resumir, não saltar secções. Extrair **todos** os requisitos numerados (FR-XX, AC-XX), cenários BDD/Gherkin, critérios de aceite, DoD, verification harness, QA package.
- Ler **todos** os comentários/notas cronologicamente — decisões posteriores ao body **sobrepõem** o body original (e.g. "mudámos de X para Y no comentário #5").
- Se a issue referencia **outras issues** (parent, blocker, related), abrir e ler para entender fronteiras de scope e dependências.
- Montar uma **lista numerada de critérios verificáveis** que será usada no passo 5 para mapear 1:1 contra o diff.
- Se a issue tem `source_plan`, ler o plano para contexto adicional.

**Proibido** aprovar baseado em leitura superficial do título/resumo da issue.

### 4a. Validar issue agent-ready

Quando a issue foi criada por fluxo `plan-to-issues`, validar presença de:

- fingerprint / plan path (quando aplicável)
- requisitos funcionais numerados e critérios testáveis
- verification harness com comandos reais
- QA package no body ou num comentário único
- skills obrigatórias declaradas
- para arquitetura/refactor: bloco de pattern com trade-offs

Se faltar QA/harness executável, **bloquear** ou pedir atualização da issue antes de aprovar.

### 4b. Discussões / notas no MR

```bash
glab mr view <IID> --comments
```

Pedidos de alteração não resolvidos em threads são **bloqueio**.

### 5. Diff completo e validação funcional

```bash
glab mr diff <IID>
```

- **Não** substituir por só lista de ficheiros: o veredito issue ↔ código baseia-se em **hunks**.
- Se o diff for enorme, particionar por paths relevantes à issue via fetch da branch do MR e `git diff origin/$TARGET_BRANCH...HEAD -- <path>`.
- Para cada issue: mapear **cada critério individual** da checklist (passo 4) → evidência concreta no diff (ficheiro, linhas, tipo de mudança). **Cada critério deve ter um veredicto explícito: ✅ implementado / ❌ ausente / ⚠️ parcial.**
- **Implementação parcial = BLOQUEIO** — a menos que o scope restante esteja explicitamente rastreado noutra issue aberta e referenciada.

#### 5a. Varredura de warnings, stubs e TODOs

No diff, procurar activamente:

```bash
# No diff ou na branch do MR
git diff origin/$TARGET_BRANCH...HEAD | grep -inE 'TODO|FIXME|HACK|XXX|STUB|UnsupportedOperationException|NotImplemented'
```

- **Warnings novos:** executar build/lint localmente ou verificar output do CI. Qualquer warning novo introduzido pelo MR é **BLOQUEIO**.
- **Stubs/TODOs:** cada ocorrência deve ser validada contra a política (referência a issue aberta + no mesmo milestone + não atingível em produção). Se não cumprir → **BLOQUEIO**.
- **`@Disabled` / `@Ignore` em testes:** só aceitável com justificativa documentada e issue de tracking. Caso contrário → **BLOQUEIO**.

#### 5b. Varredura de bypass, deprecated e gambiarras

No diff, procurar activamente:

```bash
git diff origin/$TARGET_BRANCH...HEAD | grep -inE '@SuppressWarnings|eslint-disable|@ts-ignore|@ts-expect-error|no-verify|skipTests|DskipTests|@Deprecated|Thread\.sleep|setTimeout.*solut|catch.*Exception.*\{\s*\}'
```

- **Bypass de validação/lint/build:** `@SuppressWarnings` sem justificativa, `eslint-disable` sem motivo real, `@ts-ignore`/`@ts-expect-error` sem issue, `--no-verify`, `-DskipTests` → **BLOQUEIO**.
- **APIs deprecated:** uso de métodos/classes/anotações marcados `@Deprecated` ou com aviso de deprecação nos docs → **BLOQUEIO** (deve usar a alternativa actual).
- **Gambiarras técnicas:** hardcoded values que deviam ser config, `Thread.sleep()`/`setTimeout()` como solução de timing, catch genérico que engole excepções (`catch (Exception e) {}`), casts inseguros, reflexão para contornar encapsulamento → **BLOQUEIO**.
- **Testes enfraquecidos:** se o diff mostra remoção de assertions, alargamento de matchers (`any()` onde antes era específico), substituição de integração real por mock, H2 em vez de Testcontainers/PostgreSQL → **BLOQUEIO**.

Se o MR toca **`web/**`** (frontends deste monorepo), aplicar checklist da skill `ux-review` nos ficheiros tocados — problemas de UX em scope são **bloqueantes**.

### 5b. Integridade após rebase

Após rebase com `target_branch`, confirmar que **nenhum comportamento existente no alvo foi perdido** nos paths tocados.

### 6. Revisão técnica

Conferir `AGENTS.md` e `.cursor/rules/` relevantes apenas para o escopo do MR.

### 6a. Smoke test obrigatório (rule `31-application-context-smoke-test.mdc`)

Se o MR toca **`apps/*`** (backend Java/Spring Boot):

1. **Verificar** que `ApplicationContextSmokeTest.java` existe no subprojeto com `@SpringBootTest` + Testcontainers. Um teste JUnit que instancia DTOs sem `@SpringBootTest` NÃO conta.
2. **Verificar no diff** se o MR introduziu testes integrados/E2E com `@SpringBootTest(classes = {...})`, `@ContextConfiguration(classes = ...)`, ou `@Import(...)` em `@SpringBootTest` para compor contexto parcial → **BLOQUEIO** (só permitido em slice tests como `@WebMvcTest`).
3. Se o smoke test não existe → **BLOQUEIO**. O MR deve incluir ou o agente deve criar.
4. Se o smoke test existe mas o contexto não inicia → **BLOQUEIO**. Corrigir a aplicação, não o teste.

### 6b. MCP de documentação (quando aplicável)

Para Spring Boot, React, Next.js, Flyway, MapStruct, etc.: usar **Context7** (`resolve-library-id` + `get-library-docs` / fluxo configurado no projeto) para validar uso de APIs contra documentação atualizada — não só training data.

### 7. Resposta estruturada

1. **MR:** IID, título, URL, `target` ← `source`, draft sim/não.
2. **Issues:** lista (`#n`); **OK / BLOQUEIO** (mínimo 1 referência clara).
3. **CI:** resumo por job/pipeline.
4. **Merge:** conflitos / estado mergeável (`merge_status` quando disponível via API/json).
5. **Checklist critério ↔ diff:** tabela completa com cada critério extraído da(s) issue(s), o veredicto (✅/❌/⚠️), e a evidência concreta (ficheiro:linha ou hunk). **Todos** os critérios devem aparecer — nenhum pode ser omitido.
6. **Warnings, stubs & bypass:** lista de warnings novos, TODOs/stubs encontrados, bypass/deprecated/gambiarras, e status de cada (corrigido / referencia issue #N / bloqueante).
7. **Riscos / dívidas**
8. **Veredito:** **Aprovado para merge** / **Bloqueado** com próximos passos.

**Zero tolerância:** não existe "aprovado com ressalvas". Qualquer uma destas condições = **BLOQUEADO**:
- CI vermelho (errors ou warnings novos)
- UX bloqueante em `web/**`
- Perda de código do alvo após rebase
- Critério da issue não implementado sem tracking noutra issue
- Stub/TODO sem issue referenciada e válida
- Warning novo introduzido pelo MR
- Teste `@Disabled`/`@Ignore` sem justificativa e issue de tracking
- Bypass de validação/lint/build (`@SuppressWarnings`, `eslint-disable`, `@ts-ignore`, `--no-verify`, `-DskipTests` sem justificativa)
- Uso de APIs/métodos deprecated (deve usar alternativa actual)
- Gambiarras técnicas (hardcoded, `Thread.sleep()` como solução, catch genérico vazio, casts inseguros)
- Testes enfraquecidos (assertions removidas, matchers alargados, integração real substituída por mock)
- **Smoke test ausente ou falho** em `apps/*` — `ApplicationContextSmokeTest` com `@SpringBootTest` + Testcontainers é obrigatório (rule 31)
- **Testes integrados/E2E com contexto parcial** — `@SpringBootTest(classes=...)`, `@Import(...)` em `@SpringBootTest`, `@ContextConfiguration(classes=...)` em testes que pretendem ser integração/E2E

---

## Comandos `glab` de referência rápida

| Objetivo | Comando |
|----------|---------|
| Ver MR | `glab mr view <IID> --output json` |
| Diff | `glab mr diff <IID>` |
| Discussões MR | `glab mr view <IID> --comments` |
| Issue (body + metadata) | `glab issue view <N> --output json` |
| Comentários issue | `glab issue view <N> --comments` |
| MRs vinculados à issue | `glab api "projects/:id/issues/<N>/related_merge_requests"` |
| Issues relacionadas | `glab api "projects/:id/issues/<N>/links"` |
| CI | `glab ci list --ref <branch>` |
| Logs job | `glab ci trace <job-id>` |
| Milestones | `glab api "groups/your-org/milestones?state=active"` |

---

## Relação com outras skills

| Skill / agente | Relação |
|----------------|---------|
| `posttask` | Após correções no worktree da branch do MR |
| `ci-watcher` | Aprofundar pipelines falhos |
| `code-reviewer` | Segunda opinião em arquitetura |

---

## Notas

- Dependabot/chore: política **≥1 issue** salvo exceção documentada pelo time.
- **`web/your-github-project`:** repetir este fluxo com `gh pr view`, `gh pr diff`, `gh issue view`, `gh run` conforme política GitHub.
