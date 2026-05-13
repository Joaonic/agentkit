---
name: new-ui-component
description: Criar componente UI reutilizável num frontend do monorepo com props claros, acessibilidade mínima e testes alinhados ao subprojeto (yarn).
---

# New UI Component

## Pré-requisitos

1. Confirmar **app alvo** (ex.: `web/your-app`, `web/your-github-project`).
2. Ler **`AGENTS.md`**, **`.cursor/rules/`** locais e **README** do app (`40-submodule-governance.mdc`).
3. Seguir design system / pasta de componentes já existente — não inventar estrutura paralela sem pedido explícito.

## Fluxo

1. **API do componente** — props (tipadas), callbacks/eventos, variantes (size, intent). Preferir composição (slots/children) a props excessivas.
2. **Acessibilidade** — papéis ARIA quando necessário, foco por teclado, `aria-label` em ícones só-visual; alinhar a `08-ux-mandatory.mdc` quando alterações forem user-facing.
3. **Estilo** — reutilizar tokens/Tailwind/theme do projeto; evitar valores mágicos soltos se o app já tem escala.
4. **Testes** — unit/component com o runner do app (Vitest/Jest/RTL conforme `package.json`); cobrir estados críticos (loading, erro, disabled).
5. **Export** — barrel (`index.ts`) ou padrão do app para import consistente.
6. **Validação** — `yarn lint`, `yarn test` (se existir), `yarn build` quando mudança afeta tipos ou bundle.

## Regras

- Componente **apresentacional**: dados remotos via hooks/camada de API do app, não fetch direto dentro do átomo salvo padrão local explícito.
- Preferir **componentes pequenos** e composição em vez de um único ficheiro grande.
- Se o utilizador pediu apenas backend ou não há UI no scope → esta skill **n/a**.

## Saída esperada

- Caminho dos ficheiros criados/alterados.
- Resumo de props públicas e casos de teste cobertos.
- Evidência dos comandos `yarn` executados ou `n/a` motivado.
