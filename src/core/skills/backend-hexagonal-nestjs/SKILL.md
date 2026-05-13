---
name: backend-hexagonal-nestjs
description: NestJS 11+, ports/adapters, DTOs, Commands/Queries, OpenAPI/Scalar, Orval.
---

# Backend Hexagonal NestJS

## Quando usar

Ao editar `apps/api/**`, `packages/**` (backend).

## Princípios

- **Hexagonal** — domain → ports → adapters; sem lógica em controllers
- **Commands/Queries** — imutáveis; repositórios nunca retornam null
- **OpenAPI** — @ApiTags, @ApiOperation, @ApiProperty em controllers e DTOs
- **Orval** — client gerado de `/openapi.json`; rodar `yarn gen:api` (root) ou `yarn gen:api:sync` (exporta spec + gera + formata) após mudar API

## Referências

- Rules: @hexagonal-backend.mdc, @backend-nestjs.mdc
- Skill: openapi-orval-nextauth

## MCP e documentação oficial

- Guia central MCP/docs: `docs/governance/skills/mcp-reference-by-skill.md` (seção `backend-hexagonal-nestjs`)
