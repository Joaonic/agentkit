---
name: code-audit
description: Perform structured code audit for correctness, architecture fit, rule adherence, and regression exposure.
---

# Code Audit

## Audit Dimensions

1. functional correctness vs acceptance criteria
2. architecture/layering/contract integrity
3. tenant/security/data-safety controls
4. observability and error handling quality
5. test adequacy and regression exposure

## Evidence Expectations

- findings include concrete file references
- severity reflects user/business impact
- each finding includes fix direction

## Output Format

- Critical findings
- High findings
- Medium findings
- Low findings
- Residual risks and suggested follow-up

If no findings:
- state explicitly no findings
- include confidence limits and testing gaps
