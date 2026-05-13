# Elasticsearch — Checklist de performance

Usar como guia; confirmar APIs na documentação da **versão** do cluster.

## Cluster e índice

- [ ] **Heap / disk watermarks** saudáveis? Evitar nós com disco cheio.
- [ ] **`refresh_interval`** adequado para o caso (tempo real vs near-real-time)?
- [ ] **Shard count** total razoável para o tamanho do cluster?
- [ ] **Replicas** alinhadas a nós disponíveis (evitar replica não alocada permanente)?
- [ ] **Mapping explosion** ou índice com dezenas de milhares de campos?

## Query

- [ ] Predicados amplos estão em **`filter`**?
- [ ] Evitar `wildcard`/`prefix` pesado em campos grandes; usar `keyword` + estrutura alternativa se possível.
- [ ] **`size`** e **`_source`** minimizados para o necessário?
- [ ] **`sort`** usa campos com `doc_values`?
- [ ] **`nested`** apenas onde indispensável?
- [ ] **Scripts** evitados ou isolados em último estágio de otimização?

## Agregações

- [ ] **`terms`** em campo de baixa/média cardinalidade; evitar facet em campo único massivo sem `sampler`/`partition` quando aplicável?
- [ ] **Global ordinals** — aceitar custo de primeira aggs após refresh ou usar estratégia de warm-up consciente?
- [ ] **Cardinality** — `cardinality` com `precision_threshold` consciente?

## Operações

- [ ] **Reindex** em janela com disco reservado; throttling se necessário.
- [ ] **Forcemerge** — só com entendimento de impacto (ver safety checklist).

## Ferramentas

- **Profile API** para query lenta.
- **Tasks API** para reindex e operações longas.
- **`_cat/thread_pool`**, **`_nodes/stats`**, **`_cluster/health`** para sintomas de saturação.

Marque cada item com evidência (métrica, profile snippet) ao entregar diagnóstico ao usuário.
