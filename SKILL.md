# SKILL.md

This file lists reusable skills the agent can offer to create. Add a section when the agent detects a repeatable pattern.

## create-addon
Purpose: Scaffolds a new addon in a repo using a template, CI, tests and documentation.
Steps:
1. Inspect repo layout and find similar addons via git history search.
2. Create files from template and open a PR draft.
3. Run unit tests and CI checks (dry-run).
4. Write lessons learned to memory with verification status.

Metadata:
- triggers: ["create addon", "new addon", "add addon"]
- file-types: ["ts","py","bicep","ps1"]
- requires-approval: true


Add new skills below as the agent recommends them.
