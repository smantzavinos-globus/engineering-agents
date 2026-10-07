# Project Agent Guide

Use this file as the repo entry point. It routes to the canonical docs for this repository's local working rules.

## Rules
- Keep this file short and routing-oriented; put detailed policy in the linked docs.
- Prefer small, focused changes that preserve the existing command surface.
- Follow the execution contract in `docs/execution-patterns.md`: contract-first tests authored
  by a different agent than the implementer, parent-run host verification at wave boundaries,
  and a fresh final review.

## Tech Stack
- Markdown docs define the process and contributor contract.
- Nix flake modules install and configure Pi and OpenCode.
- Bash and Node-based test helpers verify repo structure and packaging contracts.

## Architecture
- `docs/architecture.md` — repository purpose, primary surfaces, core flows, and boundaries.

## Skill Rendering
- `docs/skill-rendering.md` — how canonical `skills/` are rendered per harness into `dist/` via `harnesses/*.json` and `tools/render-skills.mjs`.
- Canonical skills are harness-neutral; never hand-edit `dist/`. After changing a skill, run `node tools/render-skills.mjs --write` and commit `dist/`.

## Coding Rules
- `docs/coding-rules.md` — repo-wide editing, shell, documentation, and verification rules, including the per-task verification classes.

## Development Environment
- `docs/development-environment.md` — required tooling, setup/apply flow, and verification entry points.

## Test Infrastructure
- `docs/testing-strategy.md` — canonical testing levels, task/final gates, scope, timing, and prerequisites.
- `tests/README.md` — suite inventory, individual spec entry points, and file-layout details.

## Task Tracking
- `docs/backlog.md` — canonical backlog and task-tracking contract for durable non-critical follow-up work.
- Non-critical follow-up work belongs in the backlog with a stable `TASK-XXXX` ID and a source backlink.
- Critical discoveries that affect correctness, safety, scope, or verification must be raised immediately instead of being deferred into backlog-only tracking.

## Requirements
- `docs/requirements.md` — canonical requirements system for the repo's current accepted requirements.
- Stable IDs use `ACT-001`, `UC-001`, `WF-001`, `FR-001`, `NFR-001`, and `OPR-001`.
- Tests cite requirements they verify using `Requirement: FR-001`.
- Draft requirement changes stay in plan artifacts until approved.
- Canonical requirement edits require human approval unless explicitly delegated.

## Planning Artifacts
- `plans/README.md` — repo-specific planning guidance, canonical verification sources, and plan/worklog constraints for this repo.
- `docs/references/design-approach-authoring.md` — change-oriented canonical approach packages and generated HTML review views.
- `docs/approaches/parallel.md` — Pi execution approach: DAG scheduler, planned fence groups, planning rules.
- `docs/execution-patterns.md` — Parallel runtime constraints (sandbox, parent-driven loop).
- Use plan/worklog artifacts to reference the canonical testing, backlog, and requirements docs instead of restating their policies inconsistently.

## Operational Memory
- `docs/issues_learnings.md` — lightweight log for recurring issues and confirmed learnings that should stay visible across plans.
- `docs/adr/README.md` — ADR index and format guidance for durable repo-level decisions.

## Per-Directory Rules
- `agents/AGENTS.md` — read before editing agent files, frontmatter, role boundaries, or model override guidance.
- `skills/AGENTS.md` — read before creating or changing skill structure, naming, references, or templates.
- `tests/AGENTS.md` — read before adding specs, fixtures, or changing verification wiring.
- `nix/AGENTS.md` — read before editing Nix modules, compile helpers, guardrails, or generated-package behavior.
- `templates/AGENTS.md` — read before editing starter content or placeholders.

## LLM Instruction Files
Read these only when editing the matching surface or reviewing generated changes against it.
- `.llm/process_docs_rules.txt` — read before editing process documentation, routing docs, or cross-link-heavy Markdown.
- `.llm/nix_rules.txt` — read before editing Nix modules, guardrails, or generated-package helpers.
