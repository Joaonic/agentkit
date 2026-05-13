---
name: frontend-design
description: Create distinctive, production-grade frontend interfaces with high design quality. Use when building web components, pages, or applications. Avoids generic AI aesthetics.
---

# Frontend Design

Use when creating UI: componentes, páginas, layouts. Gera interfaces distintivas e polidas que evitam "AI slop" (Inter, gradientes roxo, layouts genéricos).

## Design Thinking

Antes de codar, definir direção estética clara:

- **Propósito:** Que problema a interface resolve? Para quem?
- **Tom:** Minimalista brutal, maximalista, retro-futurista, editorial, industrial, orgânico, etc.
- **Diferenciação:** O que torna a interface memorável?
- **Restrições:** Framework, performance, acessibilidade.

_CRÍTICO:_ Escolher uma direção e executar com consistência.

## Guidelines de Estética

- **Tipografia:** Fontes distintivas (evitar Inter, Roboto, Arial). Par display + body refinado. Ex.: Bricolage Grotesque, Source Serif 4, Satoshi, Syne.
- **Cor e tema:** Paleta coerente. CSS variables. Cores dominantes + acentos.
- **Motion:** Animações para micro-interações. CSS primeiro; Motion (React) quando disponível. Staggered reveals, scroll-triggered, hover surpreendente.
- **Layout:** Assimetria, overlap, espaços. Quebrar grid padrão quando fizer sentido.
- **Backgrounds:** Profundidade, textura, gradiente mesh, noise sutil, grain overlay.

## Anti-Patterns (NUNCA usar)

- Inter, Roboto, Arial, Space Grotesk
- Gradientes roxo/indigo sobre branco
- Layouts cookie-cutter 3 colunas iguais
- Estética genérica de IA
- Componentes sem personalidade contextual

## Implementação

- Código production-grade e funcional
- Visualmente impactante e memorável
- Coerente com direção estética
- Detalhes refinados (spacing, contrast, motion)

## Referências

- Rules: `20-web-nextjs.mdc`, `21-web-react.mdc`
- Skills de componente: `new-ui-component`, `new-widget`, `new-feature`
