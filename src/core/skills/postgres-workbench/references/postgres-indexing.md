# PostgreSQL — indexação

Confirme a versão do servidor e leia a documentação oficial da **sua** major para sintaxe completa (`CREATE INDEX`, opções, paralelismo, `CONCURRENTLY`).

## Quando indexar

- Há predicado repetido (WHERE), join em coluna de alta cardinalidade, ou ORDER BY alinhado ao índice.
- O plano mostra seq scan caro **e** a seletividade justifica o índice.
- Sempre considerar: **custo de INSERT/UPDATE/DELETE**, espaço em disco, impacto em **autovacuum** e **bloat**.

## B-tree (default)

- Igualdade e intervalos; multicolumn — ordem das colunas importa (prefixo mais seletivo primeiro quando possível).
- **Multicolumn:** primeiro atende consultas que usam prefixo das colunas; não duplicar índices que são prefixo de outro sem motivo.

## GIN

- **jsonb**, full-text (`tsvector`), arrays, alguns tipos compostos.
- Custo de escrita e tamanho tipicamente maiores que btree; adequado a conteúdo pesquisável.

## GiST

- Dados geométricos, full-text em alguns setups, intervalos — quando a documentação do tipo recomendar GiST.

## BRIN

- Tabelas muito grandes com **correlação física** com a ordem de inserção (ex.: time-series append-only).
- Índice compacto; ineficaz se dados estão desordenados fisicamente em relação à coluna indexada.

## Índice parcial

- `WHERE condição` — excelente para subconjuntos pequenos (ex.: `WHERE deleted_at IS NULL`).
- Reduz tamanho e manutenção; exige que a query use a **mesma** condição.

## Índice em expressão

- Quando o predicado aplica função (`lower(email)`); a query deve usar a mesma expressão.
- Útil para case-insensitive unicidade controlada.

## Operações seguras em produção

- **`CREATE INDEX CONCURRENTLY`:** evita bloqueio de escrita prolongado; pode falhar e deixar índice inválido — saber como verificar e recriar (manual da versão).
- **`REINDEX`:** pode ser destrutivo em termos de I/O e tempo; planejar janela.

## EXPLAIN antes de criar

- Validar que o otimizador **usaria** o índice (`EXPLAIN` / `EXPLAIN ANALYZE` conforme política do ambiente).

## Referência oficial

- [Indexes](https://www.postgresql.org/docs/current/indexes.html)
- [Index types](https://www.postgresql.org/docs/current/indexes-types.html)
