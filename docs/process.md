# Development Process

This document defines the full lifecycle for each workflow type. The orchestrator follows these stages in order, calling sub-agents for each step.

## Commit Discipline

Agents should not accumulate large uncommitted work. Human-reviewed planning artifacts are
committed at approval boundaries. Sequential implementation commits every completed task
with its tests and `worklog.md` update; opportunistic parallel dispatch follows the
same task-commit discipline per dispatched task.

## Task Tracking and Backlog Capture

Current-plan tasks live in `plan.md` and `worklog.md`. Work discovered during a plan that is useful but outside the current scope belongs in the repo backlog, not silently added to the current task list.

Each repo defines its own backlog implementation, but it must document the hooks described in [Task Tracking](./references/task-tracking.md): where backlog items live, how to create them, how IDs are assigned, how to list `Up next` work, and how to reference created items from worklogs or reviews.

Every agent-created backlog item must have a stable ID and a source backlink. The source artifact must also reference the created ID, for example: `Created backlog item TASK-0042 from T3.` This makes follow-up work traceable through normal repo search.

By default, non-critical agent-discovered follow-ups should be proposed for capture as `Inbox` items with `origin: plan-follow-up`. If a discovery may affect current-plan correctness, safety, or verification, the agent must stop and ask whether to fix, re-plan, or backlog it.

Backlog items are intake records, not implementation plans. When a backlog item is selected for work, it becomes input to the normal process: Discovery creates or updates `brief.md`, Design creates `approach.md`, and Execution creates the plan artifacts for the selected pipeline. Moving an item to `Up next` means it is approved to start that process, not that it already contains an implementation plan. The end-to-end state machine from `Inbox` to a merge-ready PR, including human gates and scheduled jobs, is [Delivery Pipeline](./references/delivery-pipeline.md).

---

## Requirement Handling

Requirements describe durable product/system expectations. Plans describe temporary implementation work that satisfies, verifies, or changes those expectations.

Each repo may define its own requirements implementation, but it should document the hooks described in [Requirements Handling](./references/requirements.md): where actors/personas live, where use cases and workflows live, where functional/non-functional/operational requirements live, how stable IDs are assigned, how artifacts cite requirements, and how approved requirement changes are applied.

Canonical requirements docs should normally represent current accepted requirements. Draft, unclear, or proposed requirement changes should live in planning artifacts until reviewed and approved. Discovery records requirement context and questions; Design drafts requirement change proposals; the Plan identifies approved requirement edits as tasks; Execution applies them; Review checks alignment.

Tests are verification evidence, not the default canonical requirements source. Tests should cite requirement IDs they verify when the repo maintains requirement traceability. Requirements do not need to manually list every test that verifies them.

If work reveals a missing, unclear, or conflicting requirement that affects current-plan correctness, safety, scope, or verification, the agent must stop and ask whether to update the approach/plan, change the requirement, or adjust scope.

---

## Feature Development

The standard workflow for implementing new capabilities, enhancements, refactors, or integrations.

### Stages

```
brief → research → approach → approach review
                              └─ plan → plan review → worklog → execute → code review → PR review
```

#### 1. Brief

**Purpose:** Capture intent. What are we trying to do and why?

**Artifact:** `brief.md`

**What happens:**
- Document goals and success criteria
- Document non-goals (explicit scope boundaries)
- Document constraints (time, technology, backwards compatibility, etc.)
- Identify stakeholders and any approval requirements
- Capture the motivation — why this work matters now

**Quality gate:** Brief is clear enough that someone unfamiliar with the context can understand what needs to happen without guessing.

---

#### 2. Research

**Purpose:** Understand the current state. What exists? What are we working with?

**Artifact:** `findings/` directory with one or more focused findings files

**What happens:**
- Explore relevant codebase areas (modules, patterns, existing implementations)
- Identify dependencies and integration points
- Review existing documentation (architecture, design rules, AGENTS.md files)
- Identify relevant test infrastructure and verification approaches
- Discover constraints not obvious from the brief
- Note any prior art, similar patterns, or related existing features
- Identify risks and unknowns

**Findings file strategy:** Split research output into multiple focused files with descriptive names. This enables later stages to load only the findings relevant to their current concern:

| File | When to create |
|------|----------------|
| `current_state.md` | Always (what exists today) |
| `code_structure.md` | When the change touches multiple areas |
| `dependencies.md` | When external libraries or services matter |
| `root_cause.md` | Bug fix workflows (evidence-based root cause) |
| `library_research.md` | When introducing or evaluating libraries |
| `prior_art.md` | When existing patterns should be followed |
| `constraints.md` | When non-obvious limitations are discovered |

**Quality gate:** Findings are factual, evidence-based, and reference specific files/APIs/code locations. No speculation presented as fact. Each findings file is self-contained and named so an agent can decide whether to read it based on the filename alone.

**Tools commonly used:** Code search, file reading, gitnexus exploration, web search for external library documentation.

---

#### 3. Approach

**Purpose:** Define the conceptual model and structural decisions for solving the problem. How will the pieces fit together?

**Artifact:** `approach.md`

**What happens:**
- Define the model/structure being introduced or modified
- Identify the key components and how they relate
- Document the high-level architecture of the solution
- Make and record structural decisions (where things live, what depends on what, what interfaces look like)
- Identify patterns to follow from the existing codebase
- Document alternatives considered and why this approach was chosen
- Define the boundary between what changes and what stays the same

**Why this exists:** The plan itself is a detailed implementation checklist. But before you can write a good implementation plan, you need to align on *how* you're solving the problem. This stage prevents the plan from trying to carry both conceptual design and execution details. It also provides a natural review point — you can validate the approach before investing in detailed planning.

**Quality gate:** A competent developer could read the approach and understand the solution structure without needing to ask clarifying architecture questions. Key decisions are recorded with rationale. The approach is reviewed for brief alignment, boundary clarity, and risk completeness before moving to planning.

**Review:** The approach is reviewed iteratively (using the `review-approach` skill) until zero significant issues remain. This catches missing components, weak boundaries, and brief misalignment before investing in detailed planning.

**Commit checkpoint:** Commit `findings/`, `approach.md`, `approach_review.md`, and state updates only after the reviewed approach is accepted by the human. Use `design: approve approach for <slug>`.

---

#### 4A. Sequential Plan

**Purpose:** Create a detailed, executable implementation plan with dependency-ordered tasks, verification classes, and test-first checklists.

**Artifact:** `plan.md`

**What happens:**
- Break the approach into concrete implementation tasks
- Order tasks by dependency (what must be done before what)
- Assign a verification class to every task (contract / characterization / check / none — see `docs/testing-strategy.md`)
- Write test-first checklists for each task (Red → Green → Verify)
- Assign an execution tier to every task (high / low model class)
- Define verification gates (what commands prove each task is done)
- Identify the coverage matrix (what behaviors need tests at what layers)
- Reference specific files, modules, and test locations

**Quality gate:** Every task names concrete files, specific behaviors to test, and exact verification commands. No vague "implement the feature" steps. An implementer can execute the plan without making additional design decisions.

**Key principle:** The plan references repo-specific verification commands from canonical documentation — it does not invent them. Test *types* (unit, integration, e2e, golden) are process concepts; test *commands* come from the repo.

---

#### 5A. Sequential Plan Review

**Purpose:** Catch issues before implementation begins. Find missing details, inconsistencies, logic bugs, and gaps that would cause rework.

**Artifact:** `plan_review.md`

**What happens:**
- Review task graph for correctness (dependency ordering, no cycles)
- Review test-first checklists for specificity (do they name files, behaviors, commands?)
- Check for logic bugs (cross-section contradictions)
- Verify coverage matrix completeness
- Check that verification commands reference canonical repo docs
- Identify any remaining implementer decisions that should be resolved
- Iterate until zero significant issues remain

**Quality gate:** Zero Blocker/Critical/Major issues. Plan is handoff-ready — an implementer can execute without additional design decisions.

**Loop behavior:** The orchestrator runs plan reviews iteratively until the pass criteria is met. Each review pass is one sub-agent call. The review is complete only when zero significant issues are found in a pass.

**Commit checkpoint:** After plan review is clean and the human approves implementation, commit `plan.md`, `plan_review.md`, and state updates as `plan: approve implementation plan for <slug>` before creating or executing from the worklog. (Delivery-pipeline items with `Autonomy: auto` skip this approval — see [Delivery pipeline](references/delivery-pipeline.md#2-work-inside-in-progress-by-track).)

---

#### 6A. Sequential Worklog

**Purpose:** Create the execution tracking document that supports task-by-task implementation with resume capability.

**Artifact:** `worklog.md`

**What happens:**
- Extract task list from plan
- Define verification commands (fast feedback, task completion gate, final gate)
- Document gate policies (what to do if broader gates fail for unrelated reasons)
- Set up the loop log structure for tracking execution
- Define completion criteria

**Quality gate:** Worklog includes concrete verification commands copied from the plan/repo docs. An agent can read only the worklog and know exactly what to do next.

**Commit checkpoint:** Commit the initialized `worklog.md` before starting T1. Use `worklog: initialize execution log for <slug>` unless the worklog was intentionally included in the approved plan commit.

---

#### 7A. Sequential Execute

**Purpose:** Implement the plan one task at a time using strict TDD.

**Artifact:** Updates to `worklog.md` + source code changes + git commits

**What happens (per task, per its verification class):**
- Read worklog to determine current task
- For `contract`/`characterization`: write a failing test, implement the minimal change to make it pass
- For `check`/`none`: run the task's proving command
- Run task-completion verification
- Capture accepted follow-up backlog items using the repo's task-tracking mechanism
- Update worklog with results and any created backlog item IDs
- Commit code, tests, and worklog together
- Advance to next task

**Quality gate:** Each task passes its verification gate before advancing. All tasks complete before moving to final code review.

**Commit checkpoint:** Every task ends with exactly one local commit named `task(T<N>): <short description>`. The commit must include source changes, test changes, and the matching `worklog.md` update. Do not commit code first and update the worklog afterward.

**Loop behavior:** One task per sub-agent call. The orchestrator advances through tasks sequentially, each in a fresh sub-agent context with the worklog as the entry point.

**Backlog behavior:** Follow-up work discovered during execution is not added to the current plan's task list unless the human explicitly changes scope. Non-blocking follow-ups are captured in the repo backlog after confirmation and referenced from `worklog.md` by stable ID.

##### Per-Task Review (Set by the Plan)

The plan decides, per task, whether to run a lightweight code review of just that task's changes before advancing: a plan-level `Task review default` (`each` or `final-only`) and an optional per-task `Task review: yes | no` override. The final code review always runs.

**Why this helps:**
- Catches errors early before subsequent tasks build on top of them
- Prevents cascading mistakes that are harder to fix at the end
- Enables using lower-cost models for implementation while a higher-quality model reviews each step
- The final code review still happens (catches cross-task interaction issues) but finds fewer problems

**How it works:**
```
For each task:
  1. Implement and commit atomically (sub-agent: implementation model)
  2. Review just this task's commit (sub-agent: review model)
  3. Fix and commit any issues found (sub-agent: implementation model)
  4. Advance to next task
```

**When to use:** Recommended when:
- Using a lower-cost model for implementation
- The plan has many tasks and errors compound
- Working on unfamiliar codebase areas
- Tasks have tight dependencies (T2 builds directly on T1's output)

**When to set `no` (or default `final-only`):**
- Using a high-quality model for both implementation and final review
- Tasks are independent and don't build on each other
- The change is small (3 or fewer tasks)

This does NOT replace the final code review — it supplements it. The final review catches cross-task issues, coverage gaps, and architectural concerns that single-task reviews miss.

---

#### 8A. Sequential Code Review

**Purpose:** Post-implementation quality gate. Verify that the code actually delivers what the plan specified.

**Artifact:** `code_review.md`

**What happens:**
- Review actual diffs against plan requirements
- Check coverage matrix compliance (are all behaviors tested?)
- Scan for test anti-patterns (tautological assertions, source-reading tests)
- Check implementation correctness (logic bugs, missing error handling)
- Verify documentation alignment (promised doc updates exist)
- Assess regression risk (shared symbols changed without consumer tests)

**Quality gate:** Zero Blocker/Critical/Major open issues.

**Loop behavior:** The orchestrator alternates between code review (finds issues) and fix passes (resolves issues) until clean or a cap is reached.

**Backlog behavior:** Blocker/Critical/Major findings are current-plan fixes. Minor, Nit, or explicitly non-blocking improvement suggestions may be proposed as backlog items instead of blocking completion. Accepted review follow-ups are captured in the repo backlog and referenced from `code_review.md` or `worklog.md` by stable ID.

---

#### 4B. Opportunistic Parallel Dispatch

The pipeline is sequential-first. During execution (stage 7A), the orchestrator MAY
dispatch plan tasks concurrently when they are obviously independent — no dependency
edge between them and disjoint touched files. Bounds are each orchestrator's own
policy for its environment; there is no universal concurrency cap. Any conflict,
failure, or ambiguity falls back to sequential execution of the affected tasks.

Parallel execution is an acceleration, never a planning artifact: plans stay
dependency-ordered task lists; there is no DAG, no tasks.json, no fence groups.
The historical parallel machinery (dynamic-* skills, wave scheduler, team mode) is
retired — see [ADR 0006](adr/0006-retire-parallel-execution.md).

---

#### 9. PR Review

After code review passes, the work enters the PR review process defined in
[PR Review Process](references/pr-review.md): the author role prepares the PR body,
evidence, and self-review; an independent reviewer role produces the verdict; the human
merges. That document is canonical for everything past this point.

---

## Bug Fix

The workflow for fixing defects, regressions, and incorrect behavior. Similar to feature development but with debugging replacing pure research.

### Stages

```
brief → debug/research → approach → approach review → planning pipeline
```

#### 1. Brief

Same as feature development. Document the bug: what's happening, what should happen, reproduction steps if known, severity/impact.

---

#### 2. Debug / Research

**Purpose:** Find the root cause. Understand why the bug exists and what's affected.

**Artifact:** `findings/` directory (includes `root_cause.md` at minimum)

**What happens:**
- Reproduce the bug (or confirm reproduction steps)
- Trace the execution path to identify where behavior diverges from intent
- Identify the root cause (not just the symptom)
- Assess blast radius — what else might be affected by the same root cause
- Identify existing tests that should have caught this (why didn't they?)
- Research related code areas for similar latent bugs

**Findings files for bug fix:**
| File | Purpose |
|------|--------|
| `root_cause.md` | The core output: reproduction, trace, root cause with evidence |
| `current_state.md` | How the affected area works today |
| `blast_radius.md` | What else might be affected (optional, for complex bugs) |

**Debugging techniques:**
- Read error messages and stack traces
- Trace execution flows through the code (gitnexus, code search)
- Check recent changes in the affected area (git log, blame)
- Run existing tests to confirm current behavior
- Add temporary logging/assertions to narrow the cause
- Check AGENTS.md and architecture docs for intended behavior

**Quality gate:** Root cause is identified with specific file/line references. The "why" is understood, not just the "what."

---

#### 3. Approach

**Purpose:** Define how to fix the bug without introducing new problems.

**Artifact:** `approach.md`

**What happens:**
- Document the root cause (from findings)
- Define the fix strategy (what specifically changes)
- Identify what must NOT change (regression risk areas)
- Determine if the fix exposes other issues that need addressing
- Decide whether the fix is a targeted patch or requires structural change
- Document why existing tests didn't catch this and how new tests will prevent regression

**Quality gate:** The fix approach addresses the root cause (not just the symptom) and includes a clear regression prevention strategy.

---

#### 4–8. Planning → Execute → Review

Same as feature development. The plan for a bug fix always includes:
- A regression test that reproduces the bug (must fail before fix, pass after)
- The minimal fix
- Verification that no related behaviors regressed

---

### Simple Bug Fix (abbreviated)

For bugs with obvious root cause and straightforward fix:

```
brief → implement (with regression test) → verify
```

Use the simple change workflow (below) but always include a regression test.

---

## Simple Change

The lightweight workflow for trivial changes that don't warrant full ceremony.

### When to use
- Typo fixes in documentation or code
- Configuration changes with no behavioral impact
- Dependency version bumps with no API changes
- Small, obvious bug fixes where root cause is immediately clear
- Style/formatting changes

### Stages

```
brief → implement → verify
```

#### 1. Brief

**Purpose:** Even simple changes benefit from a brief note about what and why.

**Artifact:** `brief.md`

**What happens:**
- One or two sentences describing the change and motivation
- If it's a bug fix: note the symptom and obvious root cause

---

#### 2. Implement

**What happens:**
- Make the change
- If it's a bug fix: write a regression test first (always)
- Run relevant verification commands
- Commit

---

#### 3. Verify

**What happens:**
- Run the appropriate verification gate for the scope of change
- Confirm no regressions

**No separate plan, review, worklog, or code review artifacts are created.**

---

## Epic

The workflow for large initiatives that span multiple features, components, or workstreams.

**Important:** An epic is not ready for child-plan execution when `approach.md` is complete. It is ready only when the epic has been explicitly decomposed into workstreams and child plans in `epic.md`.

### When to use
- Migrations (data, API, architecture)
- Multi-component features that require coordinated changes
- Initiatives with multiple distinct but related deliverables
- Work that takes multiple days/weeks and benefits from phased delivery

### Structure

An epic is a **container** for multiple standard plans, organized into workstreams.

```
epic brief → epic research → epic approach → epic decomposition → child plans (each following standard process)
```

#### 1. Epic Brief

**Purpose:** Define the overall initiative — scope, motivation, constraints, and success criteria.

**Artifact:** `brief.md`

**What happens:**
- Define the overall goal and motivation
- Identify source documents (requirements, user workflows, existing research, etc.)
- Document non-goals and constraints
- State why this is an epic rather than a standard plan
- Capture any known workstream ideas at a high level (refined later)

---

#### 2. Epic Research

**Purpose:** Understand the cross-cutting landscape before defining workstreams and child plans.

**Testing-readiness trigger:** If research reveals broad regression risk, permission/visibility changes, migration-heavy work, high fan-out derived surfaces, weak fixture/harness support, or poor negative coverage for likely failure modes, the Design phase must explicitly decide whether a preparatory testing-readiness child plan/workstream is required before implementation-heavy work begins.

**Artifact:** `findings/` directory at the epic level

**What happens:**
- Research the current state of the system areas being changed
- Identify cross-cutting dependencies between workstreams
- Discover constraints that affect multiple child plans
- Investigate migration paths, compatibility requirements, or technical prerequisites
- Produce focused findings files (same naming patterns as standard research)

**Why epic-level research matters:** Without it, child plans independently discover the same constraints and make potentially conflicting assumptions. Epic research establishes shared understanding.

---

#### 3. Epic Approach

**Purpose:** Define the overall architectural strategy for the initiative.

**Artifact:** `approach.md` at the epic level

**What happens:**
- Define the overall model/architecture for the solution
- Make structural decisions that affect all child plans
- Define boundaries between workstreams (what each workstream owns)
- Document key decisions with rationale
- Define what changes vs what stays at the epic level
- Establish patterns and principles child plans should follow

---

#### 4. Epic Decomposition

**Purpose:** Turn the epic-level approach into an executable map of workstreams and child plans.

**Artifact:** `epic.md`

**What happens:**
- Break the initiative into workstreams (logical groupings) based on research and approach
- Define child plans within each workstream with:
  - What the child plan is meant to build (1-3 sentences)
  - Reference docs relevant to this child plan
- Note light sequencing constraints (what depends on what)
- Identify cross-cutting concerns and open questions
- Explicitly identify any tranche 0 / preparatory work before implementation-heavy child plans
- Identify the recommended first child plan to execute
- Write or update `epic.md` with the full workstream and child plan index

**Quality gate:** Every major implementation area is owned by a workstream, preparatory work is explicit, the first child plan is obvious, and dependencies are documented.

---

#### 5. Epic Decomposition Review

**Purpose:** Validate that the epic has been broken down correctly before child-plan execution begins.

**Artifact:** `epic_review.md`

**What happens:**
- Review `epic.md` for workstream completeness
- Check child-plan boundaries for overlap or missing ownership
- Review sequencing and dependency logic
- Verify preparatory work (including testing-readiness work, if needed) is explicit
- Verify the recommended first child plan is sensible
- Iterate until zero significant issues remain

**Quality gate:** The epic decomposition is complete, sequenced, and execution-ready. No major implementation area is unowned, and any preparatory work needed before implementation-heavy plans is explicitly represented.

---

#### 6. Child Plan Execution

**What happens:**
- Each child plan follows the full standard process (brief → research → approach → plan → review → worklog → execute → code review)
- The orchestrator advances through child plans in dependency order
- Each child plan gets its own numbered subdirectory within the epic
- Child plan research is lighter (references epic-level findings as shared context)
- The epic doc is updated with execution status as child plans complete

**Guardrail:** The execution orchestrator should not create a detailed `plan.md` directly at the epic root. Execution begins at the child-plan level only after both `epic.md` and `epic_review.md` exist.

---

### Epic Execution Record

As child plans complete, the epic doc accumulates an execution record:
- When each child plan was created and completed
- Duration
- Any deferred follow-ups discovered during execution
- Cross-cutting issues that emerged

### Epic-specific review requirement

Epics have two review gates before child-plan execution starts:
1. **Approach review** — confirms the architecture is sound (`approach_review.md`)
2. **Epic decomposition review** — confirms the workstream/child-plan breakdown is sound (`epic_review.md`)

Both are required. Architecture without decomposition is not execution-ready.

---

## Process Decision: Choosing a Level

The orchestrator (or human) decides the plan level based on:

| Signal | → Level |
|--------|---------|
| Change is obvious and small (< 30 min of work) | Simple |
| Single coherent feature/fix with clear boundaries | Standard |
| Multiple related features or cross-component coordination needed | Epic |
| Uncertain scope — might be simple or might be complex | Start with Standard brief + research; the research may reveal it's simple or needs an epic |

When in doubt, start at Standard. It's easy to skip stages if research reveals the change is trivial. It's harder to recover from diving into implementation without adequate planning.
