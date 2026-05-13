---
name: db-migrate
description: Apply schema/data migrations safely with append-only discipline, tenant-safety checks, and verification evidence.
---

# DB Migrate

## Required Inputs

- migration objective
- affected schema/tables/queries
- rollback/fallback expectations
- validation commands

## Mandatory Flow

1. identify repository migration tooling (Flyway/Prisma/other)
2. create append-only migration artifact
3. run migration in local/dev validation environment
4. validate impacted queries/repositories/tests
5. document rollout and rollback considerations

## Guardrails

- never rewrite applied migrations
- protect tenant boundaries in schema/query changes
- avoid silent destructive changes without mitigation

## Output

- migration files created
- validation evidence
- risk and rollback notes
