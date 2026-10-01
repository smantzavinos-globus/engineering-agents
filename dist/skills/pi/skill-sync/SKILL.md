---
name: skill-sync
description: "Use when synchronizing this agent's installed skills with the upstream engineering-agents repo, when the human says 'sync skills', or when starting a session after upstream skills may have changed. Runs the standard diff, records the upstream SHA, and makes disposition judgments."
compatibility: pi
---

# Skill sync — keeping installed skills aligned with upstream

All agents install their skills from the engineering-agents repo's rendered
tree: `dist/skills/<harness>/<name>/` (for Hermes agents:
`dist/skills/hermes/`). Upstream is the single source of truth; local edits
are exceptions that must be EITHER contributed upstream (`propose-upstream`)
OR recorded as deliberately repo-local (`keep-local`).

## Procedure

1. **Record the state.** Read `~/.hermes/skills/.sync-state.json` (upstream
   SHA + date of last sync). Missing = never synced; do the bootstrap:
   clone/pull the repo at `origin/main`, copy
   `dist/skills/hermes/<name>/` for every skill into the skill store,
   write `.sync-state.json`, done.
2. **Fetch upstream and diff.**
   `git -C <repo> fetch origin && git -C <repo> rev-parse origin/main`
   Run `node tools/sync-skills.mjs --installed <skill-store-dir>` from the
   repo — it reports per skill: `unchanged` / `upstream-new` /
   `locally-modified` / `locally-only`, plus a content diff summary.
3. **Judge each non-unchanged skill** (the script surfaces, you decide):
   - `upstream-new` → take upstream (`take-upstream`), UNLESS a local
     modification is still load-bearing → it becomes `keep-local` + a
     `propose-upstream` candidate.
   - `locally-modified` → ask: is the local delta a genuine improvement
     generalizable to all agents, or repo/harness-local? Generalizable →
     `propose-upstream` (open a PR to engineering-agents; after merge,
     `take-upstream`). Local-only → `keep-local` and RECORD it in
     `.sync-state.json` under `local_overrides` with a one-line reason.
   - `locally-only` → decide: propose upstream, or delete. Never leave
     unrecorded.
4. **Write the state file** (new SHA, date, dispositions, pending
     proposals) and report to the human: what was taken, kept, proposed.

## Rules

- Sync does not auto-overwrite: anything not `unchanged` needs a judgment
  BEFORE copying. The script never writes; the agent does.
- Upstream SHA is always recorded — an unrecorded sync is a failed sync.
- Renames/deletions of installed skills follow Rule #1 (owner OK).
- After taking upstream versions of PROCESS skills (software-development,
  create-plan, review-*, execute-task, ...), re-read them before the next
  planning/execution session — gate tables and stage rules may have moved.
