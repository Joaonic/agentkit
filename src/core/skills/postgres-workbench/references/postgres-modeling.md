# PostgreSQL — modelagem e integridade

Consulte sempre o manual da **versão major** do servidor em uso (`https://www.postgresql.org/docs/` — use o seletor de versão do site para corresponder ao ambiente).

## Integridade relacional

- **Primary key:** toda tabela deve ter chave lógica estável; prefira surrogate (`bigint`/`uuid` gerado) quando a chave natural for volátil ou composta demais.
- **Foreign keys:** declare `ON DELETE` / `ON UPDATE` explicitamente; o default pode não ser o desejado para o domínio.
- **UNIQUE:** para regras de unicidade de negócio (não duplicar índice unique sem necessidade).
- **CHECK:** invariantes de domínio no banco (faixas, enums implícitos) — evitar checks que mudam toda release sem plano.
- **NOT NULL:** colunas obrigatórias no modelo; usar `DEFAULT` só quando semanticamente correto.
- **DEFAULT:** funções imutáveis ou literais; cuidado com `now()` vs `CURRENT_TIMESTAMP` e fusos (`timestamptz` em dados de evento).

## Tipos — rigor

- **Texto:** `text` vs `varchar(n)` — `varchar(n)` só quando o limite é regra de negócio; evitar `char(n)` exceto padding intencional.
- **Números:** dinheiro e quantidades exatas → `numeric`; evitar `float`/`real` para monetário.
- **Tempo:** preferir `timestamptz` para instantes; `date` para dia civil; documentar timezone da aplicação.
- **Boolean:** uso explícito; evitar sentinelas `0/1` sem CHECK.
- **JSON:** `jsonb` para query/indexação; `json` só se preservar formatação literal importa.
- **Arrays:** úteis mas impactam ORM e validação; documentar cardinalidade máxima.

## Multi-tenant

- **Coluna `tenant_id`:** FK para tenants; índices compostos líderes com `tenant_id` em workloads filtrados por tenant.
- **RLS:** políticas testáveis; performance (cada query passa pelo qualificador) — validar com EXPLAIN.
- **Schema por tenant:** isolamento forte; custo operacional (migrations × N schemas).

## Evolução do schema

- Preferir **adicionar** colunas nullable ou com default seguro antes de tornar `NOT NULL` após backfill.
- **Renomear** em etapas com view ou sinônimo na aplicação se necessário para zero downtime.

## Referência oficial

- [SQL commands](https://www.postgresql.org/docs/current/sql-createtable.html)
- [Data types](https://www.postgresql.org/docs/current/datatype.html)
