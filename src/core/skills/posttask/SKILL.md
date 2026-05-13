---
name: posttask
description: Execute mandatory final validation checks and publish command-level evidence before completion.
---

# Posttask

## Mandatory Gate

No task is complete without posttask evidence.

## Stack Command Sets

Java repositories:
- `./mvnw test`
- `./mvnw verify`

Next/React repositories:
- `yarn lint`
- `yarn build`
- `yarn test` (when script exists)

## Application Context Smoke Test (rule `31-application-context-smoke-test.mdc`)

For every `apps/*` Java subproject touched:

1. **Verify** that `ApplicationContextSmokeTest.java` exists with `@SpringBootTest` + Testcontainers. A plain JUnit test that instantiates DTOs is NOT a smoke test — it must boot the full Spring context.
2. **Run** `./mvnw test -Dtest="ApplicationContextSmokeTest"` explicitly.
3. If missing or fake → **create a real smoke test** before proceeding (see rule 31 for pattern).
4. If the smoke test **fails** → **BLOCKER**. Diagnose and fix the application (NOT the test). The application context must start successfully with all beans wired.

## Reporting Contract

For each command report:
- command
- result (`pass`, `fail`, `n/a`)
- concise evidence/failure summary

## Blocker Policy

- any failed mandatory check blocks completion
- smoke test failure is a BLOCKER — fix the application, not the test
- missing tooling must be explicit (`binary not found`)
- failed checks cannot be hidden in aggregate summary

## Required Output

- validation evidence table (must include smoke test result)
- explicit blocker list or no-blocker statement
