# Standard Test Levels

This document defines the standard test level categories that the engineering plan process assumes. Repositories map their specific commands, tools, and configurations to these standard levels.

Skills reference these levels by their standard names. Repo documentation maps the standard names to actual commands.

---

## The Standard Levels

| Level | Purpose | Typical Scope | When to Run | What Skills Call It |
|-------|---------|---------------|-------------|---------------------|
| **Fast feedback** | Rapid iteration on current behavior during TDD | touched-files | During TDD Red→Green loops | "fast feedback command" |
| **Type check** | Cross-module type safety, interface compliance | package-wide | After any code change | "typecheck" |
| **Lint** | Code style, formatting, static analysis | package-wide or touched-files | Before task completion | "lint" |
| **Unit tests** | Module-level behavior proof, isolated logic | touched-files or package-wide | During TDD + task completion | "unit tests" |
| **Integration tests** | Cross-module or cross-service behavior | package-wide | When integration points change | "integration tests" |
| **E2E tests** | User-facing behavior through real interfaces | repo-wide | When UI/API/workflow behavior changes | "E2E tests" |
| **Build** | Compilation, bundling, artifact generation succeeds | repo-wide | Before plan completion | "build" |
| **Full verification** | All of the above pass together | repo-wide | Before declaring plan complete | "final gate" |

---

## How Skills Use These Levels

### In plans and worklogs

Skills map these standard levels to three timing categories:

| Timing | Which levels typically apply | Purpose |
|--------|----------------------------|---------|
| **During TDD loops** | Fast feedback, unit tests (scoped) | Rapid iteration — run after every change |
| **Before task completion** | Type check, lint, unit tests (full), integration tests | Task gate — proves the task doesn't break anything beyond its scope |
| **Before plan completion** | Build, E2E, full verification | Final gate — proves the whole repo is healthy |

### In coverage matrices

The coverage matrix maps behaviors to test levels:

| Behavior | Primary test level | Secondary test level |
|----------|-------------------|---------------------|
| "User can create a notification" | Unit (service layer) | E2E (UI flow) |
| "WebSocket reconnects on drop" | Integration (WebSocket + service) | — |

---

## What Repos Must Document

For each standard level that applies to the repo, document:

```markdown
### <Level Name>

**Command:** `<exact command to run>`
**Scope:** touched-files | package-wide | repo-wide
**When to run:** <during TDD loops | before task completion | before plan completion>
**What it catches:** <specific failure modes>
**Prerequisites:** <services, env vars, setup needed>
**Typical duration:** <seconds | minutes>
```

### Example (TypeScript monorepo)

```markdown
### Fast Feedback
**Command:** `pnpm vitest run --filter=<test-file>`
**Scope:** touched-files
**When to run:** During TDD loops
**What it catches:** Logic errors in the current module
**Prerequisites:** None
**Typical duration:** 1-5 seconds

### Type Check
**Command:** `pnpm typecheck`
**Scope:** package-wide
**When to run:** After any code change, before task completion
**What it catches:** Type mismatches, missing exports, interface drift between modules
**Prerequisites:** None
**Typical duration:** 10-30 seconds

### Unit Tests
**Command:** `pnpm test`
**Scope:** package-wide
**When to run:** Before task completion
**What it catches:** Behavioral regressions across the package
**Prerequisites:** None
**Typical duration:** 10-60 seconds

### Integration Tests
**Command:** `pnpm test:integration`
**Scope:** package-wide
**When to run:** When integration points change
**What it catches:** Cross-service contract violations, API mismatches
**Prerequisites:** Docker services running (`docker compose up -d`)
**Typical duration:** 1-5 minutes

### E2E Tests
**Command:** `pnpm test:e2e`
**Scope:** repo-wide
**When to run:** When user-facing behavior changes
**What it catches:** Full user workflow regressions
**Prerequisites:** Dev server running, database seeded
**Typical duration:** 2-10 minutes

### Build
**Command:** `pnpm build`
**Scope:** repo-wide
**When to run:** Before plan completion
**What it catches:** Compilation errors, bundling issues, missing assets
**Prerequisites:** None
**Typical duration:** 30-120 seconds

### Full Verification
**Command:** `pnpm verify` (runs typecheck + lint + test + build)
**Scope:** repo-wide
**When to run:** Before declaring plan complete
**What it catches:** Everything above, combined
**Prerequisites:** All services running
**Typical duration:** 3-15 minutes
```

---

## Levels Not Every Repo Has

Not every repo has all levels. Common variations:

| Repo type | Likely levels |
|-----------|--------------|
| Small library | Fast feedback, unit tests, type check, build |
| Backend service | Fast feedback, unit, integration, type check, build, lint |
| Full-stack app | All levels |
| CLI tool | Fast feedback, unit, integration (golden tests), build |
| Infrastructure/config | Lint, build, integration (deploy check) |

The key requirement: **every repo must have at least a fast feedback command, a task completion gate, and a final gate.** These three are the minimum for the TDD workflow to function.

---

## Mapping to Plan/Worklog Terminology

| Plan/Worklog term | Maps to |
|-------------------|---------|
| "Fast feedback command" | The fastest test you can run during TDD (usually scoped unit tests) |
| "Task completion gate" | The command that proves your task didn't break anything (usually typecheck + lint + full unit tests) |
| "Final gate" | The command that proves the whole repo is healthy (usually full verification or build + all tests) |

Repos with only one test command use it for all three. Repos with many commands assign them to the appropriate timing.
