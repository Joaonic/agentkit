---
name: prioritize-gitlab-roadmap
description: Priorização técnica real do backlog (GitLab + código em main + dependências + ordem de execução). Proíbe análise superficial só pelo título da issue.
disable-model-invocation: true
---

# prioritize-gitlab-roadmap

Prioriza backlog técnico com evidência de código real em `main`, cruzando **issues + MRs + labels + milestones + relações + estado real no código**.

Não aceitar análise superficial por título de issue.  
Fonte de verdade: **código em `main`**. Issues e docs são contexto, não prova de entrega.

## Quando usar

- Priorizar backlog inteiro.
- Priorizar um épico, milestone ou cluster de labels.
- Priorizar apenas issues abertas.
- Avaliar impacto de uma issue nova no roadmap.
- Revisar o que pode rodar em paralelo na sprint.
- Identificar blockers reais antes de implementar.

## Escopo de entrada (exemplos)

Convenção de invocação (sem notação slash):

- `prioritize-gitlab-roadmap`
- `prioritize-gitlab-roadmap milestone:"v2.1"`
- `prioritize-gitlab-roadmap epic:#412`
- `prioritize-gitlab-roadmap open-only`
- `prioritize-gitlab-roadmap impact:#587`
- `prioritize-gitlab-roadmap sprint-parallel labels:backend,analytics`

Se o escopo vier ambíguo, o agente deve pedir recorte mínimo (projeto GitLab atual, período, épico/milestone/labels), **sem pular validação em código**.

## Regras mandatórias de decisão (ordem fixa)

1. Bugs de modelagem/lifecycle que contaminam outras features vêm antes de features dependentes.
2. Código em `main` vale mais que docs e checkbox de issue.
3. Issue com MR aberto não conta como entregue em `main`.
4. Issue fechada só conta como entregue se o código correspondente estiver mergeado e coerente com o escopo.
5. Se analytics ou relatórios dependem de sessão/modelagem correta, modelagem vem antes.
6. Se automação depende de conceito confiável de estado/lifecycle, lifecycle vem antes de automação.
7. Se algo pode gerar retrabalho em várias issues, sobe prioridade.
8. Se algo é paralelizável sem conflito de modelagem/schema/ownership, marcar explicitamente.
9. Se houver lacuna sem ticket, propor issue nova completa.
10. Não assumir labels/milestones corretos quando o código mostrar o contrário.

## Fluxo obrigatório (não pular etapas)

### 0) Descobrir convenções locais

- Ler `AGENTS.md`.
- Ler `docs/governance/cursor/workflow.md` e `docs/governance/cursor/workflow/00-overview.md`.
- Ler skills relacionadas se necessário (`.cursor/skills/review-open-pr/SKILL.md`, `.cursor/skills/implement-plan/SKILL.md`).

### 1) Levantar backlog no GitLab (fatos)

Preferir `glab` CLI no projeto configurado (raiz do repo ou `GITLAB_PROJECT_ID` / remote). Coletar **abertas e fechadas relevantes** ao escopo:

```bash
glab issue list --state opened --per-page 100 --output json
glab issue list --state closed --per-page 100 --output json
glab mr list --state opened --per-page 100 --output json
glab mr list --state merged --per-page 100 --output json
glab label list
glab milestone list
```

Para cada issue candidata, levantar relações explícitas:

- épico/parent
- `depends on` / `blocks` / `related` (labels ou texto)
- MRs referenciados no corpo ou threads

Usar `glab issue view <N> --output json`, `glab issue view <N> --comments`, e `glab api` quando precisar de relacionamentos ou timeline não triviais.

### 2) Cruzar com MRs e estado real de merge

Para cada issue relevante:

- identificar MRs vinculados (referências no texto, branches, ou API GitLab);
- confirmar merge na branch trunk (`main` ou default do projeto);
- issue fechada com código não mergeado na trunk = **suspeita de falso concluído**.

### 3) Validar no código em `main` (verdade técnica)

Obrigatório verificar no código:

- funcionalidade existe por completo, parcial ou não existe;
- há bug de modelagem/lifecycle que bloqueia outras issues;
- item “semanticamente pronto” mas tecnicamente incompleto;
- risco de retrabalho estrutural (schema Flyway, contratos HTTP, multi-tenant).

Técnica mínima:

- buscar símbolos/fluxos com `rg`;
- ler arquivos relevantes;
- confirmar caminho executável real (entrada → domínio/use case → adapter/persistência/saída);
- não concluir por nomes de arquivo ou título de MR.

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
4. **Inconsistências entre issue/MR/docs/código**
5. **Issues novas que precisam ser abertas**
6. **Issues existentes que precisam ser editadas**
7. **Sequência recomendada de execução**

## Critérios de qualidade da análise

- Não usar “parece” sem evidência técnica.
- Cada conclusão deve citar evidência (`issue/MR`, arquivo/símbolo no código, e quando aplicável commit/merge).
- Marcar explicitamente “entregue em main”, “parcial em main” ou “não entregue em main”.
- Identificar dependências implícitas de modelagem/sessão/lifecycle (mesmo sem label).

## Formato recomendado de evidências

- GitLab: `#123`, `!456` (MR), milestone, label, timestamps.
- Código: caminhos e símbolos (ex.: `apps/my-service/src/main/java/...`, use case ou controller).
- Divergência: “Issue diz X, código em `main` implementa Y”.

## Tratamento de inconsistências

Quando houver contradição, o agente deve:

1. apontar a inconsistência;
2. classificar impacto (baixo/médio/alto retrabalho);
3. propor correção objetiva (editar issue, reabrir issue, abrir bug de modelagem, ajustar dependências no GitLab).

## Entregável mínimo aceitável

Análise sem validação de código em `main` é inválida.

## Integridade UTF-8 ao propor/criar issues

Quando esta skill resultar na criação ou edição de issues:

- Preferir corpo em ficheiro temporário; validar `file --mime-encoding` → `utf-8` ou `us-ascii`.
- Títulos: ASCII seguro quando possível; caracteres especiais densos no corpo.
- Heredocs: `cat <<'EOF'` para evitar corrupção.

Se o agente não conseguir acesso ao GitLab ou ao código:

- declarar bloqueio operacional;
- listar o que faltou;
- não inventar priorização.

## Exceção de VCS

- **`web/your-github-project`** usa GitHub (`gh`) conforme `06-vcs-policy.mdc`. Para esse subprojeto, aplicar o mesmo fluxo com `gh issue` / `gh pr` em vez de `glab`, mantendo a regra “código em main é verdade”.
