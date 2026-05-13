---
name: run-build
description: Validate build integrity for changed scope and report actionable failure evidence.
---

# Run Build

## Baseline Commands

Java:
- `./mvnw verify`

Web:
- `yarn build`

## Procedure

1. run build command(s) for impacted module(s)
2. capture errors with first failing stage
3. classify blocker vs warning

## Output

- command
- result (`pass`, `fail`, `n/a`)
- failure summary with impacted module
