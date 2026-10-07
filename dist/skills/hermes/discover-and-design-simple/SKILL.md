---
name: discover-and-design-simple
description: Fast path from a clear request to brief.md plus approach.md for simple, well-posed tasks. Use when the change is small, the outcome is known, and there is at most one obvious design. For work already talked through in detail that now needs documenting use Discover and Design. For vague, high-blast-radius, or multi-option problems use Discovery then Design instead.
compatibility: hermes
---

# Discover and Design Simple (speed run)

Produce an accepted `brief.md` and `approach.md` in one sitting. Optimized for
work that is simple and already well-posed. You may do light codebase research.
You do not run a Socratic interview or a multi-option design workshop.

## When to use / when to stop

**Use when:** the human already knows the outcome, the change is local, and
there is at most one obvious design.

**Stop and redirect when:**

- the work was already talked through in detail and is not trivial — that is
  `/discover-and-design`
- goals, non-goals, or success criteria are actually unclear — use `/discovery`
  then `/design`
- two or more designs are real, not cosmetic — use `/discovery` then `/design`
- the work is epic-sized or cross-cutting — use `/discovery` then `/design`
- research turns up a safety, compatibility, or scope surprise — use
  `/discovery` then `/design`

Do not pretend a speed run is still appropriate after that. Hand off.

## Process

1. **Restate the request** in a few sentences. Confirm only what is actually
   ambiguous. Do not walk a question checklist.
2. **Look at the code** that will change. One focused research pass is enough.

pi -p --session-id <plan-slug>-research-<topic> --name "researcher" --model <model-for-researcher> --skill <skills-dir>/research "Role: researcher. Research [specific files/modules]. Write findings to [path/findings/current_state.md]. Keep it short and evidence-based. Follow the loaded skill 'research' as the process for this work; if it did not load, stop and report."

Skip the delegate if you can answer from a few file reads in this session.
3. **Write both artifacts** into the plan directory (ask for the path if
   missing). Use the templates in [references/brief-template.md](references/brief-template.md)
   and [references/approach-template.md](references/approach-template.md).
   Read and follow [references/design-approach-authoring.md](references/design-approach-authoring.md)
   whenever an approach is produced: main change map, optional reference, linked
   meaning-bearing assets, and generated/visually inspected HTML views. Small work
   may keep contracts in the main document and mark irrelevant layers `N/A` with a
   reason; it does not bypass package authority, freshness, or acceptance scope.
   Keep them focused. Record plan level. If the repo maintains requirements,
   cite IDs or list questions; do not edit canonical requirements.
4. **Show the paths and wait.** Present the brief and full canonical package with
   generated views; acceptance covers that revision, not just the entry files.
   Record the package revision/inventory and generation/inspection evidence in
   `approach_review.md` (acceptance evidence does not claim an independent review).
   Do not commit until accepted. Then commit `brief.md`, the approach package and
   generated views, `approach_review.md`, `findings/` (if any), and
   `state.json` as `design: speed-run approach for <slug>`.
5. **Next step:** "The approach is ready. Create the plan with the create-plan skill, review it with the review-plan skill, and once the human has approved it execute it task-by-task (the execute-task skill per task, sequential with opportunistic parallel dispatch)."

For a true simple change (obvious, tiny, no design), write only `brief.md` at
plan level `simple` and say they can implement directly.

## Quality bar

- Goals, non-goals, and success criteria are explicit.
- The approach names the files/modules that change and what stays the same.
- Findings are factual and cite paths. No speculation presented as fact.
- No task list, no `tasks.json`, no implementation.

## What you must not do

- Do not implement.
- Do not write `plan.md` or `tasks.json`.
- Do not invent a second ceremony. If it needs ceremony, this is the wrong skill.
- Do not skip the human accept-and-commit gate.
