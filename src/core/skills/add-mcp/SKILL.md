---
name: add-mcp
description: Add or update MCP server entries in `.cursor/mcp.json` safely with purpose, validation, and minimal footprint.
---

# Add MCP

## Required Inputs

- MCP server purpose
- server type (stdio command or remote URL)
- expected workflow usage

## Mandatory Flow

1. validate server availability and access requirements
2. add entry with unique name in `.cursor/mcp.json`
3. keep config minimal and valid JSON
4. document purpose in governance docs when needed
5. validate no duplicate/unused entries

## Quality Gates

- no broken JSON
- no duplicate server keys
- no speculative additions without workflow usage
