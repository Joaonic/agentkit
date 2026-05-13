---
name: create-milestone
description: Cria documento de milestone e vários planos em paralelo para features complexas com várias frentes; mapeia agents/skills em `.cursor/skills/` por plano e maximiza paralelização segura.
---

# Create Milestone

## Visão geral

Use esta skill para **features complexas com muitas frentes** (backend, frontend, shared, docs, integrações). O agente cria:

1. **Um documento de milestone** — objetivo, valor de negócio, tabela de planos com status, dependências, mapeamento de agents/skills em `.cursor/skills/` por plano. Path sugerido: `docs/superpowers/plans/<slug-da-milestone>/README.md` (ou estrutura equivalente acordada — não assumir `docs/milestones/` se não existir).
2. **Vários planos** — normalmente `.cursor/plans/*.plan.md` ou `docs/superpowers/plans/**/*.plan.md`, conforme convenção do repo — um subagente por plano, em paralelo, cada um seguindo **`superpowers:writing-plans`** / **`new-plan`** como contrato local.

**Ideia central:** uma milestone = visão unificada + N planos paralelizáveis. Cada plano é independente (arquivos diferentes) e mapeado a agentes, skills e atalhos em `.cursor/skills/` conforme domínio.

## Pré-requisitos

- Feature ou tema complexo com 2+ frentes (ex.: rate limiting = API + frontend config + docs).
- Lista de planos ou tópicos (derivada do usuário ou de code-audit/achados).
- Comando **`superpowers:writing-plans`** (superpower) ou skill `new-plan` como contrato por subagente.
- Ferramenta **`Task`** para despachar subagentes em paralelo (Cursor).
- Leitura de: `docs/governance/cursor/workflow.md`, `docs/governance/cursor/workflow/08-skills-by-context.md`, `AGENTS.md`.

## Quando usar

- Pedido explícito para criar milestone + planos com tema ou lista de tópicos.
- Feature complexa com backend + frontend + shared + docs.
- Após code-audit: criar milestone de remediação (ex.: M2-code-quality) com vários planos.
- Qualquer contexto em que existam 2+ planos e se queira visão unificada + paralelização máxima.

## Quando NÃO usar

- Criar **um** único plano → usar **`superpowers:writing-plans`** ou `new-plan` diretamente.
- Feature simples, uma frente só → usar skill `new-plan` ou **`superpowers:writing-plans`**.
- Lista de planos ainda não definida → alinhar com o usuário os nomes/tópicos antes.

## Uso (invocação)

- Pedido por tema (ex.: `rate-limiting`) — o agente deriva planos (API, frontend, runbook) e cria milestone + planos.
- Lista de frentes (ex.: `backend frontend docs`) — o agente deriva nomes e especificação.
- Sem argumentos — pergunta o tema ou usa o contexto da conversa (ex.: achados de code-audit).

## Relação com outras skills de plano

| Skill / fluxo                                               | Escopo                                |
| ----------------------------------------------------------- | ------------------------------------- |
| `new-plan` (`.cursor/skills/new-plan/SKILL.md`)             | Template e um plano                   |
| `superpowers:writing-plans`                                  | Um único plano (superpower)           |
| **create-milestone** (esta skill)                           | Milestone + vários planos em paralelo |
| `implement-plan` (`.cursor/skills/implement-plan/SKILL.md`) | Executar plano já escrito             |

## Processo

### 0. Análise do código existente (evitar reinventar)

Antes de definir planos, explore o codebase para identificar o que **já existe** e pode ser reutilizado como base para a feature. Isso evita planejar do zero quando há código utilizável.

1. **Buscar por padrões e código relacionado:**
   - Use `codebase_search` / `grep` para: nomes de domínio, use cases, adapters, componentes ou docs que tangenciem o tema (ex.: rate limiting → buscar "rate", "throttle", "limit"; RAG → "knowledge", "search", "embed").
   - Consulte `docs/superpowers/plans/**`, `.cursor/plans/**`, `docs/superpowers/specs/**` por trabalhos relacionados já escritos.
   - Verifique `libraries/**`, `apps/**`, `web/**` por módulos reutilizáveis.

2. **Buscar planos e iniciativas complementares:**
   - Índices em `docs/superpowers/plans/**`.
   - Avaliar: a nova milestone **estende** uma existente? Deve **referenciar** planos já criados? Evita **duplicar** planos?

3. **Documentar achados:**
   - Listar arquivos, módulos ou padrões que podem ser **estendidos** (não reimplementados).
   - Listar **planos e milestones complementares** — referenciar na nova milestone; evitar duplicação.
   - Indicar dependências ou integrações existentes que a feature deve respeitar.
   - Incluir essa informação na especificação de cada plano e na milestone (seções "Base existente", "Planos/milestones complementares").

4. **Propagar para os planos e milestone:**
   - Na especificação enviada a cada subagente, incluir: "Código existente relevante: [paths ou descrição] — considerar extensão/reuso em vez de implementação do zero." E, se houver: "Planos/milestones complementares: [links] — evitar duplicação; referenciar ou estender."
   - Na milestone, adicionar seções "Base existente" e "Planos/milestones complementares" com links para código, planos e milestones relacionados.

### 1. Descoberta e inventário

1. Anuncie: "Estou usando a skill `create-milestone` para criar uma milestone e vários planos em paralelo."
2. Leia:
   - `docs/governance/cursor/workflow.md` e `workflow/08-skills-by-context.md`
   - `AGENTS.md` (agents, skills estendidas, gates)
   - Rule `08-ux-mandatory.mdc` — UX obrigatório quando há superfície user-facing
3. Obtenha ou derive a lista de planos:
   - Se o usuário passou tópicos (ex.: `rate-limiting frontend-config runbook`), derive nomes em kebab-case.
   - Se vier de code-audit, use achados priorizados.
   - Para cada plano: nome do arquivo, domínio (`general`, `ai-automation`, `security`, `ux-ui`, etc.), frente principal (backend, frontend, shared, docs).
   - **Sempre considerar UX:** Se plano toca interfaces/componentes/fluxos de usuário, incluir tasks de UX review e validação.

### 2. Mapear agents, skills e atalhos (`.cursor/skills/`) por plano

Para **cada** plano, preencha uma linha na tabela da milestone:

| Plano | Frente | Agent | Skills / fluxos | Atalhos `.cursor/skills/` |
| ----- | ------ | ----- | --------------- | --------------------------- |
| exemplo-backend | backend | backend | hexagonal Java/Spring, Flyway/Testcontainers | `new-use-case`, `new-api-resource`, `new-adapter`, `db-migrate`, `tdd-workflow`, `posttask` |
| exemplo-frontend | frontend | frontend | React/Next.js (subprojeto), UX | `new-feature`, `new-widget`, `new-ui-component`, `frontend-design`, **`ux-review`**, `posttask` |
| exemplo-docs | docs | docs | governança / ADRs | `docs-audit-sync`, `new-adr` |

**Regras de mapeamento (YourProject):**

- **Backend Java** (`apps/<serviço>/**`, packages hexagonais, Flyway em `src/main/resources/db/migration`): agent `backend`; rever rules `10-java-hexagonal.mdc`, `12-springboot-layering.mdc`, `15-database-flyway-testcontainers.mdc`, `18-tenant-isolation.mdc`.
- **Libraries Java** (`libraries/**`): agent `backend` ou `arch` conforme natureza; skills `gen-api` quando contratos OpenAPI forem tocados.
- **Frontend** (`web/**`, salvo políticas locais do subprojeto): agent `frontend`; rules `20-web-nextjs.mdc`, `21-web-react.mdc`; obrigar **`ux-review`** quando há UI/copy/fluxo.
- **IA / orquestração**: agent `ai-orchestrator`; seguir skills listadas em `AGENTS.md` quando LLMs estiverem em scope.
- **Docs / governança**: agent `docs`; usar `docs-audit-sync` quando alterar normativo.
- **Arquitetura / grande refactor**: agent `arch`; skill `code-audit-architecture-consistency` + `new-adr` quando aplicável.

Integrações de terceiros devem usar **MCPs realmente configurados** em `.cursor/mcp.json` — não presumir Shopify/WhatsApp/Stripe salvo estarem listados.

Inclua esse mapeamento na milestone e, quando possível, na especificação de cada plano (para o subagente saber o que invocar).

### 3. Criar o documento de milestone

Crie **`docs/superpowers/plans/<slug-da-milestone>/README.md`** (ou nome equivalente acordado). Mantenha um índice navegável se já existir hierarquia em `docs/superpowers/plans/`.

**Estrutura obrigatória:**

```markdown
# MX — [Título da Milestone]

> **Objetivo:** [Uma frase]

## Valor de negócio

| Entrega | Vantagem |
| ------- | -------- |
| ...     | ...      |

Ver [business-value.md](./business-value.md) (se aplicável).

## Planos (ordem de execução / paralelização)

### Base existente (código reutilizável)

- [Arquivos, módulos ou docs que servem de base — resultado do passo 0]

### Planos e iniciativas complementares

- [Outros planos em `docs/superpowers/plans/**` ou `.cursor/plans/**`; evitar duplicação]

### Tabela de planos

| Plano | Arquivo | Frente                | Agent                 | Status   | Prioridade       |
| ----- | ------- | --------------------- | --------------------- | -------- | ---------------- |
| ...   | ...     | backend/frontend/docs | backend/frontend/docs | Pendente | Alta/Média/Baixa |

### Dependências

- [Lista de dependências entre planos ou com outras milestones]

### Paralelização sugerida

- **Grupo 1 (paralelo):** planos A, B, C — sem dependências entre si
- **Grupo 2 (após Grupo 1):** plano D — depende de A

## Referências

- [docs/governance/cursor/workflow.md](../governance/cursor/workflow.md)
- [AGENTS.md](../../AGENTS.md)
```

### 4. Despachar um subagente por plano

Para **cada** plano da lista:

1. Invoque a ferramenta **`Task`** com:
   - **subagent_type:** `backend` | `frontend` | `docs` | `generalPurpose` conforme frente.
   - **description:** "Escrever plano &lt;nome&gt;".
   - **prompt:** instruções para executar **`superpowers:writing-plans`** (superpower) ou seguir `.cursor/skills/new-plan/SKILL.md`:
     - Nome do plano.
     - Especificação (objetivo, tasks, doc de origem).
     - **Mapeamento:** agent X, skills Y (da tabela do passo 2).
     - **Base existente (se houver)** identificada no passo 0.
     - Instrução: "Criar o ficheiro em `.cursor/plans/<nome>.plan.md` ou `docs/superpowers/plans/<slug>/<nome>.plan.md` conforme convenção vigente. Incluir Objetivo, Critérios de Aceitação, Passos, Validação/Post-Task. **Se tocar UI/fluxos de utilizador, incluir UX review obrigatória.** Ao terminar, responder com caminho do ficheiro + resumo numa linha."

2. Dispare **todos** os subagentes em paralelo (múltiplas chamadas a `mcp_task` na mesma rodada).

### 5. Aguardar e consolidar

1. Aguarde todos os subagentes retornarem.
2. Atualize o documento de milestone com os caminhos reais dos planos criados.
3. Se algum subagente falhar, reportar qual plano ficou pendente e sugerir repetir apenas esse.

### 5b. Issue sync sequencial (obrigatório)

Após consolidar planos, executar `plan-to-issues` sequencialmente:

1. Criar ou atualizar o **epic tracker** primeiro.
2. Aguardar conclusão.
3. Criar ou atualizar **uma sub-issue por vez**, em ordem.
4. Usar `Parent (epic)` com URL ou `#number`.
5. Nunca criar sub-issues em paralelo neste fluxo.
6. Incluir fingerprint em cada issue.
7. Atualizar milestone doc com URLs das issues criadas.

### 6. Resposta na conversa

Listar na conversa:

- **Milestone criada:** caminho do arquivo.
- **Planos criados:** caminho + resumo por plano.
- **Paralelização:** grupos que podem ser implementados em paralelo (conforme `executing-plans-parallel`).
- **Próximos passos:** usar skill `implement-plan` com o caminho de cada plano; garantir **worktree + issue GitLab (`glab`) + MR** por frente (excepção **your-github-project**: GitHub). Para grupos independentes na execução, usar `executing-plans-parallel`. Por task, quando aplicável, **`superpowers:subagent-driven-development`** dentro da mesma worktree. **Labels Kanban** nas issues: ver `.cursor/skills/implement-plan/SKILL.md` (secção *Labels Kanban*).

## Exemplo de prompt por subagente

> Você é um subagente que deve seguir **`superpowers:writing-plans`** (superpower) **ou** `.cursor/skills/new-plan/SKILL.md` para um único plano.
>
> 1. Contrato: `writing-plans` / `new-plan`.
> 2. Nome do plano: `SECURITY-002-rate-limiting-api`.
> 3. Domínio: `security`. Frente: backend.
> 4. Agent: `backend`. Skills/rules: hexagonal Spring Boot, Flyway, tenant isolation. Atalhos: `new-use-case`, `new-api-resource`, `posttask`.
> 5. Base existente: [paths ou "nenhum identificado"] — priorizar extensão/reuso.
> 6. Especificação: [objetivo e tasks ou link para doc].
> 7. Ficheiro: `.cursor/plans/…` ou `docs/superpowers/plans/…`. Secções: Objetivo, Critérios, Passos, Validação/Post-Task; incluir "Código reutilizável" quando houver base.
> 8. Ao concluir: (a) caminho do ficheiro; (b) resumo numa linha.

## Lembretes

- Cada subagente escreve **um** arquivo; não há conflito entre subagentes.
- Nomes de plano devem ser únicos.
- A milestone é o **índice**; os planos são os artefatos executáveis.
- Sempre verificar planos e milestones existentes (passo 0) — referenciar ou estender em vez de duplicar.
- `executing-plans-parallel` pode ser usada na **implementação** quando os planos tiverem grupos independentes.
- Actualizar o índice da milestone (`README.md` no dossier criado) quando novos planos forem adicionados — não assumir `docs/milestones/README.md` salvo existir.

## Integridade UTF-8 (obrigatório — BLOQUEIO)

Toda escrita — milestone, planos e issues no tracker — deve ser UTF-8 válida.

### Regras

1. **Ficheiros locais:** garantir UTF-8 sem BOM; shell em locale UTF-8.
2. **GitLab:** preparar corpo em ficheiro temporário; validar com `file --mime-encoding`; usar `glab issue create/update` ou API para evitar corrupção no terminal.
3. **GitHub (`web/your-github-project`):** usar `gh … --body-file` para textos longos.
4. **Heredocs:** `cat <<'EOF'` quando aplicável.
5. **Títulos curtos:** ASCII seguro quando possível; detalhe no body.
6. **Detecção de corrupção (mojibake):** não propagar; pedir correção ao utilizador.
7. Reforçar nos prompts aos subagentes: validar encoding antes de commit/publicação.
