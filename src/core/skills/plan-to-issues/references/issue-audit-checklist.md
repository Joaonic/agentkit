# Agent-Ready Issue Audit Checklist

## Identity and Dedupe

- [ ] title matches scope
- [ ] source plan path present
- [ ] fingerprint present when generated from plan
- [ ] no duplicate issue with same intent

## Metadata

- [ ] exactly one type label
- [ ] exactly one priority label
- [ ] one or more area labels
- [ ] milestone resolved or explicit `needs-research`
- [ ] dependency status explicit (`blocked` when applicable)

## Spec Quality

- [ ] objective is clear and observable
- [ ] in-scope and out-of-scope explicit
- [ ] requirements are numbered and testable
- [ ] edge cases documented
- [ ] technical context and likely files listed

## Harness and QA

- [ ] validation harness has concrete commands
- [ ] required tests listed by level
- [ ] QA package includes scenario matrix and BDD
- [ ] regression checklist included

## Architecture

- [ ] architecture block present when refactor/pattern change exists
- [ ] pattern choice and alternatives documented
- [ ] required skills declared

## Readiness

- [ ] issue implementable without chat history
- [ ] done definition is objective
