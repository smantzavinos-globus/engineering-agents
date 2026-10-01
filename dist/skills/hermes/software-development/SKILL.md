---
name: software-development
description: "Use when starting or continuing ANY software development work, when the human says 'follow the dev process' (or similar), or when unsure which development stage comes next. The top-level entry: loads the process, locates the current stage via the stage-gate table, and routes to the stage skill."
compatibility: hermes
---

# Software Development — process entry and stage routing

This is the ENTRY skill for the engineering-agents development process. It
owns the stage-gate table (below) and routing; it owns NO stage content —
each stage's skill does that. The pipeline is sequential-first:

```
intake → BRIEF → RESEARCH → APPROACH → APPROACH REVIEW → PLAN → PLAN REVIEW
       → (human approval) → WORKLOG → EXECUTE (per-task) → CODE REVIEW → PR REVIEW
```

Stage skills (universal — the same pipeline for every harness):

| Stage | Skill |
| --- | --- |
| Brief | `discovery` / `discover-and-design*` |
| Research | `research` |
| Approach | `design` |
| Approach review | `review-approach` |
| Plan | `create-plan` |
| Plan review | `review-plan` |
| Worklog | `create-worklog` |
| Execute | `execute-task` / `execution-orchestrator` |
| Code review | `review-code` |
| PR | `pull-request` |
| Epic layer | `review-epic` |

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

**Artifact precedence:** briefs, approaches, and plans are reviewable
artifacts — decisions recorded in conversation are CONTENT for those
artifacts, never a substitute for them. An agent asked to plan work
verifies the gate artifacts exist on disk first and creates whichever are
missing, in pipeline order, before any plan is written.

## Execution mode selection (NORMATIVE — required before execution starts)

The pipeline is invariant; what varies is the vehicle that drives the
stages. Confirm the mode with the human when the plan is approved (unless
one is already agreed for the repo), record it in the worklog header, and
keep it for the whole plan.

| Situation | Mode |
| --- | --- |
| Default; multi-task plans; parallel tasks likely; isolation needed | **Pi subprocesses** |
| Simple plans (≤ ~3 small tasks), one domain, no parallelism worth isolating | **Hermes subagents** |
| Trivial change, single sitting, single domain, no review loop expected | **Single Hermes session** |

Invariants in every mode: the pipeline, artifacts, verification classes,
and gates are identical; verification runs on the host (never delegated to
the context that did the work); the reviewer's context is never the
implementer's; human gates are unchanged. Mode mechanics — pi session-ID
conventions, session-reuse exceptions, per-mode evidence shapes — live in
`docs/hermes/execution-modes.md`, which is the deep-dive reference for
this table. When in doubt between two modes, pick the more isolated one;
escalating mid-execution is cheap, de-escalating is not.

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
