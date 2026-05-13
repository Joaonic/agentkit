# Começando com AgentKit

Configure a governança do seu projeto em menos de 5 minutos.

## Pré-requisitos

- Git instalado
- Um de: [Cursor](https://cursor.sh), [VS Code + GitHub Copilot](https://github.com/features/copilot), [Windsurf](https://codeium.com/windsurf), ou qualquer agente de IA
- Um de: CLI `gh` (GitHub) ou CLI `glab` (GitLab)

## Passo 1: Instalar o CLI do seu VCS

### GitHub

```bash
brew install gh          # macOS
sudo apt install gh      # Ubuntu/Debian
winget install GitHub.cli # Windows

gh auth login            # Login via browser
gh auth status           # Verificar: ✓ Logged in
```

### GitLab

```bash
brew install glab        # macOS
sudo apt install glab    # Ubuntu/Debian

glab auth login          # Login via browser
# Ou via token: glab auth login --hostname gitlab.com --token glpat-XXXXX
glab auth status         # Verificar: ✓ Logged in
```

## Passo 2: Instalar AgentKit

```bash
cd seu-projeto

# Uma linha (auto-detecta provider):
curl -sL https://raw.githubusercontent.com/Joaonic/agentkit/main/install.sh | bash

# Ou explícito:
curl -sL https://raw.githubusercontent.com/Joaonic/agentkit/main/install.sh | bash -s -- --provider gitlab --tier free
```

## Passo 3: Verificar instalação

```bash
ls .cursor/skills/       # Deve listar diretórios de skills
ls .cursor/rules/        # Deve listar arquivos .mdc
ls .cursor/agents/       # Deve listar arquivos .md
cat AGENTS.md            # Deve mostrar visão geral do AgentKit
```

## Passo 4: Usar

Abra seu projeto no Cursor (ou VS Code com Copilot) e interaja com o agente:

### Planear primeiro
> "Use a skill new-plan para criar um plano para adicionar autenticação de usuários"

### Implementar com TDD
> "Use a skill tdd-workflow para implementar a feature de autenticação"

### Revisar
> "Use a skill review-open-pr para revisar este PR"

### Validar
> "Use a skill posttask para validar tudo antes de concluir"

## O que acontece por trás

1. **Rules** são carregadas automaticamente pelo Cursor com base em globs de arquivos. Funcionam como guardrails sempre ativos.
2. **Skills** são invocadas explicitamente — guiam o agente em workflows de múltiplos passos.
3. **Agents** são personas especializadas que o agente pode assumir para tarefas específicas.
4. **Quality gates** bloqueiam o agente de concluir trabalho sem evidência.

## Próximos passos

- Veja o [Catálogo de Skills](skills-catalog.md)
- Leia a [Referência de Rules](rules-reference.md)
- Conheça os [Pipeline Scripts](pipeline-guide.md) (Pro)
- Crie suas próprias [Skills Customizadas](creating-skills.md)

## Upgrade para Pro

O tier free dá governança essencial. O Pro desbloqueia:
- 67 skills (incluindo 22 padrões GoF, workbenches de banco de dados, ferramentas de auditoria)
- 51 rules (Java/Spring Boot, NestJS, React/Next.js, segurança, observabilidade)
- 11 agents (arquitetura, orquestração IA, gestão de projeto, review UX)
- 4 pipeline scripts (loop autônomo implement → review → merge)
- Documentação de workflow em 8 fases

**[Comprar AgentKit Pro →](https://github.com/Joaonic/agentkit)**
