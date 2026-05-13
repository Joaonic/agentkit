---
name: implement-plan
description: Implementar um plano existente com execução obrigatória e sequencial por subagents.
disable-model-invocation: true
---

LEIA ESTA SKILL COMPLETAMENTE ANTES DE COMEÇAR

Implementar um plano existente. Não cria plano. Sempre numa worktree separada.

Fonte única:

- `docs/governance/cursor/workflow.md`
- `docs/governance/cursor/workflow/*.md`

Contrato operacional obrigatório desta skill:

1. Você é o agente pai e atua apenas como orquestrador.
2. Você não pode usar diretamente Read, Write, Edit, MultiEdit, Shell, Grep, Search, Browser, MCP, ferramentas de VCS remotas, Web, testes, ou qualquer outra tool fora da tool de subagent.
3. Todo acesso a ficheiros, comandos, GitLab/GitHub (tracker), MCP, web, testes e validações deve acontecer dentro de subagents.
4. A execução é obrigatoriamente sequencial. Uma etapa por vez.
5. Cada chamada de subagent deve definir explicitamente `subagent_type`.
6. Cada chamada de subagent deve incluir o marcador exato da etapa no `prompt` ou na `description`.
7. Não pular etapas obrigatórias.
8. Após `workflow:code-review`, cumprir sempre `workflow:ux-review`. Com alteração em fluxos ou superfície **user-facing** sob `web/**` (ou outro frontend definido no subprojeto), usar `ux-reviewer`. Sem alteração user-facing, usar `verifier` ou `docs` para registar **«UX Review: não aplicável (sem frontend)»** — **não** invocar `ux-reviewer` (rule `08-ux-mandatory.mdc`).
9. O `ux-reviewer` (e a etapa `workflow:ux-review`) não substituem `workflow:posttask`.
10. Antes de declarar concluído, cumprir a skill `posttask`, **MR** pareado (GitLab) ou **PR** (exceção GitHub), `review-open-pr` e CI verde conforme o workflow do projeto.

Política de zero tolerância (obrigatória em todas as etapas):

11. Não existe "aprovado com ressalvas" — qualquer problema encontrado em scope (código, testes, UX, docs, acessibilidade) é **BLOQUEANTE** e deve ser resolvido antes de avançar.
12. Se o `code-reviewer` ou `ux-reviewer` reportar problemas, o agente pai deve delegar correção ao subagent adequado e re-submeter para review até zero problemas restarem.
13. Problemas de UX em ficheiros tocados são bloqueantes quando há mudança user-facing em `web/**` (ou frontend do subprojeto em causa).

Uso obrigatório de MCP para pesquisa:

14. Subagents de `workflow:investigation`, `workflow:implementation` e `workflow:code-review` **devem** usar Context7 (servidor MCP configurado no projeto) para validar APIs/bibliotecas contra documentação actualizada (Spring Boot, React, Next.js, Flyway, MapStruct, etc.).
15. Quando existirem outros MCPs oficiais em `.cursor/mcp.json` para integrações em scope, usá-los em vez de suposições de treino.
16. Nunca depender apenas de training data para APIs/bibliotecas quando MCP aplicável estiver disponível.

Regras obrigatórias de CI (aplicar em todas as etapas que envolvam push/CI):

17. CI RED é **BLOQUEANTE** — nenhuma etapa avança com checks falhados. Corrigir antes de prosseguir.
18. CI CANCELLED == CI FAILED — pipeline fail-fast cancela jobs satélite. **Nunca** reexecutar pipelines sem corrigir causa raiz. Em GitLab: `glab ci list --ref <branch>`, depois `glab ci trace <job-id>` no job que falhou primeiro. Em GitHub Actions (ex.: `web/your-github-project`): `gh run view <id> --json jobs` e `gh run view <id> --log-failed`.
19. Bugs encontrados durante code-review ou posttask são **BLOQUEANTES** — o agente pai delega correção e re-submete até zero problemas.

Regras obrigatórias de rebase/merge (NUNCA perder código):

20. Ao fazer rebase ou merge de `main` na branch de trabalho, **NUNCA** perder conteúdo que já existia em `main`. O rebase serve para **incorporar** main — não para sobrescrever.
21. Durante resolução de conflitos, **ambos os lados** devem ser preservados: o código novo da feature **E** o código existente de main. Se houver conflito real (mesmo trecho modificado nos dois lados), o agente deve fundir manualmente, mantendo a semântica de ambos.
22. Após rebase, o agente **deve** verificar: `git diff origin/main..HEAD -- <ficheiros com conflito>` e confirmar que nenhuma funcionalidade, import, teste, config ou bloco de código de main desapareceu.
23. Se o agente detectar que perdeu código de main durante rebase, deve **imediatamente** corrigir (cherry-pick, re-apply, ou editar manualmente) antes de avançar para qualquer outra etapa.
24. Esta regra aplica-se a **todas** as etapas: investigation, implementation, code-review, posttask — sempre que houver rebase/merge de main.

Regras obrigatórias de integridade UTF-8 (BLOQUEIO):

25. Todo conteúdo escrito em ficheiros locais (planos, docs) ou publicado no tracker (GitLab issue/MR, GitHub PR/issue na exceção your-github-project) **deve** ser UTF-8 válido.
26. Para GitLab: escrever corpos longos em ficheiro temporário validado (`file --mime-encoding`) e aplicar com `glab issue update … --description "$(cat …)"` ou `glab api`. Para GitHub (`web/your-github-project`): usar `gh … --body-file`.
27. **Validar encoding** antes de publicar: `file --mime-encoding <ficheiro>` deve retornar `utf-8` ou `us-ascii`. Se não, reescrever antes de prosseguir.
28. **Heredocs:** usar `cat <<'EOF'` (quotes no delimitador) para evitar expansão de variáveis que introduza bytes inválidos.
29. **Títulos de issues/PRs:** limitar a ASCII puro (a-z, A-Z, 0-9, espaços, hífens, colchetes, parênteses). Acentos e caracteres especiais apenas no body.
30. **Detecção de corrupção:** se conteúdo lido de issue/ficheiro contiver mojibake (`â€"`, `Ã©`, `Ã£`, `ðŸ`), reportar ao usuário e não propagar.
31. Ao despachar subagentes, incluir no prompt: "Garantir integridade UTF-8 em todo conteúdo escrito; validar com file --mime-encoding antes de publicar no tracker."

Disciplina de implementação — zero débito técnico (BLOQUEIO):

32. **NUNCA fazer bypass** de mecanismos de segurança, validação, build ou qualidade para "fazer funcionar agora". Proibido: `--no-verify`, `-DskipTests` em commits/push finais, `@SuppressWarnings` sem justificativa documentada, `eslint-disable` sem motivo técnico real, `// @ts-ignore` ou `// @ts-expect-error` sem issue rastreada.
33. **NUNCA usar APIs, métodos, classes ou padrões deprecated.** Sempre usar a alternativa actual documentada. Quando uma dependência marcar algo como deprecated, investigar a substituição correcta (via MCP Context7 ou docs oficiais) e implementar com a API actual. Se a substituição não existir ainda, reportar ao utilizador — não usar o deprecated "por enquanto".
34. **NUNCA introduzir gambiarras ou workarounds temporários** sem issue de tracking. Proibido: hardcoded values que deviam ser config, `Thread.sleep()` / `setTimeout()` como solução de timing, catch genérico que engole excepções (`catch (Exception e) {}`), casts inseguros, reflexão para contornar encapsulamento, feature flags improvisados sem framework.
35. **NUNCA enfraquecer testes** para fazer passar. Proibido: remover assertions, alargar matchers (`any()` onde antes era específico), substituir integração real por mock só para evitar falha, adicionar `@Disabled` / `@Ignore` / `.skip()` sem issue, trocar Testcontainers/PostgreSQL por H2 ou in-memory.
36. **NUNCA introduzir warnings.** Compiler warnings, lint warnings, deprecation warnings introduzidos pelo código novo são **BLOQUEANTES**. Se o ficheiro tocado já tinha warnings pré-existentes, aplicar boy-scout rule e corrigi-los.
37. **Stubs e TODOs** só são aceites com issue aberta referenciada no comentário (`// TODO(#N): descrição`), no mesmo milestone ou seguinte, e em path não atingível em produção. Sem cumprir os 3 critérios: **BLOQUEIO**.
38. Ao despachar subagentes, incluir no prompt: "Zero débito técnico. Não usar APIs deprecated, não fazer bypass de validação/testes/lint, não enfraquecer testes, não introduzir warnings. Toda gambiarra requer issue de tracking."

Regras obrigatórias de push e MR/PR (economia de CI):

- **Proibido push incompleto** — cada push deve conter código compilável e com testes relevantes passando localmente. Não empurrar WIP para o remote.
- **Proibido abrir MR/PR draft sem necessidade** — MR só abre quando a implementação está pronta para review. Não usar MR como "backup" ou para ver o CI rodar antes de estar pronto.
- **Antes de push:** executar build local (`./mvnw verify -DskipITs` ou equivalente no stack) e testes unitários. Se falhar, corrigir antes de push.
- **Um push, um propósito:** evitar múltiplos force-push desnecessários que disparam pipelines repetidas.

Regras obrigatórias de merge sequencial (economia de CI — `41-merge-squash-skip-ci.mdc`):

- **Sempre squash merge** — nunca merge commit regular. O squash produz um commit limpo e semântico.
- **Reescrever a mensagem** — mensagem semântica descritiva (`tipo(#issue): descrição`), nunca a mensagem automática do GitLab/GitHub.
- **GitLab gera DOIS commits no squash merge** — o squash commit + um merge commit automático. **Ambos** disparam CI de forma independente. Usar **ambas as flags**: `--squash-message` e `--message` com a mesma mensagem (incluindo `[skip ci]` nos intermédios). Exemplo: `glab mr merge <IID> --squash --squash-message "feat(#42): desc [skip ci]" --message "feat(#42): desc [skip ci]" --yes`. No GitHub isto não é necessário (squash merge = commit único, basta `--subject`).
- **Merges sequenciais no mesmo repositório (2+):** adicionar `[skip ci]` em **todos os merges intermédios** (todos exceto o último). Só o último merge dispara o CI/CD completo com deploy.
- **Se o número de merges for incerto:** usar `[skip ci]` em todos e disparar CI no final com commit vazio: `git commit --allow-empty -m "ci: trigger deploy after batch merge" && git push origin main`.
- Ao despachar subagentes que façam merge, incluir no prompt: "Seguir rule 41-merge-squash-skip-ci: squash merge com mensagem semântica em AMBAS as flags (--squash-message e --message); em merges sequenciais no mesmo repo, usar [skip ci] em ambas as mensagens em todos exceto o último."

Leitura obrigatória de issues — fetch completo (BLOQUEIO):

Antes de qualquer etapa de implementação, o subagent de `workflow:investigation` **deve** consumir **todos** os campos relevantes de cada issue associada ao plano. Comentários contêm decisões de escopo, ajustes de critério de aceite, contexto técnico e feedback de priorizações que não estão no body original. Labels, milestone e assignees fornecem contexto de prioridade, ciclo de entrega e responsabilidade.

**Comandos obrigatórios (GitLab — default):**

```bash
# 1. Body completo + metadata (labels, milestone, assignees, state, dates, web_url)
glab issue view <N> --output json

# 2. Todos os comentários/notas (decisões, feedback, mudanças de scope)
glab issue view <N> --comments

# 3. MRs já vinculados à issue (evitar trabalho duplicado, entender estado)
glab api "projects/:id/issues/<N>/related_merge_requests" 2>/dev/null || true

# 4. Issues relacionadas (parent, blocker, linked)
glab api "projects/:id/issues/<N>/links" 2>/dev/null || true
```

**Exceção `web/your-github-project` (GitHub):**

```bash
# 1. Body + metadata completa
gh issue view <N> --json number,title,body,state,labels,milestone,assignees,url,comments

# 2. PRs vinculados (via timeline)
gh api "repos/{owner}/{repo}/issues/<N>/timeline" --jq '.[] | select(.event=="cross-referenced")' 2>/dev/null || true
```

**Campos obrigatórios a extrair e usar:**

| Campo | Uso |
|-------|-----|
| `description` (body) | Requisitos, AC, BDD, harness, escopo |
| `notes` / comments | Decisões posteriores ao body, mudanças de scope, feedback |
| `labels` | Prioridade, tipo, área, módulo, estágio Kanban, bloqueios |
| `milestone` | Ciclo de entrega, contexto temporal |
| `assignees` | Responsabilidade, contacto para dúvidas |
| `state` | Verificar se issue ainda está aberta |
| `related MRs` | Trabalho já feito, branches existentes, evitar duplicação |
| `linked issues` | Dependências, parent/child, blockers, contexto cruzado |
| `source_plan` | Path do plano fonte (se presente no body) — ler o plano |

**Não** considerar a issue lida se apenas o body foi consultado — comentários, labels, milestone e linked issues são obrigatórios.

### Labels Kanban (GitLab) — fluxo durante a implementação

Os subagents que toquem no tracker **devem** manter as issues alinhadas ao quadro Kanban do grupo, usando **exactamente** estes nomes de label (preservar outras labels da issue, ex.: `High Priority`, `New Feature`):

`To-Do` · `Awaiting Feedback` · `In Progress` · `Code Review` · `Testing` · `Done` · `Deployment` · `Acceptance Testing`

**Regra:** em cada transição, **remover** da issue a label de estágio Kanban que deixa de aplicar e **adicionar** a nova. Não acumular duas labels deste conjunto na mesma issue.

**Mapeamento sugerido (GitLab via `glab`):**

| Momento no workflow | Label Kanban |
|---------------------|--------------|
| Issue criada / ainda não há trabalho ativo | `To-Do` |
| Bloqueio por decisão ou input humano ausente | `Awaiting Feedback` |
| `workflow:tdd` e `workflow:implementation` (código em curso) | `In Progress` |
| `workflow:code-review` ou MR aberto aguardando revisão | `Code Review` |
| `workflow:posttask` / verificação automatizada e checks de qualidade antes do merge | `Testing` |
| Critérios atendidos e MR mergeado (ou entrega fechada sem MR) | `Done` |
| Após release/deploy a ambiente alvo (quando aplicável) | `Deployment` |
| Validação final com stakeholders / UAT | `Acceptance Testing` |

Exemplo (substituir `IID`, `-R` e labels conforme o caso; não remover labels de prioridade/tipo):

```bash
glab issue update <IID> -R "<group>/<project>" -u "To-Do" -l "In Progress"
glab issue update <IID> -R "<group>/<project>" -u "In Progress" -l "Code Review"
```

Regras obrigatórias de time tracking (BLOQUEIO):

39. **Registar timestamp de início** — ao iniciar `workflow:tdd` (primeiro código), o agente pai regista `implementation_started_at` em formato ISO 8601 UTC (ex.: `2025-07-12T14:30:00Z`). Este é o momento real de início do trabalho.
40. **Não abrir MR prematuramente** — o MR/PR só pode ser aberto quando o código estiver funcional, testes passarem localmente e a branch estiver pronta para review. Push incompletos ou MRs "draft" apenas para "reservar" são **proibidos** (desperdício de CI).
41. **Incluir timestamp no MR** — ao abrir o MR/PR, incluir na descrição (body) a seguinte secção:

```markdown
## Time Tracking

- **Implementation started:** <implementation_started_at ISO 8601>
- **MR opened:** <now ISO 8601>
- **Elapsed (pre-review):** <diferença humanizada, ex.: 2h 15m>
```

42. **Registar spent no tracker** — após merge, calcular tempo total (`implementation_started_at` → merge timestamp) e registar na issue como `/spend <tempo>` (GitLab) ou como comentário com tempo real (GitHub na exceção your-github-project).
43. Ao despachar subagentes, incluir no prompt: "Registar implementation_started_at (ISO 8601 UTC) no início de workflow:tdd. Incluir secção Time Tracking no body do MR com timestamps. Não abrir MR/push até código estar funcional e testes locais passarem."

Etapas obrigatórias desta skill:

1. `workflow:investigation`
   - Subagents permitidos: `arch`, `docs`, `backend`, `frontend`, `ai-orchestrator`, `project-manager`, `code-audit`, `docs-audit`

2. `workflow:tdd`
   - Subagents permitidos: `backend`, `frontend`, `ai-orchestrator`
   - **Obrigatório:** registar `implementation_started_at` (ISO 8601 UTC) antes de começar a escrever código.

3. `workflow:implementation`
   - Subagents permitidos: `backend`, `frontend`, `docs`, `arch`, `ai-orchestrator`, `project-manager`
   - **Obrigatório:** MR só abre quando código funcional + testes locais verdes. Incluir secção `## Time Tracking` no body do MR.

4. `workflow:code-review`
   - Subagent obrigatório: `code-reviewer`

5. `workflow:ux-review`
   - Com alteração user-facing em `web/**` (ou frontend do subprojeto): `ux-reviewer`
   - Sem alteração user-facing: `verifier` ou `docs` (registar N/A conforme rule `08-ux-mandatory.mdc`; **não** usar `ux-reviewer`)

6. `workflow:posttask`
   - Subagent obrigatório: `verifier`

7. `workflow:final-report`
   - Subagents permitidos: `docs`, `project-manager`, `verifier`

Entrada esperada:

- caminho do plano (ex.: `.cursor/plans/*.plan.md`, `docs/superpowers/plans/**`, ou path acordado no repo)

Fluxo obrigatório do agente pai:

1. Ler o pedido do usuário e identificar o caminho do plano.
2. Delegar `workflow:investigation` para o subagent adequado.
3. Aguardar a resposta do subagent e consolidar.
4. Delegar `workflow:tdd` para o subagent adequado.
5. Aguardar a resposta do subagent e consolidar.
6. Delegar `workflow:implementation` para o subagent adequado.
7. Aguardar a resposta do subagent e consolidar.
8. Delegar `workflow:code-review` para `code-reviewer`.
9. Delegar `workflow:ux-review`: com superfície user-facing em `web/**` (ou frontend do subprojeto) alterada, usar `ux-reviewer`; caso contrário, `verifier` ou `docs` com N/A explícito (sem `ux-reviewer`).
10. Delegar `workflow:posttask` para `verifier`.
11. Delegar `workflow:final-report` para `docs`, `project-manager` ou `verifier`.
12. Responder ao usuário com base apenas nas saídas dos subagents.

Exemplos de chamadas válidas:

- `subagent_type=backend` com prompt contendo `workflow:investigation`
- `subagent_type=backend` com prompt contendo `workflow:tdd`
- `subagent_type=frontend` com prompt contendo `workflow:implementation`
- `subagent_type=code-reviewer` com prompt contendo `workflow:code-review`
- `subagent_type=ux-reviewer` com prompt contendo `workflow:ux-review`
- `subagent_type=verifier` com prompt contendo `workflow:ux-review` (só quando não houve alteração user-facing em frontend, N/A)
- `subagent_type=verifier` com prompt contendo `workflow:posttask`
- `subagent_type=docs` com prompt contendo `workflow:final-report`

Antes de executar, carregue:

- o plano pedido
- `docs/governance/cursor/workflow.md`
- `docs/governance/cursor/workflow/00-overview.md`
- `docs/governance/cursor/workflow/01-planning.md`
- `docs/governance/cursor/workflow/02-implementation.md`
- `docs/governance/cursor/workflow/03-review.md`
- `docs/governance/cursor/workflow/05-validation.md`
- `docs/governance/cursor/workflow/07-final-report.md`
- `.cursor/rules/04-tdd-mandatory.mdc`
- `.cursor/skills/posttask/SKILL.md`
- `.cursor/skills/review-open-pr/SKILL.md`

Ao mudar o estado real de planos (`.cursor/plans`, `docs/superpowers/plans`, ou pastas equivalentes), cumprir o workflow de atualização e rastreio do repositório e das issues ligadas.
