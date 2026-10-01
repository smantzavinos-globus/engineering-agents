# Worklog Template

# <Title> — Execution Worklog

## Entry-Point Contract

- **Read this file first** every time you start working on this plan.
- Execute exactly ONE task per sub-agent call. Do not execute multiple tasks.
- Do not add new tasks to the current plan/worklog task list unless the human explicitly changes scope.
- After completing a task: update this file, commit, and stop.

## Working Rules

- Test-first discipline (Red → Green → Verify). No change without a failing test first, per the task's verification class.
- Git commits are per plan task. Do NOT push until explicitly requested.
- Follow the plan's checklists exactly.
- Non-blocking follow-up work goes to the repo backlog, not into this plan's task list.

## References

- Plan: `<relative path to plan.md>`
- Approach: `<relative path to approach.md>`

## Completion Criteria

All of these must be true before the plan is considered complete:
- [ ] All tasks marked done below
- [ ] Final verification gate passes
- [ ] Final commit made

## Prerequisites

### Environment Setup
- Required services: <list with start commands>
- Required env vars: <list names>
- Runtime: <node/python/go version if relevant>
- Setup command: <if one exists, e.g., docker compose up -d>

## Baseline Gate Audit
Run all package-wide and repo-wide gates before T1 implementation.

| Command | Scope | Baseline status | Notes |
|---------|-------|----------------|-------|
| `<command>` | package-wide | pass/fail | <notes on pre-existing failures> |

- [ ] All gates checked before implementation began
- [ ] Pre-existing failures documented above

## Testing & Verification

### Commands
| Command | Scope | When to run | What it checks |
|---------|-------|-------------|----------------|
| `<fast command>` | touched-files | During TDD loops | Fast feedback |
| `<gate command>` | package-wide | Before marking task complete | Cross-module drift |
| `<final command>` | repo-wide | Before plan completion | Full repo integrity |

### Gate Policy
- Policy: `block-on-global-gate` | `allow-scoped-completion` | `split-follow-up`
- If a broader gate fails for unrelated reasons: <specific action per policy>

### Why the Gate Command Matters
The task completion gate (package-wide) catches issues that task-level fast-feedback misses:
- Type mismatches between modules/packages
- Missing or changed exports that break consumers
- Interface drift between layers
- Cross-module integration failures

Always run the gate command before marking a task complete, even if fast-feedback passes.

### Unrelated Gate Failures Log
| Date | Command | Failure | Related to current task? | Action |
|------|---------|---------|------------------------|--------|

- If a task-specific test fails: fix before marking task complete

## Backlog Capture Policy

- Repo backlog: `<location/system, e.g. docs/backlog.md or GitHub Issues>`
- Create item procedure: `<how to create an accepted follow-up>`
- Stable ID/reference format: `<TASK-0001 | #123 | other>`
- Default non-critical follow-up status: `Inbox` or repo equivalent
- Default origin for execution follow-ups: `plan-follow-up`
- Critical/current-plan-affecting discoveries: stop and ask whether to fix, re-plan, or backlog

If no repo backlog mechanism is documented, ask before trying to capture follow-up work.

## Backlog Items Created

None yet.

## Requirement Changes

Use this section only when the repo maintains requirements and the plan includes approved requirement updates.

- Repo requirements: `<location/system, e.g. docs/requirements.md or requirements CLI>`
- Approved requirement updates from plan: `<none | list requirement IDs/changes>`
- Applied requirement updates: `<none yet | FR-001 added/updated, NFR-002 removed>`
- Requirement-change approval source: `<approach.md/plan.md/human approval reference>`
- Test requirement citation format: `<none documented | e.g. comment/annotation format>`

If execution reveals a missing, unclear, or conflicting requirement that affects current-plan correctness, safety, scope, or verification, stop and ask before changing canonical requirements.

When writing or updating tests for tasks with requirement refs, cite the relevant requirement IDs using the documented test citation format. If no format is documented, note the gap and ask before inventing one.

## Task Status

- [ ] T1: <description>
- [ ] T2: <description>
- [ ] T3: <description>

## Decisions / Constraints Discovered (append-only)

Record any decisions made or constraints discovered during execution that weren't in the original plan:
- <decision or constraint learned>

## NEXT STEP

**Current Task:** T1 — <description>

Read plan.md § T1 for full TDD checklist and implementation details.

After completing this task:
1. Capture any accepted non-blocking follow-ups in the repo backlog
2. Record created backlog item IDs in `Backlog Items Created` and/or the execution log
3. Mark T1 done above
4. Set NEXT STEP to T2
5. Append to the execution log below
6. Commit: `task(T1): <short description>`

## Execution Log

### T1 — YYYY-MM-DD
- **Changes:** <what was done>
- **Tests:** `<command>` → pass/fail
- **Verification:** gate command → pass/fail
- **Commit:** `<sha>` — `<message>`
- **Backlog items created:** <none | TASK-0001 / #123 — title>
- **Requirement changes applied:** <none | FR-001 added/updated/removed>
- **Notes:** <anything notable>
