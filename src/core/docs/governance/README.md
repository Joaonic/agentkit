# Cursor Governance

`docs/governance/cursor` is the only normative source for Cursor process in this repository.

## Principles

- skills and agents only
- no `.cursor/commands` directory
- no slash-style command notation
- single canonical source for governance
- repository-specific adaptation by stack and VCS

## Canonical Documents

- `setup.md`
- `workflow.md`
- `workflow/00-overview.md` to `workflow/08-skills-by-context.md`
- `mcp.md`
- `AGENTS.md`

## Enforcement

- Rule `05-docs-canonical-source.mdc` blocks duplicate normative sources.
- Rule `06-vcs-policy.mdc` enforces VCS vocabulary and CLI.
- Rule `30-posttask.mdc` requires command-level validation evidence.

## VCS Policy

Default: GitLab (`glab`, MR).  
Exception: `web/your-github-project` (GitHub, `gh`, PR).
