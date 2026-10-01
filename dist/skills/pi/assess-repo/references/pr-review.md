# PR Review Process

Canonical process for creating and reviewing pull requests across repos that
follow this workflow. Mirrors task tracking and requirements handling: this doc
defines common concepts, rules, and required hooks; each repo implements the
hooks via a single `pr-review-hooks.md` manifest at its root.

One skill executes the process in two roles:

- `pull-request` — as **Author**: prepares the PR body, evidence, and
  self-review before the PR opens. As **Reviewer**: executes the review
  rules, posts the findings table and verdict, and stamps the reviewed SHA.

The process exists to make PR review automatic: the human reviewer reads one
digest and merges, or gets pulled in only for escalations.

---

## Roles

| Role | Who | Rule |
|------|-----|------|
| Author | Implementing agent | Runs `pull-request` (Author role); fixes findings |
| Reviewer | A different agent than the author | Runs `pull-request` (Reviewer role); never the same agent/session as the author |
| Human | Repo owner | Escalations, backwards-compat calls, merge. Humans are never the first pass |

The reviewer-must-differ rule extends the contract-first principle: tests and
reviews come from a different agent than the implementer.

---

## Required Repo Hooks

Every repo using this process maintains a `pr-review-hooks.md` file at its
root, routed from `AGENTS.md`. One file, fixed sections, pointers plus facts.
The authoritative rule detail (typing rules, UI rules, capture guides) stays in
the files where it already lives; the manifest points to them.

| Hook | Required question answered | Manifest section |
|------|----------------------------|------------------|
| Review inputs | Which files must a reviewer load before reviewing? | `## review-inputs` |
| Local review rules | What repo-specific rules apply beyond the common set? | `## review-rules` |
| Verification commands | Which commands verify the change, per slot? | `## verification-commands` |
| Evidence captures | What visual proof is expected for which change types, and how is it produced? | `## evidence-captures` |
| PR tracking | Where does review state live, and what triggers autonomous follow-up? | `## pr-tracking` |
| Merge gate | What gates a merge and who merges? | `## merge-gate` |

### Manifest shape

Each section is a fixed-shape table so skills can parse it deterministically.

```markdown
## review-inputs
| file | why a reviewer needs it |
|------|-------------------------|

## review-rules
| rule | severity | detection |
|------|----------|-----------|

## verification-commands
| slot | command | pass condition |
|------|---------|----------------|

## evidence-captures
| change type | method | command | artifact home |
|-------------|--------|---------|---------------|

## pr-tracking
| field | value |
|-------|-------|

## merge-gate
| gate | requirement |
|------|-------------|
```

Severity vocabulary for `review-rules`: `BLOCKER` (cannot merge), `MAJOR`
(fix before merge), `MINOR` (fix or backlog), `ESCALATE` (human decision
required, always).

New repos: `assess-repo` drafts the manifest as part of repo setup.

---

## PR body contract

Every PR body contains these sections, in this order. Sections with no content
say `None.` rather than being dropped — absence must be distinguishable from
omission.

```markdown
## Intent and scope
One paragraph: the problem, the chosen approach, what is explicitly NOT in
this PR.

## What changed / What did not change
Behavior level, not file level. "What did not change" lists adjacent things a
nervous reviewer might suspect were touched.

## Diagrams
Mermaid. Required when the diff adds/modifies/removes: a component, an API
surface, a data flow, or a schema. Show the pieces of the system that exist
and mark the new/modified/removed data flows. Skip only for pure-text or
pure-config diffs.

## Evidence
Per the repo's evidence-captures table. UI changes: before/after captures.
See evidence tiers below.

## Testing overview
| test | layer | what it actually proves |
Automation first; manual steps listed separately with exact steps.

## Review rules
The filled table: rule → evidence/link → pass/fail/N-A. Pre-filled by the
author; confirmed by the reviewer.

## Follow-ups
Known limitations and backlog items (with IDs).
```

Rules for the body:

- Pseudocode or plain-language description of tricky logic beats raw diffs.
- Evidence links are durable GitHub URLs (comments, review captures), not
  ephemeral attachments.
- No plan-internal artifacts leak into the body (task IDs internal to a plan,
  scratch notes).

---

## Evidence tiers

| Tier | When | Content |
|------|------|---------|
| 0 — always | Every PR | Body contract, Mermaid diagrams, testing table |
| 1 — UI diff | Any PR touching user-visible UI | Before/after captures per the repo's evidence-captures method |
| 2 — opt-in | Requested by the human, or large feature work | Narrated demo video (captured scenes + TTS narration stitched to MP4), built by a background subagent; linked in the PR |

Tier 2 is never a default. Proof artifacts never substitute for the tests
named in the testing table.

---

## Common review rules

These apply in every repo. The manifest adds repo-specific rules; it never
repeats these.

| # | Rule | Severity | Detection guidance |
|---|------|----------|--------------------|
| R1 | **Schema review first.** Schemas/data models are the single source of truth. No hardcoded task-type or category literal enums where the repo's registry pattern applies; new types must be data, not migrations. Reviewer reads the schema layer before any logic. | BLOCKER | Read schema/migration diff first; grep for literal unions duplicating registry values |
| R2 | **Types follow the repo's typing rules.** No `any`/`unknown`-smuggling, no double casts (`as unknown as X`), no hand-rolled context/db interfaces where the framework provides generics. | BLOCKER | Grep the diff for `any`, `unknown as`, `as any` |
| R3 | **Comments earn their place.** Comments explain why, for future readers, especially where code is intentional but looks unusual. No implementation narration, no references to plan-internal task IDs. | MINOR→MAJOR | Read every added/modified comment in the diff |
| R4 | **Backwards compatibility / legacy code is a human decision.** Any code kept "for compatibility", any deprecated-path retention, any dual-write/shim is flagged for the human reviewer. This is where cruft sneaks in. The author must declare it in the body; the reviewer must verify nothing was added silently. | ESCALATE | Grep diff for `deprecated`, `legacy`, `compat`, `shim`, `fallback`; author declaration cross-check |
| R5 | **Consistency.** Patterns, UI, APIs, and tests match the repo's existing exemplars. | MAJOR | Diff against neighboring code; manifest review-inputs name the exemplars |
| R6 | **Tests catch bugs, not mirror implementation.** Each behavioral change has a test that would fail on a real regression; assertions check behavior, not internal call patterns; no tautological tests. | BLOCKER | Invert each new test mentally: would plausible bugs pass it? |

Severity calibration and finding format reuse the `review-code` conventions
(Blocker/Critical/Major/Minor/Nit). Common-rule severities above are floors,
not ceilings.

---

## Review loop rules

1. **Author self-review before opening.** The Author role runs the common rules
   and the manifest rules against the author's own diff and pre-fills the
   review-rules table. A PR that fails its own table does not open.
2. **Reviewer independence.** The Reviewer role runs in a fresh session/agent that
   is not the author's session.
3. **First pass is full.** The reviewer verifies every common rule and every
   manifest rule, runs the manifest verification commands, and posts:
   - the filled review-rules table with evidence links,
   - findings as a severity-ordered list,
   - a verdict: `READY`, `FIX` (findings below Blocker), or `BLOCKED`,
     closed by the machine-readable marker
     `<!-- pr-review verdict=<VERDICT> head=<full sha> -->` so the verdict
     history (and with it the fix-loop bound below) is countable.
4. **Re-review is incremental.** The reviewer stamps the reviewed SHA in a PR
   comment (`reviewed@<sha>`). Subsequent passes review only the delta since
   the stamp plus verification that prior findings are resolved. Unchanged,
   already-approved code is not re-reviewed.
5. **Review threads gate READY.** The Reviewer posts READY only when every
   review thread on the PR is resolved. An unresolved thread is `FIX` (the
   author resolves it by fixing or by answering with evidence), or an ESCALATE
   finding when it needs a human decision. The Reviewer never resolves threads
   itself. The author side (babysit) resolves the threads it addresses.
6. **Fix loops are bounded.** The author fixes and pushes; after **two** fix
   loops without a `READY` verdict, the PR escalates to the human with the
   findings history summarized. Agents do not loop indefinitely, and the
   human never reviews an intermediate state.
7. **Notifications.** On `READY`, the author notifies the human with a short
   digest: what the PR does, evidence links, the verdict, and the merge-gate
   status. On `BLOCKED` or any ESCALATE finding, the human is notified
   immediately with the specific question. Humans are not notified about
   intermediate `FIX` states.
8. **State stays truthful.** PR/project status moves per the repo's
   pr-tracking manifest. Reviewers and authors update state to reflect
   reality; stale "in review" state is a process bug.

---

## Merge

The merge gate is the repo's `merge-gate` manifest section (required checks,
required verdict, who merges). Default across LLS repos: only the human
merges; agents stage work for merge. Required checks are a hard gate in both
directions: the Reviewer posts BLOCKED, never READY, when a required check is
red at the reviewed head; the author (usually the babysitting session) keeps
them green and fixes reds — CI maintenance rounds do not consume the
fix-loop bound. Division of labor: the manifest row binds the Reviewer's
verdict; the sweep's mechanical demotion treats every completed failing
check as red (its CI red→round transition fires once per head+conclusion
set, tracked in `ci_key`); classic commit statuses (context/state) are not
read.

---

## Orchestration (cron / hooks)

How this process is driven automatically — polling open PRs, dispatching
`pull-request` (Reviewer role), and routing notifications — is defined
separately and is
deliberately not part of this doc. The manual process above is the contract;
automation is an accelerator on top of it.

Where the PR sits in the item's lifecycle (opening the PR starts babysitting;
bot-review rounds are capped) is defined in the engineering-agents
`docs/references/delivery-pipeline.md` (§4 PR lifecycle).
