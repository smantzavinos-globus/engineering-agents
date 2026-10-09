# Plan Levels

This document defines the three levels of engineering plans, when to use each, what artifacts they produce, and what stages they require.

---

## Simple

### When to Use

- Typo or documentation fixes
- Configuration changes with no behavioral impact
- Dependency bumps with no API changes
- Small, obvious bug fixes where root cause is immediately clear
- Style/formatting changes
- Any change where the solution is obvious and risk is minimal

### Artifacts

```
plans/
  2026_05_01_fix_typo_in_readme/
    brief.md
    state.json
```

### Stages Required

| Stage | Required | Notes |
|-------|----------|-------|
| Brief | ✅ | Minimal — 1-3 sentences |
| Research | ❌ | Not needed for obvious changes |
| Approach | ❌ | Not needed |
| Plan | ❌ | Not needed |
| Plan Review | ❌ | Not needed |
| Worklog | ❌ | Not needed |
| Execute | ✅ | Direct implementation + verify |
| Code Review | ❌ | Not needed for trivial changes |

### Simple Bug Fix Requirement

Even at the simple level, bug fixes **must** include a regression test. The test proves the fix works and prevents the bug from returning.

### Promotion Rule

If during implementation the change turns out to be more complex than expected, promote to Standard. Create the remaining artifacts and continue with the full process.

---

## Standard

### When to Use

- New features and enhancements
- Refactors that change behavior or structure
- Bug fixes with non-obvious root cause
- Integrations with external systems
- Any change where the solution requires design decisions
- Any change that modifies public interfaces or contracts

### Artifacts

```
plans/
  2026_05_01_add_user_notifications/
    brief.md
    findings/
      current_state.md
      code_structure.md
      dependencies.md
    approach.md
    approach_review.md
    plan.md
    plan_review.md
    worklog.md
    code_review.md
    state.json
```

### Stages Required

| Stage | Required | Notes |
|-------|----------|-------|
| Brief | ✅ | Full intent documentation |
| Research | ✅ | Codebase exploration, dependency mapping |
| Approach | ✅ | Conceptual model, structural decisions |
| Planning pipeline | ✅ | Sequential plan with verification class + execution tier per task |
| Planning review | ✅ | Review until zero significant issues |
| Execution log | ✅ | `worklog.md` |
| Execute | ✅ | Sequential, opportunistic parallel dispatch allowed |
| Code Review | ✅ | Reviewer distinct from the implementer |

### Stage Transitions

Each stage produces its artifact and transitions the state. The orchestrator advances stages in order and does not skip.

```
brief → research → approach → approach_review
  └─ plan → plan_review → worklog → execute → code_review → PR review
```

---

## Epic

### When to Use

- Large features spanning multiple components or layers
- Migrations (data, API, architecture)
- Multi-week initiatives with distinct deliverables
- Work requiring coordinated changes across workstreams
- Initiatives where multiple standard plans need sequencing

### Artifacts

```
plans/
  2026_05_01_auth_migration/
    brief.md
    findings/
      current_state.md
      code_structure.md
      migration_research.md
    approach.md
    approach_review.md
    epic.md
    state.json
    01_schema_changes/
      brief.md
      findings/
        current_state.md
      approach.md
      approach_review.md
      plan.md
      plan_review.md
      worklog.md
      code_review.md
      state.json
    02_api_layer/
      brief.md
      findings/
        current_state.md
        dependencies.md
      approach.md
      approach_review.md
      plan.md
      plan_review.md
      worklog.md
      code_review.md
      state.json
    03_frontend_updates/
      brief.md
      findings/
        current_state.md
      approach.md
      approach_review.md
      plan.md
      plan_review.md
      worklog.md
      code_review.md
      state.json
```

### Epic-Level Stages

| Stage | Required | Notes |
|-------|----------|-------|
| Epic Brief | ✅ | Overall goal, motivation, constraints, and why this is an epic |
| Epic Research | ✅ | Cross-cutting findings that inform all child plans |
| Epic Approach | ✅ | Overall architectural strategy, workstream boundaries |
| Epic Decomposition (`epic.md`) | ✅ | Groupings, ordering, dependencies, and child-plan index |
| Epic Decomposition Review (`epic_review.md`) | ✅ | Validates workstream completeness, sequencing, and preparatory work |
| Child Plan Execution | ✅ | Each child follows full standard process |

### Child Plan Naming

Child plans within an epic use numbered prefixes for ordering:

- `01_`, `02_`, `03_` ... — reflects dependency/execution order
- The name after the prefix is descriptive of what the child plan builds
- The date is on the epic directory itself, not repeated on child plans

### Epic Document Structure

The `epic.md` file contains:

1. **Relationship to other epic artifacts** — How `brief.md`, `approach.md`, and `epic.md` divide responsibility
2. **Source documents** — Links to requirements, user workflows, research, design docs that inform the epic
3. **Overall implementation shape** — High-level description of workstreams and their relationships
4. **Workstream sections** — Each with:
   - Goal statement
   - Planned child plans with:
     - Status
     - What this plan is meant to build (1-3 sentences)
     - Reference docs relevant to this child plan
5. **Sequencing notes** — Which workstreams/plans depend on others
6. **Cross-cutting questions** — Issues that span multiple workstreams
7. **Execution record** — Added as work progresses; timestamps, durations, and backlog item IDs for deferred follow-ups

An epic is not ready for child-plan execution until both `epic.md` and `epic_review.md` exist. `approach.md` defines architecture; `epic.md` defines decomposition; `epic_review.md` confirms the decomposition is ready to drive execution.

### Epic Execution Model

The orchestrator processes an epic by:

1. Reading the epic doc to understand workstreams and sequencing
2. Confirming the epic decomposition has been reviewed (`epic_review.md`)
3. Selecting the next child plan based on dependency ordering
4. Executing that child plan through the full standard process
5. Updating the epic doc execution record
6. Repeating until all child plans are complete
7. Recording created backlog item IDs for deferred follow-ups and cross-cutting issues discovered

### Preparatory Child Plans

Some epics should not begin with implementation-heavy child plans. If epic research or decomposition review identifies weak test harnesses, fixture gaps, poor negative coverage, or other high-regression conditions, `epic.md` should explicitly include a preparatory child plan/workstream before the main implementation slices.

Typical examples:
- testing-readiness and surface-contract work
- migration-compatibility groundwork
- fixture/harness preparation for new isolation or permission models

### When Standard Plans Within an Epic Need Their Own Research

Each child plan within an epic still goes through the full standard process including research. However, research within an epic child plan can be lighter because:

- The epic-level source documents provide shared context
- Earlier child plans have already explored related areas
- The approach from earlier plans informs later ones

The orchestrator should reference completed sibling plans' findings when starting research for a later child plan.

---

## Choosing Between Levels

### Decision Flow

```
Is the change obvious and small (< 30 min)?
  → Yes: Simple
  → No: Does it span multiple features or components?
    → Yes: Epic
    → No: Standard
```

### Promotion and Demotion

- **Simple → Standard:** If implementation reveals unexpected complexity, stop and create the remaining artifacts (findings, approach, plan, etc.)
- **Standard → Epic:** If during research/approach you discover the work naturally breaks into multiple independent deliverables with dependencies, promote to epic
- **Standard → Simple:** If research reveals the change is trivial after all, you can skip remaining stages. But the brief and findings still exist as documentation.

### Uncertainty Rule

When uncertain about the level, **start at Standard**. The brief and research stages will reveal whether the change is actually simple (and you can abbreviate) or actually epic-scale (and you should promote).

These levels describe the **real build**. `prototype-first` is an entry path, not a level: a throwaway prototype precedes the brief, and the build that follows is still planned and executed at one of the levels above.

---

## Artifact Responsibilities

| Artifact | Responsibility | Consumed by |
|----------|---------------|-------------|
| `brief.md` | Intent, goals, constraints, motivation | Research, all subsequent stages |
| `findings/` | Facts about current state, code structure, dependencies (multiple focused files) | Approach, Plan |
| `approach.md` | Conceptual model, structural decisions, "how we'll solve this" | Plan, Plan Review |
| `approach_review.md` | Review findings, issues, and decisions for the approach | Approach (updates based on review), planning readiness |
| `plan.md` | Detailed implementation tasks with verification class + execution tier, checklists, verification gates | Plan Review, Worklog, Execute, Code Review |
| `plan_review.md` | Review findings, issues, resolutions | Plan (updates based on review) |
| `worklog.md` | Execution tracking, task status, loop log | Execute (read/write each iteration) |
| `code_review.md` | Post-implementation findings, fix verification | Execute (fix pass), orchestrator (completion decision) |
| `epic.md` | Workstream index, sequencing, execution record | Child plan orchestration |
| `epic_review.md` | Review findings and decisions for epic decomposition | Epic decomposition updates, child-plan readiness |
| `state.json` | Current phase, status (for continuation enforcement) | Extension, orchestrator |

**Epic execution guardrail:** do not create a detailed `plan.md` at the epic root. Execution begins at the child-plan level only after the epic has been decomposed and reviewed (`epic.md` + `epic_review.md`).

---

## State.json Schema (Minimal)

```json
{
  "level": "simple | standard | epic",
  "phase": "draft | researching | researched | designing | planning | reviewing | ready | executing | reviewing_code | complete | blocked",
  "status": "active | paused | complete | blocked",
  "mode": "sequential | parallel"
}
```

The extension uses this only for:
- Validating that phase transitions are legal
- Detecting when an agent stopped mid-process and re-triggering continuation
- Reporting current status

All workflow intelligence lives in the skills and orchestrator, not in the extension.

`mode` is optional for legacy/sequential state. Parallel planning reuses `planned`, `reviewed`,
`ready`, `executing`, and `reviewing_code`; it does not introduce a second phase vocabulary.
