# Cursor Setup

## Required Structure

- `.cursor/rules`
- `.cursor/skills`
- `.cursor/agents`
- `.cursor/plans`
- `.cursor/mcp.json`
- `.cursor/settings.json`
- `AGENTS.md`
- `docs/governance/cursor/*`

## Validation Rules

- Skill frontmatter `name` must match skill folder name.
- Skill descriptions must be action-oriented and executable.
- Rules must be enforceable and stack-aware.
- No `.cursor/commands` directory.
- No slash-style command references in docs/rules/skills/agents.

## Repository Adaptation

- Java repos: keep Java/hexagonal/flyway/testcontainers rules and Java validation commands.
- Bun repos: keep TypeScript/runtime/integration rules and Bun validation commands.
- Web repos: keep Next.js/React/UX rules and web validation commands.
- GitLab repos: `glab` only.
- GitHub exception repo: `gh` only.

## Done Criteria For Setup

- governance files exist and are linked
- skill catalog is non-placeholder
- rule set has no contradictory duplicates
- docs/cursor (if present) is bridge-only
