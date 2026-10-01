# Repository Requirements for Autonomous Agent Workflow

This is the reference checklist used by the assess-repo skill. It defines what a repository needs to work effectively with the engineering plan process.

## Essential Requirements

### Root AGENTS.md
Must contain or reference:
- Tech stack (languages, frameworks, key libraries)
- Architecture doc links
- Test infrastructure doc links
- Coding rules links
- Per-directory AGENTS.md index
- Verification policy

### Test Architecture Document
Must include:
- Test levels defined (unit, integration, e2e, etc.)
- What each level proves
- Exact commands per level
- Command scope (touched-files, package-wide, repo-wide)
- When to run each command (TDD loops, task completion, final verification)
- Prerequisites (services, env vars, setup steps)
- Fixture/test data strategy

### Plans Directory
- Must exist at a known location
- Optionally contains a README with repo-specific planning guidance

### Build/Test/Lint Commands
- Must be documented and runnable
- Must include scope information

## Important Requirements

### Architecture Document
Must cover:
- System boundaries and major modules
- Core data flow
- External integrations
- Key constraints
- Module relationships

### Coding Rules
- Naming conventions
- Error handling patterns
- Import organization
- Anti-patterns to avoid

### Per-Directory AGENTS.md
Directories with specialized patterns need their own rules:
- Component directories (patterns, naming, structure)
- API directories (error handling, validation)
- Test directories (fixture patterns, authoring rules)
- Backend directories (data access patterns)

### Environment Documentation
- Required services and how to start them
- Required environment variables
- Prerequisites for running tests

### Task Tracking / Backlog
Must define every required hook for tracking work outside the current plan:
- Backlog store location or system
- How agents create accepted follow-up items
- Stable item ID format or assigned ID source
- How agents reference created items from worklogs/reviews/TODOs/commits
- Required source backlink format
- How to list untriaged captured work (`Inbox` or equivalent)
- How to list human-approved next work (`Up next` or equivalent)
- How to mark items ready, done, canceled, deferred/iceboxed, or blocked
- Whether `Up next` is human-controlled or delegated
- Whether agents may create non-critical follow-ups directly or must ask first
- What agents do for critical/blocking discoveries
- Tool/auth prerequisites and fallback procedures for tracker-backed systems

These hooks must be concrete enough for an agent to act. A vague note like "track TODOs somewhere" is not sufficient. For standard and epic autonomous execution, missing task tracking is a major readiness gap because accepted follow-up work can be lost or remain only in chat/worklogs.

### Requirements Handling
The repo must make its requirements posture explicit:
- Maintains requirements
- Does not maintain a separate requirements system
- Unclear / needs human decision
- Likely needed but missing, based on product, workflow, compliance, or durable contract docs

If the repo maintains requirements, it must define every required requirements hook:
- Requirements store location or system
- Actor/persona definitions
- Use case definitions
- Workflow/scenario definitions
- Functional requirement location
- Non-functional requirement location
- Operational requirement location
- Stable requirement ID format or assigned ID source
- How briefs/plans/tests/reviews/commits cite requirement IDs
- Test requirement citation format
- Traceability rules, including which links are manually maintained and in which direction
- How approved requirement changes are applied during execution
- How current requirements are retired, replaced, or materially changed
- Validation/query commands, if available
- Human approval boundary for canonical requirement edits
- Tool/auth prerequisites and fallback procedures for CLI/tracker-backed systems

These hooks must make mutating versus read-only operations clear. Agents should not have to infer how to edit canonical requirements or when approval is required.

## Recommended Requirements

### Tech Stack LLM Instruction Files
- Framework-specific rule files (e.g., sveltekit_rules.txt)
- Placed in .llm/ or similar
- Referenced from AGENTS.md with "when to read" guidance

### Architecture Decision Records
- Document non-obvious decisions
- Include: context, decision, consequences
- Prevent re-litigating settled decisions

### Issues and Learnings Log
- Running list of bugs and resolutions
- Documentation deficiencies discovered
- Recurring mistakes and prevention

### Plans README
- Where to find verification commands
- Repo-specific constraints on plans
- Links to architecture and testing docs

## Quality Indicators

### Good AGENTS.md (routing document)
```markdown
## Test Infrastructure
- `docs/engineering/test_architecture.md`

## Per-Directory Rules
- `src/components/AGENTS.md` — component patterns
- `e2e/AGENTS.md` — E2E test authoring
```

### Bad AGENTS.md (everything dumped in one file)
```markdown
## Component Rules
[500 lines of component patterns]

## E2E Rules  
[300 lines of test patterns]

## API Rules
[400 lines of API patterns]
```

### Good Test Documentation
```markdown
### Unit Tests
**Command:** `pnpm test`
**Scope:** package-wide
**When:** During TDD loops and before task completion
**What it catches:** Logic errors, interface mismatches
**Prerequisites:** None
```

### Good Task Tracking Documentation
```markdown
## Task Tracking
Backlog system: Markdown
Details: `docs/backlog.md`

Rules:
- New non-critical follow-ups go to `## Inbox` after approval unless pre-authorized by the worklog.
- Stable IDs use `TASK-0001`.
- Source backlink is required in both the backlog item and the source artifact.
- `Up next` is human-controlled.
- Critical/current-plan-affecting discoveries require stopping and asking.

Required operations are documented in `docs/backlog.md`: create item, assign ID, reference item, capture source backlink, list Inbox, list Up next, mark Ready, mark Done, mark Canceled, defer/Icebox, mark Blocked, and handle critical items.
```

### Good Requirements Documentation
```markdown
## Requirements
Requirements posture: maintains requirements
Requirements system: Markdown
Details: `docs/requirements.md`

Rules:
- Current durable requirements live in `docs/requirements.md`.
- IDs use `ACT-001`, `UC-001`, `WF-001`, `FR-001`, `NFR-001`, and `OPR-001`.
- Tests cite requirements they verify using `Requirement: FR-001`.
- Draft requirement changes live in brief/approach/plan artifacts until approved.
- Canonical requirement edits require human approval unless explicitly delegated.

Required operations are documented in `docs/requirements.md`: list actors, use cases, workflows, functional requirements, non-functional requirements, and operational requirements; assign/discover IDs; cite requirements; apply approved changes; retire/replace requirements; and validate/query references.
```

### Bad Requirements Documentation
```markdown
Requirements are somewhere in docs.
```

### Bad Task Tracking Documentation
```markdown
Keep track of TODOs somewhere.
```

### Bad Test Documentation
```markdown
Run `npm test` to run tests.
```
