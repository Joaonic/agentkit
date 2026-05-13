---
name: elasticsearch-workbench
description: >-
  Models Elasticsearch indices, mappings, templates, queries, aggregations,
  relevance, ingestion, lifecycle and cluster troubleshooting. Use when
  designing or reviewing Elasticsearch/OpenSearch schemas, ILM/rollover,
  slow queries, shard sizing, reindex, or production search/analytics patterns.
---

# Elasticsearch Workbench

## Fontes e versão

- **Não fixar versão** nesta skill: antes de recomendar sintaxe ou defaults, **consultar a documentação oficial** da stack em uso (Elasticsearch ou OpenSearch) e a **versão implantada** no cluster-alvo.
- Priorizar: docs do vendor (Elastic / OpenSearch), release notes da versão do cluster, e **Context7** ou fetch para trechos específicos de API quando necessário.

## Descoberta obrigatória (até 5 perguntas)

Se o usuário **não** tiver informado claramente, **perguntar primeiro** (combinação mínima necessária):

1. **Versão** do Elasticsearch ou OpenSearch (e se é Elastic Cloud, self-managed ou OpenSearch).
2. **Caso de uso principal:** busca textual, observabilidade, analytics, vector search, logs, catálogo de produtos (pode ser híbrido — pedir prioridade).
3. **Volume e padrão de acesso:** ingestão diária aproximada, **retenção**, leitura dominante (consultas ad-hoc, dashboards, busca em tempo real).
4. **Topologia:** número de nós, roles (master/data/ingest), limites de disco/RAM relevantes se conhecidos.
5. **Ingestão:** pipelines (ingest node), origem dos dados (beats, logstash, aplicação, CDC), necessidade de enrich/geo/normalização.

Só depois propor mapping, settings, ILM e queries detalhadas.

## Obrigações do agente

1. **Mapping em produção:** preferir **explicit mapping**; **dynamic mapping** apenas **controlado** (`dynamic: strict` ou `false` onde fizer sentido, `dynamic_templates` quando inevitável).
2. **Revisão campo a campo:** classificar cada campo como `text`, `keyword`, numérico, `date`, `boolean`, `nested`, `object` e **`dense_vector`** / campos de vetor quando aplicável; justificar `norms`, `doc_values`, `index`, `keyword` vs `text`.
3. **Desde o início:** **index templates**, **aliases** (write/read), **rollover** e **ILM** (ou política equivalente OpenSearch) como parte do desenho, não como retrabalho.
4. **Mudança incompatível:** tratar alteração de mapping que não seja **safe** como operação que **exige novo índice + reindex** (ou reindex para alias); nunca prometer “alterar tipo” in-place.
5. **Shards e retenção:** revisar **tamanho alvo por shard**, número de **primary shards**, **oversharding**, fatores de **retenção** e política de **forcemerge** (com ressalvas).
6. **Queries:** analisar **custo** (filtros em `filter` context, scoring, `sort`, **aggregations**, request/cache e fielddata onde couber); citar trade-offs.
7. **Riscos estruturais:** **scripts** (pain de performance), **alta cardinalidade** em aggs, **nested** excessivo (custo de join interno).
8. **Dois perfis de uso:** separar claramente **search use case** (relevância, latência, texto/vetor) de **analytics use case** (aggs, métricas, dashboards).

Sempre propor **naming** (índices, aliases, templates), **index settings**, **template** e **estratégia de migração** (reindex, cutover por alias, dual-write se necessário).

**Alertar explicitamente** sobre riscos de: **reindex** (disco, tempo, versão de mapping), **forcemerge**, **mappings muito grandes** e **instabilidade de cluster** (recovery, watermarks, heap).

## Formato obrigatório de resposta

Toda resposta que propor desenho ou correção deve incluir estas seções (use títulos fixos):

1. **Objetivo da busca** — o que o usuário/query precisa entregar (SLA, relevância vs agregação).
2. **Desenho do índice** — aliases, rollover/ILM, convenções de nome, fluxo de ingestão.
3. **Mapping sugerido** — JSON/YAML de `properties` (e `dynamic` / `dynamic_templates` se houver).
4. **Settings sugeridos** — bloco `settings` relevante (shards, replicas, `index.sort`, `codec` só se justificado, `lifecycle` via ILM policy name, etc.).
5. **Query DSL completa** — exemplo **completo** (não fragmento ambíguo) alinhado ao caso; se o caso for só ingestão/mapping, usar `match_all` + `size: 0` com aggs **apenas** se fizer sentido, ou declarar N/A com motivo.
6. **Riscos** — reindex, disco, breaking changes, cardinality, scripts, nested, upgrades de versão.
7. **Estratégia de evolução do schema** — como adicionar campos, deprecar, reindex, trocar alias.

## Workflows

Seguir os passos detalhados nas referências quando aplicável:

| Objetivo                         | Referência principal                                                                                                                                               |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Desenho de índice novo           | [references/es-mapping.md](references/es-mapping.md), [references/es-shards-and-lifecycle.md](references/es-shards-and-lifecycle.md)                               |
| Revisão de mapping existente     | [references/es-mapping.md](references/es-mapping.md), [references/es-safety-checklist.md](references/es-safety-checklist.md)                                       |
| Query lenta                      | [references/es-query-and-aggregation.md](references/es-query-and-aggregation.md), [references/es-performance-checklist.md](references/es-performance-checklist.md) |
| Oversharding / shards            | [references/es-shards-and-lifecycle.md](references/es-shards-and-lifecycle.md), [references/es-performance-checklist.md](references/es-performance-checklist.md)   |
| Rollover e ILM                   | [references/es-shards-and-lifecycle.md](references/es-shards-and-lifecycle.md)                                                                                     |
| Índice para logs                 | [references/es-shards-and-lifecycle.md](references/es-shards-and-lifecycle.md) (workflow logs)                                                                     |
| Índice para catálogo de produtos | [references/es-mapping.md](references/es-mapping.md) (workflow catálogo)                                                                                           |

### Resumo dos workflows (checklist)

**Novo índice:** descoberta → caso search vs analytics → template + alias write → mapping explícito → settings + shard estimate → ILM/rollover → query de validação → riscos.

**Revisão de mapping:** snapshot/backup → comparar mapping atual vs desejado → listar mudanças incompatíveis → plano reindex + alias → teste em índice sombra.

**Query lenta:** profile API (quando disponível na versão) → `filter` vs `query` → cardinality aggs → scripts → sort/doc_values → field types.

**Oversharding:** contar primários, tamanho médio por shard, heap, recovery → consolidar índices / ILM / shrink (se suportado e com ressalvas).

**Rollover + ILM:** alias write → condição de rollover → fases hot/warm/cold/delete → métricas de disco.

**Logs:** time-based indices, `data_stream` ou rollover, mapping mínimo e `ignore_above`, desabilitar `_all`/campos desnecessários conforme versão, ILM agressivo na retenção.

**Catálogo:** IDs keyword, texto com subcampos (keyword para facetas/filtros), nested para SKUs/atributos variáveis, evitar aggs em `text`.

## Referências (progressive disclosure)

- [references/es-mapping.md](references/es-mapping.md)
- [references/es-query-and-aggregation.md](references/es-query-and-aggregation.md)
- [references/es-shards-and-lifecycle.md](references/es-shards-and-lifecycle.md)
- [references/es-performance-checklist.md](references/es-performance-checklist.md)
- [references/es-safety-checklist.md](references/es-safety-checklist.md)

## Agente OpenAI (opcional)

Para perfil YAML de agente alinhado a esta skill, ver [agents/openai.yaml](agents/openai.yaml).
