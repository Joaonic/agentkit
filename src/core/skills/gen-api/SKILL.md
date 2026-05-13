---
name: gen-api
description: Regenerate API artifacts after contract changes and validate deterministic output.
---

# Generate API Artifacts

## Use When

- OpenAPI/Swagger contracts changed
- client/server generated artifacts are outdated
- integration boundaries require schema sync

## Procedure

1. identify generation command in repository scripts/build
2. regenerate artifacts
3. review generated diff for deterministic consistency
4. run build/tests for impacted modules

## If No Generator Exists

Report `n/a` explicitly with reason.

## Output

- generation command used
- generated artifact paths
- validation status after regeneration
