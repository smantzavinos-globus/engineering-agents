---
name: review-plan
description: Review an engineering plan for completeness, consistency, logic bugs, and execution readiness. Produces plan_review.md findings. Designed to be called iteratively until zero significant issues remain.
compatibility: pi
---

# Review Plan

Review an existing plan document for quality and execution readiness.

## Role

You are a senior engineering reviewer. Your job is to find problems in the plan BEFORE implementation begins — missing details, inconsistencies, logic bugs, and gaps that would cause rework.

## Inputs

- Plan directory path (MUST be provided)
- Read: `plan.md`, `approach.md`, `brief.md` for full context
- Review scope (optional):
  - `full` (default): Review the entire plan from scratch
  - `delta`: Review only changes since last review pass (use when re-reviewing after fixes were applied)

## Process

1. **Read context** — Read plan.md, approach.md, and brief.md
2. **Read existing review** — If `plan_review.md` exists, read it to understand prior findings
3. **Review the plan** against quality criteria (see below)
4. **Fix safe issues** — Issues that have an obvious correct fix, apply directly to plan.md
5. **Document findings** — Write/append to `plan_review.md`
6. **Commit** — Stage and commit only plan.md and plan_review.md

**Plan update rule:** When fixing plan issues, write the plan as if it has always been correct — no historical commentary, no "we changed" language, no references to old versions. The review log is the audit trail.

## Quality Criteria

### Task graph correctness
- Dependency IDs exist, no cycles, consistent ordering
- Every task has a concrete deliverable and verification

### TDD checklist specificity
- Each checkbox names specific files, behaviors, and commands
- No vague "implement the feature" steps
- Verification class declared for every task
- `Task review default` declared, and any per-task `Task review` override matches the create-plan criteria (inline: `yes` for contract/characterization tasks, schema/migration/auth/permission changes, cross-package changes, high-tier tasks, and tasks later tasks build on; `no` is acceptable only for low-tier mechanical, docs-only, or fully-command-proven `check` tasks — a `no` on a schema/auth/migration task is a Major finding)
- `Parallel reviews` choice declared (`dual` or `multi-model`) — `dual` rounds run two reviewers in distinct fresh sessions; if `multi-model`, the plan's review rounds run 2–3 pi invocations with distinct `--provider`/`--model` flags and DISTINCT session ids (fresh ids per reviewer, never the author's), merged into one review file with per-reviewer attribution
- Verification commands reference canonical repo docs

### Coverage completeness
- Coverage matrix maps all behaviors from the approach
- Negative/edge cases are identified for each behavior
- E2E rationale is stated where applicable
- Any likely-overlooked/day-2 needs accepted into scope by the brief or approach are mapped to concrete tasks and verification
- Any explicitly deferred day-2 needs remain outside task scope and have safe deferral rationale

### Test adequacy
- Plan includes or references a "bad-test avoidance" section (from approach.md) naming what would count as insufficient testing
- If E2E tests are planned, seed/fixture data fit is confirmed (the seed data actually supports the scenario)
- If seed data changes, the plan identifies which docs/tests must be updated in the same patch
- TDD checklists could not be satisfied by tautological, source-reading, or export-exists tests

### Logic bug hunt
Actively look for cross-section contradictions (prefix findings with "Logic bug:"):
- Tasks that depend on artifacts not yet produced
- Verification that doesn't validate the real contract (false-green)
- Non-goals that are implicitly implemented by tasks
- Assumptions that invalidate later tasks
- Parallel work hazard (tasks that conflict on same files without sequencing)
- Gate command gap (only unit tests for changes that can fail cross-module)
- Terminology drift (same concept named differently across sections)
- Completion ambiguity (done stated without objective evidence)
- Coverage gap (behavior stated but no task proves it with a real test)
- False-green test risk (TDD checklists satisfied by tautological/source-reading tests)
- Rollout/rollback contradiction (requires backout but introduces irreversible migrations)
- Compatibility/migration mismatch (promises compat but no mixed-version handling)

### Handoff readiness
Could a competent implementer execute this plan without making additional design decisions? If not, what's missing?

### Implementer decision inventory
Every review must include an explicit list of remaining implementer decisions. If any remaining decision could change UX, contracts, file layout, or toolchain integration, severity is Major (or Critical if it touches a CLI/TUI boundary). If such decisions remain open, review status MUST be NEEDS_ANOTHER_PASS.

### Tooling/CLI/TUI gate (conditional)
If the plan involves CLI/TUI/tooling, additionally verify:
- Versioned I/O contract present
- Exit code policy present
- Warning taxonomy present
- File/module skeleton present
- Acceptance checklist present
- Determinism rules present

Missing any = Critical.

## Severity Levels

| Severity | Meaning |
|----------|---------|
| Blocker | Plan cannot be safely executed as written |
| Critical | Likely major rework or correctness issues |
| Major | Likely churn/bugs; survivable |
| Minor | Clarity improvements |
| Nit | Cosmetic |

### Severity calibration overrides
- **Critical:** Missing contract/exit code/warning taxonomy/determinism; missing external dependency pinning/toolchain integration; missing deviation protocol for tooling + contracts
- **Major:** Missing baseline gate audit for package-wide/repo-wide gates; missing unrelated failure policy; missing verification scope labeling; missing verification class for tasks with observable behavior; per-task review skipped on a schema, migration, auth, or permission task; missing coverage matrix for plans changing queries/mutations/domain logic/routes/shared exports; coverage matrix present but missing negative/edge cases; missing file/module skeleton + acceptance checklist (tooling plans); plan test tasks satisfiable by tautological/source-reading tests without reviewer flagging

## Decision Handling

- **Obvious fixes** (low blast radius): Apply directly to plan.md, record in review log
- **Decision required** (high blast radius): Record options + recommendation in review log, mark as open. Do NOT apply unless the orchestrator says "apply all recommendations"

## Completion Criteria

The review is **complete** only when ZERO Blocker/Critical/Major issues are found in a pass.

If any significant issues are found (even if fixed in this pass), another review pass is required to verify the fixes didn't introduce new issues.

## Output

Write or append to `plan_review.md` using the format in [references/review-template.md](references/review-template.md). When the plan selects `multi-model` parallel reviews, run 2–3 review passes on distinct model families with fresh session ids per reviewer, then merge all findings into this one file with per-reviewer attribution.

After completing the review pass, output a summary:

```
Review Summary:
- Issues found: X Blocker, X Critical, X Major, X Minor
- Issues fixed this pass: X
- Remaining significant issues: X
- Status: COMPLETE | NEEDS_ANOTHER_PASS
```

## Git Policy

After each review pass, commit only:
- `plan.md` (if updated)
- `plan_review.md`

Commit message: `plan-review: review N`

## What You MUST NOT Do

- Do not implement code
- Do not modify source files
- Do not run tests
- Do not edit files other than plan.md and plan_review.md
