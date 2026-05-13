# Frequently Asked Questions

## General

### What is AgentKit?
A governance framework (skills, rules, agents, pipeline scripts) that enforces engineering discipline on AI coding agents like Cursor, GitHub Copilot, Windsurf, Cline, etc.

### Does AgentKit generate code?
No. AgentKit doesn't generate code — it makes your AI agent generate *good* code by enforcing TDD, reviews, quality gates, and architectural rules.

### Which AI tools does it work with?
- **Cursor** — Full native support (`.cursor/rules/`, `.cursor/skills/`, `.cursor/agents/`)
- **GitHub Copilot** — Via `.github/copilot-instructions.md` and `.github/skills/`
- **Windsurf** — Via `.windsurfrules` (manual adaptation)
- **Cline** — Via `.clinerules` (manual adaptation)
- **Any CLI agent** — Reads `AGENTS.md`

### Does it work with both GitHub and GitLab?
Yes. Install with `--provider github` or `--provider gitlab`. The pipeline scripts, VCS rules, and terminology adapt to your provider.

## Installation

### Will it overwrite my existing `.cursor/` files?
By default, the installer merges — it only adds files that don't exist. Use `--force` to overwrite.

### Can I cherry-pick which skills/rules to install?
Yes. Use the manual copy method and pick individual files from the package.

### How do I update?
Re-run the install script with `--force`, or pull the latest repo and rebuild.

## Skills

### How do I use a skill?
Reference it in your conversation with the AI agent:
> "Use the tdd-workflow skill to implement this feature"

### Can I create my own skills?
Yes. See [Creating Skills](creating-skills.md). Drop a `SKILL.md` into `.cursor/skills/your-skill/`.

### What's the difference between skills, rules, and agents?
- **Skills** = workflows you invoke explicitly (step-by-step guides)
- **Rules** = guardrails loaded automatically (always-on constraints)
- **Agents** = specialized personas (domain expertise + standards)

## Pipeline

### What are the pipeline scripts?
4 bash scripts that orchestrate AI agents to implement, review, and merge code autonomously across multiple projects using git worktrees for parallelism.

### Do I need the pipeline scripts?
No. They're a Pro feature for automated batch processing. You can use skills, rules, and agents without them.

### What does the pipeline need to run?
- `copilot` CLI installed and authenticated
- `gh` or `glab` CLI installed and authenticated
- Git configured
- A project with issues

## Pricing

### Is the free tier really free?
Yes. MIT-licensed. 14 skills, 10 rules, 4 agents. No limitations, no expiry.

### What does Pro add?
53 more skills (design patterns, database workbenches, audit tools), 41 more rules (Java, NestJS, React, security), 7 more agents, 4 pipeline scripts, and workflow documentation.

### Is Pro a one-time purchase?
Yes. $79 one-time. The Team tier ($199) adds 1 year of updates and priority support.
