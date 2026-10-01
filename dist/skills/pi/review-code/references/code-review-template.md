# Code Review Template

# Code Review Log

## Open Issues (roll-up — update each pass)

| ID | Severity | Issue | File(s) | Status |
|---|---|---|---|---|
| RN-01 | Critical | <short title> | `<path>` | open |

---

## Review YYYY-MM-DD (Review N)

**Plan:** `<path to plan.md>`
**Diff:** `<git ref range>`
**Mode:** full | delta

### Coverage Matrix Compliance

| Behavior | Primary test | Negative/edge | Status |
|----------|-------------|---------------|--------|
| <behavior> | ✅ `path/test.ts` | ✅ | ✅ covered |
| <behavior> | ⚠️ partial | ❌ missing | ⚠️ partial |

### Prior Findings Resolution (delta mode only)

| ID | Prior status | Current status | Evidence |
|----|-------------|----------------|----------|
| RN-01 | open | ✅ resolved | Fixed in commit abc123 |

### Test Adequacy

- Anti-patterns found: <none | list>
- Per-task verification evidence in worklog:
  - T1: ✅ recorded | ❌ missing
  - T2: ✅ recorded | ❌ missing
  - ...
- TODOs without backlog IDs: <none | list>

### Implementation Findings

#### Blocker
<none>

#### Critical

##### RN-01: <short title>
- **Severity:** Critical
- **File(s):** `<path:line>`
- **Problem:** <what is wrong>
- **Why it matters:** <failure mode>
- **Proposed fix:** <specific actionable fix>
- **Status:** open

#### Major
<repeat finding blocks>

#### Minor
<repeat>

### Suggested Backlog Items

Non-blocking follow-up items discovered during review. These do not block completion unless tied to an open Blocker/Critical/Major finding.

#### <none | Suggested item title>
- **Kind:** bug | feature | chore | docs | hardening | research | debt | idea
- **Origin:** review-finding
- **Suggested priority:** P0 | P1 | P2 | P3
- **Rationale:** <why this should be tracked>
- **Acceptance:** <what would make it done, if obvious>

### Documentation Alignment

| Promised update | Present in diff? | Status |
|----------------|-----------------|--------|
| <doc/readme update from plan> | Yes/No | ✅ / ❌ |
| <AGENTS.md update if patterns changed> | Yes/No | ✅ / ❌ |
| <seed data/fixture doc update> | Yes/No / N/A | ✅ / ❌ / N/A |

### Requirements Alignment

Use when the repo maintains requirements or the plan cites requirement IDs.

- Cited requirements still satisfied: <yes/no/N/A>
- Approved requirement updates applied: <yes/no/N/A>
- Undocumented requirement changes: <none | list>
- Tests/evidence cite requirements where expected: <yes/no/N/A>

### Summary
| ID | Severity | File(s) | Status |
|---|---|---|---|
| RN-01 | Critical | `path/file.ts` | open |

### Review Status
- New significant issues: X
- Suggested backlog items: X
- Total open significant issues: X
- Status: COMPLETE | NEEDS_FIX
