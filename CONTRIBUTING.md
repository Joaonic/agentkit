# Contributing to AgentKit

Thank you for your interest in contributing to AgentKit!

## How to Contribute

### Creating a new Skill

1. Fork this repository
2. Create a new directory: `src/core/skills/your-skill-name/`
3. Create `SKILL.md` inside it following the template below
4. Submit a PR with a clear description

**Skill template:**

```markdown
# Skill: your-skill-name

> One-line description of what this skill does.

## When to Use

- Situation 1
- Situation 2

## Workflow

### Step 1 — Name
Description of what to do.

### Step 2 — Name
Description of what to do.

## Quality Gates

- [ ] Gate 1
- [ ] Gate 2

## Output

What the skill produces when complete.
```

### Creating a new Rule

1. Create a `.mdc` file in `src/core/rules/`
2. Follow the naming convention: `NN-rule-name.mdc`
3. Include `description`, `globs`, and `alwaysApply` metadata
4. Submit a PR

### Creating a new Agent

1. Create a `.md` file in `src/core/agents/`
2. Define the agent's role, expertise, and constraints
3. Submit a PR

## Code of Conduct

Be respectful, constructive, and inclusive. We follow the [Contributor Covenant](https://www.contributor-covenant.org/).

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
