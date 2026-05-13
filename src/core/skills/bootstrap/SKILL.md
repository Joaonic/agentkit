---
name: bootstrap
description: /bootstrap
disable-model-invocation: true
---

# /bootstrap

Cria ou atualiza o skeleton do projeto: docs, template de ADR, template de plan, regras e skills base em .cursor/.

**Ações:**

- Criar docs/reference/adrs/ com template se não existir
- Criar docs/implementation/ com subpastas (not_implemented, partial, implemented, design_only) se não existir
- Criar docs/operations/, docs/reference/security/ com placeholders
- Garantir que `.cursor/rules/` e `.cursor/skills/` têm os ficheiros base (atalhos normativos vivem em `.cursor/skills/<nome>/SKILL.md`)
- Não sobrescrever conteúdo existente sem confirmação
