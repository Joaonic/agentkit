# Elasticsearch — Shards, rollover, ILM e logs

Ajustar recomendações à **versão** e ao **edition** (Elastic Cloud, self-managed, OpenSearch).

## Shard sizing (orientação geral)

- Tamanho **por shard** é o principal alavanca: shards pequenos demais → overhead; grandes demais → recovery lento, hotspots.
- Regra prática comum (não universal): avaliar faixa de **GB por primary shard** citada na doc atual para time-series e busca; **validar** com disk, heap e número de nós.
- **Primários:** definir no create/reindex; **replicas** para leitura e HA (mínimo 1 em produção quando houver múltiplos nós).

## Oversharding — diagnóstico

1. `GET _cat/shards?v` e `GET _cat/indices?v` — contar primários e tamanho.
2. Comparar **média GB/shard** com metas da doc e capacidade de heap.
3. Sintomas: muitos shards por GB de dados, recovery constante, cluster state grande, tasks lentas.
4. Mitigações: **ILM shrink** (quando suportado e com cuidado), **reindex** para menos shards, reduzir índices diários fragmentados, novo template com `number_of_shards` menor para índices futuros.

## Rollover e aliases

- **Alias de escrita** apontando para índice atual; **rollover** por tamanho/doc count/idade.
- **Alias de leitura** pode cobrir múltiplos índices (`logs-*`).
- Trocar padrão de nome ao mudar template (ex.: incrementar sufixo de template).

## ILM (Index Lifecycle Management)

- Fases típicas: hot → warm → cold → delete (nomes e recursos variam por versão/licença).
- Política referenciada no template ou data stream.
- Validar impacto de **readonly**, **allocate**, **forcemerge** na fase (ver safety checklist).

## Workflow: estratégia rollover + ILM

1. Definir retenção e SLA de consulta (últimos 7d quentes, etc.).
2. Escolher **data stream** vs índices datados + rollover (conforme versão/padrão).
3. Template: `index.lifecycle.name`, padrão de nome, shards primários alinhados ao volume.
4. Alias write + condições de rollover.
5. Monitorar erro de ILM, espaço em disco, tempo de fase.

## Workflow: revisão de índice para logs / observabilidade

- Séries temporais: campo `@timestamp` ou `time` mapeado como `date`.
- Mapeamento **minimalista:** strings como `keyword` quando não há necessidade de full-text; `text` só para mensagem se buscável.
- `ignore_above` em keywords longas; desabilitar indexação de campos puramente diagnosticados se a versão permitir.
- **Volume:** ILM agressivo; evitar campos dinâmicos ilimitados (explosão de mapping).
- Separar **logs de app** de **métricas** quando o modelo de consulta for muito diferente (opcional mas frequentemente saudável).

## Workflow: catálogo (remissão)

Ver workflow de produtos em `es-mapping.md`; alinhar número de shards ao tamanho do catálogo e taxa de atualização (reindex planificado).
