---
name: new-feature
description: Deliver a new feature slice with clear boundaries, test coverage, integration points, and release-safe validation.
---

# New Feature

## Required Inputs

- feature objective and non-objectives
- affected user/API flows
- architecture boundaries
- acceptance criteria and validation harness

## Mandatory Flow

1. define scope and feature boundary
2. design contracts/types (input/output/state/events)
3. implement minimal vertical slice with tests
4. integrate into route/page/workflow
5. validate regressions on adjacent flows
6. run posttask and publish evidence

## Quality Checks

- feature internals are not leaked to unrelated modules
- error/loading/empty states are explicit where applicable
- tenant/auth/security implications are covered when relevant

## Output

- changed files grouped by contract/implementation/integration
- test and validation evidence
- follow-up backlog (if any)
