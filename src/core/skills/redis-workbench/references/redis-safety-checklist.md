# Redis safety checklist (reference)

Use em code review, runbooks e antes de mudanças em produção.

## Comandos e padrões perigosos

| Risco                              | Por quê                               | Preferir                                          |
| ---------------------------------- | ------------------------------------- | ------------------------------------------------- |
| `KEYS pattern`                     | Bloqueia o núcleo em datasets grandes | `SCAN` com `MATCH` e contagem limitada            |
| `FLUSHALL` / `FLUSHDB`             | Apaga dados                           | Proibir em prod; ACLs; confirmação em runbook     |
| `DEBUG` / comandos administrativos | Podem impactar serviço                | Apenas ops, com aprovação                         |
| `SORT` grande                      | CPU/memória                           | Paginar na fonte; índices em estruturas adequadas |
| Lua/EVAL longo                     | Latência global                       | Scripts mínimos; timeout conforme doc/policy      |

## Iteração segura

- **SCAN** cursor, **HSCAN**, **SSCAN**, **ZSCAN**: não garantem snapshot consistente de todo o dataset, mas não bloqueiam como KEYS.
- Limitar trabalho por iteração na aplicação; repetir até cursor 0.

## Cluster

- Verificar se comando é suportado em cluster e se é **single-slot**.
- Evitar transações multi-key cross-slot.
- Monitorar **MOVED** / **ASK** storms (cliente mal configurado ou slot migration).

## Memória

- Definir `maxmemory` e **eviction policy** explícitas em produção.
- Alertar em uso alto de memória, evictions/min, e latência.

## ACLs e rede

- Autenticação habilitada; princípio do menor privilégio.
- TLS em trânsito onde aplicável; não expor Redis públicamente.

## Observabilidade mínima

- Slow log configurado e revisado.
- Métricas: comandos, latência, errors, clients blocked, replication lag.
- Correlação com traces da aplicação para timeouts e retries.

## Plano de incidente

- Quem pode executar flush/restart?
- Backup/restore validado?
- Runbook para “memory maxed” e “latency spike”?
