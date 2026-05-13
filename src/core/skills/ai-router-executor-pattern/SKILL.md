---
name: ai-router-executor-pattern
description: Greeter <1s, Router com Structured Outputs, executor assíncrono BullMQ, XState state machine.
---

# AI Router Executor Pattern

## Quando usar

Ao editar pipeline de conversação, Router, Composer, state machine.

## Fluxo

1. **Greeter** — ack imediato; sem tools
2. **Router** — classifica intent; Structured Outputs; disable parallel tool calls
3. **Executor** — job BullMQ; retrieval programático primeiro; LLM para compor mensagem
4. **XState** — estados em Postgres; transição a cada event
5. **Safety Filter** — pós-LLM; forbidden tokens

## Referências

- Skills: xstate-conversation-machine, openai-structured-stt
- Rule: @tool-call-policy.mdc
- AGENTS.md

## MCP e documentação oficial

- Guia central MCP/docs: `docs/governance/skills/mcp-reference-by-skill.md` (seção `ai-router-executor-pattern`)
