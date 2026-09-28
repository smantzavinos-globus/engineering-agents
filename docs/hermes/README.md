# Hermes Agent Operations

Operating manuals for Hermes agents (and similar coding agents) that run this
repo's process against the repos they own. This section explains **mechanics
and setup** — cron jobs, labels, triggers, notification routing. The
**process policy** — what a review must check, what a PR body must contain,
what escalates to a human, how plans and tasks are structured — lives in the
canonical docs and is never restated here:

- [Development Process](../process.md) — the software development pipeline.
- [PR review process](../references/pr-review.md) — review contract, common
  rules, reviewer loop, Required Repo Hooks.

If this section and a canonical doc disagree, the canonical doc wins.

## Documents

| Document | Read when |
|----------|-----------|
| [Software development process](dev-process.md) | Setting up an agent to run the development pipeline on owned repos (skill sync, stop boundaries) |
| [Execution modes](execution-modes.md) | Deciding HOW Hermes drives the pipeline: Pi subprocesses vs Hermes subagents vs single session |
| [PR automation](pr-automation.md) | Setting up an agent to detect and review PRs automatically (no-agent cron sweep, labels, triggers, detached review sessions) |

## How Hermes consumes this repo

Hermes agents do **not** install rendered copies (that's the Pi/OpenCode
model — see `docs/skill-rendering.md`). Point the agent at this repo and it
reads canonical files directly. The entry point is this directory:

1. Read this README.
2. Follow the checklist below.
3. For any job, read the canonical path from the map — never hunt.

## Skill reference map

Canonical sources (`skills/<name>/SKILL.md`), not rendered copies. Hermes
agents following the skill-sync checklist maintain their own equivalents;
agents using this repo as a live reference read these directly.

| Job | Canonical path |
|-----|----------------|
| Onboard / audit a repo | `skills/assess-repo/SKILL.md` |
| Clarify intent → brief | `skills/discovery/SKILL.md` |
| Research → approach | `skills/design/SKILL.md`, `skills/research/SKILL.md` |
| Plan creation | `skills/create-plan/SKILL.md` |
| Plan review | `skills/review-plan/SKILL.md` |
| Execution log | `skills/create-worklog/SKILL.md` |
| Task execution | `skills/execute-task/SKILL.md` |
| Full autonomous execution | `skills/execution-orchestrator/SKILL.md` + [Execution modes](execution-modes.md) |
| Code review | `skills/review-code/SKILL.md` |
| Epic decomposition review | `skills/review-epic/SKILL.md` |
| PR body + one verdict | `skills/pull-request/SKILL.md` |
| Live-PR review cycling (session-scoped) | `skills/babysit-pr/SKILL.md` |
| PR monitoring infrastructure | [PR automation](pr-automation.md) |

## Agent self-setup checklist

An agent being handed ownership of one or more repos runs this once:

1. **Verify each repo is onboarded.** Check for `pr-review-hooks.md` at the
   repo root (see the Required Repo Hooks table in the PR review process) and
   that `AGENTS.md` routes the process docs. Missing pieces: report to the
   human and offer an assess-repo setup run. Do not start automated review
   for a repo without a manifest.
2. **Sync your skills** against the checklist in
   [Software development process](dev-process.md), then create the sweep cron
   from the template in [PR automation](pr-automation.md) — one job covering
   all owned repos.
3. **Register the trigger surface**: confirm which GitHub handle mentions
   should trigger this agent, and check the repo's `pr-tracking` manifest
   row documents it.
4. **Agree the execution mode** (Pi subprocesses / Hermes subagents / single
   session) with the human when a plan is approved for execution — see
   [Execution modes](execution-modes.md).
5. **Confirm the never-merge boundary** with the human once: the agent
   detects, reviews, labels, and notifies. Only the human merges.
6. **Report the completed setup** to the human with the repo list and cron
   schedule so it is auditable.
