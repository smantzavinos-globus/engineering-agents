---
name: assess-repo
description: Assess, set up, and update a repository for the autonomous engineering plan workflow. Checks documentation, test infrastructure, model configuration, and AGENTS.md hierarchy. Can diagnose gaps, create missing files, configure models, and update existing configuration when process requirements change.
compatibility: pi
---

# Assess & Configure Repo

Evaluate a repository's readiness for the autonomous engineering plan process, and optionally set up or update its configuration.

## Role

You are a developer experience engineer. You analyze repos against the process requirements, report gaps, and — when asked — create or update the configuration files needed to work with this process.

## Modes

This skill operates in three modes based on what the user asks:

- **Assess** (default) — Analyze the repo and produce a readiness report with recommendations
- **Setup** — Create missing files and configure the repo for the process
- **Update** — Update existing configuration when process requirements or model preferences change

The user may combine these: "Assess this repo and fix what's missing" or "Update the models to use GPT-5.5 for reviews."

## Process

### 1. Read Process Requirements

Read these references to understand what a well-configured repo looks like:
- [references/repo-requirements.md](references/repo-requirements.md) — documentation structure requirements
- [../../references/standard-test-levels.md](../../references/standard-test-levels.md) — test level definitions repos must map to
- [../../references/task-tracking.md](../../references/task-tracking.md) — backlog/task-tracking hooks repos must map to
- [../../references/requirements.md](../../references/requirements.md) — requirements-handling hooks repos may map to
- [references/agent-configuration.md](references/agent-configuration.md) — model/agent setup per repo

### 2. Scan the Repository

Check for presence AND quality of:

**Essential (process won't work well without):**
- [ ] Root AGENTS.md exists and routes to deeper docs
- [ ] AGENTS.md references tech stack
- [ ] AGENTS.md references architecture docs
- [ ] AGENTS.md references test infrastructure docs
- [ ] AGENTS.md references per-directory rules
- [ ] Test architecture/strategy document exists
- [ ] Test commands documented with exact syntax
- [ ] Test commands mapped to standard levels (fast feedback, task gate, final gate)
- [ ] Test command scope labeled (touched-files, package-wide, repo-wide)
- [ ] Test command timing documented (when to run each)
- [ ] Plans directory exists
- [ ] Build/lint/typecheck commands documented and runnable

**Important (significantly improves results):**
- [ ] Architecture document with system boundaries
- [ ] Coding rules document
- [ ] Per-directory AGENTS.md files for specialized areas
- [ ] Environment setup documented (services, env vars, prerequisites)
- [ ] Task-tracking/backlog mechanism documents all required hooks: store, create item, stable ID, reference format, source backlink format, list inbox/untriaged, list `Up next`, mark ready/done/canceled/deferred/blocked, and critical/blocking policy. Treat this as essential for standard/epic autonomous execution; without it, execution runs in degraded ask-before-capture mode.
- [ ] Agent-discovered follow-up capture policy documented, including whether agents must ask before creating items or have pre-authorization for non-critical follow-ups
- [ ] Requirements posture documented: maintains requirements, does not maintain separate requirements, unclear, or likely needed but missing
- [ ] Requirements mechanism documents all required hooks if repo maintains requirements: store, actors/personas, use cases, workflows/scenarios, functional requirements, non-functional requirements, operational requirements, stable IDs, reference format, test citation format, traceability rules, apply approved changes, retire/change requirements, validation/query commands if any, and approval policy
- [ ] Tool-backed task/requirement hooks document exact commands, auth/access expectations, read-only vs mutating behavior, approval requirements, and fallback when a command/tool is unavailable
- [ ] Design rules (if UI exists)

**Recommended (further improves quality):**
- [ ] Tech stack LLM instruction files (.llm/ directory)
- [ ] Architecture Decision Records (ADRs)
- [ ] Issues and learnings log
- [ ] Plans directory README with repo-specific guidance

**Agent configuration:**
- [ ] `.pi/settings.json` exists with `subagents.agentOverrides` (if repo needs non-default models)
- [ ] Agent model overrides match the repo's tech stack (e.g., UI-strong model for frontend repos)
- [ ] No full agent `.md` copies in `.pi/agents/` (use `.pi/settings.json` → `subagents.agentOverrides` for automatic prompt updates)

### 3. Assess Quality (not just existence)

For documents that exist, evaluate:
- **Test docs:** Do they map to standard levels? Include scope + timing? Or just "run npm test"?
- **AGENTS.md:** Does it route to deeper docs, or dump everything in one file?
- **Architecture:** Does it describe boundaries and relationships, or just list technologies?
- **Per-directory AGENTS.md:** Do they include patterns AND anti-patterns, or just brief descriptions?
- **Agent config:** Do model choices match the repo's domain? (Frontend repo should have UI-strong workers) Is there a distinct agent per implementer tier (`worker-high`, `worker-low`) so tier routing needs no per-dispatch model? Do override model IDs exist in the provider catalog of the deployments that run this repo? Do critical agents state a manual fallback order for the providers this repo uses (`fallbackModels` is unsupported)? Settings-level `subagents.agentOverrides` replace agent-file values; see the agent configuration guide.
- **Operational hooks:** For each task-tracking and requirements hook, is the implementation agent-executable? A good hook names the exact file/command, ID rule, required fields, safe read operations, mutating operations, approval boundary, and fallback. A vague concept is not enough.
- **Task tracking:** Does the repo define every required task-tracking hook from `../../references/task-tracking.md`: backlog store, create item, stable ID, reference format, source backlink format, list inbox/untriaged, list `Up next`, mark ready/done/canceled/deferred/blocked, and critical/blocking policy? Is `Up next` human-controlled or explicitly delegated? Are agents allowed to create items directly or must they ask?
- **Requirements posture:** Is the repo's requirements posture explicit? Report one of: maintains requirements, explicitly no separate requirements system, unclear, or likely needed but missing.
- **Requirements:** If the repo maintains requirements, does it define every required requirements hook from `../../references/requirements.md`: requirements store, actor/persona definitions, use case definitions, workflow/scenario definitions, functional requirements, non-functional requirements, operational requirements, stable IDs, reference format, test citation format, traceability rules, apply approved requirement changes, retire/change requirements, validation/query commands if any, and approval policy? Are mutating operations and human approval boundaries clear?
- **PR review process:** Does the repo have a `pr-review-hooks.md` manifest at its root answering the required hooks from `../../references/pr-review.md`: review inputs, local review rules, verification commands, evidence captures, PR tracking, and merge gate? Are the verification rows runnable commands and is the merge gate explicit?
- **Agent role → model assignment:** Does the repo define which model fills each agent role from `../../references/agent-roles.md` (orchestrator, researcher, planner/contract author, reviewer, fresh reviewer, implementer high/low, optional visual implementer)? Check: every role has a named model or an explicit "default" record; the implementer tier mapping is stated as `worker-high` / `worker-low` overrides; a manual fallback order is stated for implementers/planner/reviewer (not `fallbackModels`, which is unsupported); the mapping lives in the repo's agent-configuration surface and is auditable. A repo that cannot state its role→model mapping fails assessment.
- **Tool availability:** For GitHub Projects, CLIs, or other external systems, are required tools installed/authenticated and are fallback procedures documented when access is unavailable?

### 4. Report or Act

**If assessing:** Produce the assessment report (see Output Format below).

**If setting up:** Create the missing files:
- `.pi/settings.json` with `subagents.agentOverrides` appropriate to the repo's stack
- A role→model assignment covering every role in `../../references/agent-roles.md` (roles, tiers, manual fallback order) in the repo's agent-configuration surface
- `plans/` directory (or `docs/engineering/plans/`)
- Test architecture skeleton populated from discovered commands (package.json, Makefile, etc.)
- Task-tracking skeleton if missing. Ensure the skeleton maps every required task-tracking hook with an operations table, item template, source backlink rule, and lifecycle transitions. Offer the user:
  1. Simple Markdown backlog (`docs/backlog.md`)
  2. GitHub Issues + Project workflow
  3. Existing tracker/tool integration
- Requirements skeleton if requested and requirements are relevant. Ensure the skeleton maps every required requirements hook with an operations table, ID/citation policy, test citation format, approval boundary, and sample actor/use case/workflow/requirement entries. Offer the user:
  1. Simple Markdown requirements (`docs/requirements.md`)
  2. Existing requirements CLI/tool integration
  3. No requirements system yet; document that requirements are not maintained separately
- `pr-review-hooks.md` manifest at the repo root, drafted from the PR-review hooks in `../../references/pr-review.md`. Point at the rule files that already exist rather than restating them; every verification row must be a runnable command; name the evidence method and the merge gate explicitly.
- AGENTS.md skeleton with proper references
- Per-directory AGENTS.md files where patterns are needed

**If updating:** Modify existing configuration:
- Update `.pi/settings.json` → `subagents.agentOverrides`
- Update test architecture doc when commands change
- Update task-tracking docs when backlog policy changes
- Update requirements docs when requirements policy changes
- Update `pr-review-hooks.md` when rule files, verification commands, evidence methods, or merge policy change
- Update the role→model assignment when `../../references/agent-roles.md` roles change or model availability changes
- Update AGENTS.md references when structure changes
- Update per-directory AGENTS.md when patterns evolve

## Task Tracking Setup Guide

When setting up backlog tracking for a repo, prefer the simplest mechanism that matches the repo's collaboration needs.

### Option A: Simple Markdown backlog

Use for small repos or personal projects.

Create `docs/backlog.md` as an operational contract, not just a list of headings:

```markdown
# Backlog

## System

This repo uses this single Markdown file as the canonical backlog. The section containing an item is its status.

## Required Operations

| Operation | How to do it |
|-----------|--------------|
| Create backlog item | Add `### TASK-XXXX — Title` under `## Inbox` |
| Assign stable ID | Find the highest existing `TASK-XXXX`, then use the next number |
| Reference item | Use `TASK-XXXX` in worklogs, reviews, TODOs, commits, and summaries |
| Capture source backlink | Add `- Source: <plan/worklog/review>, <task/finding>` to the item and write the ID back to the source artifact |
| List Inbox | Read items under `## Inbox` |
| List Up next | Read items under `## Up next` |
| Mark Ready | Move the whole item under `## Ready` |
| Mark Up next | Human moves the whole item under `## Up next` unless explicitly delegated |
| Mark Done | Move the whole item under `## Done` and add a completion note |
| Mark Canceled | Move the whole item under `## Canceled` and add a reason |
| Defer | Move the whole item under `## Icebox` |
| Mark Blocked | Move the whole item under `## Blocked` and add blocker details |
| Critical item | Stop and ask before continuing current-plan execution |

## Item Template

### TASK-0001 — <title>

- Kind: <bug|feature|chore|docs|hardening|research|debt|idea>
- Origin: <human-request|plan-follow-up|review-finding|agent-observation|external-issue>
- Priority: <P0|P1|P2|P3>
- Track: <fast-path|standard-implementation|analysis-spike|docs-process>
- Source: <artifact and task/finding>
- Created: <YYYY-MM-DD>
- Created by: <human|agent>
- Acceptance:
  - [ ] <criterion>
- Notes:
  - <optional>

## Up next

## Ready

## Inbox

## Clarification needed

## In progress

## In review

## Blocked

## Icebox

## Done

## Canceled
```

Document in AGENTS.md:

```markdown
## Task Tracking
Backlog system: Markdown
Details: `docs/backlog.md`

Rules:
- New agent-discovered non-critical follow-ups go under `## Inbox` after approval unless a plan/worklog pre-authorizes capture.
- Stable IDs use `TASK-0001`, `TASK-0002`, etc.
- Source backlink is required in both the backlog item and the source artifact.
- `Up next` is human-controlled unless explicitly delegated.
- Critical/current-plan-affecting discoveries require stopping and asking.
```

### Option B: GitHub Issues + Project

Use for team repos or repos already centered on GitHub.

Document:
- Issues are canonical backlog items
- Project `Status` values map to Inbox, Ready, Up next, In progress, In review, Blocked, Done, Canceled, Icebox
- Project `Track` maps to Fast path, Standard implementation, Analysis / spike, Docs / process
- Project `Priority` maps to P0–P3
- Labels capture kind/origin/area/risk metadata
- Agent-created issues include a Source section linking the plan/worklog/task/commit
- Required `gh` authentication, project access, exact project field commands, and fallback when project field mutation is unavailable

### Option C: Existing tool

If the repo already uses Beads, Linear, Jira, or another tracker, document the equivalent operations for the required hooks in `../../references/task-tracking.md`.

## Requirements Setup Guide

When setting up requirements handling for a repo, do not force a requirements system if the repo does not maintain requirements. If requirements are relevant, prefer the simplest mechanism that gives agents stable IDs and clear approval boundaries.

### Option A: Simple Markdown requirements

Use for small repos or early-stage projects.

Create `docs/requirements.md` with current accepted requirements and an operations table:

```markdown
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
| Cite requirement | Use IDs such as `FR-001`, `NFR-002`, `OPR-003` in briefs, plans, worklogs, reviews, commits, and summaries |
| Cite requirement in tests | Add a test comment or metadata line: `Requirement: FR-001` |
| Apply approved requirement change | Edit this file as part of the approved plan task |
| Retire or replace requirement | Remove/replace the current requirement; record rationale in the approving plan/worklog |
| Validate/query requirements | Use `rg "(ACT|UC|WF|FR|NFR|OPR)-[0-9]{3}" docs/requirements.md` |
| Approval policy | Ask before editing canonical requirements unless explicitly delegated |

## Actors / Personas

| ID | Persona | Goal |
|----|---------|------|
| ACT-001 | Maintainer | Safely change and validate the system |

## Use Cases

| ID | Actor | Use Case |
|----|-------|----------|
| UC-001 | ACT-001 | Validate changes before applying them |

## Workflows / Scenarios

### WF-001 — Run validation before applying changes

- Use case: UC-001
- Actor: ACT-001

Steps:
1. Edit the system.
2. Run documented validation.
3. Review failures.
4. Apply only after validation passes.

## Functional Requirements

### FR-001 — Validation command exists

- Type: functional
- Use case: UC-001
- Related workflows: WF-001
- Source: human-request

The repo must provide a documented validation command for common local changes.

## Non-Functional Requirements

### NFR-001 — Fast validation remains quick

- Type: non-functional
- Scope: UC-001
- Source: human-request

Fast validation should complete within the repo-defined target time.

## Operational Requirements

### OPR-001 — Mutating commands are explicit

- Type: operational
- Scope: global
- Source: human-request

Commands that mutate user/system state must be documented separately from read-only validation commands.
```

Document in AGENTS.md:

```markdown
## Requirements
Requirements system: Markdown
Details: `docs/requirements.md`

Rules:
- Durable current requirements live in `docs/requirements.md`.
- IDs use `ACT-001`, `UC-001`, `WF-001`, `FR-001`, `NFR-001`, and `OPR-001`.
- Tests cite requirements they verify using `Requirement: FR-001`.
- Draft requirement changes live in brief/approach/plan artifacts until approved.
- Canonical requirement edits require human approval unless explicitly delegated.
```

### Option B: Existing requirements tool or CLI

If the repo already has a requirements system, document exact commands for the required hooks in `../../references/requirements.md`: list/show actors, use cases, workflows, requirements, apply approved changes, validate/query, and export reports. Mark every command as read-only or mutating, document auth/access prerequisites, and state which mutating commands require human approval.

### Option C: No separate requirements system

If the repo does not maintain requirements separately, document that explicitly. Do not invent a requirements file just because the process supports one.

## Agent Configuration Guide

When setting up or updating agent models for a repo, use `.pi/settings.json` → `subagents.agentOverrides` — NOT full agent file copies in `.pi/agents/`. This ensures repos automatically get updates when global agent definitions change (new skills, updated prompts, tool changes).

```json
{
  "subagents": {
    "agentOverrides": {
      "worker": { "model": "<model-id>", "thinking": "high" },
      "code-reviewer": { "model": "<model-id>", "thinking": "high" }
    }
  }
}
```

Only override agents where the model should differ from the global default.

Precedence: Settings-level `subagents.agentOverrides` fields replace the agent file's frontmatter values. Project overrides beat user overrides. Do not set `fallbackModels`: it is unsupported, and an agent or override that declares it fails to load.

Ask the user about:
- Preferred providers (cost constraints, API access)
- Whether they have provider-specific API keys
- Any model preferences based on past experience with this codebase
- Whether critical agents (worker, code-reviewer) should state a manual fallback order, and to which alternate providers

## Test Level Mapping

When setting up test docs, discover existing commands from:
- `package.json` scripts
- `Makefile` / `Justfile` targets
- `Cargo.toml` / `pyproject.toml` configuration
- CI/CD pipeline definitions (`.github/workflows/`, etc.)
- Existing README or CONTRIBUTING docs

Map discovered commands to the standard levels:

| Standard level | Look for |
|---------------|----------|
| Fast feedback | `test --watch`, `vitest`, test commands with file filter args |
| Type check | `tsc --noEmit`, `typecheck`, `mypy`, `cargo check` |
| Lint | `eslint`, `prettier`, `ruff`, `clippy` |
| Unit tests | `test`, `vitest run`, `pytest`, `cargo test` |
| Integration tests | `test:integration`, `test:e2e` (if tests services) |
| E2E tests | `playwright`, `cypress`, `test:e2e` |
| Build | `build`, `compile`, `cargo build` |
| Full verification | `verify`, `check-all`, or a composite of the above |

## Output Format (Assessment Mode)

```markdown
# Repository Assessment: [repo name]

**Date:** YYYY-MM-DD
**Overall Readiness:** Ready | Partially Ready | Not Ready

## Score: X/Y checks passing

### Essential (X/Y)
- ✅ Root AGENTS.md exists
- ❌ Test commands not mapped to standard levels
- ⚠️ Architecture doc exists but lacks module boundaries

### Important (X/Y)
...

### Recommended (X/Y)
...

### Agent Configuration
- .pi/settings.json with subagents.agentOverrides: Yes/No
- Model choices appropriate for stack: Yes/No/N/A
- Recommendations: <specific model suggestions>

## Top Priority Recommendations

1. **[Most impactful fix]** — Why it matters, what to create/change
2. **[Second priority]** — Why, what
3. **[Third priority]** — Why, what

## Test Level Mapping Status

| Standard Level | Repo Command | Documented? | Scope labeled? | Timing labeled? |
|---------------|-------------|-------------|----------------|-----------------|
| Fast feedback | `pnpm vitest` | ⚠️ exists but no scope | ❌ | ❌ |
| Type check | `pnpm typecheck` | ✅ | ✅ | ✅ |
| ... | | | | |

## Operational Readiness Findings

Use severities consistently:
- **Blocker** — plan execution is unsafe or impossible without this fix
- **Major** — agents will frequently stop, guess, or lose traceability
- **Minor** — quality/documentation improvement
- **N/A** — explicitly not applicable to this repo

| Severity | Area | Finding | Impact | Recommended fix |
|----------|------|---------|--------|-----------------|
| Major | Task tracking | <gap> | <why it hurts planning/execution> | <specific file/change> |

## Task Tracking Status

| Hook | Repo implementation | Documented? | Agent-ready? |
|------|---------------------|-------------|--------------|
| Backlog store | `docs/backlog.md` / GitHub Issues / other | ✅/❌ | ✅/❌ |
| Create item | <command/procedure> | ✅/❌ | ✅/❌ |
| Stable ID | `TASK-0001` / issue number / other | ✅/❌ | ✅/❌ |
| Reference format | <format used in worklogs/reviews/TODOs> | ✅/❌ | ✅/❌ |
| Source backlink format | <required source section/line> | ✅/❌ | ✅/❌ |
| List Inbox | <command/procedure> | ✅/❌ | ✅/❌ |
| List Up next | <command/procedure> | ✅/❌ | ✅/❌ |
| Mark Ready | <command/procedure> | ✅/❌ | ✅/❌ |
| Mark Done | <command/procedure> | ✅/❌ | ✅/❌ |
| Mark Canceled | <command/procedure> | ✅/❌ | ✅/❌ |
| Defer/Icebox | <command/procedure> | ✅/❌ | ✅/❌ |
| Mark Blocked | <command/procedure> | ✅/❌ | ✅/❌ |
| Agent capture policy | <ask/pre-authorized rule> | ✅/❌ | ✅/❌ |
| Critical/blocking policy | <stop/fix/re-plan/backlog policy> | ✅/❌ | ✅/❌ |
| Tool/auth requirements | <gh/tracker CLI/access/fallback> | ✅/❌/N/A | ✅/❌/N/A |

## Requirements Handling Status

**Requirements posture:** maintains requirements | explicitly no separate requirements system | unclear | likely needed but missing

| Hook | Repo implementation | Documented? | Mutating? | Approval clear? | Agent-ready? |
|------|---------------------|-------------|-----------|-----------------|--------------|
| Requirements store | <file/system> | ✅/❌/N/A | No | N/A | ✅/❌/N/A |
| Actor/persona definitions | <file/command> | ✅/❌/N/A | No | N/A | ✅/❌/N/A |
| Use case definitions | <file/command> | ✅/❌/N/A | No | N/A | ✅/❌/N/A |
| Workflow/scenario definitions | <file/command> | ✅/❌/N/A | No | N/A | ✅/❌/N/A |
| Functional requirements | <file/command> | ✅/❌/N/A | No | N/A | ✅/❌/N/A |
| Non-functional requirements | <file/command> | ✅/❌/N/A | No | N/A | ✅/❌/N/A |
| Operational requirements | <file/command> | ✅/❌/N/A | No | N/A | ✅/❌/N/A |
| Assign/discover IDs | <rule/command> | ✅/❌/N/A | Maybe | ✅/❌/N/A | ✅/❌/N/A |
| Cite requirements | <brief/plan/review format> | ✅/❌/N/A | No | N/A | ✅/❌/N/A |
| Test citation format | <comment/annotation/metadata format> | ✅/❌/N/A | No | N/A | ✅/❌/N/A |
| Apply approved changes | <edit procedure/command> | ✅/❌/N/A | Yes | ✅/❌/N/A | ✅/❌/N/A |
| Retire/replace requirements | <procedure/command> | ✅/❌/N/A | Yes | ✅/❌/N/A | ✅/❌/N/A |
| Validate/query | <read-only command/report> | ✅/❌/N/A | No | N/A | ✅/❌/N/A |
| Tool/auth requirements | <CLI/access/fallback> | ✅/❌/N/A | Maybe | ✅/❌/N/A | ✅/❌/N/A |

## Quick Wins (can fix in < 5 minutes)
- <immediate improvement>
```

## What You MUST NOT Do

- Do not invent test commands (discover them from package.json, Makefile, etc.)
- Do not assume model preferences without asking
- Do not create full agent `.md` files in `.pi/agents/` — use `.pi/settings.json` → `subagents.agentOverrides`
- Do not produce a generic report — reference specific files and paths in THIS repo
- Do not guess at architecture or patterns — report what's there and what's missing
- Do not mark backlog or requirements handling as agent-ready just because headings exist; required operations must be concrete enough to execute
