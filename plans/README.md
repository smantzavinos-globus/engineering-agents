# Plans Directory Guide

This directory stores repo-specific planning artifacts. Use it together with the process docs, but treat this file as the local contract for how plans should be written and verified in this repository.

## Canonical Verification Sources
- `docs/testing-strategy.md` — canonical mapping from standard test levels to this repo's exact commands and gate roles.
- `tests/README.md` — suite inventory, file layout, and spec entry points.
- `tests/specs/` — targeted fast-feedback commands used during TDD loops when a task touches a specific contract surface.
- `docs/development-environment.md` — setup/apply prerequisites for commands that depend on local tooling.

Use the commands documented there instead of inventing new top-level verification commands. This supports `FR-002` and the gate policy in `OPR-001`.

## Repo-Specific Plan Constraints
- Keep plan directories under `plans/YYYY_MM_DD_<slug>/` as described in `docs/plan-directory-structure.md`.
- Use the repo's documented command surface: `bash tests/specs/<spec>.sh` for fast feedback and `./tests/run-tests.sh fast|all|full` for broader gates.
- Do not invent a second canonical source for verification, backlog, or requirements policy; route to `docs/testing-strategy.md`, `docs/backlog.md`, and `docs/requirements.md`.
- When a plan introduces or changes repo-operating docs, update the touched readiness spec, the canonical doc, and the root `AGENTS.md` route together.
- Keep non-critical follow-up work out of the active task list; capture accepted follow-ups in `docs/backlog.md` with `TASK-XXXX` IDs.
- Cite requirement IDs from `docs/requirements.md` when tasks implement or verify durable repo behavior, and keep test citations in the documented `Requirement: <ID>` format.
- Keep execution logs operational: sequential `worklog.md` uses one current `NEXT STEP`.

## Artifact Expectations for This Repo
- `brief.md` records goals, non-goals, constraints, and any requirement context that matters for the work.
- `approach.md` leads the canonical change map; follow [Change-oriented approach authoring](../docs/references/design-approach-authoring.md) for the optional reference, linked assets, generated HTML views, and package-wide review/approval inventory.
- `plan.md` is the sequential planning artifact and must include dependency-ordered tasks, a verification class and execution tier per task, explicit checklists, exact verification commands, and requirement refs where relevant.
- ~~`team_plan.md`, `team_plan_review.md`, `team-worklog.md`~~ — RETIRED with team mode (ADR 0006). Do not create them in new plans.
- `worklog.md` is the execution entry point. It should copy the task gate and final gate from the canonical docs, record backlog IDs created during execution, and note approved requirement changes.
- `plan_review.md` and `code_review.md` remain the durable records for review findings; do not hide review-only decisions in chat.
- `state.json` should stay minimal and resumable.

## Related Docs
- `docs/plan-directory-structure.md` — generic artifact layout and naming rules.
- `docs/testing-strategy.md` — command-level verification policy for this repo.
- `docs/backlog.md` — follow-up capture mechanism used by plans and worklogs.
- `docs/requirements.md` — canonical requirement IDs and approval boundary.
- `docs/issues_learnings.md` — operational memory for recurring issues and confirmed learnings.
- `docs/adr/README.md` — accepted architecture decision record index and format.
