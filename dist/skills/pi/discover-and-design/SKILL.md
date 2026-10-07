---
name: discover-and-design
description: Document an already-discussed piece of work into an accepted brief.md plus approach.md. Use when the problem, scope, and design direction were already talked through in detail and what remains is writing it down, checking for genuinely overlooked gaps, and asking only targeted clarifying questions. For simple obvious tasks use Discover and Design Simple. To start from a vague idea use Discovery then Design.
compatibility: pi
disable-model-invocation: true
---

# Discover and Design

Turn an already-aligned discussion into an accepted `brief.md` and
`approach.md`. The prior conversation is the source of truth: you document it,
verify the few claims that matter against the codebase, and surface gaps the
discussion genuinely missed. You do not restart the interview, and you do not
run a research program.

## When to use / when to stop

**Use when:** the human has already talked through the problem in detail —
goals, scope, and design direction are effectively agreed — and what remains
is to write it down, check for overlooked areas, and resolve a small number of
targeted questions.

**Stop and redirect when:**

- the task is small and obvious — use `/discover-and-design-simple`
- the direction is not actually agreed, or two or more designs are still live —
  use `/discovery` then `/design`
- the work turns out to be epic-sized — use `/design` (epic decomposition is
  required there)
- verification contradicts a load-bearing assumption from the discussion —
  that is a real design fork, not a documentation detail; say so and redirect
  to `/design`

## Unattended mode

When a dispatcher runs you through `work-item` (no human in the session), the
backlog item and its comments stand in for the conversation. Follow the same
process with these changes:

- The premise changes: there was no prior discussion, so the item is the
  whole input. "When to use / when to stop" does not apply; do not redirect.
- Wherever this skill says *ask* (steps 1, 3 and 4) or *wait* (step 6), choose
  the best-supported default and record it in the brief as a numbered
  **assumption** or a numbered **open question with your recommended answer**.
  Do not stop to ask.
- The plan directory is the one `work-item` names; never ask for a path.
- Step 5's approach review always runs (no human is present to waive it).
- If verification or the review exposes a real design fork, do not redirect:
  write the options into the approach, recommend one, and make the choice the
  first gate question.
- If the work is epic-sized, say so as the first gate question and recommend
  splitting the item; do not decompose it unattended.
- A `revise:` reply from an earlier Design gate is authoritative: apply every
  answer, and do not re-ask what it settled.
- If the item is too vague to draft responsibly, still write the brief with
  what is known, and make the first gate question whether to `discuss` it live.
- Step 6 becomes: commit the artifacts, then post the **Design** gate per the
  `backlog` skill. The gate is the human accept step; do not wait in-session.

## Process

1. **Mine the conversation, don't restart it.** Extract from the discussion:
   goals, non-goals, constraints, success criteria, decisions already made
   (with the rationale that was given), and open points. Present a compact
   restatement — "here is what we agreed" — not a question checklist. Ask only
   about contradictions or true blanks, and batch every remaining question
   into a single round. If the context arrived as a handoff summary rather
   than a live conversation and key parts are missing, ask for them instead of
   guessing.
2. **Verify only what matters.** Check the discussion's load-bearing claims
   against the actual code: the files and modules it names, the integration
   points and behavior it assumes. A few file reads in this session is usually
   enough; at most one focused research delegate:

subagent({
  agent: "worker",
  task: "Verify [specific claim from the discussion] against [specific files/modules]. Write findings to [path/findings/current_state.md]. Keep it short and evidence-based.",
  skill: "research"
})

   Do not run a broad topic-by-topic research program — that is what the full
   Design phase is for.
3. **Run a focused gap scan.** Even a thorough discussion misses things. Check
   for legitimately overlooked areas — lifecycle, failure recovery, day-2
   operations, validation and safety, compatibility, requirement gaps — and
   raise only the ones that would change the design or are required for a
   complete, safe v1. Ask at most one focused batch of questions about them.
   Record the scan outcome in the brief (goals, non-goals, or open questions)
   so planning can see what was considered. Everything else goes to open
   questions or, with the human's confirmation, the backlog — not into scope.
4. **Write both artifacts** into the plan directory (ask for the path if
   missing). Use the templates in
   [references/brief-template.md](references/brief-template.md) and
   [references/approach-template.md](references/approach-template.md). Read and follow
   [references/design-approach-authoring.md](references/design-approach-authoring.md):
   author the main change map, optional linked reference and meaning-bearing assets;
   generate and inspect HTML views with the repository's chosen renderer. The fast
   path does not bypass package semantics, freshness, or visual evidence. Record
   plan level. Fill the decisions tables from the conversation — each decision
   records what was chosen and the rationale as discussed, not new options you
   invented. If the repo maintains requirements, cite IDs or list questions;
   do not edit canonical requirements.
5. **Run one approach review pass** unless the human waives it:

subagent({
  agent: "plan-reviewer",
  task: "Review the package linked from [plan directory path]/approach.md, including its reference and meaning-bearing assets, for architectural soundness, brief alignment, readability, and rendered visual evidence. Record the reviewed revision and artifact inventory.",
  skill: "review-approach"
})

   Fix what it finds in one pass. If review exposes a real design fork the
   discussion never settled, stop — that work belongs in the full Design
   phase.
6. **Show the paths and wait.** Present the brief and full canonical package with
   generated views. Human acceptance covers the recorded package revision, not
   only the two entry files. If review was waived, still record the package
   inventory and generation/inspection evidence in `approach_review.md`, explicitly
   noting the waiver rather than claiming an independent clean review.
   Do not commit until accepted. Then commit `brief.md`,
   the approach package and generated views, `approach_review.md`,
   `findings/` (if any), and `state.json` as
   `design: document agreed approach for <slug>`.
7. **Next step:** "The approach is ready. Create the plan with `/create-plan`, review it with `/review-plan`, and once you have approved it execute it task-by-task (`/execute-task` per task, sequential with opportunistic parallel dispatch)."

## Quality bar

- The artifacts faithfully record what was agreed — no silent scope additions,
  no dropped constraints, no reopened decisions presented as settled.
- Every load-bearing claim about the codebase was either verified or is marked
  as an open question.
- Gaps raised are ones that change the design or are required for a safe v1 —
  not a generic checklist dump.
- Goals, non-goals, and success criteria are explicit. The approach names the
  files/modules that change and what stays the same.
- No task list, no `tasks.json`, no implementation.

## What you must not do

- Do not re-run the Socratic interview — the discussion already happened.
- Do not implement.
- Do not write `plan.md` or `tasks.json`.
- Do not reopen settled decisions unless verification shows one is wrong — and
  then say so explicitly.
- Do not skip the human accept-and-commit gate (in unattended mode, the Design gate is that step).
