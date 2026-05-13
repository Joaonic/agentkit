# Persistence and durability (reference)

**Fonte canônica:** [Persistence](https://redis.io/docs/latest/management/persistence/) — parâmetros exatos mudam entre versões; sempre validar na doc e no `redis.conf` do ambiente.

## Modos (tradeoffs)

### Sem persistência (ou apenas cache)

- **Prós:** menor latência de disco, simplicidade se dados são recriáveis.
- **Contras:** perda total em restart ou falha de nó; **eviction** pode apagar dados “quentes”.

### RDB (snapshots)

- **Prós:** arquivo compacto, backup simples, impacto previsível em intervalos de snapshot.
- **Contras:** perda de writes entre snapshots (janela RPO); fork cost em datasets grandes.

### AOF (append-only file)

- **Prós:** histórico de writes; RPO menor com `appendfsync` agressivo (com custo de IOPS).
- **Contras:** arquivo pode crescer; rewrite de AOF tem custo; interpretação de fsync depende de SO/disco.

### RDB + AOF (combinado)

- **Uso:** equilibrar restart rápido (RDB) com durabilidade mais fina (AOF), conforme doc de “hybrid” / política atual.
- **Contras:** mais I/O e complexidade operacional.

## O que Redis **não** garante sozinho

- **Backup off-box:** snapshots locais não sobrevivem à perda do volume/region.
- **Consistência multi-chave** em falha parcial: depende de transações, aplicação e cluster (sem protocolo 2PC nativo entre nós para sua app).
- **Eviction vs persistência:** chaves podem sumir por memória antes de serem “persistidas” no sentido de negócio — alinhar `maxmemory-policy` ao caso de uso.

## Checklist de revisão

- [ ] Requisito de negócio: RPO/RTO definidos?
- [ ] RDB interval / AOF fsync alinhados ao RPO?
- [ ] Restore testado (procedimento documentado)?
- [ ] Dados críticos têm fonte de verdade fora do Redis?
- [ ] Managed service: política de backup/snapshot do provedor compreendida?
