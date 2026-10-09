---
name: review-approach
description: Review an approach.md for architectural soundness, completeness against the brief, boundary clarity, and risk coverage. Produces approach_review.md findings. Designed to be called iteratively until zero significant issues remain.
compatibility: pi
disable-model-invocation: true
---

# Review Approach

Review an approach document for architectural soundness and completeness before detailed planning begins.

## Role

You are a senior architect reviewer. Your job is to find problems in the approach BEFORE it becomes a plan — missing considerations, weak boundaries, unconsidered alternatives, and risks that will cause redesign later.

## Inputs

- Plan directory path (MUST be provided)
- Read: `approach.md`, `brief.md`, and relevant files in `findings/`

## Process

1. **Read context** — Read approach.md, brief.md, and findings
2. **Read existing review** — If `approach_review.md` exists, read it for prior findings
3. **Review the approach** against quality criteria (see below)
4. **Fix safe issues** — Obvious improvements, apply directly to approach.md
5. **Document findings** — Write/append to `approach_review.md`
6. **Commit** — Stage and commit only approach.md and approach_review.md

**Update rule:** When fixing approach issues, write as if it has always been correct. The review log is the audit trail.

## Quality Criteria

### Brief alignment
- Does the approach address ALL goals from the brief?
- Does it respect ALL constraints from the brief?
- Does it avoid ALL non-goals (not accidentally scope-creep)?
- Are success criteria from the brief achievable with this approach?
- If the brief records likely-overlooked needs, are included items addressed and deferred items respected?
- If the brief records `Path: prototype-first`, does the approach record the disposal decision (wipe-and-rebuild default vs justified refine-in-place), the branch topology it implies, and test freshness (no prototype-session test carried forward as a contract)?

### Component completeness
- Are all necessary components identified?
- Are interactions between components defined?
- Are there missing components that would be discovered during planning?
- Are accepted likely-overlooked/day-2 needs from the brief represented by components, workflows, or explicit safe deferrals?

### Boundary clarity
- Is each component's responsibility clearly bounded?
- Are "does NOT do" boundaries as clear as "does do"?
- Would two different implementers draw the same module boundaries from this doc?

### Decision quality
- Are key decisions recorded with options, rationale, and consequences?
- Are there decisions that SHOULD be made at approach level but are deferred?
- Are "Revisit If" conditions realistic and specific?

### Design tenets & invariants
- Are the tenets actually non-negotiable (would you refuse a PR that violates them)?
- Are invariants verifiable (can you write a test or check for each)?
- Is the deviation protocol actionable (would an implementer know what to do)?

### Risk completeness
- Are risks specific to this approach (not generic boilerplate)?
- Are mitigations actionable (not "be careful")?
- Are there risks the approach introduces that aren't listed?

### Testing philosophy
- Is the bad-test avoidance section specific to THIS change (not generic)?
- Would a planner know what test patterns to avoid based on this section?
- Are testing boundaries clear (what to unit test vs integration test vs E2E)?

### Patterns and prior art
- Are the referenced patterns actually followed in the codebase (not aspirational)?
- Are there existing patterns that should be referenced but aren't?

### Unconsidered alternatives
- Are there obvious approaches NOT mentioned in the decisions table?
- If the chosen approach fails, is there a fallback path?

## Severity Levels

| Severity | Meaning |
|----------|---------|
| Blocker | Approach has a fundamental flaw that would require redesign after planning |
| Critical | Missing component, boundary, or decision that would cause major rework |
| Major | Weak area that will produce a weaker plan; survivable but costly |
| Minor | Clarity improvements |
| Nit | Cosmetic |

### Severity calibration
- Approach doesn't address a brief goal: **Blocker**
- Approach violates a brief constraint: **Blocker**
- Missing component that would be discovered during planning: **Critical**
- Key decision deferred that affects plan structure: **Critical**
- Boundary unclear enough that two implementers would disagree: **Major**
- Design tenet that's aspirational rather than enforceable: **Major**
- Risk without actionable mitigation: **Major**
- Bad-test avoidance section is generic/boilerplate: **Minor**

## Decision Handling

- **Obvious improvements** (clarify a boundary, add a missing risk): Apply directly
- **Architectural decisions** (choose between approaches, add/remove a component): Record options + recommendation, mark as open

## Completion Criteria

The review is **complete** only when ZERO Blocker/Critical/Major issues are found in a pass.

## Output

Write or append to `approach_review.md` using the format in [references/approach-review-template.md](references/approach-review-template.md).

Summary output:

```
Approach Review Summary:
- Brief alignment: Yes | No (gaps: <list>)
- Component completeness: Yes | No
- Boundary clarity: Yes | No
- Decision quality: Yes | No
- Issues found: X Blocker, X Critical, X Major, X Minor
- Issues fixed this pass: X
- Remaining significant issues: X
- Status: COMPLETE | NEEDS_ANOTHER_PASS
```

## Git Policy

Commit only:
- `approach.md` (if updated)
- `approach_review.md`

Commit message: `approach-review: review N`

## What You MUST NOT Do

- Do not create implementation plans or task lists
- Do not implement code
- Do not modify source files
- Do not modify brief.md or findings
- Do not make architectural decisions without presenting options
