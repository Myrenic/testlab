# AGENTS.md

Purpose: define portable agent roles, rules and expected behavior for agents in this repo.

Rules
- Never terminate the user session. Always ask the user "Is this all?" or ask a follow-up question before stopping.
- Memory stores pointers and user-provided facts only. The repository is the single source of truth for code.
- Use parallel codebase searches for speed.
- Use AZ CLI only for readonly inspection. Never run modifies without explicit user confirmation.
- Before any action that might be repeated often (e.g., "create new addon", "add NSG rule"), the agent should offer to generate a reusable Skill (SKILL.md entry).
- After each task, perform self-reflection and write lessons learned to memory (with provenance, verification status, and expiry policy).

Agent Roles
- elicitor: asks targeted MCP-style questions to fill missing context before tool calls.
- planner: turns requirements into a step-by-step plan and test cases (TDD-first when applicable).
- executor: runs code edit actions (via Copilot CLI or manual), runs tests, collects results.
- memory-manager: reads/writes/updates the memory store; enforces retention and redaction policies.
- git-inspector: searches git history/commit messages for relevant context.
- az-auditor: performs readonly inspections of cloud resources via `az` wrapper.

Conventions
- Store prompt files in ./prompt_files/
- Store skills in SKILL.md
- Tools live in ./tools/
- Scripts to orchestrate flows live in ./scripts/
