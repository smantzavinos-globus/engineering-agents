# Requirements Handling

This reference defines the process-level contract for requirements handling. It defines **what** repos should expose; each repo defines **how** requirements are stored, queried, updated, and referenced.

The model mirrors task tracking: the process defines common concepts and required hooks, while a repo maps them to Markdown, a requirements CLI, a tracker, generated reports, or another durable system.

---

## Core Boundary

Requirements describe durable product/system expectations. Plans describe temporary implementation work to satisfy, verify, or change those expectations.

```text
requirements = durable expectations
brief.md     = current work intent
approach.md  = selected design direction and proposed requirement changes
plan.md      = implementation task graph, including approved requirement edits
tests        = verification evidence
backlog      = future work intake
```

Tests are verification evidence. Requirements live in the repo's canonical requirements system. Tests may cite the requirements they verify, but tests are not the default source of durable product/system intent.

Canonical requirements docs should normally describe the repo's **current accepted requirements**. Draft, unclear, or proposed requirement changes should live in planning artifacts until approved and applied.

---

## Conceptual Structure

Use this as the recommended conceptual model, while allowing repos to flatten or adapt it. Functional requirements sit alongside workflows under a use case; they are not children of workflows.

```text
Actor / Persona
  → Use Case
    → Workflow / Scenario(s)
    → Functional Requirement(s)

Cross-cutting:
  → Non-Functional Requirement(s)
  → Operational Requirement(s)
```

Definitions:

- **Actor / Persona** — a human, system, operator, admin, service, or external integration that interacts with or depends on the repo's output.
- **Use Case** — a goal an actor needs to accomplish.
- **Workflow / Scenario** — a concrete path through a use case, including mainline and important alternate/error flows.
- **Functional Requirement** — behavior or capability the system must provide for a use case. Workflows may exercise or demonstrate these requirements, but do not own them hierarchically.
- **Non-Functional Requirement** — quality constraints such as performance, reliability, security, accessibility, compatibility, maintainability, privacy, or usability.
- **Operational Requirement** — deployment, observability, migration, backup/restore, support, runbook, safety, or operating constraints.

---

## Required Repo Hooks

Every repo using requirements with this process should document the following hooks in `AGENTS.md`, a requirements doc, or equivalent repo guidance.

| Hook | Required question answered |
|------|----------------------------|
| Requirements store | Where do current durable requirements live? |
| Actor/persona definitions | Where are users, operators, systems, and integrations defined? |
| Use case definitions | Where are user/system goals defined? |
| Workflow/scenario definitions | Where are concrete flows and alternate/error paths defined? |
| Functional requirements | Where are required behaviors/capabilities defined? |
| Non-functional requirements | Where are quality constraints defined? |
| Operational requirements | Where are deployment/operations constraints defined? |
| Stable IDs | How are requirement-related IDs assigned or discovered? |
| Reference format | How should briefs, approaches, plans, reviews, commits, and summaries cite requirement IDs? |
| Test citation format | How should tests cite the requirement IDs they verify? |
| Traceability rules | Which links are manually maintained, and in which direction? |
| Apply approved requirement changes | How does execution update canonical requirements after approval? |
| Retire/change requirements | How are current requirements removed, replaced, or materially changed? |
| Validation/query commands | What read-only commands or reports exist, if any? |
| Approval policy | Which requirement changes require human approval before editing canonical requirements? |
| Tool/auth/fallback | What tool access is required, which operations mutate state, and what should agents do if the tool is unavailable? |

Repos may implement these hooks with files, issue trackers, CLIs, generated indexes, project docs, or another durable system.

---

## Minimum Contract

Keep the minimum contract lightweight.

### Requirement objects

Each durable requirement should have:

| Concept | Purpose |
|---------|---------|
| Stable ID | Allows briefs, plans, tests, reviews, commits, and search to reference the requirement |
| Title or summary | Human-readable requirement name |
| Requirement text | The actual durable expectation |
| Type | Functional, non-functional, or operational |
| Source or rationale | Why this requirement exists, if known |
| Trace context | The use case, workflow, area, or global scope it belongs to |

A status field is **not required** for the default process. By default, canonical requirements docs represent current accepted requirements. Draft/proposed/unclear changes live in planning artifacts until they are approved and applied.

### Related objects

Actors/personas, use cases, and workflows/scenarios should have stable IDs when other artifacts reference them. Small repos may use stable headings; larger repos may use system-assigned IDs.

Recommended ID prefixes:

```text
ACT-001   actor/persona
UC-001    use case
WF-001    workflow/scenario
FR-001    functional requirement
NFR-001   non-functional requirement
OPR-001   operational requirement
```

Repos may use slug IDs instead:

```text
UC-config-authoring
FR-config-membership-editing
NFR-local-first-data
OPR-monthly-close-status
```

Document whichever ID scheme the repo uses.

---

## Requirement Changes in the Planning Lifecycle

Because this process controls brief → approach → plan → execution, proposed requirement changes should usually move through those artifacts before becoming canonical requirements.

### Discovery / `brief.md`

Discovery identifies requirement context and gaps. It may cite existing requirements and record questions, but should not silently edit canonical requirements.

```md
## Requirement Context

Relevant existing requirements:
- UC-001
- FR-003
- NFR-002

Requirement questions:
- Is this behavior intended for all users or only admins?
- Does this change an existing workflow?
```

### Design / `approach.md`

Design drafts proposed requirement changes when the approach implies new or changed durable intent.

```md
## Requirement Change Proposal

### Add

#### FR-009 — Export includes generation timestamp

The system must include a generation timestamp in exported reports.

Rationale:
- Required for auditability.

### Update

#### FR-004 — Credit-card payments are excluded from expense totals

Proposed change:
- Clarify that liability payment transfers are excluded from P&L expense totals.

### Remove

<none>
```

This proposal is reviewed with the approach before execution planning.

### Plan / `plan.md`

The approved plan records which requirement changes will be applied and in which tasks.

```md
## Requirement Updates

| Requirement change | Applied in task | Notes |
|--------------------|-----------------|-------|
| Add FR-009 | T1 | Update `docs/requirements.md` before implementation |
| Update FR-004 | T1 | Clarify report semantics |
```

### Execution / `worklog.md`

Execution applies approved requirement changes as part of normal task work and records what changed.

```md
T1:
- Updated requirements: added FR-009, updated FR-004.
```

### Review / `code_review.md`

Review checks whether implementation matches cited requirements and whether any durable requirement changes were made without being proposed/approved.

---

## Traceability Expectations

Prefer manual links that flow in one direction and generated reverse links when tooling exists. Avoid requiring hand-maintained bidirectional trace links because they drift.

### Recommended manual trace direction

- Use cases reference their actor/persona.
- Workflows reference their use case.
- Functional requirements reference their use case and may reference related workflows.
- Non-functional and operational requirements reference their scope: global, area, use case, or workflow.
- Briefs, approaches, plans, worklogs, reviews, and commits cite requirement IDs when relevant.
- Tests cite the requirements they verify.

Requirements should not be required to list every test that verifies them. Let tests point up to requirements; let tools aggregate reverse test coverage when the repo has tooling.

### Example traces

Requirement doc:

```md
### FR-004 — Credit-card payments are excluded from expense totals

- Type: functional
- Use case: UC-004
- Related workflows: WF-003
- Source: human-request

Credit-card payment transfers must not be counted as business expenses in P&L reports.
```

Test file:

```python
# Requirement: FR-004
def test_credit_card_payments_excluded_from_expense_totals():
    ...
```

Plan task:

```md
**Requirement refs:** FR-004, OPR-002
```

---

## Agent Behavior

### Do not silently invent requirements

Agents may cite existing requirements and propose new or changed requirements, but must not silently convert implementation details into durable requirements.

If implementation reveals a missing, unclear, or conflicting requirement:

1. If it affects current-plan correctness, safety, scope, or verification: stop and ask whether to update the approach/plan, change the requirement, or adjust scope.
2. If it is useful but non-blocking: capture it as a proposed requirement change in the appropriate planning artifact or as a backlog item according to repo policy.
3. If canonical requirements must change: apply only approved changes using the repo's documented mechanism.

### Tests are evidence

Tests should reference requirement IDs when the repo maintains requirements traceability. Tests should not be the only durable record of product/system intent.

---

## Repo Requirements Documentation Pattern

Repos should keep root `AGENTS.md` concise and route agents to a detailed requirements document.

### Root AGENTS.md blurb

```md
## Requirements

Requirements system: <Markdown | requirements CLI | tracker | generated docs | none>
Details: `<path/to/requirements-doc.md>`

Rules:
- Current durable requirements live in `<location/system>`.
- Requirement IDs use `<FR-001 | FR-slug | system assigned IDs>`.
- Tests cite requirements they verify; requirements do not need to list tests manually.
- Draft requirement changes live in plan artifacts until approved and applied.
- Durable requirement changes require human approval unless explicitly delegated.
```

### Detailed repo doc skeleton

```md
# Requirements Handling

## System

This repo uses <system> as the canonical requirements store.

## Required Operations

| Operation | How to do it |
|-----------|--------------|
| Find current requirements | <file/command> |
| List actors/personas | <file/command> |
| List use cases | <file/command> |
| List workflows/scenarios | <file/command> |
| List functional requirements | <file/command> |
| List non-functional requirements | <file/command> |
| List operational requirements | <file/command> |
| Assign/discover ID | <rule/command> |
| Cite requirement | <format> |
| Apply approved requirement change | <edit procedure/command> |
| Retire or replace requirement | <edit procedure/command> |
| Validate/query requirements | <optional commands> |
| Approval policy | <when to ask before editing> |

## Traceability Rules

- <manual link direction and required references>
- <test-to-requirement citation format>
- <plan/review citation expectations>
```

The operations table is the most important part: it gives agents a stable contract regardless of the backing system.

---

## Simple Markdown Reference Implementation

For small repos, the recommended lightweight implementation is a single canonical file:

```text
docs/requirements.md
```

The file describes current accepted requirements. Proposed or unclear requirement changes live in planning artifacts until approved and applied.

### Root AGENTS.md blurb

```md
## Requirements

Requirements system: Markdown
Details: `docs/requirements.md`

Rules:
- Durable current requirements live in `docs/requirements.md`.
- IDs use `ACT-001`, `UC-001`, `WF-001`, `FR-001`, `NFR-001`, and `OPR-001`.
- Tests cite the requirements they verify.
- Draft requirement changes live in brief/approach/plan artifacts until approved.
- Canonical requirement edits require human approval unless explicitly delegated.
```

### `docs/requirements.md` skeleton

```md
# Requirements

## System

This file is the canonical source for current accepted requirements.

## Required Operations

| Operation | How to do it |
|-----------|--------------|
| Find current requirements | Read this file |
| List actors/personas | Read `## Actors / Personas` |
| List use cases | Read `## Use Cases` |
| List workflows/scenarios | Read `## Workflows / Scenarios` |
| List functional requirements | Read `## Functional Requirements` |
| List non-functional requirements | Read `## Non-Functional Requirements` |
| List operational requirements | Read `## Operational Requirements` |
| Assign ID | Find highest existing prefix and use next number |
| Cite requirement | Use IDs such as `FR-001`, `NFR-002`, `OPR-003` |
| Apply approved requirement change | Edit this file as part of the approved plan task |
| Retire or replace requirement | Remove/replace the current requirement; record rationale in the approving plan |
| Validate/query requirements | Use `rg` for IDs and references |
| Approval policy | Ask before editing canonical requirements unless explicitly delegated |

## Actors / Personas

| ID | Persona | Goal |
|----|---------|------|
| ACT-001 | Maintainer | Safely change and validate the system |

## Use Cases

| ID | Actor | Use Case |
|----|-------|----------|
| UC-001 | ACT-001 | Validate configuration changes before applying them |

## Workflows / Scenarios

### WF-001 — Run fast validation before applying changes

- Use case: UC-001
- Actor: ACT-001

Steps:
1. Edit configuration.
2. Run fast validation.
3. Review failures.
4. Apply only after validation passes.

## Functional Requirements

### FR-001 — Fast validation command exists

- Type: functional
- Use case: UC-001
- Related workflows: WF-001
- Source: human-request

The repo must provide a documented fast validation command for common local changes.

## Non-Functional Requirements

### NFR-001 — Fast validation remains quick

- Type: non-functional
- Scope: UC-001
- Source: human-request

Fast validation should complete within the repo-defined target time.

## Operational Requirements

### OPR-001 — Apply commands are explicit

- Type: operational
- Scope: global
- Source: human-request

Commands that mutate user/system state must be documented separately from read-only validation commands.
```

### ID assignment

Use normal repo search to find existing IDs:

```bash
rg "(ACT|UC|WF|FR|NFR|OPR)-[0-9]{3}" docs/requirements.md
```

Then choose the next unused number for the relevant prefix. If there is ambiguity or concurrent editing risk, ask before assigning an ID.

### Compact table variant

Very small repos may keep requirements in tables, similar to:

```md
## Functional Requirements

| ID | Requirement | Scope |
|----|-------------|-------|
| FR-001 | Canonical ledger data is stored in CSV. | UC-001 |
| FR-002 | Imported transactions preserve source IDs for dedupe. | UC-001 |
```

When a table row becomes too terse to drive implementation or review, expand it into a headed item.

---

## Workflow Documentation Pattern

For complex user-facing systems, a repo may split workflow documentation into an overview and detailed companion file. This pattern is optional, but useful when workflows must drive UI/API/agent implementation.

Recommended files:

```text
docs/product/workflows/<area>_workflows.md
docs/product/workflows/<area>_workflow_details.md
```

### Overview document structure

```md
# <Area> User Workflows

## Why this document exists
## Primary interaction model
## Workflow family
## Core concepts and naming
## Core rules

## Workflow 1 — <name>

### Goal
### Typical starting point
### Typical user intents
### High-level step flow
### Key questions the workflow should answer

## Surface model
## Relationship to other documents
## Open questions
```

### Details document step template

```md
## Step N — <name>

**Related use case:** UC-001
**Related requirements:** FR-001, NFR-002

**Primary surface:** <surface>
**Supporting surfaces:** <surfaces>

**Context the system should know:**
- ...

**Data visible to the user:**
- ...

**Actions that should be available:**
- ...

**Agent/chat actions that should be available:**
- ...

**Exact user action pattern:**
1. ...

**Result / exit condition:**
- ...
```

This pattern captures enough detail to drive implementation without making workflows children of functional requirements. Workflows and functional requirements remain siblings under a use case and link to each other by ID.

---

## CLI-Backed Reference Implementation

For repos with a requirements management tool or custom CLI, document exact commands. The process does not mandate a specific tool.

### Root AGENTS.md blurb

```md
## Requirements

Requirements system: `<req-system>`
Details: `docs/engineering/requirements.md`
CLI: `<req-cli>`

Rules:
- Read operations are safe.
- Mutating operations require human approval unless explicitly delegated.
- Run `<req-cli> check` after requirements edits.
- Tests cite requirements they verify.
```

### Required operations table

| Operation | Command |
|-----------|---------|
| List actors | `<req-cli> actors list` |
| Show actor | `<req-cli> actors show ACT-001` |
| List use cases | `<req-cli> use-cases list` |
| Show use case | `<req-cli> use-cases show UC-001` |
| List workflows | `<req-cli> workflows list --use-case UC-001` |
| Show workflow | `<req-cli> workflows show WF-001` |
| List requirements | `<req-cli> requirements list` |
| Show requirement | `<req-cli> requirements show FR-001` |
| Apply approved requirement change | `<req-cli> requirements update FR-001 ...` or documented edit procedure |
| Retire/replace requirement | `<req-cli> requirements replace FR-001 --by FR-009` or documented edit procedure |
| Link workflow to requirement | `<req-cli> links create WF-001 FR-001` |
| Link test/evidence | `<req-cli> evidence add FR-001 tests/foo_test.py::test_bar` |
| Validate graph | `<req-cli> check` |
| Show evidence gaps | `<req-cli> gaps` |
| Export report | `<req-cli> export --format markdown` |

If a repo expects agents to use a CLI, it must document exact command names, arguments, output formats, whether commands mutate durable requirements, and what approval is required before mutating commands run.

### Validation expectations

CLI-backed systems should consider validation checks inspired by requirements aggregation tools:

- duplicate IDs
- missing parent/context links
- tests referencing nonexistent requirements
- workflows without use cases
- functional requirements without use-case scope
- requirement IDs that are not referenced by any plan/test when the repo expects coverage
- deprecated/replaced IDs still referenced by active tests or plans, if the repo tracks history

Validation can start as warning-only during migration, then become stricter as the repo's requirements system matures.
