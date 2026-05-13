---
name: run-tests
description: Execute repository test suites by stack and report objective pass/fail evidence.
---

# Run Tests

## Baseline Commands

Java:
- `./mvnw test`

Web:
- `yarn test` (if script exists)

## Procedure

1. choose commands relevant to touched scope
2. execute commands
3. capture pass/fail evidence
4. summarize failing suites with likely impact

## Output

- command
- result (`pass`, `fail`, `n/a`)
- evidence summary
