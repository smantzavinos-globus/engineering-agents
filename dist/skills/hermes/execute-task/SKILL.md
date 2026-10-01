---
name: execute-task
description: Execute exactly one plan task using test-first discipline. Read the worklog to determine the current task, implement it with Red-Green-Verify (per its verification class), update the worklog, and commit all task changes atomically. One task per invocation.
compatibility: hermes
---

# Execute Task

Implement exactly one task from the worklog using strict TDD.

## Role

You are a disciplined implementer. You execute one task completely and correctly, following its checklist exactly.

## Process

1. **Read the worklog** — Find the NEXT STEP section to determine your current task
2. **Read the plan** — Read the full task details (TDD checklist) from plan.md
3. **Read backlog capture policy** — Note repo backlog store, follow-up capture procedure, and critical-item policy from the worklog
4. **Read requirement policy** — If the worklog includes requirement refs or approved requirement updates, note the requirements store, approved changes, and stop-and-ask policy
5. **Execute the task per its verification class:**
   - `contract`/`characterization`: write a failing test (Red), implement minimal code to pass (Green)
   - `check`/`none`: run the task's proving command
   - Refactor if needed (tests stay green)
6. **Run verification** — Run the task completion gate command
7. **Capture accepted follow-ups** — Create backlog items for approved non-blocking follow-ups and capture their stable IDs
8. **Apply approved requirement updates** — If this task includes approved requirement edits, update the canonical requirements store and record the affected IDs
9. **Update worklog** — Mark task done, set next NEXT STEP, append execution log entry, and record any created backlog item IDs or requirement changes
10. **Commit atomically** — Commit code, tests, requirements docs if changed, and the worklog update together as `task(TX): <short description>`
11. **Stop** — Do not proceed to the next task

## Rules

### One task only
You execute exactly ONE task. After verification, worklog update, and atomic task commit, you are done. The orchestrator will call another sub-agent for the next task.

### Follow the checklist exactly
The plan provides a specific checklist for this task. Follow it step by step. If the reviewer demands a break-it demonstration on a high-risk invariant test, run it and record the evidence.
- For `contract`-class tasks: after Green, verify the authored test is UNCHANGED since its authoring commit (`git diff --exit-code <authoring-commit> -- <test-paths>`); a modified frozen test is a gate failure regardless of Green.

### Verification before worklog update and commit
Run the task completion gate command BEFORE marking the task complete in the worklog and BEFORE committing. If it fails for reasons related to your task, fix it. If it fails for unrelated reasons, document it in the worklog execution log and apply the plan's gate policy.

### Atomic task commit
Each completed task must end with exactly one local commit that includes:
- Source changes
- Test changes
- Requirement doc changes approved for the task, if any
- The matching `worklog.md` update

Do not leave a completed task's code or worklog update uncommitted. Do not commit code first and update the worklog afterward; the worklog is part of the task's completion record.

### Follow-up work and backlog capture
If you discover work outside the current task:
1. Do not silently expand the current task or add tasks to the current plan/worklog task list.
2. Decide whether the discovery affects current-task correctness, current-plan correctness, safety, or verification.
3. If it may affect the current plan, stop and ask whether to fix it now, re-plan, or backlog it.
4. If it is useful but non-blocking, ask whether to record it in the repo backlog unless the worklog says capture is pre-authorized.
5. If accepted, create the backlog item using the repo's documented mechanism.
6. Record the stable backlog item ID in `worklog.md` under `Backlog Items Created` and in the task execution log.

Do not leave accepted follow-ups only in chat. The durable record is the repo backlog plus the worklog backlink.

### Requirement handling during execution
If the current task includes approved requirement updates, apply them using the repo's documented requirements mechanism and record the changed IDs in `worklog.md`.

If you discover a missing, unclear, or conflicting requirement:
1. Do not silently edit canonical requirements.
2. If it affects current-task correctness, current-plan correctness, safety, scope, or verification, stop and ask whether to update the approach/plan, change the requirement, or adjust scope.
3. If it is useful but non-blocking, record it as a proposed requirement change in the appropriate plan artifact or as a backlog item only after approval according to repo policy.
4. Tests are verification evidence, not the default source of durable requirements.

### Requirement citations in tests
When writing or updating tests:
1. Check the current task's `Requirement refs` and the worklog's requirement policy.
2. If the repo maintains requirement traceability and the task cites requirement IDs, cite the relevant IDs in tests using the repo's documented format.
3. If no test citation format is documented, do not invent one. Note the gap in the worklog and ask before adding a new convention.
4. If a test does not correspond to a cited requirement, do not force a citation; use the requirement conflict process if that suggests a missing requirement.

### Commit message format
```
task(T<N>): <short description of what was implemented>
```

### Worklog update format
After verification passes and any accepted follow-ups are captured, update worklog.md before committing:
1. Check off the task in the Task Status section
2. Update NEXT STEP to the next pending task (or note completion if last task)
3. Record created backlog item IDs under `Backlog Items Created` if any
4. Record requirement changes applied, if any
5. Append an execution log entry

## What to Do If Things Go Wrong

### Test won't pass
- Re-read the plan task details — are you testing the right behavior?
- Check if a dependency task's output is what you expected
- If genuinely stuck, note the issue in the worklog and mark the task as blocked

### Unrelated test failures
- Document in the worklog execution log
- Apply gate policy (continue if the failure is clearly unrelated)

### Task is larger than expected
- Implement what you can within the task's scope
- Ask before capturing any out-of-scope follow-up in the repo backlog
- Note accepted follow-up item IDs in the worklog
- Do NOT expand scope beyond what the plan specifies

## What You MUST NOT Do

- Do not execute multiple tasks
- Do not skip the TDD cycle
- Do not skip a reviewer-demanded break-it demonstration (see task checklist)
- Do not modify the plan
- Do not add new tasks to the current plan/worklog task list unless explicitly instructed
- Do not leave accepted follow-ups only in chat
- Do not commit without passing verification
- Do not commit code/tests without the matching worklog update
- Do not leave intended task changes uncommitted before stopping
- Do not push (commits are local only)
