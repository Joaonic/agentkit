---
name: add-skill
description: Create or upgrade a skill with executable workflow, quality gates, and clear output contracts.
---

# Add Skill

## Required Inputs

- skill objective
- target repository stack/context
- expected user outcome

## Mandatory Flow

1. choose kebab-case skill name
2. create `.cursor/skills/<name>/SKILL.md`
3. set frontmatter:
   - `name` (must match folder)
   - `description` (action-oriented)
4. include sections:
   - purpose/when-to-use
   - required inputs
   - mandatory procedure
   - blocking conditions
   - expected output
5. verify consistency with rules/workflow docs

## Quality Gates

- no slash-command notation
- no placeholder/vague body
- operationally executable guidance
- no contradiction with repository VCS/architecture policy
