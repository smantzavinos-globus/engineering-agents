# pr-review-hooks — engineering-agents

Integration manifest for the PR review process. The common contract (verdicts,
stamps, loop bounds, body contract, evidence tiers) is canonical in this repo:
`docs/references/pr-review.md`. This file answers only repo-specific questions
and is the first file a reviewer loads. If this file and the canonical contract
disagree, the canonical contract wins.

## review-inputs

| file                               | why a reviewer needs it                                                                                    |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| AGENTS.md                          | repo entry rules and routing to every per-directory guide                                                  |
| docs/references/pr-review.md       | the canonical review contract this manifest integrates                                                     |
| docs/coding-rules.md               | repo-wide editing, shell, documentation, and verification rules                                            |
| docs/testing-strategy.md           | canonical test tiers, gates, and prerequisites — verification rows below cite it                           |
| docs/execution-patterns.md         | the execution contract a diff claims to follow (contract-first tests, host verification)                   |
| docs/requirements.md               | requirement ID system; tests cite via `Requirement: <ID>`                                                  |
| docs/backlog.md                    | TASK-XXXX tracking; PRs closing backlog items must move the item, not duplicate it                         |
| .llm/process_docs_rules.txt        | read before reviewing changes to process/routing/cross-linked Markdown                                     |
| .llm/nix_rules.txt                 | read before reviewing Nix module or generated-package changes                                              |
| skills/AGENTS.md, tests/AGENTS.md, nix/AGENTS.md, agents/AGENTS.md, templates/AGENTS.md | load the matching guide when the diff touches that directory |

## review-rules

| rule                                                                                                   | severity | detection                                                                        |
| ------------------------------------------------------------------------------------------------------ | -------- | -------------------------------------------------------------------------------- |
| No file deletions or renames without the owner's written approval                                      | ESCALATE | `git diff --diff-filter=DR --name-only origin/main...HEAD` non-empty → stop and ask |
| `dist/` is generated: never hand-edit; changes come from `node tools/render-skills.mjs --write` committed together with the canonical `skills/` change | BLOCKER  | diff touches `dist/` → run the render-check verification row; any residual diff fails |
| Canonical requirement edits (`docs/requirements.md`) carry human approval                              | ESCALATE | diff touches `docs/requirements.md` without an approved-change reference          |
| No credentials or token material in the diff; scripts read secrets from environment or instance files  | BLOCKER  | scan diff for token/secret literals and `.env` additions                          |
| Completed plan/worklog history is not silently rewritten                                               | MAJOR    | diff rewrites executed sections of `plans/**` instead of appending                |
| Shell scripts keep `set -euo pipefail` and stable command surfaces                                     | MINOR    | read diff of `scripts/**`, `tests/**`                                             |
| Tests that verify a requirement cite it (`Requirement: <ID>`)                                          | MINOR    | read diff of `tests/**`                                                           |

## verification-commands

Run from the repo root. Rows must pass as written on the branch under review.

| slot       | command                                                 | pass condition                                                                    |
| ---------- | ------------------------------------------------------- | --------------------------------------------------------------------------------- |
| unit       | `nix develop --command ./tests/run-tests.sh fast`       | exit 0, every spec OK (task completion gate per docs/testing-strategy.md)          |
| render     | `nix develop --command node tools/render-skills.mjs --check` | exit 0 (required whenever `skills/` or `harnesses/` changed)                  |
| e2e-local  | `nix develop --command ./scripts/pi-dev.sh --verify`    | exit 0 (required when Pi modules, managed packages, skills, or extensions changed) |
| build      | `nix develop --command ./tests/run-tests.sh all`        | exit 0 (final plan gate before merge per docs/testing-strategy.md)                 |

## evidence-captures

| change type          | method                                                | command                              | artifact home       |
| -------------------- | ----------------------------------------------------- | ------------------------------------ | ------------------- |
| any                  | text evidence in PR body (always required — tier 0)   | manual                               | PR body             |
| UI-visible change    | N/A — this repo ships no UI surface                   | N/A                                  | N/A                 |
| narrated video       | N/A — no UI surface (tier 2 remains opt-in by contract) | N/A                                | N/A                 |

## pr-tracking

| field           | value                                                                                                                |
| --------------- | -------------------------------------------------------------------------------------------------------------------- |
| review state    | labels + `reviewed@<sha>` stamps per `docs/references/pr-review.md`                                                   |
| agent handle    | `@smantzavinos` (agent operates under the owner account until a dedicated handle exists)                              |
| sweep           | Dean's Hermes cron, every 2 minutes, repos: `smantzavinos/engineering-agents` + `laminar-logic-systems/clarity_lens`   |
| dispatch record | agent-side `dispatches.jsonl` (idempotency per head SHA)                                                             |
| never-merge     | agents never merge; `pr:ready-merge` is the human decision surface                                                    |

## merge-gate

| gate             | requirement                                                                        |
| ---------------- | ---------------------------------------------------------------------------------- |
| verdict          | READY from an independent reviewer with a `reviewed@<head-sha>` stamp at the current head |
| verification     | the `unit` row green at the reviewed head; `build` row green before merge            |
| evidence         | durable GitHub links in the PR body per the canonical evidence tiers                 |
| merge authority  | human only                                                                          |
