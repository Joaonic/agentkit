---
name: openapi-orval-nextauth
description: Use when editing OpenAPI spec, Orval client, NextAuth, or API-frontend integration. Covers Scalar, decorators, mutator with accessToken.
---

# OpenAPI, Scalar, Orval, NextAuth - Skill Completa

## Contexto

O projeto usa **OpenAPI** gerado automaticamente pelo NestJS para documentar a API. A UI de documentação é **Scalar** (não Swagger UI). O frontend gera cliente tipado com **Orval** a partir de `GET /openapi.json`. **NextAuth** fornece a sessão com `accessToken` que o mutator Orval injeta em `Authorization: Bearer`. Production-ready.

## Quando usar

- Arquivos em `apps/api/**`, `apps/web/**`, `**/orval*.{ts,js}`
- Alterações em controllers/DTOs que afetam a API, mutator, client generation

## Backend: OpenAPI + Scalar

### Dependências

```bash
yarn workspace @repo/api add @nestjs/swagger @scalar/nestjs-api-reference
```

### Spec derivada de tipos (CLI plugin)

O **Swagger CLI plugin** em `nest-cli.json` gera automaticamente:

- `type`, `enum`, `required` a partir dos tipos TypeScript
- `@ApiProperty` injetado em arquivos `*.dto.ts` e `*.entity.ts`
- `classValidatorShim`: reutiliza regras do class-validator no schema
- `introspectComments`: extrai description/example de JSDoc

**Não** é necessário manter spec OpenAPI manual em JSON. A spec é 100% gerada pelo NestJS a partir dos DTOs e controllers.

### Decorators

**Controllers:** `@ApiTags`, `@ApiOperation`, `@ApiResponse`, `@ApiBearerAuth`, `@ApiParam`, `@ApiQuery`

**DTOs:** Use `@ApiProperty` / `@ApiPropertyOptional` para **descriptions, examples, enums** — o plugin preenche type/required. Override explícito quando precisar.

### CORS

- Habilitar para origem do frontend (ex: `http://localhost:3000`)
- Headers: `Authorization`, `Content-Type`
- `credentials: true` se usar cookies

## Frontend: Orval + NextAuth

### Regra obrigatória

- **Usar SOMENTE** as funções do `generated.ts` para chamadas à API própria (NestJS).
- **NUNCA** criar wrappers manuais (`fetch`, `customFetch`) para endpoints já definidos no OpenAPI — isso quebra sincronia spec ↔ client e duplica tipos.
- Novos endpoints: adicionar decorators Swagger no controller → rodar `gen:api` → usar a função gerada.

### Orval Config

- Input: `GET /openapi.json` (endpoint fixo, sem auth)
- Output: `./src/shared/api/generated.ts`
- Mutator obrigatório para injetar `Authorization: Bearer <accessToken>` via `getSession()`

### Mutator

- Sem mutator: chamadas não terão Authorization
- `getSession()` é async — mutator deve ser async
- BaseURL: usar env para dev/prod

### NextAuth Callbacks

- `jwt` e `session` devem expor `accessToken` para o mutator
- Para Shopify embedded: token pode vir do token exchange (MVP03)

## Scripts

- `gen:api` — Roda Orval. API deve estar up ou usar spec estática em CI
- Rodar `gen:api` após mudar controllers/DTOs

## CI

- Rodar `gen:api` e falhar se `git diff` mostrar alterações não commitadas

## Referências

- NestJS Swagger: https://docs.nestjs.com/openapi/introduction
- Scalar NestJS: https://github.com/scalar/nestjs-api-reference
- Orval: https://orval.dev/
- NextAuth: https://next-auth.js.org/

## MCP e documentação oficial

- Guia central MCP/docs: `docs/governance/skills/mcp-reference-by-skill.md` (seção `openapi-orval-nextauth`)
