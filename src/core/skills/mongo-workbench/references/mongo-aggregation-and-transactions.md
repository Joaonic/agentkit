# MongoDB — Aggregation, `$lookup`, e transações

## Separar tipos de workload

| Tipo                 | Característica                          | Cuidado principal                                                                         |
| -------------------- | --------------------------------------- | ----------------------------------------------------------------------------------------- |
| **Operacional**      | Baixa latência, poucos docs por request | Índices, projeção mínima, evitar pipeline pesado na request crítica                       |
| **Aggregation OLTP** | Transformação, relatórios menores       | `$match` cedo; índices alinhados; limitar cardinalidade de `$lookup`                      |
| **Analítico**        | Grandes scans, muitos stages            | Memória, `allowDiskUse`, impacto no mesmo cluster; considerar replica analytics ou export |

## Boas práticas de pipeline

1. **`$match` e `$project` cedo** — reduzir documentos e bytes downstream.
2. **Índices** — o primeiro `$match` deve ser compatível com índice quando possível; confirmar com `explain` na versão do servidor.
3. **`$lookup`** — tratar como join: cardinalidade explode facilmente; filtrar foreign collection cedo; indexar chave local e foreign.
4. **`$unwind`** — multiplica documentos; usar apenas quando necessário.
5. **`$group`** — custo de memória; em datasets grandes, avaliar pré-agregação ou materialização (`$merge` / `$out` com cuidado operacional).
6. **`$facet`** — útil mas pode multiplicar trabalho; não usar por padrão em hot path.

## `$merge` e `$out`

- Escrevem para coleções; exigem planejamento de **permissões**, **concorrência** com leitores, e **rollback conceitual** (são side effects).
- Adequados a jobs batch ou ETL interno; não como substituto de transação sem desenho idempotente.

## Transações multi-documento

### Quando fazem sentido

- Invariantes que **não** cabem em um único documento nem em update idempotente único.
- Consistência forte entre **poucas** operações relacionadas na mesma replica set.

### Custos e limites (verificar manual da versão)

- Overhead de **latência** e coordenação.
- **Timeouts** e necessidade de **retry** transacional na aplicação.
- Interação com **sharding**: transações multi-shard têm custo e restrições maiores.
- Tamanho/tempo da transação — evitar trabalho pesado dentro da transação.

### Preferir quando possível

- **Modelo embed** ou **sequência de updates idempotentes** com compensação.
- **Outbox pattern** para eventos eventualmente consistentes.

## Read concern / read preference

- Workloads de relatório podem usar **secondary** com tolerância a lag; operações críticas de consistência no **primary**.
- Combinar com transações apenas após ler a matriz de suporte da versão.

## Checklist de revisão de pipeline

- [ ] Há `$match` seletivo no início?
- [ ] Algum stage materializa lista gigante intermediária?
- [ ] `$lookup` tem filtro indexável do lado direito?
- [ ] Pipeline precisa de `allowDiskUse` — e o cluster aguenta?
- [ ] O mesmo resultado poderia ser um **incremental maintain** (view materializada / coleção resumo)?

Documentação: MongoDB Manual — **Aggregation**, **Aggregation Pipeline Optimization**, **Transactions**.
