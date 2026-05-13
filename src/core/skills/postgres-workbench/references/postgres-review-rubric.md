# PostgreSQL — rubrica de revisão (schema / query / migration)

Use esta lista como guia; adapte ao contexto (OLTP vs analytics, multi-tenant, tamanho das tabelas). Complemente com o manual oficial da **versão** do servidor.

## Schema e modelo

| Critério     | Pergunta                                                                 |
| ------------ | ------------------------------------------------------------------------ |
| PK           | Toda tabela tem identificador estável e indexado?                        |
| FK           | Referências explícitas com ação de delete/update correta?                |
| Unicidade    | `UNIQUE` onde o negócio exige?                                           |
| Domínio      | `CHECK` / tipos adequados (sem float para dinheiro)?                     |
| Nulidade     | `NOT NULL` + `DEFAULT` coerentes?                                        |
| Nomenclatura | Consistência (`snake_case`, singular/plural conforme padrão do projeto)? |
| Comentários  | `COMMENT ON` para tabelas/colunas não óbvias?                            |

## Queries

| Critério       | Pergunta                                                                         |
| -------------- | -------------------------------------------------------------------------------- |
| Plano          | `EXPLAIN` / `EXPLAIN ANALYZE` revisado?                                          |
| Parametrização | Literais evitados onde causam plan cache ruim (contexto app)?                    |
| Selectividade  | Predicados sargáveis (sem função na coluna indexada, salvo índice de expressão)? |
| Agregações     | GROUP BY / DISTINCT necessários e baratos?                                       |
| Limite         | `LIMIT` + `ORDER BY` alinhados a índice quando crítico?                          |

## Índices

| Critério     | Pergunta                                               |
| ------------ | ------------------------------------------------------ |
| Necessidade  | Índice cobre predicado real de produção?               |
| Tipo         | btree vs GIN vs GiST vs BRIN vs parcial — justificado? |
| Redundância  | Dois índices com prefixo sobreposto sem motivo?        |
| Escrita      | Impacto em ingestão e autovacuum considerado?          |
| Concorrência | `CONCURRENTLY` em produção para tabelas grandes?       |

## Transações e concorrência

| Critério   | Pergunta                                             |
| ---------- | ---------------------------------------------------- |
| Duração    | Transação mínima necessária?                         |
| Locks      | Ordem de `FOR UPDATE` definida para evitar deadlock? |
| Isolamento | Nível adequado sem excesso de retries?               |

## Segurança e governança

| Critério  | Pergunta                                   |
| --------- | ------------------------------------------ |
| Roles     | Princípio do menor privilégio?             |
| RLS       | Políticas corretas para multi-tenant?      |
| Extensões | Só as aprovadas; quem pode criar extensão? |

## Migration

| Critério  | Pergunta                                       |
| --------- | ---------------------------------------------- |
| Fases     | Expandir → backfill → contrair respeitado?     |
| Lock      | DDL pode trancar produção? Alternativa online? |
| Rollback  | Passo anterior reversível documentado?         |
| Validação | Métricas/queries pós-deploy definidas?         |

## Saída esperada da revisão

A conclusão deve seguir o formato da skill: **diagnóstico**, **hipótese principal**, **evidências esperadas**, **SQL sugerido**, **risco**, **rollback**, **validação pós-mudança**.
