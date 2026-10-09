# Backlog

## System

This file is the canonical backlog for this repo. Record durable follow-up work here instead of leaving it only in chat, ephemeral notes, or plan discussions.

Use this backlog for non-critical work that is accepted but does not belong in the current task. Critical discoveries that affect correctness, safety, scope, or verification are not backlog-only items: raise them immediately so the current plan can be adjusted.

## Required Operations

| Operation | Required contract |
|-----------|-------------------|
| Create item | Add a new item from the template below in the appropriate lifecycle section. |
| Assign stable ID | Give each new item the next unused `TASK-XXXX` identifier and never reuse an old ID. |
| Reference format | Refer to backlog items as `TASK-XXXX` in plans, worklogs, reviews, commits, and chat. |
| Source backlink | Every item must include a `Source:` line that points back to the originating plan, worklog, review, or discussion artifact. |
| List Inbox | Review `## Inbox` for newly accepted work that is not yet prioritized. |
| List Up next | Review `## Up next` for the highest-priority items that are ready to pull soon. |
| Mark Ready | Move an item into `## Ready` when it is clarified enough to execute without more triage. |
| Mark Done | Move an item into `## Done` when the work is finished and the durable record should remain visible. |
| Mark Canceled | Move an item into `## Canceled` when it will not be pursued; keep the ID and reason. |
| Defer / Icebox | Move an item into `## Icebox` when it is intentionally deferred with no near-term execution slot. |
| Mark Blocked | Move an item into `## Blocked` when progress is waiting on another decision, task, or dependency. |
| Critical item policy | If the discovery could change the current task or plan correctness, safety, scope, or verification, stop and raise it immediately instead of quietly adding it to the backlog. |

## Item Template

Use this template for every new item:

```markdown
### TASK-XXXX — Short title
- Status: Inbox
- Summary: One or two sentences describing the work.
- Source: <path, review section, issue, or conversation reference>
- Notes: Optional constraints, links, or acceptance cues.
```

The `TASK-XXXX` placeholder describes the required stable ID format. Replace `XXXX` with the next unused four-digit number.

## Related Docs
- `plans/README.md` — when plans and worklogs should capture accepted follow-up work here.
- `docs/requirements.md` — cite requirement IDs there when backlog work implies durable requirement changes.
- `docs/issues_learnings.md` — use the learnings log for repeat observations that are not yet accepted backlog work.

## Up next

_No items yet._

## Ready

### TASK-0002 — Fork-currency audit: retire out-of-date forks where upstream has the fix
- Status: In progress (pi-subagents upstream; pi-gitnexus retired by user; pi-hooks fork retained)
- Summary: Audit the historical personal Pi package forks against upstream. Keep pi-hooks on the fork while its unique Ralph fixes are needed; remove unused pi-gitnexus entirely instead of migrating it to upstream.
- Source: Package-update review session; fork/upstream compares via GitHub API (2026-07-13).
- Notes:
  - **pi-subagents** → upstream `nicobailon/pi-subagents` (fork 2 ahead / 232 behind). Custom commits: `feat: apply agentOverrides to user agents (not just builtins)`, `fix: disableBuiltins takes priority over agentOverrides for builtins`. NOTE: the staleness warning comparing our pin to the fork's own `main` is a false positive — evaluate against `nicobailon` upstream instead.
    - **AUDIT VERDICT (2026-07-13): RETIRE.** Both customizations are now native in upstream `src/agents/agents.ts`: `applyCustomAgentOverrides` applies `agentOverrides` to user/project (non-builtin) agents, and `applyBuiltinOverrides` handles `projectBulkDisabled`/`userBulkDisabled` (disableBuiltins) priority. Action: pin a specific current upstream commit; verify our exposed extension/skill/prompt paths still match after the 232-commit restructure; run a real per-repo agentOverrides + disableBuiltins smoke test; update proof-set.json.
    - **DONE (2026-07-13):** Retired — pinned upstream `github:nicobailon/pi-subagents#c940fe20e86d9ba429eebcac809ec79d478ef206` (v0.34.0). Upstream `pi` manifest is identical to the old fork (extensions/skills/prompts paths unchanged), so no module `expose` or `resourceExpectations` changes were needed. Verified the `skills/assess-repo/references/agent-configuration.md` config surface (`subagents.agentOverrides` + `disableBuiltins`, project-beats-user priority, all override fields) is still accurate against upstream's override schema. Updated `proof-set.json` and aligned `tests/spec-fixtures/resource-snapshot.v2.ok.json` (this fix also corrected a latent branch-ref mismatch and the earlier pi-ext bump). NOTE: a real `home-manager switch` smoke test of agentOverrides/disableBuiltins still recommended (the repo's `test-fast` runtime snapshot step is environmentally broken here — bin-only pi package — so runtime verification was not possible locally).
  - **pi-hooks** → upstream `prateekmedia/pi-hooks` (5 ahead / 8 behind). Custom commits: ralph-loop escape-sequence RPC-stdout fix, `execute()` parameter-order fix, auto-detect project-local agents when `agentScope` omitted, `processClosed` vs `proc.killed` SIGKILL fallback, `vscode-languageserver-protocol` import path for v3.18+.
    - **AUDIT VERDICT (2026-07-13): REBASE (keep fork).** Upstreamed/redundant: execute param-order (upstream `fix(ralph-loop): correct execute signature parameter order`) and vscode-lsp import (upstream uses ESM-correct `/node.js`). Still UNIQUE and unmerged: (1) `fix(ralph-loop): handle escape sequence contamination in RPC stdout`, (3) `feat(ralph-loop): auto-detect project-local agents` (`resolveAgentScope`/`"auto"` scope default), (4) `processClosed` SIGKILL fallback. Upstream also carries a change we LACK: `@mariozechner/*` → `@earendil-works/*` namespace migration + lsp-core refactor. Action: rebase our fork onto current upstream keeping commits 1/3/4, dropping 2/5, then re-pin; consider upstreaming 1/3/4 via PR to eventually drop the fork.
  - **pi-gitnexus** → upstream `tintinweb/pi-gitnexus` (1 ahead / 18 behind; disabled by default). Custom commit: `fix: stop MCP child process on session_shutdown to prevent hang`.
    - **AUDIT VERDICT (2026-07-13): RETIRE FORK.** Upstream `src/index.ts` has the same shutdown handler. **Decision (2026-09-23): remove GitNexus altogether** because it is unused. Remove its managed source, optional module switches, and CLI wiring; do not replace it with upstream.
  - Any fork we drop must keep the pinned-commit + idempotent-install contract (see `nix/AGENTS.md`) and update `tests/fixtures/proof-set.json`.

## Inbox

### TASK-0003 — Fix resource-snapshot.mjs Pi module path resolution through the startup wrapper
- Status: Inbox
- Summary: `tests/scripts/resource-snapshot.mjs` (`buildPiModulePath()`) locates the real `pi-coding-agent` package by resolving `which pi` and walking two directories up to find `lib/node_modules/{@earendil-works,@mariozechner}/pi-coding-agent/dist/index.js`. On hosts where the repo's own `pi` startup wrapper is on `PATH` (see `pi-startup-wrapper-spec.sh` / `pi-launch-wrapper.sh`), `which pi` resolves to the wrapper's Nix store package (which only contains `bin/pi`, no `lib/node_modules`), not the real `pi-coding-agent` package — so the entrypoint lookup fails with "Unable to locate Pi module entrypoint" and `./tests/run-tests.sh all` / the Pi proof-set step cannot run.
- Source: Chat discussion during team-mode wave execution follow-up (2026-07-15); observed running `./tests/run-tests.sh all` after deploying `plans/2026_07_14_team_mode_wave_execution/`. Same root cause independently noted in TASK-0002's pi-subagents entry ("the repo's `test-fast` runtime snapshot step is environmentally broken here — bin-only pi package").
- Notes: Root cause confirmed locally: `which pi` → `/home/spiros/.nix-profile/bin/pi` → realpath → `/nix/store/<hash>-pi/bin/pi`, a wrapper script that `export`s `PI_WRAPPER_REAL_PI_BIN=/nix/store/<hash>-pi-0.80.6/bin/pi` and execs `pi-launch-wrapper.sh`. The real package (with the expected `lib/node_modules/@earendil-works/pi-coding-agent/` layout) lives under that `PI_WRAPPER_REAL_PI_BIN` path, one level further down. Fix should make `buildPiModulePath()` detect and unwrap the startup wrapper (e.g. read `PI_WRAPPER_REAL_PI_BIN` out of the wrapper script, or exec `pi` with an env-dump escape hatch) before falling back to the current two-levels-up heuristic, so proof-set verification works both with and without the wrapper enabled. Not caused by and unrelated to the team-mode wave execution work; that feature's own verification (fast suite + flake eval, including explicit "skill installed" checks for the new skills) is fully green.

### TASK-0006 — Plumb required-vs-advisory checks into the sweep engine
- Status: Inbox
- Summary: The sweep engine demotes `pr:ready-merge` on ANY completed failing check (engine-level red); the required-vs-advisory split lives in each repo's `merge-gate` manifest row and binds only the Reviewer's verdict (contracted in `docs/references/pr-review.md`, Merge). Once a real advisory check lands on a swept repo, add an engine input (e.g. `PR_SWEEP_REQUIRED_CHECKS`, repo→check-names map, default all = current behavior) consumed by `ci_round_due`.
- Source: Independent review of PR #24 (finding F1, 2026-09-30); contract note added in the same PR.
- Notes: Deliberately deferred — no swept repo currently runs an advisory check, so the env would be dead config. Revisit when the first advisory check appears.

### TASK-0007 — Fix two stale specs failing on clean main (repo-readiness-docs, skill-content)
- Status: Inbox
- Summary: Two specs fail on a clean `origin/main` checkout (verified on a pristine stash, 2026-10-09): (1) `tests/specs/repo-readiness-docs-spec.sh` expects `docs/hermes/README.md` to contain "do **not** install rendered copies" — the README no longer carries that phrase; (2) `tests/specs/skill-content-spec.sh` expects `review-code/SKILL.md` to contain "Team mode" + "per-task verification evidence" and expects `execution-orchestrator`/`execute-task`/`create-worklog`/`create-plan`/`review-plan`/`review-code` to carry `harnesses: [opencode]` — none of the six skills restrict harnesses anymore. Both specs are stale relative to main's own content (post-ADR-0004/0006 world), so `tests/run-tests.sh fast`/`all` exit 1 on main regardless of branch content and mask real regressions in those two specs.
- Source: feat/prototype-first-entry PR (author self-review, verification rows); baseline proof: stashed clean tree, same 8 failures (1 + 7).
- Notes: Fix direction: either update the specs to the post-code-mode contract or restore the asserted content in the docs/skills — needs a decision on which side is the intended truth. Not caused by this PR; disclosed here per the PR body's Testing overview.

## Clarification needed

_No items yet._

## In progress

_No items yet._

## In review

_No items yet._

## Blocked

### TASK-0004 — Un-pin llmAgents input once upstream Copilot Enterprise compaction fix lands
- Status: Blocked
- Summary: `flake.nix` pins the `llmAgents` input to `github:numtide/llm-agents.nix/70ff0e7f69a5fe712d675ac29b484e91e98daff0` (pi **0.80.7**), rolling back from latest (pi 0.80.10) because pi >=0.80.8 broke `/compact` and auto-compaction for GitHub Copilot Enterprise accounts (`Error: Compaction failed: Turn prefix summarization failed: 421 Misdirected Request`). Root cause: the 0.80.8 "Unified model runtime and provider authentication" (`ModelRuntime`) refactor stopped threading the resolved Enterprise base URL into the compaction/summarization call path, so it falls back to the individual-account Copilot endpoint and gets rejected.
- Source: Chat discussion diagnosing Atlas-worktree2 compaction failures (2026-07-20); upstream bug https://github.com/earendil-works/pi/issues/6768.
- Notes: A community fix exists but is unmerged as of 2026-07-20: https://github.com/earendil-works/pi/compare/main...Marvae:fix/copilot-summarization-base-url. To un-pin: watch https://github.com/numtide/llm-agents.nix/commits/main/packages/pi/hashes.json for a bump to a pi version where #6768 is closed, then in `flake.nix` restore `url = "github:numtide/llm-agents.nix";` and run `nix flake lock --update-input llmAgents`. Re-verify `pi --version` and test `/compact` on a Copilot Enterprise session before considering this done.

## Icebox

_No items yet._

## Done

### TASK-0001 — Upgrade @aliou/pi-guardrails 0.9.5 → 0.17.0
- Status: Done
- Summary: Bump the held pi-guardrails managed package to 0.17.0, enable ask-mode outside-workspace path access, allow normal pushes while auto-denying force pushes, and document repository-local Guardrails configuration in `configure-pi`.
- Source: Package-update review session (commits 822f83d..80a8d19) and follow-up configuration discussion; changelog https://github.com/aliou/pi-guardrails/releases
- Notes: v0.12.0 split Guardrails into four manifest extensions (policy / path-access / permission-gate / Herdr) and renamed public events; v0.14.0 migrated `pathAccess.allowedPaths` to `{ kind, path }[]`. The Nix compiler auto-discovers the latest manifest entries. The repo config uses `pathAccess.mode: ask`; ordinary `git push` is not configured as a gate, while `--force`, `-f`, `--force-with-lease`, and `+refspec` force-push forms are auto-denied. `./tests/run-tests.sh fast`, `./tests/run-tests.sh all`, and `./scripts/pi-dev.sh --verify` pass. `skills/configure-pi/SKILL.md` documents `.pi/extensions/guardrails.json`.

### TASK-0005 — Onboard engineering-agents itself with a root pr-review-hooks.md manifest
- Status: Done
- Summary: The repo defines the PR review process (`docs/references/pr-review.md`) and its Required Repo Hooks table, but has no root `pr-review-hooks.md` manifest of its own — a reviewer of this repo's PRs proceeds on task-supplied facts instead of the fixed-shape manifest (found during the independent review of PR #18, 2026-09-28). Fix: run `assess-repo` against this repo and draft the manifest (review-inputs / review-rules / verification-commands / evidence-captures / pr-tracking / merge-gate), routing it from root `AGENTS.md`.
- Source: Reviewer MINOR finding on PR #18 (review comment 5880478914); parent session onboarding run 2026-09-28.
- Resolution (2026-09-29): manifest drafted at repo root (fixed-shape sections); verification rows copied from the repo's own canonical commands (`docs/testing-strategy.md`); devShell gained `python3` (fixes the 4 red fast-suite specs on `main`); root `AGENTS.md` routing line added (owner-approved in-session).

## Canceled

_No items yet._
