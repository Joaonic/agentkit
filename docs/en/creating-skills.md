# Creating Custom Skills

Skills are the core of AgentKit — executable workflows that guide AI agents step by step.

## Skill Structure

```
.cursor/skills/your-skill-name/
├── SKILL.md              # Required: the skill definition
└── references/           # Optional: reference docs, templates
    ├── template.md
    └── checklist.md
```

## SKILL.md Template

```markdown
# Skill: your-skill-name

> One-line description.

## When to Use

- Use when...
- Don't use when...

## Prerequisites

- [ ] Prerequisite 1
- [ ] Prerequisite 2

## Workflow

### Step 1 — Investigation

1. Do this first
2. Then do this
3. Verify with: `command`

### Step 2 — Implementation

1. Create file X
2. Implement Y
3. Run tests: `command`

### Step 3 — Validation

1. Run `command`
2. Verify output matches expected
3. Check quality gates

## Quality Gates

- [ ] All tests pass
- [ ] No lint errors
- [ ] Code reviewed
- [ ] Documentation updated

## Anti-patterns

- Don't do X
- Avoid Y

## Output

When this skill completes, you should have:
- [ ] Deliverable 1
- [ ] Deliverable 2
```

## Best Practices

1. **Be specific** — Each step should be actionable, not vague
2. **Include commands** — Give exact commands to run
3. **Add quality gates** — Define what "done" looks like
4. **Add anti-patterns** — Tell the agent what NOT to do
5. **Keep it focused** — One skill = one workflow
6. **Use references** — Put templates and checklists in `references/`

## Adding to AgentKit

1. Create your skill in `.cursor/skills/your-skill-name/SKILL.md`
2. Test it by asking your AI agent to use it
3. Refine based on results
4. Submit a PR to the AgentKit repo (see [CONTRIBUTING.md](../../CONTRIBUTING.md))

## Skill Categories

| Category | Naming Pattern | Examples |
|----------|---------------|----------|
| Planning | `new-*`, `create-*` | `new-plan`, `create-milestone` |
| Implementation | `new-*`, `*-workflow` | `new-use-case`, `tdd-workflow` |
| Validation | `run-*`, `posttask*` | `run-tests`, `posttask` |
| Review | `review-*`, `*-audit` | `review-open-pr`, `code-audit` |
| Infrastructure | `*-workbench` | `postgres-workbench`, `redis-workbench` |
| Design Patterns | `design-pattern-*` | `design-pattern-strategy` |
