---
name: new-adapter
description: Create a new adapter implementation for persistence/integration/messaging with port contract alignment and failure-safe behavior.
---

# New Adapter

## Required Inputs

- target port contract
- external dependency/protocol details
- error/retry expectations
- observability requirements

## Mandatory Flow

1. confirm or define output **or** input port contract (inbound external triggers use `adapters/in` → `port/in`; see `10-java-hexagonal.mdc`)
2. implement adapter in `infrastructure` (outbound) **or** `adapters/in` (external inbound)
3. map external/persistence models to domain or use-case contract
4. add tests for success/failure/retry paths
5. wire DI/registration and validate integration

## Guardrails

- no domain business rules inside adapter
- persistence adapters respect **Flyway append-only** and schema owned by the service (`15-database-flyway-testcontainers.mdc`)
- queries/commands **tenant-scoped** when dados são por tenant (`18-tenant-isolation.mdc`)
- avoid ambiguous null-style error outcomes
- keep external protocol details encapsulated

## Output

- adapter contract compliance summary
- failure behavior evidence
- operational notes (timeouts/retries/logging)
