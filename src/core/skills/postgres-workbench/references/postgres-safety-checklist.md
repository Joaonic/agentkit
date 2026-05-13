# PostgreSQL — checklist de segurança operacional

## Antes de qualquer mudança em produção

- [ ] **Versão** do servidor confirmada; comportamento verificado no manual dessa major.
- [ ] **Backup** recente testado ou replicação adequada; PITR disponível se política exigir.
- [ ] **Janela** ou feature flag definida para DDL de alto impacto.
- [ ] **Rollback** documentado (migration down, drop index, revert feature).
- [ ] **Permissão** explícita para o tipo de comando (analyze em prod, DDL, `VACUUM FULL`, etc.).

## Operações de alto risco (avisar sempre)

- `DROP TABLE`, `TRUNCATE`, `DROP COLUMN`, `ALTER … DROP CONSTRAINT` sem fase de deprecação.
- `ALTER TYPE`, mudanças que reescrevem tabela (depende do tipo de alteração e versão).
- `VACUUM FULL`, `CLUSTER`, `REINDEX` em objetos grandes — locks e I/O intensivos.
- Índice **sem** `CONCURRENTLY` em tabela quente e grande.
- Carga massiva sem `throttle` — saturação de WAL, réplicas e autovacuum.

## Migrations “seguras” (direção)

1. **Expandir:** adicionar coluna/tabela/índice novo sem quebrar clientes antigos.
2. **Backfill** em batches com `sleep`/`LIMIT` se necessário para não monopolizar.
3. **Validar** dados e planos (`EXPLAIN`, métricas).
4. **Contrair:** remover coluna antiga ou constraint só após nenhum cliente depender.

## Privilégios e dados

- App role: apenas DML necessário + uso de sequences; migration role separada.
- Evitar `SECURITY DEFINER` sem revisão de `search_path` e ownership.
- Não logar valores sensíveis em queries de debug.

## Pós-mudança

- [ ] Latência e erros monitorados.
- [ ] `ANALYZE` após mudanças grandes de distribuição (conforme política).
- [ ] Plano de **validação** documentado na resposta (queries de smoke).

## Referência oficial

- [Routine Vacuuming](https://www.postgresql.org/docs/current/routine-vacuuming.html)
- [Backup and Restore](https://www.postgresql.org/docs/current/backup.html)
