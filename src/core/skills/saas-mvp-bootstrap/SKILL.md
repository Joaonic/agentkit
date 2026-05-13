---
name: saas-mvp-bootstrap
description: Como iniciar e rodar o repo localmente; Docker Compose; webhooks Meta/Shopify/Stripe; Langfuse/OTel; commands do Cursor.
---

# SaaS MVP Bootstrap

## Quando usar

Ao configurar ambiente de desenvolvimento, onboarding de novos devs, ou verificar se o setup está correto.

## Passos

1. **Docker Compose** — `docker compose up -d postgres redis` (obrigatório); `docker compose up -d mailpit` (dev SMTP, opcional)
2. **Env** — copiar `.env.example`, preencher credenciais (ver `AGENTS.md` para env vars obrigatórias)
3. **Migrations** — `yarn db:migrate` (interactivo) ou `yarn db:migrate:deploy` (CI/não-interactivo)
4. **API** — Ver `AGENTS.md` secção "Running the API" para workaround Node 24 com `ts-node/esm`
5. **Web** — `yarn dev:web` (Next.js na porta 3000)
6. **Webhooks** — Meta (WABA), Shopify, Stripe; configurar URLs e tokens
7. **Langfuse/OTel** — variáveis LANGFUSE\_\*, OTLP endpoint
8. **Atalhos** — `/run-build`, `/run-tests`, `/posttask` → ficheiros em `.cursor/skills/<nome>/SKILL.md`

## Referências

- README.md — quick start
- docs/reference/architecture/integrations.md — secrets e endpoints

## MCP e documentação oficial

- Guia central MCP/docs: `docs/governance/skills/mcp-reference-by-skill.md` (seção `saas-mvp-bootstrap`)
