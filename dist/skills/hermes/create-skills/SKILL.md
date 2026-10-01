---
name: create-skills
description: Create valid OpenCode SKILL.md skills (naming rules, frontmatter schema, discovery paths, templates) and optionally configure opencode.json skill permissions.
compatibility: hermes
metadata:
  audience: maintainers
  domain: opencode
---

## Goal
Create new OpenCode skills quickly and correctly.

## Where skills live
OpenCode discovers skills at:
- (Claude-compatible) Project: `.claude/skills/<name>/SKILL.md` *(default for maximum compatibility)*
- (Claude-compatible) Global: `~/.claude/skills/<name>/SKILL.md`
- Project: `.opencode/skills/<name>/SKILL.md` *(use this if the repo already uses `.opencode/skills` for consistency)*
- Global: `~/.config/opencode/skills/<name>/SKILL.md`

## Naming rules (must follow)
- `name` must match directory name containing `SKILL.md`
- `SKILL.md` must be spelled in all caps
- `name` regex: `^[a-z0-9]+(-[a-z0-9]+)*$`

## Template (copy/paste)
Default: create `.claude/skills/<name>/SKILL.md`.

If the repo already uses `.opencode/skills`, create `.opencode/skills/<name>/SKILL.md` instead.

```md
---
name: <name>
description: <when to use this skill and what it does>
compatibility: opencode
---

## What I do
- 

## When to use me
Use this when...

## What I need
- Inputs, files, commands, constraints

## Non-goals
- What I explicitly will not do

## Examples
- Example prompt(s)
```

## Authoring checklist
- Description answers: “use this when …” (not just a label)
- Include concrete do/don’t constraints and any required tools
- Prefer small, composable skills over one mega-skill

## Ralph-loop stop criteria (optional, for loop-driven skills)
If a skill is intended to be run under a Ralph loop (or any iterative driver), it MUST define explicit stopping criteria and emit a machine-readable status.

- Separate “this pass finished” from “the loop should stop”.
- Define objective exit criteria (what must be true for the loop to stop).
- Prefer a machine-readable promise tag at the end of the response:
  - `<promise>DONE</promise>` only when exit criteria are met
  - `<promise>NOT_DONE</promise>` when another cycle is required (even if fixes were applied)
- MUST NOT claim “the task is complete” solely because issues were fixed; completion is based on meeting the exit criteria.
- When outputting `NOT_DONE`, include a short recommended next action (e.g., “re-run after fixes”, “request decisions <IDs>”).

## Permissions (optional)
In `opencode.json`, you can gate skills via `permission.skill`:

```json
{
  "permission": {
    "skill": {
      "*": "allow",
      "experimental-*": "ask",
      "internal-*": "deny"
    }
  }
}
```

## Troubleshooting
- Skill not listed: verify path + `SKILL.md` caps + frontmatter includes `name` and `description`
- Skill loads but seems unused: make `description` more specific and add “When to use me” examples
