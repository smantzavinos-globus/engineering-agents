# Software Development Process for Hermes Agents

How a Hermes agent runs this repo's software development process on the repos
it owns. This is the mechanics-and-setup companion to the canonical pipeline.
Policy lives in the canonical docs and is never restated here:

- [Development Process](../process.md) — the pipeline: brief → research →
  approach → approach review → plan → plan review → worklog → execute →
  code review → [PR review](references/pr-review.md).
- [Testing Strategy](../testing-strategy.md) — verification classes
  (contract / characterization / check / none) and gate roles.
- [Coding Rules](../coding-rules.md) — verification rules every plan must
  follow.
- [Plans Directory Guide](../../plans/README.md) — artifact contract.

If this document and a canonical doc disagree, the canonical doc wins.

## Hermes agent setup checklist

1. **Verify the repo is onboarded.** Root `AGENTS.md` routes the process
   docs; `pr-review-hooks.md` exists at the root (see the PR review process).
   Missing pieces: report to the human, offer an assess-repo run.
2. **Locate the canonical docs at run time.** Read `docs/process.md` and
   `docs/testing-strategy.md` from the repo checkout — fetch first. Never
   work from memory of a previous version.
3. **Confirm the stop boundaries** with the human once: plan review and code
   review end in human approval; the agent never merges PRs.
4. **Record the setup** (repo, cron schedule if any, trigger handle) so the
   human can audit it.

## Skill-sync checklist

Hermes agents maintain their own native skills. Each agent-side skill must
cover the corresponding canonical content; diff your skills against this list
and update yours when the canon changes.

| Agent-side skill | Must cover | Canonical source |
|------------------|------------|------------------|
| discovery / brief | Intent, non-goals, constraints, likely-overlooked needs | `process.md` §Brief |
| research / findings | Evidence-based findings files with file:line anchors | `process.md` §Research |
| approach / design | Conceptual model, alternatives, boundary clarity | `process.md` §Approach |
| plan creation | Dependency-ordered tasks; verification class + execution tier per task; repo's canonical commands, never invented | `testing-strategy.md` + `coding-rules.md` |
| plan review | Iterate to zero Blocker/Critical/Major | `process.md` §Plan Review |
| execution log | One current NEXT STEP; per-task atomic commits | `process.md` §Worklog/Execute |
| task execution | Red→Green→Verify for contract/characterization; proving command for check/none | `testing-strategy.md` Verification classes |
| code review | Coverage matrix, anti-patterns, severity calibration; reviewer ≠ implementer | `process.md` §Code Review |
| PR preparation & review | Body contract, rules table, verdict + stamp; author links the item and starts babysitting | `references/pr-review.md` + the `pull-request` skill |
| backlog operations | Ask-before-capture, transitions by actor, claim/heartbeat, gate comment and reply grammar | `references/task-tracking.md`, `references/delivery-pipeline.md` + the `backlog` skill |
| triage | Definition of Ready, field filling, questions with recommended answers; never Up next/Icebox/Canceled | the `triage-backlog` skill |
| dispatched work | One stage per session, resume from committed artifacts, gates instead of chat questions | the `work-item` skill; `discover-and-design` unattended mode; `execution-orchestrator` detached mode |

## Refinements (conventions from practice, binding for our agents)

These tighten the canonical pipeline for Hermes agents running it autonomously.
They are additions, never overrides.

1. **Findings are a separate dispatched phase.** Research is delegated to a
   dedicated subagent (or run explicitly as its own step) that produces
   findings files with verified file:line anchors before any planning starts.
   A plan built on unverified recollection is a defect.
2. **Two-reviewer loop to zero Critical.** Plan and code reviews run as a
   loop across two distinct reviewer agents (different from each other and
   from the implementer). The loop ends when *both* report zero Critical
   findings — one clean pass is not a clean plan.
3. **STOP-class taxonomy.** The agent interrupts the human only for
   STOP-class items: contradictions in the spec/plan, contract-level open
   questions it cannot resolve from the repo, destructive or irreversible
   actions, money/legal/external commitments. Everything else is decided,
   logged in the worklog, and surfaced in the digest.

## Which vehicle runs the stages

Hermes can drive the pipeline three ways — Pi subprocesses (standard),
Hermes subagents, or a single Hermes session — with mode confirmed at
execution start and selection guidance per plan complexity. That is a
logistics concern, not a pipeline change; it is defined in
[Execution modes](execution-modes.md).

---

## Worked example

For a reference execution of this process — including a plan written in the
new format (verification classes, execution tiers, no break-it) — see
`plans/2026_09_23_sdp_simplify/` in the engineering-agents repo.

PR detection and automation for owned repos is defined separately in
[PR automation](pr-automation.md).
