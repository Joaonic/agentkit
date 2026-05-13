---
name: ai-guardrails-and-redaction
description: Forbidden tokens, Safety Filter, redaction de IDs e termos técnicos, POLICIES.md.
---

# AI Guardrails and Redaction

## Quando usar

Ao editar Safety Filter, prompts, políticas de resposta, logging, ou domain language.

## Domain Language Guard

Teste `architecture-domain-language.spec.ts` proíbe vocabulário de provider no `domain/`:

- **Path tokens proibidos:** shopify, stripe, openai, gemini, elevenlabs, langfuse, prisma
- **Content patterns proibidos:** mesmos + metaCatalog, metaErrorCode
- Excepções registadas em `PATH_TOKEN_EXCEPTIONS`

Rodar `yarn workspace @repo/api test -- architecture-domain-language` para validar.

## Safety Filter

- `ProhibitedPromiseSafetyGuardrailPolicy` — determinístico, pós-LLM
- `AnalyzeSafetyFilterViolationUseCase` — analisa violações
- `SafetyFilterContext` em `correlation-context.ts` — metadata (set quando filter dispara)
- `safetyFilterOptions` por conversation flow: `vocabularyAllowlist`, `fallbackMessage`

## PII Redaction

- `redactPii()` em `@repo/shared` — usado no batch-eval export e AI Studio
- Aplicar antes de guardar em logs, traces, ou export de dados

## Regras

- **Nunca expor** — "Shopify", "customerId", IDs brutos, gid://
- **Merchant allowlist** — vocabulário permitido por tenant (regulado via `safetyFilterOptions`)
- **Redaction** — logs, traces; PII e payloads sensíveis

## Referências

- POLICIES.md
- Rules: @tool-call-policy.mdc, @02-ai-orchestration.mdc, @03-data-security.mdc

## MCP e documentação oficial

- Guia central MCP/docs: `docs/governance/skills/mcp-reference-by-skill.md` (seção `ai-guardrails-and-redaction`)
