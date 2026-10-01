---
name: software-development
description: "Use when starting or continuing ANY software development work, when the human says 'follow the dev process' (or similar), or when unsure which development stage comes next. The top-level entry: loads the process, locates the current stage via the stage-gate table, and routes to the stage skill."
---

# Software Development — process entry and stage routing

This is the ENTRY skill for the engineering-agents development process. It
owns the stage-gate table (below) and routing; it owns NO stage content —
each stage's skill does that. The pipeline is sequential-first:

```
intake → BRIEF → RESEARCH → APPROACH → APPROACH REVIEW → PLAN → PLAN REVIEW
       → (human approval) → WORKLOG → EXECUTE (per-task) → CODE REVIEW → PR REVIEW
```

Stage skills BY HARNESS (the stage names above are universal; the skill
names differ where the pi and OpenCode/Hermes processes diverged — see
`docs/skill-rendering.md`):

| Stage | OpenCode + Hermes (sequential pipeline) | pi (wave engine) |
| --- | --- | --- |
| Brief | `discovery` / `discover-and-design*` | same |
| Research | `research` | same |
| Approach | `design` | same |
| Plan | `create-plan` | `create-tasks` |
| Plan review | `review-plan` | `review-tasks` |
| Worklog | `create-worklog` | (tasks.json carries it) |
| Execute | `execute-task` / `execution-orchestrator` | wave engine |
| Code review | `review-code` | `review-diff` |
| PR | `pull-request` | same |
| Epic | `review-epic` | same |

## The stage-gate table (NORMATIVE)

A stage may not START until its gate artifacts exist. This table is the
single authority; the per-stage skills do not re-litigate it.

| Stage you want to start | Gate (must already exist) | If the gate is missing |
| --- | --- | --- |
| Research | `brief.md` (goals/non-goals/constraints/success criteria) | Run `discovery` first. CHAT CONTEXT IS NOT A BRIEF — formalize it. |
| Approach (`design`) | `brief.md` + research findings on disk | `discovery`/`research` first |
| Approach review | `approach.md` | `design` first |
| Planning (`create-plan`) | APPROVED `approach.md` (review clean) | `review-approach` first |
| Plan review | `plan.md` complete per template | `create-plan` first |
| Worklog / execution | plan review CLEAN (zero Critical) + **human approval** | Stop. Present the plan for approval. |
| Code review | task(s) executed, commits landed | `execute-task` first |
| PR review | code review clean | `review-code` first |

**The failure this gate exists for (real incident, 2026-09-30):** an agent
with rich chat context wrote `plan.md` directly, skipping brief and
approach. Chat is decision-CONTENT, not the artifact trail — reviewers then
have nothing to review the plan AGAINST. Never write a plan from chat
memory of decisions; write the brief and approach first, even when the
content already "exists" in the conversation.

## Locating yourself

- **New work item** (no brief): start at `discovery` (or
  `discover-and-design` if brief+approach will be one session).
- **Epic-scale work**: the brief/approach become an epic skeleton
  (`epic.md`, numbered child plans); use `review-epic` at the epic layer.
  Child plans enter at PLAN in the table above, gated by the epic approach.
- **Existing plan approved**: `create-worklog`, then `execute-task`.
- **"Review this"**: identify the artifact (approach/plan/code/PR) → the
  matching `review-*` skill.
- **Bug fix**: `process.md` §Bug Fix — brief → debug/research → approach →
  the planning pipeline.

## Autonomy defaults (harness/human may override per plan)

- **Auto**: everything WITHIN an approved plan's execution (task order,
  internal fixes, gate re-runs).
- **Human gates**: (1) plan approval before execution; (2) contract
  freezes; (3) owner-ruling classes — irreversible actions, external
  contact, spend, security posture; (4) PR merge (agents never merge).
- Reviews are always delegated to a DIFFERENT agent than the author.

## Multi-model rule

Approach/plan reviews use 2–3 parallel reviewers on distinct model
families; iterate until zero Critical findings; Minors ride with recorded
follow-ups. Full mechanics live in the review skills.
