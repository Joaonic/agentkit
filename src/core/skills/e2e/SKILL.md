---
name: e2e
description: Execute end-to-end validation for critical user/integration journeys and report reproducible evidence.
---

# E2E

## Use When

- user-facing journeys changed
- cross-service/integration boundaries changed
- regression impact could be high

## Mandatory Flow

1. select critical journeys first (p0/p1)
2. run configured E2E command(s)
3. capture failures with scenario, step, and repro notes
4. classify blocker vs non-blocker impact

## If No E2E Setup Exists

- report `n/a` explicitly
- recommend automation target for highest-risk flow

## Output

- journey matrix with result status
- failure evidence and repro hints
- release risk statement
