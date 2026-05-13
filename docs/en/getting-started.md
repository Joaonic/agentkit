# Getting Started with AgentKit

Get your project governed in under 5 minutes.

## Prerequisites

- Git installed
- One of: [Cursor](https://cursor.sh), [VS Code + GitHub Copilot](https://github.com/features/copilot), [Windsurf](https://codeium.com/windsurf), or any AI coding agent
- One of: `gh` CLI (GitHub) or `glab` CLI (GitLab)

## Step 1: Install your VCS CLI

### GitHub

```bash
brew install gh          # macOS
sudo apt install gh      # Ubuntu/Debian
winget install GitHub.cli # Windows

gh auth login            # Login via browser
gh auth status           # Verify: ✓ Logged in
```

### GitLab

```bash
brew install glab        # macOS
sudo apt install glab    # Ubuntu/Debian

glab auth login          # Login via browser
glab auth status         # Verify: ✓ Logged in
```

## Step 2: Install AgentKit

```bash
cd your-project

# One-liner (auto-detects provider):
curl -sL https://raw.githubusercontent.com/Joaonic/agentkit/main/install.sh | bash

# Or explicit:
curl -sL https://raw.githubusercontent.com/Joaonic/agentkit/main/install.sh | bash -s -- --provider github --tier free
```

## Step 3: Verify installation

```bash
ls .cursor/skills/       # Should list skill directories
ls .cursor/rules/        # Should list .mdc files
ls .cursor/agents/       # Should list .md files
cat AGENTS.md            # Should show AgentKit overview
```

## Step 4: Use it

Open your project in Cursor (or VS Code with Copilot) and interact with the agent:

### Plan first
> "Use the new-plan skill to create a plan for adding user authentication"

### Implement with TDD
> "Use the tdd-workflow skill to implement the authentication feature"

### Review
> "Use the review-open-pr skill to review this PR"

### Validate
> "Use the posttask skill to validate everything before we finish"

## What happens behind the scenes

1. **Rules** are automatically loaded by Cursor based on file globs. They act as always-on guardrails.
2. **Skills** are invoked explicitly — they guide the agent through multi-step workflows.
3. **Agents** are specialized personas that the agent can assume for specific tasks.
4. **Quality gates** block the agent from completing work without evidence.

## Next steps

- Browse the [Skills Catalog](skills-catalog.md)
- Read the [Rules Reference](rules-reference.md)
- Learn about [Pipeline Scripts](pipeline-guide.md) (Pro)
- Create your own [Custom Skills](creating-skills.md)

## Upgrade to Pro

The free tier gives you essential governance. Pro unlocks:
- 67 skills (including 22 GoF design patterns, database workbenches, audit tools)
- 51 rules (Java/Spring Boot, NestJS, React/Next.js, security, observability)
- 11 agents (architecture, AI orchestration, project management, UX review)
- 4 pipeline scripts (autonomous implement → review → merge loop)
- 8-phase workflow documentation

**[Get AgentKit Pro →](https://github.com/Joaonic/agentkit)**
