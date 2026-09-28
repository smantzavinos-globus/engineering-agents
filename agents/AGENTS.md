# Agents Directory Guide

Read this file before adding, renaming, or materially editing files in `agents/`.

## Agent Frontmatter Conventions
- Keep one Markdown file per agent at `agents/<name>.md`.
- Start each agent file with YAML frontmatter that matches the runtime contract already used in this repo: `name`, `description`, `model`, and `thinking`; add `skill` or `defaultProgress` only when the agent actually needs them.
- Keep `name` aligned with the filename stem so routing, tests, and overrides stay obvious.
- Make `description` answer when to use the agent, not just restate the name.
- After frontmatter, keep the body focused on role, domain boundaries, required verification behavior, and any injected-skill contract.

## Role Boundaries
- Preserve the repo's role split: planning agents plan and review, execution agents implement, the oracle stays read-only, and `ui-worker` owns UI-specific work.
- Put reusable process steps in skills, not directly in every agent file.
- Keep directory-local guidance here and task-specific instructions in the agent body.
- When changing one agent's scope, check adjacent agent files so boundaries still line up.

## Override Guidance
- For repo-local model or thinking overrides, use `.pi/settings.json` → `subagents.agentOverrides`.
- Do not create repo-local `.pi/agents/` copies just to tweak models or thinking levels; that duplicates canonical agent content and drifts quickly.
- Only edit the checked-in agent Markdown when the actual role, instructions, or durable contract should change for everyone.

## When to Read Each Agent File
- Read `planner.md` or `plan-reviewer.md` before touching planning or review contracts.
- Read `worker.md` or `ui-worker.md` before changing execution responsibilities.
- Read `researcher.md`, `vision.md`, or `oracle.md` before changing research, visual-analysis, or read-only escalation behavior.
- Read `preset.jsonc` alongside agent files when a role change also affects preset routing.

## Anti-Patterns
- Do not let two agents claim the same primary responsibility without an explicit handoff rule.
- Do not bury verification or commit rules in only one agent if the behavior belongs in a shared skill.
- Do not use agent files for ephemeral repo overrides that belong in `agentOverrides`.
