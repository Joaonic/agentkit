---
name: docs-audit-sync
description: Use when auditing documentation, rules, skills, and agents for sync with implementation, duplication, staleness, contradictions, or obsolete content. Use when /docs-audit is invoked or when cleaning up docs, .cursor/rules, .cursor/skills, .cursor/agents.
---

# Auditoria de Documentação — Sincronia e Consistência

## Visão Geral

Esta skill guia o agente a auditar documentação e artefatos de configuração do repositório, verificando se estão **sincronizados com a implementação**, **livres de duplicação**, **atualizados** e **sem contradições**.

O foco é **limpar documentação inútil, velha ou contraditória**, especialmente em `docs/plans`, `docs/implementation`, `.cursor/rules`, `.cursor/skills` e `.cursor/agents`.

## Quando Usar

Use esta skill quando:

- O usuário pedir **auditoria de documentação**, **docs audit**, **limpeza de docs** ou **verificar se docs estão atualizados**.
- For necessário **comparar doc por doc com o que está implementado**.
- Suspeitar de **duplicação**, **contradições** ou **docs obsoletos**.
- Quiser **auditar rules, skills e agents** para consistência com o código e entre si.

Não use esta skill para:

- Auditoria de código (prefira `code-audit-architecture-consistency`).
- Criar documentação nova (prefira agent `docs`).

## Escopos Auditáveis

| Escopo     | Localização       | O que verificar                                                                             |
| ---------- | ----------------- | ------------------------------------------------------------------------------------------- |
| **docs**   | `docs/`           | implementation, plans, operations, reference — sync com código                              |
| **rules**  | `.cursor/rules/`  | referências corretas, sem contradição, sem regras obsoletas                                 |
| **skills** | `.cursor/skills/` | descrição vs uso real, referências quebradas, skills órfãs, atalhos duplicados ou obsoletos |
| **agents** | `.cursor/agents/` | referências corretas, agents órfãos ou redundantes                                          |

## Dimensões de Revisão

### 1. Sincronia com Implementação

Para cada doc relevante:

- **docs/implementation/** (quando existir nalgum subprojeto) — estado dos plans vs código implementado.
- **docs/plans/** ou **`docs/superpowers/plans/**`** vs `.cursor/plans/` — duplicação ou divergência?
- **docs/operations/setup/** — Setup docs refletem variáveis de ambiente e fluxos atuais?
- **docs/reference/** — ADRs, arquitetura e data-model estão alinhados ao código?

**Ação:** Comparar doc com código (grep, semantic search). Marcar como desatualizado quando houver divergência clara.

### 2. Duplicação

- **Conteúdo duplicado** — Mesma informação em vários docs; preferir referência a doc canônico.
- **docs/plans vs docs/implementation** — Planos podem estar em `docs/plans/`, `docs/implementation/*/` e `.cursor/plans/`. Identificar redundância.
- **Rules/skills** — Múltiplos artefatos cobrindo o mesmo conceito; consolidar ou referenciar fonte única.

### 3. Obsoleto / Sem Sentido

- **Docs de features já implementadas** em `not_implemented/` — mover para `implemented/` ou remover.
- **Planos superseded** — Design antigo substituído por outro; marcar ou arquivar.
- **Rules/skills** referenciando fluxos ou arquivos que não existem mais.
- **Referências quebradas** — Links para arquivos removidos ou renomeados.

### 4. Contradições

- **docs/plans** — Dois planos ou designs contradizendo-se (ex.: fluxo A vs fluxo B para o mesmo domínio).
- **Rules vs workflow** — Regra em `.cursor/rules/` contradizendo `docs/governance/cursor/workflow.md`.
- **Skills vs agents** — Skill dizendo "use agent X" mas agent não existe ou tem descrição divergente.
- **Skills vs workflow** — Skill referenciando processo diferente do workflow.

### 5. Consistência de Referências

- **Fonte única** — `docs/governance/cursor/workflow.md` é a fonte para TDD, post-task, agents e atalhos em `.cursor/skills/`. Rules, skills e agents devem **referenciar** esse doc, não duplicar.
- **Cross-references** — Verificar se `@rule-name.mdc`, links entre docs, e menções a skills/agents estão corretas.

## Workflow de Auditoria

1. **Definir escopo** — docs apenas, ou docs + rules + skills + agents.
2. **Dividir em blocos** — Por tipo (docs, rules, skills, agents) ou por área (implementation, plans, operations).
3. **Para cada bloco:**
   - Listar artefatos.
   - Aplicar dimensões (sincronia, duplicação, obsoleto, contradições, referências).
   - Produzir achados estruturados.
4. **Priorizar achados:**
   - 🔴 Crítico — contradição, doc desatualizado que induz erro, referência quebrada em artefato central.
   - 🟡 Importante — duplicação significativa, obsoleto que confunde, regra/skill sem uso.
   - 🟢 Sugestão — consolidação, melhoria de referências, arquivamento de docs antigos.

## Formato de Saída Recomendado

```markdown
### Visão geral

- **Escopo auditado**: [docs, rules, skills, agents]
- **Resumo**: [2–4 frases sobre estado geral, principais riscos]

### Achados 🔴 Críticos

- **[Título curto]**
  - **Artefato**: [caminho do arquivo]
  - **Problema**: [contradição, desatualização grave, referência quebrada]
  - **Evidência**: [onde está a divergência]
  - **Ação sugerida**: [atualizar, remover, consolidar]

### Achados 🟡 Importantes

- **[Título curto]**
  - **Artefato**: [...]
  - **Problema**: [duplicação, obsoleto]
  - **Ação sugerida**: [...]

### Achados 🟢 Sugestões

- **[Título curto]**
  - **Artefato**: [...]
  - **Benefício**: [consolidação, clareza]
  - **Ação sugerida**: [...]
```

## Execução em Paralelo

Quando o escopo for grande, dividir em blocos independentes e disparar subagentes em paralelo (um por bloco):

- Bloco 1: `docs/implementation/` + `docs/plans/`
- Bloco 2: `docs/operations/` + `docs/reference/`
- Bloco 3: `.cursor/rules/`
- Bloco 4: `.cursor/skills/` + `.cursor/agents/`

Cada subagente aplica esta skill ao seu bloco e devolve achados estruturados. A main thread consolida, remove duplicatas e prioriza.

## Relatório persistente (opcional)

Use quando o usuário pedir **arquivo** além do relatório na conversa (o padrão é só conversa).

- **Path sugerido (opcional):** `docs/superpowers/reports/YYYY-MM-DD-docs-audit-<slug>.md` ou path acordado com o utilizador — relatório é **estado para acção**, não evidência de feature já shipada em produção.
- **Alternativa:** issue GitLab com o relatório quando pedido explícito em formato tracker-first.
- **Conteúdo mínimo:** resumo do escopo auditado; achados 🔴/🟡/🟢; recomendações de próximos passos — alinhado ao **Formato de Saída Recomendado** desta skill.
- **Execução:** delegar criação/edição ao agent `docs`. Se o usuário indicar outro path ou nome, seguir o pedido explícito.

## Erros Comuns a Evitar

- **Não deletar docs sem confirmar** — Propor remoção/arquivamento; o usuário decide.
- **Não inventar problemas** — Só marcar como desatualizado quando houver evidência concreta (código vs doc).
- **Respeitar escopo estrito** — Limitar-se à auditoria; mudanças em massa vão para sugestões/planos de remediação.
