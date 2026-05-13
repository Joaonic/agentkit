---
name: posttask-workspace-lint
description: Executar lint/type-check/build/testes nos subprojetos realmente tocados (apps/, web/, libraries/) antes de concluir — não assumir apenas scripts na raiz do monorepo.
---

# Posttask Workspace Lint

## Objetivo

No monorepo YourProject, qualidade local vive **no subprojeto**. Antes de declarar conclusão, rodar os comandos que o **próprio módulo** define (`README`, `package.json`, `pom.xml`), agrupados por pasta tocada.

## Quando é obrigatório

- Qualquer alteração sob `apps/<serviço>/`, `web/<app>/`, ou `libraries/<lib>/`.
- Consultar **`AGENTS.md`** e **README** do subprojeto quando existirem (`40-submodule-governance.mdc`).

## Detecção de escopo

1. A partir de `git diff`, lista de ficheiros, ou instrução explícita do utilizador → extrair prefixos de primeiro nível (`apps/foo`, `web/bar`, …).
2. Agrupar por subprojeto (segmento imediato após `apps/`, `web/`, `libraries/`).
3. Mudanças **só** em `docs/`, `.cursor/`, scripts na raiz sem tocar código de app → pode não haver módulo Maven/Yarn; marcar comandos como `n/a` com motivo.

## Comandos padrão (sobrescrever pelo README local)

| Área | Onde executar | Comandos típicos |
|------|----------------|------------------|
| Backend Java | Diretório com `pom.xml` do serviço | `./mvnw verify` ou `./mvnw test` |
| Library Java | Raiz da biblioteca | `./mvnw verify` / `./mvnw test` |
| Frontend | Raiz do app (`package.json`) | `yarn lint`, `yarn build`, `yarn test` (se scripts existirem) |

Se só uma classe ou pacote mudou e `verify` for pesado, pode usar alvo restrito **desde que** o README/CI do projeto aceite (ex.: `./mvnw -pl modulo test` quando multi-módulo).

## Relatório obrigatório

Tabela:

| Subprojeto | Diretório | Comando | Resultado (`pass` / `fail` / `n/a`) | Notas |

- Qualquer `fail` **bloqueia** conclusão (alinhado a `posttask` / `30-posttask.mdc`).
- `n/a` só com razão explícita (ex.: alteração só em Markdown na raiz).

## Relação com outras skills

- **`posttask`** — gate global de evidência; esta skill **especializa** por workspace no monorepo.
- **`lint-fix`** — usar quando falhas forem corrigíveis por autofix seguro no escopo tocado.
