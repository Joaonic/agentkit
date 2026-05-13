---
name: new-widget
description: Montar widget ou vista composta no frontend a partir de componentes/features existentes, com fronteiras claras, estado local mínimo e testes de composição.
---

# New Widget

## Pré-requisitos

- Identificar o **app** em `web/<nome>/` e carregar governança local (`AGENTS.md`, rules, README).
- Localizar **features/entities** já existentes para reutilizar — não duplicar formulários, tabelas ou hooks equivalentes.

## Fluxo

1. **Entrypoint** — ficheiro principal do widget (página seção, painel, card composto) no local convencionado do app (`widgets/`, `features/`, etc.).
2. **Composição** — encadear componentes menores + hooks de dados já definidos no app; manter o widget como **orquestrador de UI**, não como camada de negócio duplicada do backend.
3. **Estado** — preferir estado derivado de props/router/store existente; estado local só para UI efémera (abrir modal, tab ativa).
4. **Contratos** — tipos alinhados a DTOs/OpenAPI ou camada `api` do subprojeto; sem tipos soltos duplicados se já há gerados/compartilhados no app.
5. **Testes** — comportamento composto (interação entre peças), não só snapshot vazio; mocks nos limites da camada HTTP conforme padrão do repo.
6. **Gate de qualidade** — `yarn lint` / `yarn test` / `yarn build` conforme scripts; UX obrigatória se fluxo user-facing (`08-ux-mandatory.mdc`).

## Regras

- Negócio que já existe no backend permanece no backend; o widget chama **casos de uso expostos** (REST/actions), não reimplementa regras.
- Documentar dependências do widget (rotas, permissões, dados mínimos nas props).

## Saída esperada

- Árvore de ficheiros tocados.
- Lista de componentes/hooks reutilizados vs novos.
- Evidência de comandos ou justificativa `n/a`.
