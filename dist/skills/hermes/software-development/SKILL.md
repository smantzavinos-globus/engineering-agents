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
| Brief | `discovery` (vague idea) / `discover-and-design` (already discussed; also the unattended pipeline mode) / `discover-and-design-simple` (small, obvious) |
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
| Live PR fix loop | `babysit-pr` |

## Precedence and repo overlays

Order of authority: the human's instruction > the target repo's own docs
(`AGENTS.md` and what it links) > the agent's **repo overlay** skill > the
stage skills > this skill. A repo overlay is a local, repo-specific skill
(e.g. `<repo>-dev-overlay`) that holds the repo's path map (plan directory,
test-command catalog, backlog), and every deliberate deviation from this
process as a row: ID, deviation, justification, exit condition. Load it
together with this skill whenever one exists. Paths in the stage skills
(e.g. `plans/YYYY_MM_DD_<slug>/`) are defaults the overlay may remap. When
repo docs and this process conflict, follow the repo and report the
conflict; never fix it silently. Overlays are always `keep-local` in
`skill-sync`.

## Pick the plan level

| Signal | Level | Stages |
| --- | --- | --- |
| Obvious, < ~30 min, no design choice | Simple | brief → implement → verify |
| Clear bug, obvious root cause | Simple bug fix | as Simple; regression test first, mandatory |
| One coherent feature/fix | Standard | full pipeline below |
| Multi-feature / cross-component | Epic | brief → research → approach → `epic.md` → `review-epic` → child plans (each Standard) |
| Unsure | Standard | research may downgrade |

The stage-gate table applies in full to Standard and Epic. Simple levels
still need a `brief.md`; chat context is not a brief.

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
| Worklog / execution | plan review CLEAN (zero Blocker/Critical/Major) + **human approval** | Stop. Present the plan for approval. |
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
`references/execution-modes.md` (packaged with this skill), which is the deep-dive reference for
this table. When in doubt between two modes, pick the more isolated one;
escalating mid-execution is cheap, de-escalating is not.

## Locating yourself

- **New work item** (no brief): start at `discovery`, or the combined
  `discover-and-design` / `discover-and-design-simple` variants per the
  Brief row above.
- **Epic-scale work**: the brief/approach become an epic skeleton
  (`epic.md`, numbered child plans); use `review-epic` at the epic layer.
  Child plans enter at PLAN in the table above, gated by the epic approach.
- **Existing plan approved**: `create-worklog`, then `execute-task`.
- **"Review this"**: identify the artifact (approach/plan/code/PR) → the
  matching `review-*` skill.
- **Bug fix**: see the plan-level table — Simple bug fix when the root cause
  is obvious (regression test first), otherwise Standard.

## Process choices (each has a point, a mechanism, and a record)

Every choice in the process happens at a defined point, by a defined
mechanism, documented in a defined place:

| Choice | When it happens | Mechanism | Documented in |
| --- | --- | --- | --- |
| Execution mode (pi subprocesses / Hermes subagents / single session) | At plan approval | Confirm with the human (default: pi subprocesses) | Worklog header |
| Parallel reviews (`dual` — default: two independent reviewers, distinct from each other and the author — vs `multi-model`: 2–3 reviewers on distinct model families) | At plan creation | Agent proposes per plan risk; human confirms at plan approval | plan.md "Parallel reviews" choice row; if multi-model, the review files carry a merged findings table with per-reviewer attribution |
| Per-task review (yes/no per task) | At plan creation | Agent proposes per task risk (a `no` on schema/auth/migration tasks is a review finding); human confirms at plan approval | plan.md task graph |
| Approval gates (approval-gate / auto-continue / detached) | At execution start | Human decides (default: approval-gate) | Worklog header |
| Contract freezes | When a contract-task's tests are frozen | Agent-determines; changing frozen tests afterward requires human approval | plan.md freeze schedule + worklog |

## Autonomy defaults (harness/human may override per plan)

- **Auto**: everything WITHIN an approved plan's execution (task order,
  internal fixes, gate re-runs).
- **Human gates**: (1) plan approval before execution; (2) contract
  freezes — the point where a contract task's tests are declared frozen;
  changing them afterward requires human approval; (3) owner-ruling
  classes — contradictions in the spec or plan, contract-level questions the repo cannot answer, irreversible actions, external contact, spend, security
  posture; (4) PR merge (agents never merge).
- Reviews are always delegated to a DIFFERENT agent than the author, in a
  fresh session (never the author's session id).
- **Filling pi delegation placeholders:** `<skills-dir>/<skill>` is the
  installed skill's directory (find it in your store; it may sit under a
  category folder). `<model-for-ROLE>` comes from the repo's role->model
  mapping (`AGENTS.md` roles table, `.pi/settings.json` agentOverrides); if
  the repo has none, use `references/agent-roles.md` tiers and ask once.
  `--name` is a display name only and selects nothing.
- Verification runs on the orchestrator's host after every delegated step; a
  worker's report is not evidence.
- **Investigation continuity:** while one task's root cause is unproven, the
  same implementer session may be resumed across rounds. Record
  `session: <id> — continuity: <reason>` in the worklog, gate on the host
  every round, review in fresh sessions, and end it once the cause is proven
  (details: `references/execution-modes.md`).

## Review bar

A plan/code review passes at zero **Blocker/Critical/Major** findings;
Minors ride with recorded follow-ups. Approach/plan/code reviews run as a
loop: each round re-reviews the fixed artifact until the bar is met. Every
plan and code review round uses at least TWO reviewers, distinct from each
other and from the author (`dual`, the default); the round passes only when
both meet the bar — one clean pass is not enough. When the plan selects
`multi-model`, 2–3 reviewers on distinct model families run the round. In
both cases findings merge into one review file with per-reviewer
attribution.
