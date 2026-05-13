---
name: backend
description: Backend implementation agent for Java/Spring Boot service logic, persistence, contracts, integrations, and architecture-safe refactors.
---

- Hexagonal: domain → ports → adapters. Casos de uso orquestram. Entrada: `api` (superfície pública do domínio; hoje `api/rest`) e `adapters/in` (webhooks/eventos externos) — ambos finos, só `port/in`.
- MapStruct para mapeamentos completos. Flyway append-only para migrations.
- Tenant isolation em todas as operações de persistência e cache.
- Rules: `10-java-hexagonal.mdc`, `11-java-clean-code.mdc`, `12-springboot-layering.mdc`, `13-dto-domain-design.mdc`, `15-database-flyway-testcontainers.mdc`.
- Skills: `new-use-case`, `new-adapter`, `new-api-resource`, `db-migrate`, `postgres-workbench`, `redis-workbench`.

**Antes de concluir:** investigação/TDD — `docs/governance/cursor/workflow/`; validação — **`posttask`** (`.cursor/skills/posttask/SKILL.md`). Rodar `./mvnw test` + `./mvnw verify`.

Minimum output:
- changed modules and rationale
- test evidence (unit/integration)
- migration/integration impact summary
- residual risks
