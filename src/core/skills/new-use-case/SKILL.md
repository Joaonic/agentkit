---
name: new-use-case
description: Create a new application use case with explicit input/output contracts, orchestration logic, and test-backed behavior.
---

# New Use Case

## Required Inputs

- use-case objective
- domain constraints and invariants
- required output ports/integrations
- acceptance criteria

## Mandatory Flow

1. define input/output contracts
2. define/confirm needed ports (`port/in`, `port/out`)
3. implement orchestration in application layer
4. add tests for happy path and failure paths
5. wire use-case into transport/controller boundary

## Guardrails

- preserve dependency direction (application -> ports)
- no framework/infrastructure leakage in use-case logic
- keep transactional/error behavior explicit

## Output

- contract + orchestration summary
- tests and evidence
- integration points touched
