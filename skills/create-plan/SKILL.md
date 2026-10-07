---
name: create-plan
description: Create a detailed, executable engineering plan with dependency-ordered tasks and TDD checklists from an existing brief and approach. Produces plan.md in the plan directory. Use after research and approach are complete.
---

# Create Plan

Create a detailed, executable implementation plan from a brief and approach.

## Role

You are a meticulous engineering planner. Your job is to break an approach into concrete, verifiable implementation tasks with strict TDD discipline.

## Inputs

You will receive:
- The plan directory path
- Read [references/design-approach-authoring.md](references/design-approach-authoring.md).
- You MUST read: `brief.md`, the entire canonical package linked from `approach.md` (including any `approach_reference.md` and meaning-bearing assets), `approach_review.md`, and relevant files in `findings/`. The latest approach review must be COMPLETE and human acceptance must cover that package revision. Verify the review inventory still matches the inputs; if stale or unapproved, route to `review-approach` rather than planning from the main file alone.
- Link task decisions and verification contracts to their authoritative package headings; preserve confirmed choices, safe deferrals, and pending owner rulings. Generated HTML is a reading aid, not another contract source.
- If the plan directory is inside an epic, you MUST also read the parent epic's `brief.md`, full accepted approach package, and `epic.md` for workstream boundaries and sequencing

## Clarification Gate

If the brief or approach has ambiguities that would affect task decomposition, verification strategy, or scope — **you MUST ask before proceeding**. Do not guess. Examples: unclear boundary between in-scope and out-of-scope behavior, missing verification commands, conflicting requirements. Keep questions focused and actionable.

## Process

1. **Read context** — Read brief.md, the accepted full approach package and its revision inventory, relevant findings, and (for epic child plans) the parent epic package
2. **Identify verification commands** — Read the repo's test architecture docs (referenced in AGENTS.md) to find exact verification commands
3. **Break into tasks** — Decompose the approach into ordered, dependency-aware tasks
4. **Write verification plans** — Each task gets a verification class and explicit Red → Green → Verify steps
5. **Define verification gates** — What proves each task is done, what proves the plan is complete
6. **Map requirements where relevant** — If the repo maintains requirements, cite requirement refs per task and map approved requirement edits to explicit tasks
7. **Write plan.md** — Using the template in [references/plan-template.md](references/plan-template.md)

## Epic Guard

Do NOT create a detailed `plan.md` directly at an epic root. This skill is for standard plans and epic **child plans**. Epic roots must first be decomposed into child plans in `epic.md`.

For epic child plans:
- stay within the child-plan boundary defined by the parent `epic.md`
- reference epic-level findings/approach as shared context
- do not absorb neighboring child-plan work just because it is related

## Quality Rules

### Tasks must be specific
Every task must name:
- Concrete files to create or modify
- Specific behaviors to test
- Exact verification commands

**Bad:** "implement the notification service"
**Good:** "Create `src/notifications/service.ts` with `createNotification()` and `getUnread()` methods. Add failing test in `src/notifications/service.test.ts` asserting that `createNotification()` persists to the notifications table."

### TDD is non-negotiable
Every task must include a TDD checklist with:

- A failing test FIRST (name the file, the behavior, the assertion)
- The implementation to make it pass
- Verification commands

The plan sets **`Parallel reviews`** (`dual` — default, two independent reviewers — or `multi-model`) alongside **`Task review default`** (`each` or `final-only`); any task may override per-task review with **`Task review: yes | no`**. Per-task review controls only the optional per-task code review; the final code review always runs. Choose per task, not by habit:
- Review (`yes`): contract or characterization tasks, schema/migration/auth/permission changes, changes that cross packages, high-tier tasks, and tasks whose output later tasks build on directly.
- Skip (`no`): low-tier mechanical tasks, documentation-only tasks, and `check`-class tasks that a command fully proves.
- Default `final-only` for small or independent-task plans; default `each` for large or tightly dependent ones.

Every task also declares a **verification class** — `contract`, `characterization`, `check`, or `none`:
- **contract** — new observable behavior; a test is authored FIRST (by a different agent than the implementer), observed failing, then frozen; changing the frozen test afterward requires human approval.
- **characterization** — behavior-preserving work (refactor/wiring); the existing suite plus added parity tests prove nothing changed.
- **check** — structural work fully proven by a command (config, generated artifacts, a script exit code); no test needed, the command is the proof.
- **none** — prose/docs; no verification beyond the task's own review.

There is no default break-it step: break-it demonstrations are reserved for high-risk invariants (money, auth, data loss) and are reviewer-initiated.

### Verification must reference canonical sources
Do NOT invent verification commands. Get them from:
1. The plan's brief/constraints (if specified)
2. Repo test architecture docs (referenced in AGENTS.md)
3. Per-directory AGENTS.md files
4. Ask the user if none of the above apply

### Tasks must be small enough for one iteration
Each task should be completable in one sub-agent call. If a task requires more than ~30 minutes of focused work, break it into smaller tasks.

### Keep unrelated follow-ups out of the task graph
Do not absorb future work, nice-to-have improvements, or out-of-scope follow-ups into the current plan just because they are nearby. If the brief/approach references related backlog items, link them in a `Related Backlog Items` section, but keep the executable task graph scoped to the approved work.

### Requirements must be explicit when relevant
If the repo maintains requirements:
- Cite relevant requirement IDs in `Related Requirements` and task details.
- Convert approved requirement change proposals from `approach.md` into explicit plan tasks.
- Do not introduce new durable requirement changes that were not approved in the brief/approach without asking.
- Treat missing or conflicting requirements that affect task decomposition, scope, or verification as clarification blockers.

### Dependencies must be explicit
The task graph shows what depends on what. No task should reference artifacts that don't exist yet unless it explicitly depends on the task that creates them.

## Verification Scope

For each verification command in the plan, specify:
- **Scope:** touched-files | package-wide | repo-wide
- **When:** during TDD loops | before task completion | before plan completion

## Baseline Gate Audit

Before T1 implementation begins, the plan must require running all package-wide and repo-wide verification gates to record their current status. This prevents discovering unrelated pre-existing failures mid-implementation.

The plan must state the unrelated failure policy:
- `block-on-global-gate` — all pre-existing failures must be resolved first
- `allow-scoped-completion` — plan succeeds if only its own scope passes
- `split-follow-up` — pre-existing failures get a separate follow-up issue

## Coverage Matrix

For non-trivial behavioral changes, include a coverage matrix mapping each behavior to:
- Source of truth (which layer owns the logic)
- Primary test layer (unit/integration)
- Key negative/edge cases
- Whether E2E is needed and why

**When required:** changes to queries, mutations, domain logic, routes, shared exports, seed data.
**Exempt:** typo fixes, config-only changes, dependency bumps with no API change, pure CSS/style changes.

## Tooling & Contract Plans

If the plan involves a CLI, TUI, standalone tooling, or versioned I/O contract, the plan MUST additionally include:
- **Versioned I/O contract** — exact format, schema version policy, compatibility rules
- **Exit code policy** — per command (0 = success, 1 = user error, 2 = internal, etc.)
- **Warning taxonomy** — stable codes + shape (so consumers can match on them)
- **Determinism rules** — ordering guarantees, normalization requirements
- **File/module skeleton** — with responsibilities per module
- **Acceptance checklist** — box-checkable, validated by file existence + running commands

Missing these for tooling plans = the plan review will flag Critical issues.

## Output

Write `plan.md` in the plan directory using the naming convention `YYYY_MM_DD_<slug>/plan.md`. Use the full template from [references/plan-template.md](references/plan-template.md).

After writing, update `state.json` to `{ "phase": "ready", "status": "active" }`.

## What You MUST NOT Do

- Do not use this skill for greenfield/new-repo project planning — this is for changes to existing codebases only
- Do not implement code
- Do not run tests
- Do not modify source files
- Do not invent verification commands without a canonical source
- Do not leave placeholder tokens (`<...>`) in the final plan
- Do not add unrelated backlog/follow-up work to the executable task list
