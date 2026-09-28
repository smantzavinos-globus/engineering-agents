# Agent Roles

The harness-neutral inventory of agent roles in this repo's development
process: who does what across planning, implementation, and review, which
execution tier each defaults to, and the independence rules between them.
Orchestration docs map these roles to specific runtimes (Pi subagents,
OpenCode categories); per-repo model assignments are a repo hook (see
"Per-repo model assignment" below).

## The roles

| # | Role | Stage(s) | Responsibility | Tier |
|---|------|----------|----------------|------|
| 1 | Orchestrator | all | The human's interface and owner of the loop: leads brief and approach with the human, advances stages, dispatches roles, runs verification on the host, commits checkpoints. Never implements, never reviews its own artifacts. | high |
| 2 | Researcher | research | Investigates the codebase; produces findings files with verified anchors. | low |
| 3 | Planner / contract author | plan | Decomposes into tasks; assigns verification class + execution tier; authors failing contract tests (observes red, never implements). | high |
| 4 | Reviewer | approach, plan, code, PR review | Runs the review procedure for the stage — the stage skill defines the checklist; the role is the identity. Never reviews artifacts it (or its session lineage) authored. | high |
| 5 | Fresh reviewer | final review; second reviewer in two-reviewer loops | Full-diff review with **no prior context** on the work. Read-only. | high (strongest available) |
| 6 | Implementer, high tier | execute | Executes high-tier tasks per their verification class; atomic task commit. | high |
| 7 | Implementer, low tier | execute | Executes low-tier tasks (mechanical, bounded, well-specified work). | low |
| 8 | Visual implementer *(optional)* | execute (UI) | UI-specific tasks needing a UI-specialized model. Assign only if the repo wants a distinct UI model; otherwise implementer-high covers it. | high |

Review stages share one Reviewer role because the thing that varies per
stage is the **procedure** (a skill: review-plan, review-code, the PR
review process), not the identity — and every review stage defaults to the
same tier, so per-stage roles would all resolve to the same model slot.
The one exception is the Fresh reviewer: freshness is a context property,
not a procedure, and it cannot be produced by a role that has been in the
loop. Similarly, brief and approach are **phases the Orchestrator leads**
in dialogue with the human, not separate identities: the human talks to
one thread from intent to dispatch (in Pi subprocess mode that thread may
span several sessions — a session mechanic, see execution-modes, not a
role boundary).

## Independence rules

- A reviewer must not review artifacts authored by its own session or
  lineage — including the Orchestrator's co-authored `brief.md` and
  `approach.md`. Approaching review, the Reviewer is never the Orchestrator.
- The Fresh reviewer has no prior context on the work at all — clean
  session, read-only.
- Two-reviewer review loops use two distinct reviewer instances (Reviewer +
  Fresh reviewer, or two Reviewer instances with different sessions/models).
- Contract tests are authored by the Planner, never by an implementer.
- Verification runs on the host (Orchestrator), never in the context that
  did the work.

## Execution tiers

Plans assign each task a tier (`high` / `low`); the Orchestrator dispatches
the matching implementer role. All reviewer and authoring roles default to
`high` — review quality is not where cost is saved. Tier → model mapping is
repo configuration, not canon.

## Per-repo model assignment (required hook)

Every repo consuming this process **must document which model fills each
role**, because the right assignment is stack- and budget-specific. The
repo records this in its agent-configuration surface (e.g.
`.pi/settings.json` → `subagents.agentOverrides`, the OpenCode equivalent,
or the Hermes equivalent), and `skills/assess-repo` checks for it during
assessment:

- every role above has a named model (or an explicit "default" record);
- the Implementer tier mapping is stated (which model is `high`, which is
  `low`);
- critical roles (implementers, Planner, Reviewer) state a manual fallback
  order (the next model to re-dispatch when the primary is unavailable).
  Do not configure automatic fallback chains: pi-subagents 0.68 removed
  `fallbackModels`, and an agent file or override that still declares the
  key fails to load;
- the assignment is auditable — a reviewer can tell from repo config alone
  which model reviewed the code.

A repo that cannot state its role→model mapping fails assessment. The
mapping lives in the repo, not here: this document defines the roles; the
repo defines who plays them.
