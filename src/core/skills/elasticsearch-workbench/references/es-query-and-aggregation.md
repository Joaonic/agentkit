# Elasticsearch — Query DSL, scoring e agregações

Validar sintaxe e opções na documentação da **versão do cluster**.

## Search vs analytics

| Aspecto  | Search (relevância)                     | Analytics (métricas)                               |
| -------- | --------------------------------------- | -------------------------------------------------- |
| Foco     | score, ranking, highlighting, sugestões | aggs, buckets, métricas                            |
| Latência | sub-segundo típico                      | pode ser maior; muitas aggs = custo                |
| Campos   | `text`, vetores, boosts                 | `keyword`, numéricos, `date` com `doc_values`      |
| Cache    | request cache em contextos específicos  | global ordinals em `keyword` de alta cardinalidade |

Tratar **no mesmo índice** apenas quando os trade-offs forem aceitos; às vezes separar **índice de busca** vs **índice de eventos** (denormalização).

## Filter vs query

- Condições **sem impacto em score** (yes/no) → `filter` context: cacheável, frequentemente mais barato.
- **Scoring** (full-text, `function_score`, etc.) → `must` / `should` em `query` context.
- Combinar `bool`: `filter` para recorte grande + `must` para texto.

## Sort

- Ordenar por `keyword` ou numérico com `doc_values`.
- Ordenar por `text` costuma exigir `.keyword` ou `fielddata` (evitar `fielddata` em produção).

## Agregações — custo

- **Alta cardinalidade** (`terms` em campo com milhões de valores únicos): memória, global ordinals, lentidão.
- **Nested aggs:** multiplicam custo; revisar se `flattened` ou modelo denormalizado resolve.
- **Scripts em aggs:** caro; preferir campos indexados.
- **Pipeline aggs:** dependência de ordem e versão; validar na doc.

## Scripts

- Groovy/Painless e políticas mudam por versão.
- Scripts em query/filter/aggs aumentam CPU e invalidam otimizações; último recurso.

## Query lenta — sequência de análise

1. Confirmar **tamanho** do índice, **shards**, `refresh_interval`.
2. Usar **profile API** (se disponível) para ver árvore de execução.
3. Verificar uso de `wildcard`/`prefix`/`regex` em campos pesados.
4. Verificar `nested` + `nested` aggs em volume alto.
5. Checar **sort** em campos sem `doc_values`.
6. Reescrever com `filter` + combinação `bool`; reduzir `size` e campos retornados (`_source` filtering).

## Exemplo mental (padrão)

- Recorte temporal + tenant em `filter`.
- Texto do usuário em `must` com `match`/`multi_match` com campos e boosts explícitos.
- Facetas em `aggs` sobre `keyword` com `size` limitado e `shard_size` ajustado quando necessário (consultar doc).

Sempre que propor otimização, indicar **efeito colateral** (precisão, recall, cardinalidade).
