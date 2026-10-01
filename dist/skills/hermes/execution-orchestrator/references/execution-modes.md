# Execution Modes for Hermes

The pipeline (brief → research → approach → approach review → plan → plan
review → worklog → execute → code review → PR review) is invariant. What
varies is **how Hermes drives the stages**. Three modes exist; they differ in
isolation, cost, and speed — not in what each stage must produce.

**Mode selection is normative in the `software-development` skill** (its
"Execution mode selection" table): confirm the mode with the human when the
plan is approved, record it in the worklog header, keep it for the plan.
This document is the deep-dive reference — the per-mode mechanics that the
table summarizes.

## The three modes

### 1. Pi subprocesses (standard)

Hermes acts as the human orchestrator would: each stage is a separate `pi`
process invocation. Hermes owns the loop — it launches Pi, verifies results
on the host between calls, and advances the pipeline.

- **Fresh session per stage by default.** Each planning step, each task
  execution, and each review runs in a new Pi session:
  `pi -p --session-id <plan-slug>-<stage>[-<N>] --name "<stage>" "<prompt>"`
  — one session per stage/task (e.g. `<plan-slug>-research`,
  `<plan-slug>-plan`, `<plan-slug>-task-1`, `<plan-slug>-task-2`), and
  reviews always get their own fresh ids suffixed `-review-<N>`
  (`<plan-slug>-approach-review-1`, `<plan-slug>-code-review-1`) — never
  the author's id.
  Fresh sessions keep reviewer and implementer contexts independent — the
  same independence the review rules require of agents.
- **Session reuse is the exception, for small follow-ups.** Continuing the
  *same* session is appropriate when the follow-up is small, belongs to the
  same stage's mental context, and carries no review-independence
  requirement: a fix to the task just implemented, a clarification while a
  plan is being written, a re-run after a trivial failure. Use
  `pi --session-id <same-id> "<follow-up>"` (the exact ID resumes the
  existing session). Never reuse a session across the
  implementer/reviewer boundary, and never reuse one across tasks.
- **Investigation continuity is the second exception.** Sometimes a task's
  root cause is not yet proven: a debug/findings stage, or a task whose fix
  keeps failing for reasons nobody understands yet. There, the open
  hypotheses and experiments *are* the working state, and a fresh session
  has to rebuild them every round. Hermes may resume the *same implementer
  session* across those iterations, within that one task, provided:
  - the worklog records the session ID and why continuity was chosen
    (`session: <id> — continuity: <reason>`), so a resume or a reviewer can
    see it;
  - every round still ends with Hermes running the task's gate on the host;
    the session's own report is never the evidence;
  - reviews of that work still run in fresh sessions (independence is
    unchanged);
  - the session ends once the root cause is proven. The rest of the task,
    and every later task, starts fresh. If the context bloats first, write
    the current hypotheses into the findings or worklog and start a fresh
    session from them instead of pushing on in a degraded one.
- Worklog-first discipline still applies: Hermes reads `worklog.md`, points
  Pi at the current task, runs the task's verification gate on the host, and
  commits the checkpoint itself (or has the Pi session commit, per repo
  rules).

### 2. Hermes subagents

Hermes implements stages directly with its own subagent delegation — no Pi.
Useful for simple plans where Pi's process-per-stage overhead exceeds the
work. The stage contracts are unchanged: the implementer subagent executes
one task per its verification class; a different subagent (never the same
context) reviews; Hermes runs verification gates on the host and commits
checkpoints. All review-independence rules apply unchanged.

### 3. Single Hermes session

Hermes does the work itself in the current conversation: plan tasks in
order, verification gates after each, commits per task. Acceptable only for
trivial plans; the moment a task fails twice or the plan grows, Hermes
should propose escalating to mode 1 or 2. The no-self-review rule still
holds — code review of this work must still go through a different agent
(mode 2 subagent or a Pi review process), never the same session grading
its own work.

## Invariants common to all modes

Normative summary lives in the `software-development` skill. Mode-specific
additions here:

- Human approval gates (plan review → execution; PR merge) are unchanged.
  Exception: delivery-pipeline items with `Autonomy: auto` skip the plan
  gate (see `docs/references/delivery-pipeline.md` §2); PR merge is never
  skipped.
- Mode is recorded in the worklog header at execution start, so a resume
  knows what it is resuming into.
- Any session continued under the investigation-continuity exception is
  recorded in the worklog with its reason.

## Escalation / de-escalation

- Single-session → subagents: on the second task failure, or when a plan
  turns out bigger than triage suggested.
- Subagents → Pi subprocesses: when tasks need hard isolation, when
  parallel dispatch across machines/toolchains matters, or when repo rules
  require Pi-authored contract tests.
- De-escalation mid-plan is discouraged; finish the plan in the selected
  mode and choose differently next time.
