# Redis data structures (reference)

**Atualização:** confira tipos e comandos na documentação oficial atual: [Data types](https://redis.io/docs/latest/develop/data-types/) e grupos de comandos por tipo.

## Mapa rápido de escolha

| Necessidade                         | Candidatos                      | Notas                                                          |
| ----------------------------------- | ------------------------------- | -------------------------------------------------------------- |
| Valor blob, contador, lock leve     | String                          | `SET`, `GET`, `INCR`, `SET NX EX`                              |
| Objeto com campos (usuário, sessão) | Hash                            | Evita serializar tudo em um JSON string se campos são parciais |
| Fila simples FIFO, worker pool      | List                            | `LPUSH`/`BRPOP`; sem grupos de consumidores                    |
| Conjunto único, interseções         | Set                             | Cardinalidade alta = memória                                   |
| Ranking, leaderboard, scores        | Sorted set                      | Por score; range por rank                                      |
| Log de eventos, fila com grupos     | Stream                          | `XADD`, `XREADGROUP`, pending                                  |
| Geo                                 | Geo (sobre sorted set)          | Raio, distância                                                |
| Bitmap / contadores compactos       | Bitmap, Bitfield                | Contadores em poucos bits                                      |
| JSON aninhado (módulo)              | JSON                            | Requer Redis Stack / módulo JSON habilitado                    |
| Similaridade vetorial (módulo)      | Vector set / Search             | Confirmar módulo e doc na sua versão                           |
| Cardinalidade aproximada            | HyperLogLog                     | Tradeoff precisão/memória                                      |
| Probabilística (Bloom, etc.)        | Módulos Bloom / probabilísticos | Ver doc de módulos                                             |

## Memória e cardinalidade

- **Strings grandes:** cada valor ocupa memória proporcional ao tamanho; comprimir no aplicativo ou fragmentar.
- **Hash, Set, ZSet:** custo cresce com número de elementos e tamanho dos membros.
- **Stream:** retenção com `MAXLEN` / políticas atuais na doc; pending não consumido acumula.
- **Hot key:** uma chave com tráfego extremo pode saturar um nó (Cluster: um slot = um nó primário).

## Hot keys e sharding lógico

- Distribuir carga: partição por sufixo (`item:{shard}:id`) com cuidado em cluster (hash tags).
- Evitar “mega-hash” único para milhões de entidades sem subpartição.

## Quando não usar Redis

- Fonte de verdade transacional complexa com joins e ACID fora do escopo → banco relacional.
- Arquivos grandes / objetos imutáveis → object storage.
- Filas com retenção longa e replay massivo → broker dedicado (avaliar custo/ops).
