# MCP

MCP configuration lives in `.cursor/mcp.json`.

## Policy

- keep only servers that are actively used by workflows
- remove speculative or stale servers
- document each server purpose near onboarding docs when needed

## Usage Expectations

- planning/review workflows must prefer stable local/project sources first
- external connector usage must follow repository VCS policy
- MCP usage must not bypass architecture/security rules
