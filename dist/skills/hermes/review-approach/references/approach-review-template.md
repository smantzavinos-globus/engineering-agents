# Approach Review Template

## Open Issues (roll-up — update each pass)

| ID | Severity | Issue | Section | Status |
|---|---|---|---|---|
| RN-01 | Critical | <short title> | <section> | open |

---

## Review YYYY-MM-DD (Review N)

**Approach:** `<path to approach.md>`
**Reviewed revision:** <commit ID, or per-input content digests for working-tree inputs>
**Brief alignment:** Yes | No

### Reviewed package and evidence
| Artifact | Role (canonical Markdown / meaning-bearing asset / generated view) | Revision or digest |
| --- | --- | --- |
| <exact relative path; enumerate all package inputs and generated outputs> | <role> | <revision> |

- Generation: <renderer/version, exact invocation, inputs and presentation configuration>
- Freshness: <evidence that generated views match the reviewed inputs>
- Navigation: <Markdown/HTML links, images, heading anchors and portable assets checked>
- Visual inspection: <rendered views/diagrams/wireframes and widths inspected, result, or blocker>
- Semantic equivalence: <evidence for editorial moves between main/reference, or N/A>
- Readability: <consequential decisions visible in main; detailed contracts discoverable>
- Pending owner rulings: <owner/options/what is blocked, or none>

### Brief Alignment Check
| Brief Goal/Constraint | Addressed in Approach? | How |
|----------------------|----------------------|-----|
| <goal from brief> | Yes/No | <which section/component> |

### Component & Boundary Assessment
- All components identified: Yes | No (missing: <list>)
- Interactions defined: Yes | No
- Boundaries clear to an implementer: Yes | No

### Decision Quality
- All approach-level decisions made: Yes | No (deferred: <list>)
- Options and rationale documented: Yes | No

### Design Tenets & Invariants
- Tenets enforceable (not aspirational): Yes | No
- Invariants verifiable (testable): Yes | No
- Deviation protocol actionable: Yes | No

### Testing Philosophy
- Bad-test avoidance specific to this change: Yes | No
- Testing boundaries clear: Yes | No

### Issues

#### Blocker
<none>

#### Critical

##### RN-01: <short title>
- **Severity:** Critical
- **Section:** <which part of approach.md>
- **Problem:** <what is wrong>
- **Why it matters:** <what goes wrong downstream>
- **Fix:** <what was done or proposed>
- **Status:** applied | open

#### Major
<repeat>

#### Minor
<repeat>

### Changes Applied to Approach
- <bullet list of what was updated>

### Review Status
- Significant issues found: X
- Status: COMPLETE | NEEDS_ANOTHER_PASS
