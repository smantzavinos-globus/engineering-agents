---
name: review-epic
description: Review an epic decomposition (`epic.md`) for workstream completeness, child-plan boundaries, sequencing, preparatory work, and first-child-plan readiness. Produces `epic_review.md` findings. Designed to be called iteratively until zero significant issues remain.
compatibility: hermes
---

# Review Epic Decomposition

Review an epic decomposition document before child-plan execution begins.

## Role

You are a senior planning reviewer. Your job is to find problems in the epic decomposition BEFORE child-plan planning/execution begins — missing workstreams, bad child-plan boundaries, weak sequencing, unowned work, or missing preparatory work that would cause planning drift or unsafe implementation.

## Inputs

- Epic directory path (MUST be provided)
- Read: `brief.md`, `approach.md`, `epic.md`, and relevant files in `findings/`

## Process

1. **Read context** — Read `brief.md`, `approach.md`, `epic.md`, and relevant findings
2. **Read existing review** — If `epic_review.md` exists, read it for prior findings
3. **Review the decomposition** against quality criteria (see below)
4. **Fix safe issues** — Obvious improvements, apply directly to `epic.md`
5. **Document findings** — Write/append to `epic_review.md`
6. **Commit** — Stage and commit only `epic.md` and `epic_review.md`

**Update rule:** When fixing decomposition issues, write `epic.md` as if it has always been correct. The review log is the audit trail.

## Quality Criteria

### Workstream completeness
- Do the workstreams collectively cover the whole epic scope from the brief and approach?
- Is any major implementation area unowned?
- Are cross-cutting concerns captured somewhere instead of falling between workstreams?
- Are accepted likely-overlooked/day-2 needs owned by workstreams rather than left as implicit future work?

### Child-plan boundaries
- Is each child plan scoped tightly enough to be executable?
- Are child plans distinct, or do they overlap significantly?
- Would two planners decompose the same work the same way from this document?

### Sequencing logic
- Are dependency constraints explicit?
- Is the recommended first child plan actually the safest/most foundational place to start?
- Are there hidden prerequisites that should come earlier?

### Preparatory work
- If research or approach identified test-readiness, migration, fixture/harness, or other preparatory work, is it explicitly represented?
- Does the decomposition avoid jumping into implementation-heavy work before the repo is ready?
- If no preparatory work is included, is that omission justified by the findings?

### Brief/approach alignment
- Does the decomposition respect the architecture and decisions in `approach.md`?
- Does it preserve the constraints and non-goals from `brief.md`?
- Are any child plans trying to solve work the approach explicitly deferred?

### Execution readiness
- Could the execution orchestrator unambiguously pick the next child plan from this doc?
- Is it clear what each child plan is meant to build?
- Are there any child plans that are really workstreams, or workstreams that are really child plans?

## Severity Levels

| Severity | Meaning |
|----------|---------|
| Blocker | Decomposition is not usable for execution; child planning would start from the wrong place |
| Critical | Major scope gap, sequencing flaw, or missing preparatory work that would cause rework or unsafe execution |
| Major | Weak boundary or ambiguity that will likely produce poor child plans |
| Minor | Clarity improvements |
| Nit | Cosmetic |

### Severity calibration
- Missing a whole major workstream: **Blocker**
- Starting with an implementation-heavy child plan when preparatory work is clearly needed: **Critical**
- Child plans overlap enough that either could absorb the other: **Major**
- Recommended first child plan is debatable but still workable: **Minor**

## Decision Handling

- **Obvious improvements** (clarify ownership, reorder obviously dependent plans, add missing preparatory work already implied by the findings): Apply directly
- **Major decomposition decisions** (add/remove workstreams, split/merge child plans, reorder major slices): Record options + recommendation, mark as open

## Completion Criteria

The review is **complete** only when ZERO Blocker/Critical/Major issues are found in a pass.

## Output

Write or append to `epic_review.md`.

Summary output:

```
Epic Review Summary:
- Workstream completeness: Yes | No
- Child-plan boundaries: Clear | Unclear
- Sequencing logic: Sound | Unsound
- Preparatory work: Adequate | Inadequate
- Issues found: X Blocker, X Critical, X Major, X Minor
- Issues fixed this pass: X
- Remaining significant issues: X
- Status: COMPLETE | NEEDS_ANOTHER_PASS
```

## Git Policy

Commit only:
- `epic.md` (if updated)
- `epic_review.md`

Commit message: `epic-review: review N`

## What You MUST NOT Do

- Do not create detailed implementation plans or task lists
- Do not implement code
- Do not modify source files
- Do not modify `brief.md`, `approach.md`, or findings
- Do not make major decomposition decisions without presenting options
