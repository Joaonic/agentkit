---
name: postgres-workbench
description: >-
  Models, reviews, queries, optimizes, and operates PostgreSQL with integrity,
  indexing discipline, EXPLAIN-first tuning, locking awareness, and safe
  migrations. Use when designing or altering schemas, slow queries, deadlocks,
  vacuum/bloat, partitioning, privileges, or production DDL; when the user
  mentions PostgreSQL, SQL migrations, indexes, transactions, or RLS.
---

# PostgreSQL Workbench

## Descoberta obrigatória (até 5 perguntas)

Se o contexto do servidor, workload ou permissões não estiver claro, pergunte antes de recomendar DDL destrutivo ou comandos em produção:

1. **Versão do PostgreSQL** — major/minor do servidor (e se há réplicas / streaming).
2. **Volume e workload** — tamanho aproximado do cluster, maiores tabelas, pico de QPS, leitura vs escrita, jobs batch.
3. **Padrão de uso** — OLTP, analytics, fila/eventos, multi-tenant (RLS, `tenant_id`, schema por tenant).
4. **ORM, migrations e stack** — Flyway, Hibernate/JPA, Liquibase, SQL puro; linguagem da aplicação (Java/Spring Boot ou TypeScript/Next.js).
5. **Permissões reais** — só revisão offline, ou acesso read-only / DDL em staging / produção; se `EXPLAIN ANALYZE` e `CREATE INDEX CONCURRENTLY` são permitidos.

## Documentação e versão

- **Não fixe versão** de PostgreSQL em respostas genéricas: confirme a versão do ambiente e consulte a documentação oficial da **mesma major** (ex.: `https://www.postgresql.org/docs/current/` como entrada; para comportamento exato, a documentação da major correspondente ao servidor).
- Para mudanças de comportamento entre releases, use as **release notes** oficiais da versão alvo.
- Se usar MCP ou busca web, priorize **postgresql.org** e o manual do projeto da ferramenta de migration/ORM.

## Princípios operacionais

- **Integridade:** PK, FK, `UNIQUE`, `CHECK`, `NOT NULL` e `DEFAULT` coerentes com o domínio; evitar “tabela larga” sem constraints quando o negócio exige regras.
- **Tipos:** escolher tipos com rigor (`text` vs `varchar`, `numeric` vs `float`, `timestamptz` vs `timestamp`, `uuid`, enums vs lookup tables); justificar exceções.
- **Índices:** propor só quando alinhados a predicados/joins/ordenação reais; sempre mencionar custo de escrita, armazenamento e manutenção (`VACUUM`/bloat).
- **Famílias de índice:** diferenciar **btree**, **GIN**, **GiST**, **BRIN**, **índice parcial**, **índice em expressão** e **multicolumn** — ver [references/postgres-indexing.md](references/postgres-indexing.md).
- **Tuning de query:** padrão **EXPLAIN** e, quando permitido, **EXPLAIN (ANALYZE, BUFFERS, …)** antes de mudar schema ou GUCs; interpretar no contexto da versão.
- **Concorrência:** locks, deadlocks, isolamento, `SELECT FOR UPDATE` / `SKIP LOCKED` quando filas — ver [references/postgres-locking-transactions.md](references/postgres-locking-transactions.md).
- **Degradação ao longo do tempo:** particionamento quando apropriado; **autovacuum**, bloat, estatísticas (`ANALYZE`, `extended_statistics`).
- **Migrations:** preferir passos **reversíveis**, expansão antes de contração (add column nullable → backfill → constraint), e **rollback** documentado; avisar locks longos e janelas.
- **Operações pesadas:** `ALTER` que reescreve tabela, `VACUUM FULL`, índices sem `CONCURRENTLY` em tabelas grandes — explicar **risco operacional** e **janela de manutenção** explicitamente.

## Formato obrigatório de resposta

Toda resposta substantiva (review, plano de índice, migration, diagnóstico) deve incluir estas seções, nesta ordem:

| Seção                       | Conteúdo                                                                   |
| --------------------------- | -------------------------------------------------------------------------- |
| **Diagnóstico**             | O que foi observado ou pedido, em termos de schema/query/operação.         |
| **Hipótese principal**      | Causa ou direção mais provável (uma frase objetiva).                       |
| **Evidências esperadas**    | O que coletar (planos, `pg_stat_*`, logs, amostras de query) e por quê.    |
| **Comando ou SQL sugerido** | DDL/DML/consultas ao catálogo, com comentários de pré-requisitos.          |
| **Risco**                   | Locks, tempo, espaço em disco, impacto em réplicas, segurança.             |
| **Rollback**                | Como desfazer ou mitigar (migration down, feature flag, índice a remover). |
| **Validação pós-mudança**   | Queries/métricas para confirmar melhora ou ausência de regressão.          |

## Workflows

### 1. Review de query lenta

1. Capturar SQL parametrizado e cardinalidades esperadas.
2. `EXPLAIN` (e `EXPLAIN ANALYZE` se permitido); verificar seq scan inesperado, nested loop em grandes conjuntos, sort/hash excessivos.
3. Checar estatísticas e skew; hipótese de índice só com predicado alinhado.
4. Resposta no **formato obrigatório**.

### 2. Criação de tabela em produção

1. Confirmar schema, PK, FKs, defaults, comentários (`COMMENT ON`).
2. Ordem: criar tabela vazia → índices necessários (avaliar `CONCURRENTLY` se aplicável após carga inicial) → FKs que referenciam tabelas grandes com plano de lock.
3. Plano de backfill se houver dados iniciais; risco e rollback explícitos.

### 3. Revisão de schema

Usar [references/postgres-review-rubric.md](references/postgres-review-rubric.md) e [references/postgres-modeling.md](references/postgres-modeling.md); cobrir nomenclatura, tipos, constraints, multi-tenant, extensões.

### 4. Diagnóstico de deadlock

1. Logs com `deadlock detected`; identificar ordem de acesso às linhas/tabelas.
2. Sugerir redução de transação, ordem fixa de locks, `FOR UPDATE` explícito onde couber, evitar hot rows.
3. Evidências: `pg_locks`, traces da aplicação; formato obrigatório.

### 5. Estratégia de indexação

1. Listar queries e predicados (WHERE, JOIN, ORDER BY).
2. Para cada índice candidato: tipo (btree/GIN/GiST/BRIN/partial/expression), cobertura vs redundância, custo de manutenção.
3. Preferir **um índice bem desenhado** a vários sobrepostos.

### 6. Migração com baixo downtime

1. Expandir (add nullable / new table) → deploy código compatível → backfill em batches → validar → adicionar constraint/index `CONCURRENTLY` → contrair (drop antigo) em fase separada.
2. Documentar rollback em cada fase; ver [references/postgres-safety-checklist.md](references/postgres-safety-checklist.md).

### 7. Revisão de segurança e privilégios

1. Princípio do menor privilégio; roles separadas para app/migration/readonly.
2. RLS quando multi-tenant; evitar `SUPERUSER` na aplicação.
3. Auditoria: quem pode `COPY`, funções `SECURITY DEFINER`, extensões.

## Referências (progressive disclosure)

- [references/postgres-modeling.md](references/postgres-modeling.md) — modelo de dados e constraints.
- [references/postgres-indexing.md](references/postgres-indexing.md) — tipos de índice e custo.
- [references/postgres-locking-transactions.md](references/postgres-locking-transactions.md) — transações e locks.
- [references/postgres-safety-checklist.md](references/postgres-safety-checklist.md) — checklist operacional.
- [references/postgres-review-rubric.md](references/postgres-review-rubric.md) — rubrica de revisão.

## Integração com o repositório

Alinhar nomenclatura e migrations ao padrão existente no subprojeto (`src/main/resources/db/migration/` para Flyway, ou equivalente). Não alterar regras de negócio sem pedido explícito. Ver `15-database-flyway-testcontainers.mdc` para política de migrations.
