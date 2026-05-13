---
name: prioritize-github-roadmap
description: Priorização técnica real do backlog (GitHub + código em main + dependências + ordem de execução)
disable-model-invocation: true
---

# /prioritize-github-roadmap

Prioriza backlog técnico com evidência de código real em `main`, cruzando **issues + PRs + labels + milestones + relações + estado real no código**.

Não aceitar análise superficial por título de issue.  
Fonte de verdade: **código em `main`**. Issues/docs são contexto, não prova de entrega.

## Quando usar

- Priorizar backlog inteiro.
- Priorizar um épico, milestone ou cluster de labels.
- Priorizar apenas issues abertas.
- Avaliar impacto de uma issue nova no roadmap.
- Revisar o que pode rodar em paralelo na sprint.
- Identificar blockers reais antes de implementar.

## Escopo de entrada (exemplos)

- `/prioritize-github-roadmap`
- `/prioritize-github-roadmap milestone:"MVP 12"`
- `/prioritize-github-roadmap epic:#412`
- `/prioritize-github-roadmap open-only`
- `/prioritize-github-roadmap impact:#587`
- `/prioritize-github-roadmap sprint-parallel labels:backend,analytics`

Se o escopo vier ambíguo, o agente deve pedir recorte mínimo (repo atual, período, epic/milestone/labels), **sem pular validação em código**.

## Regras mandatórias de decisão (ordem fixa)

1. Bugs de modelagem/lifecycle que contaminam outras features vêm antes de features dependentes.
2. Código em `main` vale mais que docs e checkbox de issue.
3. Issue com PR aberto não conta como entregue em `main`.
4. Issue fechada só conta como entregue se o código correspondente estiver mergeado e coerente com o escopo.
5. Se analytics depende de sessão/modelagem correta, modelagem vem antes de analytics.
6. Se automação depende de conceito confiável de conversa ativa/reaberta, lifecycle vem antes de automação.
7. Se algo pode gerar retrabalho em várias issues, sobe prioridade.
8. Se algo é paralelizável sem conflito de modelagem/schema/ownership, marcar explicitamente.
9. Se houver lacuna sem ticket, propor issue nova completa.
10. Não assumir labels/milestones corretos quando o código mostrar o contrário.

## Fluxo obrigatório (não pular etapas)

### 0) Descobrir convenções locais

- Ler `AGENTS.md`.
- Ler `docs/governance/cursor/workflow.md` e `docs/governance/cursor/workflow/00-investigation.md`.
- Ler skills relacionadas se necessário (`.cursor/skills/review-open-pr/SKILL.md`, `.cursor/skills/implement-plan/SKILL.md`).

### 1) Levantar backlog no GitHub (fatos)

Preferir `gh` CLI. Coletar **abertas e fechadas relevantes** ao escopo:

```bash
gh issue list --state open --limit 200 --json number,title,state,labels,milestone,createdAt,updatedAt,closedAt,assignees,url
gh issue list --state closed --limit 200 --json number,title,state,labels,milestone,createdAt,updatedAt,closedAt,assignees,url
gh pr list --state open --limit 200 --json number,title,state,isDraft,labels,milestone,createdAt,updatedAt,mergedAt,closedAt,headRefName,baseRefName,url
gh pr list --state merged --limit 200 --json number,title,state,labels,milestone,createdAt,updatedAt,mergedAt,closedAt,headRefName,baseRefName,url
gh label list
gh api repos/{owner}/{repo}/milestones?state=all
```

Para cada issue candidata, levantar relações explícitas:

- `parent/epic`
- `depends on`
- `blocks`
- `related to`
- links para PR

Use `gh issue view <N> --json ...` e `gh api` de timeline/eventos quando necessário para dependências não triviais.

### 2) Cruzar com PRs e estado real de merge

Para cada issue relevante:

- identificar PRs vinculados (abertos/fechados/mergeados);
- confirmar se houve merge em `main` (`baseRefName=main` ou equivalente trunk);
- issue fechada com PR não-mergeado em `main` = **suspeita de falso concluído**.

### 3) Validar no código em `main` (verdade técnica)

Obrigatório verificar no código:

- funcionalidade existe por completo, parcial ou não existe;
- há bug de modelagem/lifecycle que bloqueia outras issues;
- item “semanticamente pronto” mas tecnicamente incompleto;
- risco de retrabalho estrutural (schema, estado de conversa, sessão, contratos).

Técnica mínima:

- buscar símbolos/fluxos com `rg`;
- ler arquivos relevantes;
- confirmar caminho executável real (entrada -> domínio/use case -> adapter/persistência/saída);
- não concluir por nomes de arquivo/título de PR.

### 4) Consultar docs apenas quando necessário

- Usar docs para contexto/intent.
- Se docs divergirem de `main`, registrar inconsistência e priorizar código.

### 5) Classificar backlog

Cada item deve cair em uma classe:

- fazer agora
- fazer depois
- bloqueado
- paralelizável
- precisa issue nova
- precisa corrigir issue existente

### 6) Produzir matriz final + sequência

A resposta final deve conter **obrigatoriamente** uma matriz com estas colunas:

- Item
- Tipo
- Status real
- Prioridade recomendada
- Pode começar agora?
- Bloqueadores
- Depende de
- Pode rodar em paralelo com
- Risco de retrabalho
- Justificativa técnica
- Evidências
- Próxima ação recomendada

Depois da matriz, incluir obrigatoriamente:

1. **Top 3 para atacar agora**
2. **Itens bloqueados e por quê**
3. **Itens que podem rodar em paralelo**
4. **Inconsistências entre issue/PR/docs/código**
5. **Issues novas que precisam ser abertas**
6. **Issues existentes que precisam ser editadas**
7. **Sequência recomendada de execução**

## Critérios de qualidade da análise

- Não usar “parece” sem evidência técnica.
- Cada conclusão deve citar evidência (`issue/pr`, arquivo/símbolo no código, e quando aplicável commit/merge).
- Marcar explicitamente “entregue em main”, “parcial em main” ou “não entregue em main”.
- Identificar dependências implícitas de modelagem/sessão/lifecycle (mesmo sem label).

## Formato recomendado de evidências

- GitHub: `#123`, `PR #456`, milestone, label, timestamps.
- Código: caminhos e símbolos (ex.: `apps/api/src/...`, `ProcessInboundWebhookUseCase`).
- Divergência: “Issue diz X, código em `main` implementa Y”.

## Tratamento de inconsistências

Quando houver contradição, o agente deve:

1. apontar a inconsistência;
2. classificar impacto (baixo/médio/alto retrabalho);
3. propor correção objetiva (editar issue, reabrir issue, abrir bug de modelagem, ajustar dependências no GitHub).

## Entregável mínimo aceitável

Análise sem validação de código em `main` é inválida.

## Integridade UTF-8 ao propor/criar issues

Quando esta skill resultar na criação ou edição de issues (passo 5 do output — "Issues novas que precisam ser abertas"), aplicar:

- **Nunca `--body` inline** para conteúdo longo. Usar `--body-file` com ficheiro temporário.
- **Validar encoding:** `file --mime-encoding <ficheiro>` deve retornar `utf-8` ou `us-ascii`.
- **Títulos:** apenas ASCII seguro (sem acentos). Acentos e caracteres especiais apenas no body.
- **Heredocs:** `cat <<'EOF'` (quotes) para evitar bytes inválidos.

Se o agente não conseguir acesso a GitHub ou ao código:

- declarar bloqueio operacional;
- listar o que faltou;
- não inventar priorização.

## Exemplo de uso no Cursor

```text
/prioritize-github-roadmap milestone:"MVP 13" open-only
```

```text
/prioritize-github-roadmap impact:#742
```

```text
/prioritize-github-roadmap sprint-parallel labels:lifecycle,analytics
```
