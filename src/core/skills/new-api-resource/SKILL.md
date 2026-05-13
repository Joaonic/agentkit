---
name: new-api-resource
description: Add a new API resource with explicit transport contracts, validation, use-case integration, and documentation/test updates.
---

# New API Resource

## Required Inputs

- endpoint purpose and audience (**first-party** `api` surface — not external webhooks; those belong in `adapters/in`, see `10-java-hexagonal.mdc`)
- request/response contract
- auth/tenant requirements
- acceptance criteria

## Mandatory Flow

1. define request/response DTO or schema
2. implement or wire use-case behavior
3. add controller/handler under `api/...` (first-party public surface)
4. add tests (success, validation, authorization/error)
5. regenerate API artifacts when applicable (`gen-api`)
6. run posttask and publish evidence

## Guardrails

- transport layer remains thin
- business behavior stays outside controller/handler
- contract changes are explicit and version-safe

## Output

- endpoint contract summary
- test evidence
- artifact regeneration status
