# Investigation: process-vs-mechanics consistency audit (Hermes skill tree)

**Date:** 2026-10-01 · **Branch:** `feature/hermes-harness-and-skill-sync` (PR #25)
**Method:** two parallel audits of the rendered `dist/skills/hermes/` tree —
(1) an information-availability audit modeling each stage's *loaded set*
(entry skill + one stage skill + gate-guaranteed artifacts; nothing else),
and (2) an end-to-end walkthrough simulating a fresh agent with no memory,
told only "follow the dev process", verifying every reference, command, and
gate empirically (including executing `pi` without `-p` to confirm the hang).

**Question:** how the process is intended to work vs how it will actually
work, given what agents are told — and what they have loaded — at each step.

## Result: 25 findings — 6 Critical, 11 Major, 8 Minor

The core pipeline is sound: no slash-command leakage into the Hermes tree,
no named-subagent assumptions, artifact templates are packaged via
skill-resources.json, review severity ladders are inlined, gh-only commands
work as written, and the packaged pr-review.md is hash-identical to
canonical. The failures cluster in two layers: **delegation mechanics**
(session IDs, flags, skill paths) and **knowledge packaging** (skills
reference in-repo docs that are not in the rendered tree).

### Critical

| ID | Finding | Fix |
| --- | --- | --- |
| C1 | Every Hermes delegation points subprocesses at `~/.pi/agent/skills/` (the Pi store) — wrong path for Hermes agents, and the pi store lacks 6 of the pointed-at skills (create-plan, review-plan, create-worklog, execute-task, review-code, execution-orchestrator). The subprocess silently loses its stage skill. | `skillPathPrefix` → the Hermes store; add a locate-or-ask fallback line. |
| C2 | Reviewer independence not operationalized: identical `<session-id>` placeholder for author AND reviewer in every pi example. Filled literally, the reviewer runs inside the author's session — the exact violation the pipeline forbids. | Distinct conventioned placeholders (`<plan-slug>-<stage>` / `<plan-slug>-<stage>-review-<N>`) + an explicit never-reuse line in every review delegation. |
| C3 | pi invocations lack `-p`: a verbatim copy launches the interactive TUI and blocks forever (verified: exit 124 on timeout). The orchestrator hangs its own session on the first delegation. | `-p` on every pi example. |
| C4 | `docs/hermes/execution-modes.md` — the normative deep-dive for session-ID conventions, reuse exceptions, and mode mechanics — is never packaged; unreachable on target repos. | Package via skill-resources.json into the software-development tree. |
| C5 | The entry skill mandates "2–3 parallel reviewers on distinct model families; mechanics live in the review skills" — neither review skill contains any multi-model mechanics. Following them alone yields a single-model pass believed compliant. | **Ruled:** multi-model becomes a plan-level choice (see §Decisions). Review skills gain a conditional "Parallel reviews" section with the mechanics for when the plan selects it. |
| C6 | Worklog gate mismatch: the normative "record execution mode in the worklog header" and the entry gate "plan review CLEAN + human approval" have no carrier — the worklog template has no Mode field, and create-worklog never reads plan_review.md nor records approval. | Mode + Plan-approval fields in the worklog template header; gate-check step 0 in create-worklog. |

### Major

| ID | Finding | Fix |
| --- | --- | --- |
| M1 | **Systemic:** skills reference in-repo docs (testing-strategy.md, agent-roles.md, execution-modes.md, process.md, pr-automation.md) that are not in skill-resources.json — unreachable on target repos. Only pr-review.md and delivery-pipeline.md (backlog/triage/work-item) are packaged today. | Package the needed sections; inline the one-liners. |
| M2 | Verification-class definitions (contract/characterization/check/none) live solely in testing-strategy.md; create-plan assigns classes and execute-task runs them without the semantics — including the missing frozen-test guard (`git diff --exit-code <contract-commit> -- <paths>`) at execution. | Package the 4-row table into create-plan + execute-task; add the freeze-guard to execute-task's verification step. |
| M3 | Execution-tier semantics (high/low, roles 6/7) live in agent-roles.md, unreachable from the orchestrator. | Package or inline the two role definitions. |
| M4 | Entry skill routes Brief to `discover-and-design*` and PR babysitting to `babysit-pr` — both pi-only, absent from the Hermes tree. Hard routing targets that don't exist. | Annotate routing as pi-tree-only; Hermes routes to `discovery`; babysit step guarded per harness. |
| M5 | `state.json`: no schema or creation owner inside the skill tree; create-plan writes phase `"planned"`, off the documented enum. Detached mode resumes from these values — invented values are load-bearing. | Discovery creates it (`{"phase":"briefed","status":"active"}`); inline the enum; reconcile the value. |
| M6 | The "contract freezes" human gate is never defined anywhere in the loaded set. | One-line definition in the entry skill. |
| M7 | Plan-review pass thresholds disagree: entry skill says "zero Critical"; review-plan requires zero Blocker/Critical/Major. | Reconcile to the stricter ladder in the entry table. |
| M8 | execution-orchestrator selects the mode "per the software-development skill's mode table" — a skill the orchestrator session has not loaded. | Inline the 3-row mode table into its inputs. |
| M9 | create-plan never reads approach_review.md, so it cannot verify its own stage gate (APPROVED approach). | Add to inputs with a stop condition. |
| M10 | pull-request never checks the code-review gate (code_review.md) — an agent can jump from execute to PR authoring. | Add gate check to common inputs. |
| M11 | Session-ID conventions exist only for task execution (`<plan-slug>-task-<N>`); the other seven stage types are unconventioned, and stage sessions are never recorded for resumability. | Generalize `<plan-slug>-<stage>[-review-<N>]`; mirror one line in the entry skill. |

### Minor

| ID | Finding | Fix |
| --- | --- | --- |
| N1 | review-code retains team-mode branches (team_plan.md, rescue/remediation teams) — retired by ADR 0006; dead path referencing unrendered skills. | **Ruled:** delete outright. |
| N2 | research lists a `fetch_content` tool that exists under no such name. | Harness-neutral phrasing. |
| N3 | review-code hardcodes `main..HEAD`. | Default-branch detection. |
| N4 | execute-task MUST-NOT says "Do not skip the break-it check" while the canon says break-it is reviewer-initiated only. | "Do not skip a reviewer-demanded break-it demonstration." |
| N5 | Repo-relative doc paths leak into universal skills (`docs/testing-strategy.md`), dangling in target repos. | Neutral phrasing. |
| N6 | skill-rendering.md documents delegationStyle `hermes-delegate` while the profile (correctly) uses `hermes-pi`. | Update the doc. |
| N7 | discovery's plan-dir suggestion ("repo conventions") uninlined. | Inline `plans/YYYY_MM_DD_<slug>/`. |
| N8 | pull-request cites docs/hermes/pr-automation.md for the verdict marker grammar (unpackaged; format is given inline anyway). | Inline the grammar, drop the pointer. |

## Decisions recorded (owner, 2026-10-01)

1. **Multi-model review is a plan-level choice**, not a blanket rule — same
   treatment as per-task review: the plan template gains a Parallel-reviews
   choice row (default: single reviewer loop; multi-model selected for
   high-risk plans); review skills carry the mechanics conditionally for
   when the plan selects it. **Rule for all process choices:** every choice
   must have a clear point in the process where it happens, a clear mechanism
   (ask the human vs agent-determines), and a location where the decision is
   documented.
2. **Team mode is deleted outright** from review-code (ADR 0006 retired it;
   dead paths rot).

## Disposition

Fixes land on `feature/hermes-harness-and-skill-sync` (PR #25) as a single
fix commit + re-render + render-spec run. This doc is the finding record;
each fix cites its finding ID in the commit message.
