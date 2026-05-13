# PostgreSQL — locks, transações e deadlocks

Comportamento exato varia com a **versão** do PostgreSQL — consulte o capítulo de MVCC e locking do manual da major em uso.

## Níveis de isolamento

- **Read committed** (default): cada comando vê snapshot novo; menos anomalias de leitura longa que em alguns outros defaults de mercado, mas ainda há nuances de visibilidade.
- **Repeatable read / Serializable:** mais proteção contra anomalias; podem aumentar **retries** e erros de serialização na aplicação — a aplicação deve tratar.

## Locks de linha

- `UPDATE` / `DELETE` prendem linhas alvo.
- `SELECT FOR UPDATE` / `FOR SHARE` / `FOR NO KEY UPDATE` — use com transação curta; documentar ordem de acesso para evitar deadlock.
- **Filas:** `FOR UPDATE SKIP LOCKED` (padrão comum de worker); requer design explícito de timeout e retry.

## Deadlocks

- Ciclo de espera entre transações; PostgreSQL aborta uma delas.
- **Mitigação:** transações curtas; ordem determinística de locks nas tabelas; evitar atualizar a mesma linha “quente” de vários fluxos sem fila.

## Locks ao nível de tabela

- DDL e alguns `LOCK TABLE`; `ACCESS EXCLUSIVE` é o mais forte — bloqueia leituras/escritas.

## Diagnóstico (exemplos de evidência)

- Logs: `deadlock detected`.
- Views/sessões: `pg_locks`, `pg_stat_activity` (consultar documentação da versão para colunas e joins recomendados).
- **Não** assumir queries de catálogo idênticas entre majors sem verificar o manual.

## SELECT FOR UPDATE — impacto

- Segura linhas para atualização subsequente na mesma transação.
- Risco: aumenta contenção, filas de espera, deadlocks; combinar com timeouts de statement e de lock na aplicação quando suportado.

## Referência oficial

- [Explicit Locking](https://www.postgresql.org/docs/current/explicit-locking.html)
- [Transaction Isolation](https://www.postgresql.org/docs/current/transaction-iso.html)
- [MVCC](https://www.postgresql.org/docs/current/mvcc.html)
