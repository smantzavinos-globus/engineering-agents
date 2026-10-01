---
name: pull-request
description: Prepare or review a PR per the PR review process — body, evidence, rules, verdict.
---

# Pull Request

Executor for the PR review process, in one of two roles. The canonical
contract — body sections, common rules R1–R6, evidence tiers, loop rules,
verdict definitions — lives in
[docs/references/pr-review.md](docs/references/pr-review.md) (packaged inside
this skill tree when installed via the engineering-agents harnesses; in the
engineering-agents repo itself, use the repo path). This file is only the
role procedure; never restate the contract from memory.

## Role selection

- **Author** — you implemented a change and are about to open its PR.
- **Reviewer** — a PR exists and you are judging it. You must be a different
  agent and a fresh session than the author; if you are the author's session,
  stop and say so.

## Common inputs (both roles)

1. Read the canonical contract (above).
2. Read the target repo's `pr-review-hooks.md` manifest at its root. No
   manifest: STOP, report the repo as not onboarded, offer assess-repo.
3. **Verify the code-review gate**: read `<plan-dir>/code_review.md`; its
   latest pass must be COMPLETE (zero open Blocker/Critical/Major). If not,
   stop and route to `review-code` — do not author or review a PR past an
   open code review.
4. Load every file the manifest's `review-inputs` section names.
5. Completion check: you can state the repo's verification commands, evidence
   method, and merge gate without re-reading.

## Author procedure

1. **Build the body** per the contract's body-contract section, exactly.
   Missing sections say `None.`; diagrams per the contract's trigger rules.
2. **Generate evidence** per the manifest's `evidence-captures` rows —
   before/after captures for UI diffs; durable URLs only. Tier 2 video only
   on explicit request.
3. **Run verification**: every relevant `verification-commands` row; record
   exact command + outcome. Never write a line for a command you did not run.
4. **Self-review**: apply R1–R6 and every manifest `review-rules` row to your
   own diff with their detection methods; fill the review-rules table with
   real evidence links. Fix BLOCKERs; declare ESCALATEs in Follow-ups with
   the question for the human.
5. **Open the PR**, set tracking state per `pr-tracking`. The body on GitHub
   must match the prepared body and describe the final SHA you push.
6. **Link and hand off.** When the work came from a backlog item, the body
   carries its closing reference (`Closes #N` on GitHub) and the item moves to
   `In review` (per the `backlog` skill). Then start babysitting: add
   `pr:babysat` and post the claim comment
   `babysit: session=babysit-pr-<item or PR>-<UTC ISO> heartbeat=<UTC ISO>`.
   The `babysit-pr` prefix makes it sweep-owned, so the PR sweep runs fix
   rounds on FIX verdicts and bot reviews without a watcher (see the delivery
   pipeline's dispatch contract). The PR is not handed off until it is labeled
   for review, linked, and claimed. From hand-off until merge, the author
   owns CI at the PR head: keep every required check green, fix it when it
   goes red — CI maintenance rounds do not consume the fix-loop bound.

## Reviewer procedure

1. **Scope**: check out the branch locally. First pass: full diff vs base.
   Re-review: delta since the latest `reviewed@<sha>` comment plus verifying
   prior findings are resolved. Do not re-review approved code.
2. **Apply rules**: R1–R6 in order, then the manifest rows, recording
   evidence anchors (file:line).
3. **Verify**: run every relevant manifest command; a claimed green without a
   run is a finding. Check the PR's checks at the exact head under review
   (`gh pr checks <n> -R <repo>`); a red required check (the manifest's
   `merge-gate` row names them) is a BLOCKED-class fact: post BLOCKED, never
   READY, naming the failing check.
4. **Check body and evidence** against the contract; silently wrong rows in
   the author's table are a MAJOR finding.
5. **Post one comment**: confirmed rules table, severity-ordered findings
   with anchors and suggested fixes, verification outcomes, verdict
   (`READY` / `FIX` / `BLOCKED` per the contract), and on READY the stamp
   `reviewed@<sha>` of the exact HEAD you reviewed. No stamp on FIX/BLOCKED.
   End the comment with the machine-readable marker
   `<!-- pr-review verdict=<VERDICT> head=<full sha> -->` — VERDICT is one of
   `READY | FIX | BLOCKED`; head is the full reviewed commit sha — so
   automation can read the state without an LLM.
6. **Notify** per the contract's loop rules: the human hears about READY,
   BLOCKED, and ESCALATE — never intermediate FIX states. Bound: two fix
   loops, then escalate with findings history.

## Pitfalls

- Reviewer: do not stamp a SHA you did not fully verify — the stamp is the
  trust anchor for incremental re-review.
- Reviewer: ESCALATE findings (always including backwards-compat code) are
  stated as questions for the human, never resolved by agents.
- Author: do not open a draft PR as a substitute for self-review; do not let
  plan-internal artifacts leak into the body.
- Either role: the manifest is pointers plus facts — if you find yourself
  copying rule text from the contract into a PR comment beyond the filled
  table, you are restating instead of referencing.

## Verification

Author: PR exists with contract-ordered body, pre-filled table, resolving
evidence links, commands actually run. Reviewer: PR comment with confirmed
table, anchored findings, verification outcomes, verdict, and stamp on READY.
A human reading only the PR (author case) or the comment (reviewer case) can
decide without reading the diff.
