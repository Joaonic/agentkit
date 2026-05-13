---
name: redis-workbench
description: >-
  Guides Redis data-structure choice, key/TTL design, persistence, concurrency,
  queues, cache, memory, cluster safety, and observability. Use when modeling Redis,
  reviewing Redis usage, rate limits, sessions, Streams, pub/sub, JSON/vector features,
  or operational Redis decisions.
---

# Redis workbench

## Documentação e versões

**Não fixe versões** de servidor Redis, Redis Stack/módulos nem de bibliotecas cliente nesta skill. Antes de recomendar comandos ou APIs de módulo (JSON, Bloom, Search, Time series, etc.), **consulte a documentação oficial atual** em [redis.io/docs/latest](https://redis.io/docs/latest/) e a documentação da **biblioteca cliente** escolhida (comportamento de cluster, pipelining, timeouts). Use a versão mais nova **compatível** com o ambiente do usuário (topologia, módulos habilitados, política de suporte).

## Descoberta obrigatória (até 5 perguntas)

Se o contexto de uso **não** estiver claro, faça perguntas objetivas antes de propor modelo de dados ou comandos:

1. **Uso principal:** cache, sessão, fila, leaderboard, stream de eventos, rate limit, pub/sub, busca vetorial, JSON/documento, outro?
2. **Topologia:** standalone, Sentinel, Cluster, ou serviço gerenciado (e se há módulos/Redis Stack)?
3. **Política de persistência desejada:** nenhuma (puro cache), RDB, AOF, ou combinação — e quem define isso (ops/SRE)?
4. **Sensibilidade a perda de dados:** aceita perda em restart/eviction? precisa consistência forte entre chaves? SLA de RPO/RTO?
5. **Linguagem e cliente:** runtime e biblioteca (ex.: Node `ioredis`/`node-redis`, Java Lettuce, Go `go-redis`, Python `redis-py`) — afeta cluster, pipelining e APIs.

## Regras obrigatórias para o agente

1. **Estrutura antes de comandos:** escolha o tipo Redis adequado (string, hash, list, set, sorted set, stream, JSON se módulo disponível, etc.) e **justifique** em uma linha; só então proponha comandos.
2. **Chave, TTL, cardinalidade, invalidação:** defina convenção de nome, TTL (ou ausência), cardinalidade esperada e estratégia de invalidação (event-driven, TTL-only, version stamp, etc.).
3. **Cache vs durabilidade:** separe explicitamente **dados recriáveis** (cache) de **dados que exigem sobreviver a restart** (fonte de verdade ou réplica durável). Redis **não substitui** banco relacional/ledger sem desenho de persistência e backup.
4. **Persistência:** explique tradeoffs **sem persistência**, **RDB**, **AOF** e **combinações**; aponte risco de perda entre snapshots/fsync. Detalhes: [references/redis-persistence-and-durability.md](references/redis-persistence-and-durability.md).
5. **Atomicidade condicional:** quando leitura+escrita precisam ser coerentes frente a concorrência, use **MULTI/EXEC** e **WATCH** (ou alternativa documentada equivalente no cliente). Detalhes: [references/redis-transactions-and-concurrency.md](references/redis-transactions-and-concurrency.md).
6. **Memória e hot keys:** considere tamanho de valores, política de **eviction**, cardinalidade de coleções, compressão no app, e risco de **hot key** / fan-out. Detalhes: [references/redis-data-structures.md](references/redis-data-structures.md).
7. **Comandos perigosos:** alerte para **KEYS**, **FLUSHALL**, **FLUSHDB**, deletes massivos sem **SCAN**, e scripts Lua longos bloqueantes. Prefira **SCAN**, **SSCAN**, **HSCAN**, **ZSCAN**, **XREAD** com limites. Checklist: [references/redis-safety-checklist.md](references/redis-safety-checklist.md).
8. **Cluster:** para Redis Cluster, considere **hash slots**, chaves com **hash tag** `{...}` quando necessário, e impacto de operações **multi-key** / transações **cross-slot**. Referência geral de tipos: [references/redis-data-structures.md](references/redis-data-structures.md); chaves: [references/redis-key-design.md](references/redis-key-design.md).
9. **Observabilidade:** inclua o que medir (latência p99, comandos lentos, memória, evictions, conexões, replica lag) e passos de troubleshooting. Ver seção abaixo.

## Formato obrigatório de toda resposta

Toda proposta ou revisão deve incluir, nesta ordem:

| Seção                                  | Conteúdo                                                |
| -------------------------------------- | ------------------------------------------------------- |
| **Objetivo do uso**                    | O problema de negócio/técnico                           |
| **Estrutura Redis escolhida**          | Tipo(s) + breve justificativa                           |
| **Modelo de chave**                    | Padrão, exemplos, hash tags se cluster                  |
| **Política de TTL**                    | Valores, renovação, ou “sem TTL” + motivo               |
| **Comando completo**                   | Sequência Redis (e notas de cliente: cluster, pipeline) |
| **Riscos e limitações**                | Perda de dados, race, memória, cluster, bloqueio        |
| **Alternativa se Redis não for ideal** | Ex.: Postgres, Kafka, S3, fila dedicada, CDN            |

## Workflows (copiar e seguir)

### Rate limit

1. Confirmar janela (fixa vs sliding), limite por identidade (IP, user, tenant), e topologia (cluster → mesma slot ou chave agregada).
2. Escolher estrutura: contador com **INCR** + **EXPIRE**, sorted set com timestamps para janela deslizante, ou **sliding window** documentado na doc atual.
3. Definir chave: `ratelimit:{tenant}:{bucket}:{id}` (ajustar); TTL = janela ou limpeza por score.
4. Avaliar race: precisa **WATCH**/Lua/script oficial do cliente ou operação atômica única.
5. Saída: preencher formato obrigatório + observabilidade (rejeições, cardinality).

### Cache de catálogo

1. Fonte de verdade e **staleness** aceitável.
2. Granularidade: item vs lista; tamanho de valor; **cache-aside** vs **read-through**.
3. Chaves versionáveis: `catalog:{tenant}:product:{id}:v{version}` ou invalidação por pub/sub/evento.
4. TTL + invalidação em update; evitar uma única chave gigante “todo o catálogo”.
5. Riscos: stampede (locks/early refresh), hot key de lista popular.

### Sessão distribuída

1. Conteúdo (IDs, tokens opacos — nunca secrets em claro desnecessários), TTL de inatividade vs absoluto.
2. **Hash** por sessão vs string serializada; tamanho e campos mutáveis.
3. Chave: `session:{tenant}:{sid}`; renovação de TTL em request.
4. Logout: **DEL** ou blacklist com TTL; considerar **WATCH** se atualizar vários campos com consistência.
5. Alternativa: cookie JWT stateless + Redis só para revoke/allowlist.

### Fila com Streams

1. Produtor: **XADD**; consumidor: grupo **XREADGROUP**; ACK **XACK**; pending **XPENDING**/claim.
2. Chave stream + consumer group por serviço; maxlen aprox (**MAXLEN ~** ou política atual na doc).
3. Dead letter: stream secundária ou trim + métrica de falhas.
4. Não confundir com **List** (BLPOP) — escolher conforme necessidade de replay, grupos e pending.

### Revisar persistência

1. Mapear: apenas cache? precisa sobreviver restart?
2. RDB/AOF ativos? `appendfsync` / frequência de snapshot (consultar doc de configuração atual).
3. Backup externo e teste de restore.
4. Saída: tradeoffs e lacunas vs requisito de negócio.

### Diagnóstico de memória excessiva

1. **INFO memory**, **MEMORY STATS** / comandos de análise suportados na versão deployment.
2. Amostrar chaves grandes (evitar **KEYS**): **SCAN** + **MEMORY USAGE** quando disponível.
3. Ver eviction e `maxmemory-policy`; fragmentação.
4. Ações: TTL, reduzir valor, shard de chave, estrutura mais compacta, arquivar para store externo.

### Revisar naming e TTL

1. Auditar padrão: prefixo tenant/ambiente, separadores, evitar caracteres problemáticos.
2. Cardinalidade por prefixo; uso de hash tags só onde necessário (cluster).
3. TTL: default, renovação, sessões vs cache; chaves sem TTL justificadas.
4. Checklist de segurança: [references/redis-safety-checklist.md](references/redis-safety-checklist.md).

## Observabilidade e troubleshooting

- **Métricas:** ops/s, latência (p50/p99), erros, conexões, uso de memória, evictions, replica lag (se réplica).
- **Comandos lentos:** log de slowlog (configuração atual na doc); correlacionar com KEYS, SORT grandes, Lua longo.
- **Traces:** no app, spans em torno de operações Redis críticas (cluster redirect, timeouts).
- **Plano:** definir alertas em memória alta, evictions súbitas, latência, e falhas de conexão.

## Referências internas

- [references/redis-data-structures.md](references/redis-data-structures.md)
- [references/redis-key-design.md](references/redis-key-design.md)
- [references/redis-persistence-and-durability.md](references/redis-persistence-and-durability.md)
- [references/redis-transactions-and-concurrency.md](references/redis-transactions-and-concurrency.md)
- [references/redis-safety-checklist.md](references/redis-safety-checklist.md)

## Links oficiais (sempre revalidar na doc atual)

- [Redis documentation (latest)](https://redis.io/docs/latest/)
- [Data types](https://redis.io/docs/latest/develop/data-types/)
- [Persistence](https://redis.io/docs/latest/management/persistence/)
- [Transactions](https://redis.io/docs/latest/develop/interact/transactions/)
