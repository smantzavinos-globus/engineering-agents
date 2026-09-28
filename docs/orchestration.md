# Orchestration

This document defines the three agent modes that drive the autonomous development process, how they interact with the human, and practical guidance for invoking each.

---

## Three Agent Modes

The process is not driven by a single "orchestrator." It's driven by three distinct agent modes, each with a different role, personality, and level of human interaction:

| Mode | Phase | Human Interaction | Personality |
|------|-------|-------------------|-------------|
| **Discovery** | Pre-brief → Brief | High (Socratic dialogue) | Challenging, exploratory, pushes back |
| **Design** | Brief → Approach | Medium (collaborative with delegation) | Structured, suggests options, delegates research |
| **Execution** | Approach → Complete | Low (approval gate + critical decisions only) | Autonomous, systematic, self-directing |

These can be three different agent definitions (with different system prompts), or three modes of a single configurable agent. The key distinction is their behavior, not their implementation.

### Handoff Between Modes

Each mode produces artifacts that serve as the input for the next:

```
Discovery → brief.md → Design → findings/ + approach.md
Standard: approach.md → Execution → implementation
Epic: approach.md → epic.md → child-plan execution
```

When a repo maintains requirements, requirement context flows through the same artifacts: Discovery cites relevant actors/use cases/workflows/requirements and questions, Design drafts any proposed requirement changes, Execution applies approved requirement edits as plan tasks, and Review checks alignment.

The human explicitly transitions between modes. The modes do not auto-advance into each other — each represents a different kind of work requiring different human engagement.

---

## Discovery Agent

### Purpose
Help the human go from a vague idea or problem to a clear brief with a determined plan level.

### When to Use
- You have an idea but aren't sure of the direction
- You have a problem but don't know the scope of the solution
- You need to think through tradeoffs before committing to an approach
- You want someone to challenge your assumptions

### Behavior

The Discovery agent is **Socratic and challenging**. It should:

- **Push back on assumptions** — "You said X, but have you considered that Y might invalidate that?"
- **Identify blind spots** — "You haven't mentioned how this interacts with [system Z]. Is that intentional?"
- **Surface tradeoffs** — "Option A gives you speed but sacrifices flexibility. Option B is slower but more extensible. Which matters more for this case?"
- **Ask probing questions** — "What's the failure mode if this doesn't work? What's the cost of getting it wrong?"
- **Challenge scope** — "Is this really one thing or three things? Could you ship value with just the first part?"
- **Help determine plan level** — "This sounds like it touches three independent systems with dependencies between them. That's probably an epic, not a single plan."
- **Guide toward specificity** — "What would success look like? How would you know if this is done?"
- **Identify prerequisites** — "Before you can do X, do you need Y in place first?"

### What It Produces
By the end of a Discovery session, the human should have:
- Clear understanding of the problem/opportunity
- Identified constraints and tradeoffs
- A decision on plan level (simple, standard, epic)
- Key decisions and their rationale
- Enough clarity to write a brief (or the agent writes it collaboratively)

### What It Does NOT Do
- Does not research the codebase (that's Design's job)
- Does not make implementation decisions
- Does not create plan artifacts beyond a brief
- Does not delegate to sub-agents
- Does not move into the Design or Execution phase

### Output
A `brief.md` written collaboratively with the human, capturing the intent, goals, non-goals, constraints, chosen plan level, and requirement context/questions when the repo maintains requirements.

---

## Design Agent

### Purpose
Move from a brief through research and into a completed approach, with documented options and decisions.

### When to Use
- You have a clear brief and need to figure out how to solve it
- You need codebase research to understand what you're working with
- You want to explore design options and their tradeoffs before committing
- You need help assembling findings into a coherent approach

### Behavior

The Design agent is **collaborative and structured**. It should:

- **Suggest research topics** — "Based on your brief, I think we need to understand: (1) how the event system works, (2) what WebSocket capabilities exist, (3) how user settings are stored. Should I investigate these?"
- **Delegate research to sub-agents** — Offload codebase exploration, library evaluation, and dependency analysis to specialized research sub-agents
- **Synthesize findings** — Assemble research outputs into a coherent picture
- **Present design options** — "I see three approaches: A, B, C. Here are the tradeoffs..."
- **Help weigh tradeoffs** — "Given your constraint of zero downtime, Option B is eliminated. Between A and C, A is simpler but C handles the edge case you mentioned."
- **Document decisions** — Ensure every significant decision records options considered, choice made, and rationale
- **Challenge weak designs** — "This approach doesn't address the concurrency issue we found in research. How should we handle that?"
- **Identify what's missing** — "We've decided on the model but haven't addressed how existing data migrates. Should we add a migration section to the approach?"

### Research Delegation

The Design agent delegates research to sub-agents rather than doing it all itself:

```
Design agent:
  - Identifies research topics needed
  - Proposes topics to human for confirmation
  - Calls research sub-agents for each topic
  - Receives findings files back
  - Synthesizes across findings
  - Presents options and tradeoffs to human
  - Documents the chosen approach
```

Research sub-agents produce focused findings files:
- `findings/current_state.md`
- `findings/code_structure.md`
- `findings/dependencies.md`
- `findings/library_research.md`
- etc.

### Design Options Documentation

When multiple approaches exist, the Design agent documents them in the approach:

```markdown
## Options Considered

### Option A: Piggyback on existing WebSocket
- **Pros:** No new infrastructure, faster to implement
- **Cons:** Couples notifications to data sync lifecycle
- **Risk:** WebSocket reconnection drops notifications

### Option B: Dedicated notification channel (SSE)
- **Pros:** Independent lifecycle, simpler protocol
- **Cons:** New infrastructure, additional connection per client
- **Risk:** Proxy/firewall issues with SSE

### Option C: Hybrid (WebSocket primary, polling fallback)
- **Pros:** Reliable delivery, graceful degradation
- **Cons:** More complex implementation
- **Risk:** Polling interval tuning

### Decision
Option A chosen. Rationale: Our WebSocket infrastructure is stable, 
reconnection is already handled, and the coupling is acceptable for MVP. 
Revisit if notification volume exceeds data sync volume significantly.
```

### What It Produces
By the end of a Design session:
- `findings/` directory with focused research files
- `approach.md` with the chosen design, documented options, key decisions, requirements alignment, and proposed requirement changes when relevant
- For **standard** work: confidence that the approach addresses the problem stated in the brief and is ready for detailed planning/execution
- For **epic** work: `epic.md` defining workstreams, child plans, sequencing, and the recommended first child plan
- For **epic** work: `epic_review.md` confirming the decomposition is ready for child-plan execution
- Clear boundaries for what the implementation plan should contain

### What It Does NOT Do
- Does not write implementation plans (task lists, TDD checklists)
- Does not implement code
- Does not autonomously proceed to execution
- Does not make decisions without presenting options to the human

### Human Interaction Points
- **Research topic approval** — "Should I investigate these topics?"
- **Design option decisions** — "Here are the options and tradeoffs. Which direction?"
- **Approach review** — "Here's the completed approach. Does this match your intent?"

---

## Execution Orchestrator

### Purpose
Take a completed approach and drive it through plan creation, review, implementation, and code review to completion with minimal human interaction.

### When to Use
- You have a completed brief + findings + approach
- You're ready for autonomous implementation
- You want the system to handle everything from plan to merged code

### Behavior

The Execution orchestrator is **autonomous and systematic**. It should:

**Epic guard:** If the target directory is an epic root, the orchestrator should not create a detailed `plan.md` at the epic root. It should require `epic.md` and `epic_review.md`, select or propose the next child plan, respect any preparatory/tranche-0 ordering, and execute planning at the child-plan level.

- **Drive the full lifecycle** — Plan → review → worklog → execute → code review
- **Call sub-agents for each step** — Fresh context per step, one task per implementation call
- **Validate quality gates** — Check each step's output before advancing
- **Handle iteration loops** — Plan review until clean, code review until clean
- **Make routine decisions automatically** — Obvious choices don't need human input
- **Stop only for critical decisions** — Only pause when a decision has high blast radius and genuine ambiguity
- **Self-recover from errors** — If a sub-agent produces bad output, retry or escalate

### Approval Gate

By default, the Execution orchestrator stops **once after plan review is complete** to get human approval before implementation begins:

```
Plan created → Plan reviewed (clean) → STOP: "Plan is ready. Approve to proceed with implementation?"
Human approves → Commit approved plan checkpoint → Create and commit worklog → Begin T1
```

This is the last natural checkpoint where the human reviews the full approach + plan before autonomous implementation begins.

**Auto-continue mode:** If the human says "automatically continue" or "proceed without stopping," the orchestrator skips this gate and runs through to completion. In this mode, it still creates local commits at each required checkpoint and only stops for:
- Critical decisions that genuinely require human judgment
- Unresolvable blockers
- Convergence cap exhaustion (too many review iterations without progress)

### Decision Autonomy

The orchestrator makes decisions autonomously along a spectrum:

| Decision Type | Action | Example |
|---------------|--------|---------|
| **Obvious/mechanical** | Make it, don't ask | File naming, import ordering, which test file to put a test in |
| **Low-risk design** | Make it, document in worklog | Whether to use a helper function vs inline code |
| **Medium-risk design** | Make it, document in approach/plan | Choosing between two valid patterns that both fit |
| **High-risk/ambiguous** | Stop and ask | Changing a public API contract, choosing between approaches with very different tradeoffs |
| **Irreversible** | Always stop | Data migrations, schema changes that affect production |

The key heuristic: **"Would I be upset if the agent chose wrong here?"** If yes, stop and ask. If no, decide and move on.

### Sub-Agent Strategy

The Execution orchestrator delegates all work to sub-agents:

| Step | Sub-agent task | Model tier |
|------|---------------|------------|
| Plan creation | Create detailed plan from brief + findings + approach | High |
| Plan review | Review plan for issues (iterative) | High |
| Worklog creation | Create worklog from plan, including repo backlog capture policy | Medium |
| Implementation | Execute one task per call using worklog; each task commits atomically; capture accepted follow-ups | Medium-High |
| Per-task review | Review just this task's diff (optional); separate blockers from backlogable suggestions | High |
| Code review | Review full implementation against plan (iterative); propose non-blocking backlog follow-ups separately | High |
| Fix pass | Address review findings and commit coherent fixes | Medium-High |

### Commit Checkpoints

The orchestrator enforces local commits as workflow checkpoints:

| Checkpoint | Commit timing | Message |
|------------|---------------|---------|
| Approved brief | After human accepts `brief.md` | `brief: finalize scope for <slug>` |
| Approved design | After reviewed `approach.md` is accepted | `design: approve approach for <slug>` |
| Approved plan | After plan review is clean and implementation is approved | `plan: approve implementation plan for <slug>` |
| Initialized worklog | Before T1 starts | `worklog: initialize execution log for <slug>` |
| Completed task | After verification and worklog update | `task(T<N>): <short description>` |
| Per-task review fix | After a task-review fix pass | `fix(T<N>): <short description>` |
| Final review fix | After each coherent final-review fix | `fix(review): <short description>` |
| Completion state | When marking the plan complete, if not included elsewhere | `status: mark <slug> complete` |

Before committing, check for unrelated dirty changes and pause if the commit would include work outside the current checkpoint. Before stopping, leave no intended changes uncommitted unless explicitly waiting for human review.

### Backlog Capture Checkpoints

Before task execution, the orchestrator must know the repo's task-tracking mechanism from `AGENTS.md` or repo docs. If no mechanism is documented, pause and ask whether to use a simple Markdown backlog, GitHub Issues, an existing tracker, or no backlog capture for this run.

During execution and review:
- Task agents may propose or create backlog items for non-blocking follow-ups according to repo policy.
- Created backlog item IDs must be recorded in `worklog.md`, `code_review.md`, or the relevant source artifact.
- The orchestrator includes created backlog IDs in progress and final summaries.
- Optional backlog items do not block plan completion unless they expose a Blocker/Critical/Major issue for the current plan.

### Iteration Loops

**Plan review loop:**
```
while plan_review_status != COMPLETE:
  call sub-agent with review-plan skill
  read plan_review.md for status
Cap: 5 iterations
```

**Code review loop:**
```
while code_review_status != COMPLETE:
  call sub-agent with review-code skill
  if issues found:
    call sub-agent to fix issues
  read code_review.md for status
Cap: 5 iterations
```

**Per-task review loop (optional):**
```
for each task:
  call implementation sub-agent
  record any created backlog item IDs
  call review sub-agent (this task's diff only)
  if issues:
    call fix sub-agent
    Cap: 2 attempts per task
  if review suggests non-blocking backlog items:
    ask/capture according to repo task-tracking policy
```

### Convergence Caps

To prevent infinite loops:
- **Plan review:** 5 iterations max
- **Code review:** 5 iterations max
- **Per-task review:** 2 iterations per task

When a cap is hit:
1. Document what's unresolved
2. Update state.json to `paused`
3. Present the situation to the human for decision

### Context Strategy

Each sub-agent starts with **fresh context**. This is critical:
- Implementation context from T1 would pollute T2
- Review context should not carry implementation bias
- The worklog is the durable handoff mechanism

**What each sub-agent receives:**

| Step | Context |
|------|---------|
| Plan creation | Brief + findings + approach |
| Plan review | Plan file path + skill instructions |
| Worklog creation | Plan file path + skill instructions + repo task-tracking docs |
| Implementation | Worklog (entry point) + plan (reference) + codebase + repo task-tracking docs |
| Per-task review | Task diff + plan (reference) + repo task-tracking docs |
| Code review | Plan path + branch diff + skill instructions + repo task-tracking docs |
| Fix pass | Code review findings + codebase; commit expectations + repo task-tracking docs |

### Error Handling

| Error | Action |
|-------|--------|
| Sub-agent produces inadequate output | Re-run with clearer instructions; try different model on second failure |
| Sub-agent stops mid-task | Continuation enforcement re-triggers (extension) |
| Build/test failure during implementation | Implementation agent attempts fix; if unrelated, document and apply gate policy |
| Convergence cap hit | Pause, document unresolved issues, escalate to human |
| Irrecoverable failure | Set status to blocked, present full context to human |

---

## Parallel Role Execution (Pi)

The Execution Orchestrator above is the frozen sequential path (OpenCode). Pi runs
**Parallel**: a DAG per planned fence group. See [Parallel Approach](approaches/parallel.md).

```text
approach + approach review
  └─ dynamic-create-plan → dynamic-review-plan → [human approval] → fence-group execution
```

`plan.md` and `tasks.json` are gated by `node tools/check-plan.mjs`. The parent owns
planning, approval, host verification, commits, and final review.

```text
create plan + task graph -> review -> approval
-> freeze interfaces -> freeze contracts (different agent than implementers)
-> [ generate dataflow.<group>.js -> host verification -> review -> checkpoint ]*
-> final gate -> fresh strong review -> complete
```

#### Parallel execution roles

| Role | Responsibility |
|---|---|
| Parent orchestrator | Owns the loop. Generates one DAG script per fence group, runs host verification, classifies failures, applies fixes, commits checkpoints. |
| Contract author | Freezes the interface surface and authors failing tests for `contract` tasks. Never an implementer of those tasks. |
| Implementer | Makes a frozen test pass inside its declared write-set. Runs only its own task-scoped check. |
| Group reviewer | Reviews each fence-group diff; may demand a break-it demonstration on a specific suspect test. |
| Final reviewer | Starts fresh after the last group and reviews the complete diff against `plan.md`. |

| Role | Agent |
|---|---|
| Parent orchestrator | primary Pi session with the `execute` preset |
| Contract author | `planner` |
| Implementer | `worker`, or `ui-worker` for frontend work |
| Group reviewer | `code-reviewer` with the `dynamic-review-code` skill |
| Final reviewer | `oracle`, fresh context |

#### Role-to-runtime mapping

The canonical role inventory (12 roles, independence rules, execution
tiers) is defined in [Agent Roles](references/agent-roles.md); per-repo
model assignment is a repo hook checked by assess-repo. Pi resolves these
to named subagents; OpenCode's sequential pipeline resolves the equivalent
roles to categories. Repository/user overrides remain the source of truth.

| Role | Pi agent | OpenCode agent type/category |
|---|---|---|
| Parent orchestrator | primary session (`execute` preset) | primary Execute agent/chat |
| Planner / contract author | `planner` | category `deep` |
| Standard implementer | `worker` | category `unspecified-high` |
| Mechanical / bounded-cheap implementer | `worker` on the cheap model | category `unspecified-low` |
| Visual implementer | `ui-worker` | category `visual-engineering` |
| Plan reviewer | `plan-reviewer` | category `deep` |
| Group / code reviewer | `code-reviewer` | category `unspecified-high` |
| Fresh final reviewer | `oracle` | external category `deep` |
| Escalation / hard debugging | `oracle` | `ultrabrain` |

In Parallel execution, `class: contract` and the `ui` flag pick the model and agent when the
group script is generated. There are no lanes or claims.

#### Suggested model mapping

These are recommendations, not hard requirements. Repository/user overrides remain the source
of truth.

| Agent type/category | Intended work | General model suggestion | GitHub Copilot suggestion |
|---|---|---|---|
| Primary lead | orchestration and decisions | GPT-5.5 or Claude Opus-class reasoning model | `github-copilot/claude-opus-4.8` |
| `unspecified-low` | mechanical isolated edits and decision-complete cheap tasks | GLM-5.2 or a fast coding model | `github-copilot/kimi-k2.7-code` |
| `unspecified-high` | standard implementation, contract authoring, group review | Claude Sonnet 5 or GLM-5.2 | `github-copilot/claude-sonnet-5` |
| `visual-engineering` | UI, accessibility, interaction, visual work | Gemini 3.5 Flash | `github-copilot/gemini-3.5-flash` |
| `deep` | planned complex implementation and fresh authoritative final review | GPT-5.5 or Claude Opus-class coding/review model | `github-copilot/claude-opus-4.8` |
| `ultrabrain` | escalation-only: unusually hard final reviews and difficult debugging | GPT-5.5/5.6 or Claude Opus-class highest-reasoning model | `github-copilot/claude-opus-4.8` |

`ultrabrain` is escalation-only/low-volume by design, so `github-copilot/claude-fable-5`
(priciest, smartest) is a reasonable per-repo swap-in when cost is not the binding constraint.

### Rigor tradeoffs (explicit)

| Guarantee | Sequential | Parallel |
|-----------|------------|---------|
| Per-task break-it check | yes | removed; reviewer-initiated on suspicion instead |
| Test authorship | implementer writes its own test | different agent, frozen before implementation, diff-checked |
| Commit granularity | per task | per verified fence group |
| Review context | fresh per pass | per-group review plus a fresh strong final review |
| Verification location | inside the task | on the host, by the parent, at fence boundaries |

### Runtime constraints

These are properties of the runtime, not preferences:

- Use `runs.all`, never `runs.run` — `runs.run` throws and aborts in-flight siblings.
- Result objects expose `ok`; there is no `status` field.
- Every child needs an explicit `model`.
- A child `gate:` cannot carry verification: acceptance evidence is validated before the gate
  command's result is consulted.
- There is no `worktree.apply`, so groups share the tree and write-set collisions must be
  prevented at plan time inside a fence group.
- A run allows 64 spawns and never refunds them; per-child default timeout is 30 minutes.

See [Execution Patterns](execution-patterns.md) and the `dynamic-execute-plan` skill for the
full protocol.

---

## Agents & Model Tiers

### Model Tiers

| Tier | Purpose | Characteristics | Examples |
|------|---------|----------------|----------|
| **Frontier (reasoning)** | Orchestration, planning, plan review | Best logical reasoning, cross-document analysis, finding contradictions | Opus, GPT-5.5 |
| **Frontier (code)** | Code review, architectural decisions | Best code comprehension, pattern recognition, anti-pattern detection | GPT-5.4, Codex, Opus |
| **Frontier (highest)** | Oracle/second opinion | Maximum reasoning depth, risk assessment | Opus highest thinking, o3 |
| **Execution** | Implementation, mechanical tasks | Good code output, cost-effective, high volume | Sonnet, GLM-5.1, DeepSeek V4 |
| **Execution (UI)** | Frontend/UI implementation | Strong at CSS, components, accessibility, visual design | Claude Sonnet (strong UI), specialized UI models |
| **Visual** | Image/screenshot analysis | Multimodal, can reason about visual content | Gemini Pro, GPT-4o vision |

### Agent Reference

| Agent | Model Tier | Role | Skills Used |
|-------|-----------|------|-------------|
| **`planner`** | Frontier (reasoning) | Create plans from brief + approach | `create-plan` |
| **`plan-reviewer`** | Frontier (reasoning) | Review plans for logic, completeness, consistency | `review-plan` |
| **`code-reviewer`** | Frontier (code) | Review implementation against plan | `review-code` |
| **`worker`** | Execution | Implement backend/logic tasks, create worklog, codebase research, fixes | `execute-task`, `create-worklog`, `research` |
| **`ui-worker`** | Execution (UI) | Implement frontend/UI tasks | `execute-task` |
| **`researcher`** | Execution | Web/external documentation research | — |
| **`vision`** | Visual | Analyze screenshots, UI mockups, visual content | — |
| **`oracle`** | Frontier (highest) | Read-only second opinion, architecture advice | — |

> **Harness note:** The agent names in these tables describe the Pi roster, where every role is a named subagent. OpenCode ships only the three primary mode agents (`discovery`, `design`, `execute`) and delegates every engineering sub-role through the `task` tool: planning and all reviews default to `category="deep"` (escalate to `category="ultrabrain"` only for unusually hard or unique cases), the oracle read-only second opinion uses `category="ultrabrain"`, implementation roles use `category="deep"` (UI to `visual-engineering`), and research uses the built-in `explore` (codebase) and `librarian` (external) subagent types. The skill bodies are generated per harness from one canonical source — see [Skill Rendering](skill-rendering.md).

### Full Process with Agent Assignments

| Stage | Invocation | Agent | Skill | Model Tier | Notes |
|-------|-----------|-------|-------|-----------|-------|
| Discovery | `/preset discovery` | — (preset) | `discovery` | Frontier (reasoning) | Interactive dialogue |
| Design — orchestrate | `/preset design` | — (preset) | `design` | Frontier (reasoning) | Interactive, delegates research |
| Design — codebase research | sub-agent | `worker` | `research` | Execution | Explore code, produce findings |
| Design — web research | sub-agent | `researcher` | — | Execution | External docs, library eval |
| Design — visual analysis | sub-agent | `vision` | — | Visual | Analyze UI screenshots if needed |
| Design — write approach | direct (Design preset) | — | — | Frontier (reasoning) | Writes approach.md from findings + decisions |
| Design — review approach | sub-agent | `plan-reviewer` | `review-approach` | Frontier (reasoning) | Architectural soundness, brief alignment |
| Execute — orchestrate | `/preset execute` | — (preset) | `execution-orchestrator` | Frontier (reasoning) | Drives full lifecycle |
| Execute — create plan | sub-agent | `planner` | `create-plan` | Frontier (reasoning) | Needs strong decomposition |
| Execute — review plan | sub-agent | `plan-reviewer` | `review-plan` | Frontier (reasoning) | Logical cross-section analysis |
| Execute — create worklog | sub-agent | `worker` | `create-worklog` | Execution | Mechanical extraction |
| Execute — implement task | sub-agent | `worker` or `ui-worker` | `execute-task` | Execution / Execution (UI) | Use ui-worker for frontend tasks |
| Execute — per-task review | sub-agent | `code-reviewer` | `review-code` | Frontier (code) | Catch errors early |
| Execute — fix task issues | sub-agent | `worker` or `ui-worker` | — | Execution | Match worker type to domain |
| Execute — final code review | sub-agent | `code-reviewer` | `review-code` | Frontier (code) | Full branch diff analysis |
| Execute — fix review issues | sub-agent | `worker` or `ui-worker` | — | Execution | Match worker type to domain |
| Second opinion | sub-agent | `oracle` | — | Frontier (highest) | Read-only, any time |
| Visual analysis | sub-agent | `vision` | — | Visual | Any agent can delegate here |
| Assess repo | direct | any | `assess-repo` | Frontier | Evaluate repo readiness |

### When to Use Each Agent

| Agent | Use when... | Do NOT use for... |
|-------|-------------|-------------------|
| `planner` | Creating the detailed implementation plan from brief + approach | Implementation, review, research |
| `plan-reviewer` | Reviewing plan.md for logic bugs, gaps, consistency; reviewing approach.md for architectural soundness | Code review, implementation |
| `code-reviewer` | Reviewing code diffs against plan requirements | Plan review, approach review, implementation |
| `worker` | Implementing backend/logic tasks, creating worklogs, codebase research, fixing review findings | Frontend/UI tasks (use ui-worker), plan creation (use planner) |
| `ui-worker` | Implementing frontend tasks: components, styling, state, accessibility | Backend logic, API work, data layer |
| `researcher` | Searching the web, reading external docs, evaluating libraries | Codebase research (use worker + research skill) |
| `vision` | Analyzing screenshots, UI mockups, visual diffs, design comps | Code analysis, text-only tasks |
| `oracle` | Architecture decisions, risk assessment, debugging second opinion | Implementation, review (it's read-only) |

### Domain Worker Selection

The orchestrator should choose `worker` vs `ui-worker` based on the task content:

| Task involves... | Use |
|-----------------|-----|
| API endpoints, mutations, queries | `worker` |
| Database/schema changes | `worker` |
| Business logic, data processing | `worker` |
| CLI commands, tooling | `worker` |
| Infrastructure, CI/CD, Nix | `worker` |
| UI components, pages, layouts | `ui-worker` |
| CSS, Tailwind, styling | `ui-worker` |
| Client-side state management | `ui-worker` |
| Accessibility (a11y) | `ui-worker` |
| Animations, transitions | `ui-worker` |
| Responsive design | `ui-worker` |
| Mixed (API + UI in same task) | `worker` (backend first), then `ui-worker` (UI portion) |

### Vision Agent Usage

Any agent can delegate to `vision` when visual analysis is needed:

- **During research:** Analyze existing UI screenshots to document current state
- **During implementation:** Verify visual output matches design intent
- **During review:** Compare before/after screenshots for visual regression
- **During design:** Analyze mockups or design comps to inform the approach

```
subagent({
  agent: "vision",
  task: "Analyze this screenshot of the current dashboard. Describe the layout, components, and visual hierarchy. Note any accessibility concerns."
})
```

### Cost Optimization Strategy

The biggest savings come from:
1. **Execution tier for implementation** — Most token volume is in code writing. Use cost-effective models here.
2. **Frontier only for quality gates** — Reviews and planning need the best reasoning but use fewer tokens.
3. **Domain-specialized workers** — UI-strong models produce better frontend code on the first try, reducing fix cycles.

Do NOT cut costs on:
- **Discovery/Design presets** — Bad early decisions waste all downstream work
- **Orchestrator** — Bad delegation decisions waste sub-agent calls
- **Plan review** — Missing logic bugs means rework during implementation
- **Code review** — Weak review means bugs ship

---

## Resumption

If the process is interrupted at any point:

1. **Read state.json** — determines current phase
2. **Read the current stage's artifact** — determines where within that stage
3. **Resume from the correct point:**

| State phase | Resume action |
|-------------|--------------|
| `draft` | Brief exists; start Design agent |
| `researching` | Check findings/ for completed research; continue or restart |
| `researched` | Findings complete; start approach |
| `designing` | Check approach.md; continue or restart |
| `designed` | Approach complete; start Execution orchestrator |
| `planning` | Re-run plan creation |
| `planned` | Start plan review |
| `reviewing` | Continue plan review (review log shows progress) |
| `reviewed` | Plan approved; create worklog or start implementation |
| `ready` | Worklog exists; start execution |
| `executing` | Read worklog for next task; continue |
| `reviewing_code` | Continue code review (review log shows progress) |

The worklog is the most important resumption artifact — it explicitly says what's been done and what's next.

---

## Practical Examples

### Example 1: Full flow from idea to implementation

```
[Discovery session — high interaction]
Human: I want to add real-time notifications...
Discovery: What problem? Who's affected? What constraints? ...
→ Produces: brief.md

[Design session — medium interaction]  
Human: Let's design this. Here's the brief.
Design: I'll research the event system, WebSocket layer, and user settings.
        Here are three approaches... tradeoffs are...
→ Produces: findings/ + approach.md

[Execution — low interaction]
Human: Implement this. Auto-continue, only stop for critical decisions.
Execution: Creating plan... reviewing... implementing T1... T2... reviewing code...
→ Produces: plan.md, worklog.md, code_review.md, implementation
```

### Example 2: Skip straight to execution (approach already clear)

```
Human: I have a brief and approach ready in plans/2026_05_01_notifications/. 
       Implement it. Stop after plan review for approval.

Execution: Creating plan from approach... reviewing plan... 
          [STOP] Plan is ready. 5 tasks, estimated 45 minutes. Approve?
Human: Go.
Execution: Implementing... reviewing... complete.
```

### Example 3: Bug fix flow

```
[Discovery — brief]
Human: Users are getting 403 errors intermittently on the dashboard.
Discovery: Is this all users or specific ones? When did it start? ...
→ Produces: brief.md (bug fix, standard level)

[Design — debug/research]
Human: Research and debug this.
Design: I'll trace the auth flow, check recent changes, look at the error pattern.
        Root cause: race condition in token refresh. Here's the approach to fix it.
→ Produces: findings/root_cause.md + approach.md

[Execution — fix it]
Human: Fix it. Auto-continue.
Execution: Plan (regression test + fix)... implementing... reviewing... done.
```

### Example 4: Epic orchestration

```
[Discovery — scope the epic]
Human: We need to migrate from REST to GraphQL.
Discovery: Full migration or incremental? Which services first? ...
→ Produces: brief.md (epic)

[Design — epic level research + approach + decomposition]
Human: Design the migration approach and break it into workstreams.
Design: [researches current API surface, dependencies, client usage]
        Here's the phased approach with 3 workstreams, 8 child plans...
→ Produces: findings/ + approach.md + epic.md + epic_review.md

[Execution — child plans]
Human: Execute the epic. Stop after each child plan's plan review for approval.
Execution: This is an epic root. I found epic.md and recommend starting with 01_schema_definition.
          [STOP] Child plan 01 ready. Approve?
Human: Go.
Execution: Implementing 01... complete. Starting 02_resolver_layer...
```

---

## Per-Repository Model Configuration

The agent definitions (planner, plan-reviewer, code-reviewer, worker, ui-worker, etc.) are installed globally with default model settings. Repositories can override specific fields (typically just `model` and `thinking`) using `.pi/settings.json` → `subagents.agentOverrides` at the repo root.

### How Agent Overrides Work

Pi subagents support field-level overrides via settings:

| Location | Scope | Priority |
|----------|-------|----------|
| `.pi/settings.json` (project) | This repo only | Highest |
| `~/.pi/agent/settings.json` (user) | All repos | Lower |

Overrides modify specific fields of the agent definition **without copying the full agent file**. This means:
- Agent system prompts, skills, and tools stay centralized in `~/.pi/agent/agents/`
- Updates to agent definitions automatically apply to all repos
- Repos only specify what's different

### Overriding Models Per Repo

Create `.pi/settings.json` in the repo root and add a `subagents.agentOverrides` block:

```json
{
  "subagents": {
    "agentOverrides": {
      "worker": {
        "model": "fireworks/accounts/fireworks/models/deepseek-v4-pro",
        "thinking": "high"
      },
      "code-reviewer": {
        "model": "openai-codex/gpt-5.4",
        "thinking": "high"
      }
    }
  }
}
```

Supported override fields: `model`, `thinking`, `skills`, `tools`, `systemPrompt`, `systemPromptMode`, `inheritProjectContext`, `inheritSkills`, `defaultContext`, `disabled`.

Settings-level `subagents.agentOverrides` fields replace the agent file's frontmatter values (pi-subagents >=0.73; earlier releases skipped frontmatter-declared fields). Project overrides beat user overrides. pi-subagents 0.68 removed `fallbackModels`; a definition or override that still sets it fails to load.

### Common Per-Repo Configurations

**Budget-conscious repo:**
```json
{
  "subagents": {
    "agentOverrides": {
      "worker": { "model": "fireworks/accounts/fireworks/models/deepseek-v4-pro" },
      "ui-worker": { "model": "fireworks/accounts/fireworks/models/deepseek-v4-pro" },
      "code-reviewer": { "model": "openai-codex/gpt-5.4", "thinking": "high" }
    }
  }
}
```

**High-quality repo:**
```json
{
  "subagents": {
    "agentOverrides": {
      "worker": { "model": "anthropic/claude-sonnet-4", "thinking": "high" },
      "planner": { "model": "anthropic/claude-opus-4", "thinking": "high" },
      "code-reviewer": { "model": "anthropic/claude-opus-4", "thinking": "high" }
    }
  }
}
```

**Frontend-heavy repo:**
```json
{
  "subagents": {
    "agentOverrides": {
      "ui-worker": { "model": "anthropic/claude-sonnet-4", "thinking": "high" }
    }
  }
}
```

**Disable unused agents:**
```json
{
  "subagents": {
    "agentOverrides": {
      "ui-worker": { "disabled": true },
      "vision": { "disabled": true }
    }
  }
}
```

### Why NOT Full Agent File Copies

Do NOT create repo-local `.pi/agents/{name}.md` copies to override models. Field-level overrides in `.pi/settings.json` → `subagents.agentOverrides` are the supported path, and full file copies create maintenance burden:
- When global agent prompts/skills change, every repo copy goes stale
- No automatic updates — requires manual sync across all repos
- Easy to drift on system prompt quality

Use `.pi/settings.json` → `subagents.agentOverrides` — you get model customization with zero maintenance.
