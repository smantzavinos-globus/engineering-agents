# Task Tracking and Backlog Capture

This reference defines the process-level contract for tracking work outside the currently active plan. It defines **what** repos must support; each repo defines **how** those operations are implemented.

The model mirrors test levels: the process defines common concepts and required hooks, while a repo maps them to Markdown, GitHub Issues, Beads, Jira, Linear, or another store.

---

## Core Boundary

### Current-plan tasks

Current-plan tasks live in the active plan artifacts:

- `plan.md` — planned implementation task graph
- `worklog.md` — current execution state and task-by-task evidence

Agents must not silently add new tasks to the current plan or worklog task list during execution.

### Backlog items

Backlog items are work outside the current plan. They may be discovered during discovery, design, implementation, review, or normal repo maintenance.

Examples:

- a non-blocking hardening idea discovered while implementing T3
- a future feature intentionally excluded from the current brief
- a review suggestion that is useful but not required for the current plan to pass
- an unrelated pre-existing failure found during baseline gate audit

Backlog items are stored using the repo's documented task-tracking mechanism.

---

## Required Repo Hooks

Every repo using this process should document the following hooks in `AGENTS.md`, a task-tracking doc, or equivalent repo guidance.

| Hook | Required question answered |
|------|----------------------------|
| Backlog store | Where do backlog items live? |
| Create item | How does an agent add a new backlog item? |
| Stable ID | How is a repo-unique item ID assigned or discovered? |
| Reference format | How should artifacts reference backlog items? |
| Source backlink format | How does a backlog item point back to the plan/worklog/review/commit that created it, and how does the source artifact record the created ID? |
| List inbox | How does an agent find untriaged captured work? |
| List up next | How does an agent find human-approved next work? |
| Mark ready/done/canceled/deferred/blocked | How are lifecycle transitions recorded? |
| Agent capture policy | May agents create non-critical follow-ups directly, or must they ask first? |
| Critical/blocking policy | What should an agent do when the item may affect current-plan correctness or safety? |
| Tool/auth/fallback | What tool access is required, which operations mutate state, and what should agents do if the tool is unavailable? |

Repos may implement these hooks with files, issue trackers, CLIs, project boards, labels, or any other durable system.

---

## Minimum Item Contract

Every backlog item created by an agent must have, or be created in a system that assigns, these concepts:

| Concept | Purpose |
|---------|---------|
| Stable ID | Allows worklogs, reviews, commits, and search to reference the item |
| Title | Short actionable summary |
| Status or queue location | Indicates whether the item is inbox, ready, up next, blocked, done, etc. |
| Source backlink | Identifies where the item came from when agent-created from another artifact |

The stable ID must appear both in the backlog item and in the source artifact that created it.

Example worklog reference:

```md
Created backlog item TASK-0042: Add malformed config regression tests.
```

Example issue/work item source backlink:

```md
Source: `plans/config-validation/worklog.md`, T3
```

This makes the item traceable with normal repo search:

```bash
rg TASK-0042
```

---

## Recommended Vocabulary

Repos do not have to store these as literal fields, but they should map their tracking system to these concepts when possible.

### Status / queue state

| Status | Meaning |
|--------|---------|
| `Inbox` | Captured item; not yet triaged or shaped |
| `Clarification needed` | Missing information or unresolved questions block readiness |
| `Ready` | Clear enough to start discovery/design/planning or direct implementation |
| `Up next` | Human-approved queue; eligible for agent execution |
| `In progress` | Actively being worked |
| `In review` | Implementation is ready for human or final review |
| `Awaiting approval` | An agent reached a human gate (design, plan, findings) and is waiting on a reply; see [Delivery Pipeline](delivery-pipeline.md#3-gate-protocol) |
| `Blocked` | Cannot proceed without external input, dependency, or decision |
| `Done` | Completed |
| `Canceled` | Explicitly closed without implementation |
| `Icebox` | Intentionally captured but not active for agent processing |

`Up next` should usually be human-controlled. Agents may recommend readiness, but should not start arbitrary backlog work without approval.

How items move between these states, and which transitions a human, an agent, or a scheduled job makes, is defined in [Delivery Pipeline](delivery-pipeline.md).

### Kind / type

Kind describes what the work is:

- `bug`
- `feature`
- `chore`
- `docs`
- `hardening`
- `research`
- `debt`
- `idea`

Do not use `task` as a kind; every backlog item is already a task/work item.

### Origin

Origin describes where the work came from:

- `human-request`
- `plan-follow-up`
- `review-finding`
- `agent-observation`
- `external-issue`

Use `origin: plan-follow-up` for future work discovered while executing a current plan.

### Track

Track describes the expected process depth:

- `fast-path` — small, localized, low-risk change
- `standard-implementation` — full brief/approach/plan/worklog process
- `analysis-spike` — investigate before implementation is approved
- `docs-process` — documentation or process work

### Priority

Recommended priority values:

- `P0` — urgent/critical; may affect safety, correctness, or current-plan validity
- `P1` — important near-term work
- `P2` — normal planned work
- `P3` — low-priority or someday work

Priority is not queue state. `Up next` is a status/queue decision, not a priority.

---

## Backlog Items Becoming Plans

Backlog items are intake records, not substitutes for plan artifacts. When a backlog item is selected for work, it feeds the normal process:

```text
backlog item → brief → approach → plan → worklog → execution
```

Moving an item to `Up next` means it is approved to begin that process. It does not mean the issue/backlog text already contains enough implementation detail to skip `brief.md`, `approach.md`, `plan.md`, or `worklog.md` when those artifacts are required by the plan level.

### Definition of Ready

A backlog item is `Ready` when an agent can begin Discovery, Design, or Execution without asking foundational scoping questions.

A ready item should have:
- An understandable problem or request
- A concrete desired outcome
- Enough scope boundary to avoid accidental expansion
- Known constraints or non-goals, if relevant
- Verification intent or success criteria
- Unresolved decisions called out explicitly

`Ready` does not require a full implementation plan. It means there is enough signal for the normal planning process to start safely.

---

## Agent Capture Behavior

### Do not expand scope silently

If an agent discovers work outside the current task or plan, it must not silently add it to the current implementation scope.

Instead, it should classify the discovery:

1. **Required for current correctness** — stop and ask, or treat as a current-plan blocker/finding.
2. **Useful but non-blocking follow-up** — ask whether to capture it in the repo backlog, unless repo policy pre-authorizes capture.
3. **Unrelated pre-existing issue** — follow the plan's gate policy and repo task-tracking policy.

### TODO comments are not backlog tracking

TODO comments may exist as local code markers, but they are not a backlog system. If a TODO represents real follow-up work, it must reference a backlog ID:

```ts
// TODO(TASK-0042): Add malformed config regression tests.
```

Do not leave TODOs, chat notes, or worklog notes as the only durable record of future work.

### Suggested prompt

```text
I found a possible follow-up that is outside the current task:

Title: Add malformed config regression tests
Suggested kind: hardening
Suggested origin: plan-follow-up
Suggested priority: P2
Suggested status: Inbox

Should I add this to the repo backlog?
```

### If the user says yes

The agent should:

1. Create the backlog item using the repo's documented mechanism.
2. Capture the stable ID assigned by that mechanism.
3. Add a reference to the source artifact, usually `worklog.md` or `code_review.md`.
4. Include the created ID in its final summary.

### Critical discoveries

If the item may invalidate the current plan, affect correctness, introduce security/safety risk, or block verification, the agent should stop and ask before continuing:

```text
I found a potential blocker that may affect the current plan: <summary>.
Should I stop and re-plan, fix it in this plan, or capture it as a backlog item?
```

---

## Repo Task-Tracking Documentation Pattern

Repos should keep root `AGENTS.md` concise and route agents to a detailed task-tracking document.

### Root AGENTS.md blurb

```md
## Task Tracking

Backlog system: <Markdown backlog | GitHub Issues + Project | Beads | Jira | other>
Details: `<path/to/task-tracking-doc.md>`

Rules:
- New agent-discovered non-critical follow-ups default to `<Inbox equivalent>`.
- Stable IDs are `<TASK-0001 | #123 | BD-123 | other>`.
- `Up next` is human-controlled unless explicitly delegated.
- Critical/current-plan-affecting discoveries require stopping and asking.
```

### Detailed repo doc skeleton

Use a dedicated repo doc such as `docs/task-tracking.md`, `docs/backlog.md`, or `docs/engineering/task_tracking.md` for operational detail.

```md
# Task Tracking

## System

This repo uses <system> as the canonical backlog.

## Concepts

| Process concept | Repo implementation |
|-----------------|---------------------|
| Backlog item | <Markdown heading / GitHub issue / tracker item> |
| Stable ID | <ID format or assigned ID source> |
| Status | <sections / project field / tracker status> |
| Kind/type | <metadata field / labels / text line> |
| Origin | <metadata field / labels / source section> |
| Priority | <metadata field / project field / labels> |
| Track | <metadata field / project field / labels> |

## Required Operations

| Operation | How to do it |
|-----------|--------------|
| Create backlog item | <exact command or edit procedure> |
| Assign/discover stable ID | <how to choose/read the ID> |
| Add to Inbox | <command/procedure> |
| List Inbox | <command/procedure> |
| List Up next | <command/procedure> |
| Mark Ready | <command/procedure> |
| Mark Done | <command/procedure> |
| Mark Canceled | <command/procedure> |
| Move to Icebox/defer | <command/procedure> |
| Capture source backlink | <required format> |
| Handle critical item | <stop/fix/re-plan/backlog policy> |

## Agent Capture Policy

- Ask before creating backlog items unless <pre-authorization rule>.
- Default new follow-ups to <status> with <metadata>.
- Record the created ID back in the source artifact.
```

The operations table is the most important part: it gives agents a stable contract regardless of the backing system.

---

## Simple Markdown Reference Implementation

For small repos, the recommended lightweight implementation is a single file:

```text
docs/backlog.md
```

The file uses headings as canonical status. This avoids keeping an index and separate item files in sync.

### Root AGENTS.md blurb

```md
## Task Tracking

Backlog system: Markdown
Details: `docs/backlog.md`

Rules:
- New agent-discovered non-critical follow-ups go under `## Inbox`.
- Stable IDs use `TASK-0001`, `TASK-0002`, etc.
- `Up next` is human-controlled by moving items under `## Up next`.
- Critical/current-plan-affecting discoveries require stopping and asking.
```

### `docs/backlog.md` structure

```md
# Backlog

## System

This repo uses this single Markdown file as the canonical backlog. The section containing an item is its status.

## Required Operations

| Operation | How to do it |
|-----------|--------------|
| Create backlog item | Add `### TASK-XXXX — Title` under `## Inbox` |
| Assign stable ID | Find the highest existing `TASK-XXXX`, then use the next number |
| List Inbox | Read items under `## Inbox` |
| List Up next | Read items under `## Up next` |
| Mark Ready | Move the whole item under `## Ready` |
| Mark Up next | Human moves the whole item under `## Up next` |
| Mark Done | Move the whole item under `## Done` and add a completion note |
| Mark Canceled | Move the whole item under `## Canceled` and add a reason |
| Move to Icebox | Move the whole item under `## Icebox` |
| Reference item | Use `TASK-XXXX` in worklogs, reviews, and summaries |
| Critical item | Stop and ask before continuing current-plan execution |

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

### ID assignment

Use normal repo search to find existing IDs:

```bash
rg "TASK-[0-9]{4}" docs/backlog.md
```

Then choose the next unused number. If there is any ambiguity or concurrent editing risk, ask before assigning an ID.

### Item template

```md
### TASK-0004 — Add malformed config regression tests

- Kind: hardening
- Origin: plan-follow-up
- Priority: P2
- Track: standard-implementation
- Source: `plans/config-validation/worklog.md`, T3
- Created: 2026-05-07
- Created by: agent
- Acceptance:
  - [ ] Add malformed config regression tests.
  - [ ] Run the repo's relevant validation command.
- Notes:
  - Captured during T3 while validating malformed config handling.
```

### Example backlog file

```md
# Backlog

## System

This repo uses this single Markdown file as the canonical backlog. The section containing an item is its status.

## Required Operations

| Operation | How to do it |
|-----------|--------------|
| Create backlog item | Add `### TASK-XXXX — Title` under `## Inbox` |
| Assign stable ID | Find the highest existing `TASK-XXXX`, then use the next number |
| List Inbox | Read items under `## Inbox` |
| List Up next | Read items under `## Up next` |
| Reference item | Use `TASK-XXXX` in worklogs/reviews |

## Up next

### TASK-0003 — Add malformed config regression tests

- Kind: hardening
- Origin: plan-follow-up
- Priority: P2
- Track: standard-implementation
- Source: `plans/config-validation/worklog.md`, T3
- Created: 2026-05-07
- Acceptance:
  - [ ] Add malformed config regression tests.
  - [ ] Run the repo's relevant validation command.

## Ready

## Inbox

### TASK-0004 — Investigate GitHub issue sync workflow

- Kind: research
- Origin: agent-observation
- Priority: P3
- Track: analysis-spike
- Source: `plans/task-tracking/worklog.md`, T2
- Created: 2026-05-07
- Notes:
  - Captured during task tracking process design.

## Clarification needed

## In progress

## In review

## Blocked

## Icebox

## Done

## Canceled
```

### Markdown rules

- The section containing the item is the canonical status.
- Do not duplicate status inside the item unless the repo has automation to keep it synchronized.
- New agent-discovered non-critical follow-ups default to `Inbox`.
- Stable IDs use a documented format such as `TASK-0001`.
- Moving an item between sections changes its lifecycle state.
- Worklogs and reviews reference the item ID after creation.
- Keep each item self-contained so it can be moved between sections without losing context.

---

## GitHub Issues Reference Implementation

For repos using GitHub as the work surface, GitHub Issues should be the canonical backlog items. GitHub issue numbers are the stable IDs, referenced as `#123`.

### Root AGENTS.md blurb

```md
## Task Tracking

Backlog system: GitHub Issues + Project
Details: `docs/engineering/task_tracking.md`

Rules:
- Issues are canonical backlog items.
- Stable IDs are GitHub issue numbers, referenced as `#123`.
- New agent-discovered non-critical follow-ups are created as issues with Status `Inbox`.
- `Up next` is human-controlled through the GitHub Project Status field.
- Critical/current-plan-affecting discoveries require stopping and asking.
```

### Detailed GitHub task-tracking doc skeleton

```md
# Task Tracking

## System

This repo uses GitHub Issues as canonical backlog items and the `<Project Name>` GitHub Project for workflow state.

## Concepts

| Process concept | GitHub implementation |
|-----------------|-----------------------|
| Backlog item | GitHub issue |
| Stable ID | Issue number, e.g. `#123` |
| Status | Project field `Status` |
| Track | Project field `Track` |
| Priority | Project field `Priority` |
| Kind/type | Labels: `type:*` |
| Origin | Labels: `origin:*` and issue body `## Source` |
| Source backlink | Issue body `## Source`; source artifact references `#123` |

## Required Operations

| Operation | How to do it |
|-----------|--------------|
| Create backlog item | `gh issue create --title ... --body-file ... --label ...` |
| Assign/discover stable ID | Use the issue number returned by `gh issue create` |
| Add to Inbox | Add issue to project and set `Status = Inbox` |
| List Inbox | Query project items with `Status = Inbox` or list issues with repo's inbox label fallback |
| List Up next | Query project items with `Status = Up next` |
| Mark Done | Close issue after merge/completion and set `Status = Done` |
| Mark Canceled | Comment with reason, close issue, set `Status = Canceled` |
| Move to Icebox | Set `Status = Icebox` |
| Capture source backlink | Add `## Source` section to issue body and write `#123` in worklog/review |
| Critical item | Stop and ask before continuing current-plan execution |
```

### Recommended project fields

| Field | Purpose |
|-------|---------|
| `Status` | Workflow state: Inbox, Clarification needed, Ready, Up next, In progress, Awaiting approval, In review, Blocked, Done, Canceled, Icebox |
| `Stage` | Optional; Design, Plan, Execute, PR (see [Delivery Pipeline](delivery-pipeline.md#item-fields)) |
| `Autonomy` | Optional; `gated` (default) or `auto` (skips the plan gate) |
| `Track` | Process depth: Fast path, Standard implementation, Analysis / spike, Docs / process |
| `Priority` | P0–P3 |
| `Area` | Optional; use only if useful for project views |

### Recommended labels

Use labels for orthogonal metadata, not duplicate workflow state:

```text
type:bug
type:feature
type:chore
type:docs
type:hardening
type:research
type:debt
type:idea

origin:human-request
origin:plan-follow-up
origin:review-finding
origin:agent-observation
origin:external-issue

risk:high
needs:info
needs:decision
blocked
```

### Issue body template

```md
## Summary

<One-paragraph summary of the work item.>

## Metadata

- Kind: hardening
- Origin: plan-follow-up
- Priority: P2
- Track: standard-implementation

## Source

- Source plan: `plans/config-validation/plan.md`
- Source worklog: `plans/config-validation/worklog.md`
- Source task: T3
- Source commit: abc1234

## Rationale

<Why this should be tracked.>

## Acceptance Criteria

- [ ] <criterion 1>
- [ ] <criterion 2>

## Notes

<Optional context.>
```

### Creating an issue with `gh`

Use a temporary body file so the issue is readable and structured:

```bash
cat > /tmp/backlog-issue.md <<'EOF'
## Summary

Add malformed config regression tests.

## Metadata

- Kind: hardening
- Origin: plan-follow-up
- Priority: P2
- Track: standard-implementation

## Source

- Source plan: `plans/config-validation/plan.md`
- Source worklog: `plans/config-validation/worklog.md`
- Source task: T3
- Source commit: abc1234

## Rationale

While implementing T3, malformed configs were identified as under-tested.

## Acceptance Criteria

- [ ] Add malformed config regression tests.
- [ ] Run the repo's relevant validation command.
EOF

gh issue create \
  --title "Add malformed config regression tests" \
  --label "type:hardening" \
  --label "origin:plan-follow-up" \
  --body-file /tmp/backlog-issue.md
```

Record the issue number returned by `gh issue create` in the source artifact:

```md
Created backlog item #123: Add malformed config regression tests.
```

### Listing issues with `gh`

Labels alone are not a complete substitute for project status, but they are useful for focused lists:

```bash
# Agent-created plan follow-ups
gh issue list --state open --label "origin:plan-follow-up"

# High-risk open items
gh issue list --state open --label "risk:high"

# Research/spike candidates, if represented by label
gh issue list --state open --label "type:research"
```

### Viewing and updating issues with `gh`

```bash
# View an issue with comments
gh issue view 123 --comments

# Add a source/update comment
gh issue comment 123 --body "Captured from \`plans/config-validation/worklog.md\`, T3."

# Add labels
gh issue edit 123 --add-label "type:hardening,origin:plan-follow-up"

# Remove labels
gh issue edit 123 --remove-label "needs:info"

# Close as completed
gh issue close 123 --comment "Completed by <PR-or-commit-reference>."

# Close as canceled / not planned
gh issue close 123 --reason "not planned" --comment "Canceled because <reason>."

# Reopen with context
gh issue reopen 123 --comment "Reopening because <reason>."
```

### GitHub Project field commands

Project v2 updates require repo-specific owner, project number, project item, field, and option IDs. If agents are expected to update Project fields, the repo task-tracking doc must include those IDs or a deterministic command to discover them (see Project ID Discovery below).

Document IDs in the repo like this:

```md
## GitHub Project IDs

| Object | ID |
|--------|----|
| Project owner | `<owner>` |
| Project number | `<project-number>` |
| Project ID | `<project-id>` |
| Status field | `<status-field-id>` |
| Track field | `<track-field-id>` |
| Priority field | `<priority-field-id>` |

## Status option IDs

| Status | Option ID |
|--------|-----------|
| Inbox | `<inbox-option-id>` |
| Ready | `<ready-option-id>` |
| Up next | `<up-next-option-id>` |
| In progress | `<in-progress-option-id>` |
| In review | `<in-review-option-id>` |
| Blocked | `<blocked-option-id>` |
| Done | `<done-option-id>` |
| Canceled | `<canceled-option-id>` |
| Icebox | `<icebox-option-id>` |
```

Command shapes for adding and listing project items:

```bash
# Add an issue to the project
gh project item-add "<project-number>" \
  --owner "<owner>" \
  --url "https://github.com/<owner>/<repo>/issues/123"

# List project items as JSON so the repo can filter by field values
gh project item-list "<project-number>" \
  --owner "<owner>" \
  --format json
```

Command shape for setting a single-select field:

```bash
gh project item-edit \
  --id "<project-item-id>" \
  --project-id "<project-id>" \
  --field-id "<status-field-id>" \
  --single-select-option-id "<inbox-option-id>"
```

Use the same command shape for lifecycle transitions by changing only the option ID:

```bash
# Mark Ready
gh project item-edit \
  --id "<project-item-id>" \
  --project-id "<project-id>" \
  --field-id "<status-field-id>" \
  --single-select-option-id "<ready-option-id>"

# Move to Up next (normally human-controlled)
gh project item-edit \
  --id "<project-item-id>" \
  --project-id "<project-id>" \
  --field-id "<status-field-id>" \
  --single-select-option-id "<up-next-option-id>"

# Mark Done
gh project item-edit \
  --id "<project-item-id>" \
  --project-id "<project-id>" \
  --field-id "<status-field-id>" \
  --single-select-option-id "<done-option-id>"
```

Because item IDs differ from issue numbers, repos should document how to find the project item for an issue. If this is not documented, agents should create/comment on the issue and ask before attempting Project field automation.

### Project ID Discovery

If project IDs, field IDs, and option IDs have not been pre-configured in the repo's task-tracking doc, an agent can discover them from scratch using the `gh` CLI. This turns the ID tables from a prerequisite into something an agent can bootstrap.

Repos should document the project name and GitHub owner so agents can match the right project.

Find the project:

```bash
gh project list --owner "<owner>" --format json
```

Match the project by name, note its number, then get the project ID and field IDs:

```bash
gh project view "<project-number>" --owner "<owner>" --json id,title,fields
```

The output includes the project-level `id` plus a `fields` array with `name` and `id` for each field.

Get the option IDs for each single-select field:

```bash
gh project field-list "<project-number>" --owner "<owner>" --format json
```

Each field will have an `options` array with `name` and `id` for every choice. Map these to the ID tables and populate the placeholders so future agents can skip re-discovery.

### Project v2 Fallback

If Project IDs, field IDs, option IDs, or item IDs are not configured and discovery fails, agents must not guess IDs.

Use this fallback sequence:

1. Use `gh issue` commands for issue creation, comments, labels, and close/reopen operations — these do not require Project IDs.
2. Add an issue comment stating the intended Project transition, for example:

   ```md
   Intended Project update: set `Status = Ready`, `Track = Standard implementation`, `Priority = P2`.
   I did not mutate Project fields because the required Project v2 IDs are not available.
   ```

3. Record the limitation in the final summary and ask the human or automation owner to update the Project item.

### Human approval boundary

Agents may triage issues and recommend readiness, but moving work into `Up next` should normally be a human decision unless the repo explicitly delegates that authority.

---

## Backlog Hygiene

Repos should periodically review backlog state so captured work remains useful:
- Triage `Inbox` items into `Ready`, `Clarification needed`, `Icebox`, or `Canceled`
- Keep `Up next` intentionally small and human-approved
- Move stale low-value items to `Icebox` or `Canceled`
- Close or update items completed by plans
- Ensure old follow-ups still have enough context to be actionable
- Ensure TODO comments that represent real follow-up work reference backlog IDs
