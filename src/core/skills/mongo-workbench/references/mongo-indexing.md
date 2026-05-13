# MongoDB — Indexing

## Objetivo

Cada índice deve servir a **consultas ou constraints reais**, com consciência de **custo de escrita**, RAM e manutenção em **compactação/rebuild**.

## Índice composto e ordem dos campos

### Guideline ESR (Equality → Sort → Range)

Ao compor um índice multi-campo, priorizar nesta ordem mental:

1. **Equality** — campos comparados com igualdade (`field: value`) e que mais **reduzem** o conjunto.
2. **Sort** — campos usados em `sort()` que devem ser atendidos pelo índice para evitar sort em memória.
3. **Range** — desigualdades (`$gt`, `$lte`, `$in` grande), intervalos de tempo — tipicamente **um** bloco de range por índice “eficiente”; após o primeiro range grande, campos seguintes no índice podem não ser usados para filtro na mesma forma.

Regra prática: desenhe o índice a partir de **uma query de referência** parametrizada; confirme com `explain()` na **versão do servidor** em uso.

## Prefixos e índices redundantes

- Um índice `{ a: 1, b: 1 }` pode servir queries só em `a`; o inverso não vale.
- Evitar dois índices onde um é **prefixo** do outro salvo necessidades de sort distintas ou índices parciais diferentes.

## Seletividade e cardinalidade

- Campos com **poucos valores** (booleano global, `status` com 3 valores) sozinhos são pouco seletivos — combinar com campo mais seletivo primeiro (ex.: `tenantId`, `userId`).
- **Hashed** para shard key ou igualdade pontual; não para range queries.

## Índices parciais e filtro

Use **partialFilterExpression** quando:

- A query sempre restringe a um subconjunto (ex.: `deleted: false`, `type: "active"`).
- Reduz tamanho do índice e custo de manutenção.

## TTL

Para expiração por tempo: índice TTL em campo data; entender granularidade (background thread) e **timezone/UTC**. Não substitui política de arquivo se o volume for extremo.

## Texto e geoespacial

- **Text index:** requisitos e limites (um text index por coleção na configuração clássica) — ver manual da versão.
- **2dsphere:** queries geo; escolher campos e ordem coerentes com predicado.

## Multikey (arrays)

Índice em array gera entradas **por elemento**; impacto em tamanho e writes. Evitar índice em array que cresce sem limite.

## Cobertura e projeção

`covered queries` quando o índice contém todos os campos necessários (incluindo projeção); validar com `explain` e versão do servidor.

## Manutenção

- **Build em foreground vs background** / **createIndex** em produção: implicações de lock e tempo dependem da versão — consultar documentação da release.
- Remover índices **não usados** após evidência em métricas (`$indexStats`) com janela representativa.

## Checklist rápido

- [ ] Predicados e `sort` da query estão refletidos na ordem ESR?
- [ ] Há índice redundante ou quase redundante?
- [ ] Writes por segundo nesta coleção suportam mais um índice?
- [ ] `$in` com centenas de valores se comporta como range grande — ajustar estratégia?

Consulte o MongoDB Manual da sua versão: **Indexes**, **Compound Indexes**, **Index Strategies**.
