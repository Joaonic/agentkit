---
name: lint-fix
description: Apply lint/static-analysis fixes safely, then revalidate clean state.
---

# Lint Fix

## Procedure

1. run lint/static checks for touched stack
2. apply safe autofixes
3. resolve remaining issues manually
4. re-run lint/type checks and confirm clean state

## Stack Hints

Web:
- `yarn lint`

Java:
- run configured static checks (checkstyle/pmd/spotbugs) when present

## Output

- commands executed
- unresolved violations (if any)
- final lint/type status
