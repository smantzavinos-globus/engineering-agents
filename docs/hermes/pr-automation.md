# PR Automation for Agent Owners

How a Hermes agent that owns one or more repos detects PRs awaiting review,
dispatches the review, keeps label state truthful, and routes notifications.
The review itself — what to check and how to judge it — is the
[pull-request skill's Reviewer role](../../skills/pull-request/SKILL.md)
executing the [PR review process](../references/pr-review.md). This document
is only the logistics around it.

---

## Label state machine

Labels plus `reviewed@<sha>` comments are the system of record. They survive
agent restarts, and every sweep tick reconstructs state from them
statelessly — no agent-side memory is required.

| Label | Meaning | Set by |
|-------|---------|--------|
| `pr:ready-review` | Awaiting first review | Author, when opening the PR |
| `pr:in-review` | A reviewer is actively working it | Reviewer, on start |
| `pr:re-review` | New commits or comments since the last `reviewed@` stamp | Reviewer on FIX verdict, or automation on push |
| `pr:ready-merge` | Reviewer posted READY + stamp; human decision pending | Reviewer |
| `pr:escalated` | BLOCKED verdict or an ESCALATE question is pending | Reviewer |

One **ownership label** sits alongside the state labels. It never replaces them:

| Label | Meaning | Set by |
|-------|---------|--------|
| `pr:babysat` | An author-side babysit session owns the fix loop (see [Babysit coexistence](#babysit-coexistence)) | The babysit session, on start; removed by it on exit, or by the sweep when the claim goes stale |

Transitions:

```mermaid
flowchart LR
  O[PR opened<br/>author labels ready-review] --> R{Sweep or mention<br/>dispatches reviewer}
  R --> IR[pr:in-review]
  IR -->|READY + stamp| RM[pr:ready-merge]
  IR -->|FIX| RR[pr:re-review]
  IR -->|BLOCKED / ESCALATE| ES[pr:escalated]
  RR -->|new commits| IR
  RR -->|sweep re-dispatch| IR
  RM -->|push detected| RR
  ES -->|push / answer| IR
  RM -->|human merges| D[done]
```

Label drift (a PR in a wrong or missing state) is corrected by the sweep,
never by alerting the human — except drift on `pr:ready-merge` (see failure
policy).

---

## Triggers

Four trigger surfaces, in priority order:

1. **Cron sweep (backbone).** One scheduled job per owning agent covering
   all owned repos. Interval: every 1–2 minutes. With the monitor guard
   (below), idle ticks cost zero LLM tokens and stay far inside GitHub API
   rate limits.
2. **Comment mentions.** A human comment containing the agent's handle
   (`@<agent> review` / `@<agent> fix`) triggers immediately. The handle is
   per-repo configuration, recorded in the repo's `pr-tracking` manifest
   row. Mentions always win over sweep state — a mention forces a run even
   if labels look stale.
3. **Push demotion.** A new commit on a PR labeled `pr:ready-merge`,
   `pr:escalated`, or past a `reviewed@` stamp moves it to `pr:re-review`
   (labels updated mechanically; no LLM needed). This closes the
   silent-stale-approval hole: a stamped READY whose branch moved is not
   mergeable advice.
4. **Babysit mention.** `@<agent> babysit` on a PR starts an author-side
   babysit session for it (the `babysit-pr` skill), the same as asking in
   chat. The sweep dispatches the session; it does not babysit inline.

Webhook-triggered instant dispatch is the eventual upgrade and is
deliberately deferred: the sweep architecture below is intentionally
webhook-shaped so the monitor script can be reused as the webhook payload
handler later.

---

## Babysit coexistence

The sweep and babysitting are two different jobs, and both are needed:

| | Sweep | Babysit |
|---|---|---|
| Started by | Labels, mentions, pushes (always on) | A human asks: chat or `@<agent> babysit` |
| Lifetime | Persistent cron | Until READY, PR closed, human stop, escalation, or session end |
| Role | Reviewer logistics: dispatch independent reviews, keep labels truthful | Author: fix findings, reply, push, request re-review |
| Never does | Fix code | Issue a verdict or stamp on its own work |

Rules that let them run on the same PR without fighting:

1. **Claim.** A babysit session adds `pr:babysat` and posts one claim comment,
   `babysit: session=<id> heartbeat=<iso-time>`. It edits that same comment's
   heartbeat on every round it processes (it does not post a new one). On exit
   it removes the label and edits the comment to `babysit: released`.
2. **What the sweep still does on a babysat PR:** dispatches independent
   Reviewer runs (push demotion to `pr:re-review` works as usual), corrects
   label drift, and reports stuck states.
3. **What the sweep stops doing on a babysat PR:** dispatching any fix or
   author-side work, and notifying the human about FIX verdicts. The babysitter
   owns those. READY, BLOCKED, and ESCALATE still notify the human.
4. **Handoff.** Babysitter pushes a fix, push demotion sets `pr:re-review`, the
   sweep dispatches a fresh Reviewer, and the Reviewer's verdict comment wakes
   the babysitter. The babysitter therefore watches for new verdict/`reviewed@`
   comments and human comments, not just bot reviews.
5. **Shared bound.** The two-fix-loop limit from the
   [PR review process](../references/pr-review.md) is counted from the PR's
   FIX verdict history, not per session. A babysitter that reaches it
   escalates. Being asked to babysit does not raise the bound.
6. **Stale claim.** If the heartbeat is older than `PR_BABYSIT_STALE_MIN`
   (default 60 minutes), the monitor reports `claim=stale`. The sweep then
   removes `pr:babysat`, treats the PR as a stuck state, and notifies the human
   once. The PR then falls back to normal sweep handling.

---

## Monitor guard: no LLM on idle ticks

The sweep cron uses a Hermes `monitor_script`. Each tick the script runs
first; its output is hashed as exact bytes. **Unchanged output = silent
`no_change` tick: no LLM, no delivery, zero tokens. Changed output = the
diff is injected into a normal agent run.**

The script queries GitHub (read-only) and prints a sorted, deterministic
summary of actionable PR state per repo:

```
repo: <owner>/<repo>
  pr:<number> label=<label> head=<sha> stamp=<sha-or-none> comments-new=<n> mentioned=<yes|no> claim=<none|active|stale> babysit-request=<yes|no>
```

Rules for the script:

- **Byte-stable output**: fixed line format, sorted by repo then PR number,
  no timestamps, no counts of things that jitter (e.g. do not include
  "seconds since last run").
- **Actionable means actionable**: include a PR when (a) its label is
  `pr:ready-review` or `pr:re-review`, or (b) its head SHA differs from the
  last stamped SHA and its label is not `pr:in-review`, or (c) a new comment
  mentions the agent. Do NOT include `pr:in-review` PRs the agent itself is
  already working (the dispatch record below covers that) or
  `pr:ready-merge` PRs whose stamp matches HEAD and have no new comments —
  those would re-fire the LLM every tick until the human merges.
- **Babysat PRs**: a `pr:babysat` PR with an active claim is listed only for
  reviewer-side reasons (actionable label, a moved head); new comments alone
  do not make it actionable, because the babysitter handles them. A stale
  claim is always actionable. The `claim=` field changes once when the claim
  goes stale and then stays stable.
- **Detect its own actions as calm, not change**: after the agent reviews a
  PR, the resulting label + stamp change produces one changed hash (the
  triggering tick) and then stability. If the output would flap, the script
  is wrong — fix the script, do not widen the agent's job.

Reference implementation lives at `scripts/pr-sweep-monitor.mjs` (Node,
GitHub REST via `gh` or token, repos passed as an env var). Keep it
deterministic; it is infrastructure, not judgment.

---

## Dispatch: the tick never reviews inline

Hermes cron agent runs are hard-interrupted at 3 minutes. A real review —
checkout, rule pass, verification commands — does not fit. Therefore:

- The sweep tick's only job: parse the injected change summary, then
  **dispatch one background review task per actionable PR** (delegation or
  spawned process), each running the pull-request skill's Reviewer role
  with the PR number, repo, and the repo's manifest path as inputs.
- **One dispatch record per tick**, written before spawning
  (e.g. `~/.../pr-automation/dispatches.jsonl`: timestamp, repo, PR, head
  SHA). The record is what makes re-dispatches idempotent — a PR already
  dispatched at a given head SHA is skipped even if the monitor output
  changes again.
- **Reviews may take arbitrarily long** — they run outside the cron tick.
  The next sweep sees their label/stamp effects, not their runtime.

---

## Failure policy

- **Never half-post.** A reviewer that dies mid-run (provider timeout,
  iteration cap) must not leave a partial review comment or a label it did
  not earn. Post-verify after any dispatch failure: if the agent's working
  note says it posted, confirm the comment exists before trusting the
  label; on mismatch, remove the label and let the sweep re-dispatch.
- **Retry on next tick.** A failed dispatch is simply retried by the next
  sweep (the dispatch record prevents double-dispatch at the same head SHA;
  a new SHA always re-fires).
- **Escalate stuck states.** A PR in `pr:in-review` across more than one
  sweep with no progress, or repeated dispatch failure at the same SHA
  (3+ times), is reported to the human as an automation failure — not
  silently retried forever.
- **Notify the human only on**: stale babysit claims, READY digests (per the loop rules in the
  PR review process), BLOCKED/ESCALATE questions, label drift on
  `pr:ready-merge`, and stuck states. FIX loops stay silent (bounded at
  two, per the process).

---

## Boundaries

- **Agents never merge.** `pr:ready-merge` is a human decision surface. The
  agent's READY digest is the full case for merging; the human merges (or
  asks the agent to, explicitly, case by case).
- **The sweep is an accelererator, not a reviewer of record.** Verdicts come
  only from a properly dispatched independent reviewer run. Automation
  never stamps `reviewed@<sha>` itself.
- **Base-branch hygiene.** Never `--delete-branch` a merge while other open
  PRs use that branch as base (GitHub auto-closes them, unreopenably).
  Sweep merges — if the human delegates any — must re-target dependents
  first.
- **Canonical policy wins.** If logistics here ever conflict with
  [pr-review.md](../references/pr-review.md), pr-review.md wins; fix this
  doc.

---

## Sweep cron template

Copy per owning agent; fill the three uppercase fields. The prompt inlines
only logistics — the process contract is read from the repo at run time.

```
Schedule: every 1m (or 2m)
Monitor script: scripts/pr-sweep-monitor.mjs   (packaged via skill-resources
                into the agent's tree, or referenced from a local checkout)
Script env:    PR_SWEEP_REPOS="owner/repo-a owner/repo-b"
               GH_TOKEN via the agent's existing auth
Prompt: |
  You are the PR-logistics sweep for repos: $PR_SWEEP_REPOS.
  The MONITOR CHANGE DETECTED block lists actionable PRs.
  For each PR listed:
    1. Read docs/hermes/pr-automation.md and docs/references/pr-review.md
       in the repo (local checkout under the agent's repos/ directory;
       fetch first).
    2. Check the dispatch record; skip PRs already dispatched at this head SHA.
    3. If claim=stale: remove pr:babysat, report the stuck babysit, continue.
       If babysit-request=yes and claim=none: dispatch ONE background babysit
       session (babysit-pr skill, repo + PR as inputs), append the record, and
       continue.
    4. If the label calls for review: set pr:in-review, then dispatch ONE
       background reviewer task running the pull-request skill's Reviewer
       role (repo, PR number, manifest path as inputs). This applies to
       babysat PRs too.
    5. Append the dispatch record. Never dispatch author-side fix work for a
       PR with claim=active.
  Do not review inline. Do not post comments yourself. Do not merge.
  Report only failures and stuck states.
```

Setup is step 2 of the [self-setup checklist](README.md#agent-self-setup-checklist).
