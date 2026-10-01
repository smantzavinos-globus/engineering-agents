# Approach Template

**Created:** YYYY-MM-DD
**Plan:** ./brief.md
**Based on:** ./findings/

## Solution Model

### Components
- **ComponentA** — responsibility
- **ComponentB** — responsibility

### How They Fit Together
<Description of the interaction model between components>

## Key Decisions

| Decision | Options Considered | Chosen | Rationale | Consequences | Revisit If |
|----------|-------------------|--------|-----------|--------------|------------|
| <decision> | A, B, C | B | <why> | <tradeoffs accepted> | <conditions that would change this> |

## What Changes vs What Stays
- **Changes:** <what will be modified or added>
- **Stays:** <what must NOT change — explicit non-regressions>

## Requirements Alignment

If the repo maintains requirements, cite relevant IDs and explain alignment.

| Requirement | How the approach satisfies or changes it |
|-------------|------------------------------------------|
| <FR-001, NFR-001, or OPR-001> | <alignment> |

## Requirement Change Proposal

Draft proposed durable requirement changes here. These are not canonical until approved and applied during execution.

### Add
- <none | proposed new requirement text with suggested ID>

### Update
- <none | existing requirement ID and proposed wording change>

### Remove
- <none | existing requirement ID and rationale>

## Boundary Definitions
- <Component X only does Y; it never does Z>
- <Module A does not import from Module B>

## Design Tenets
Non-negotiable principles that must hold even if implementation details change:
- <e.g., "read-only scanner — never mutates source">
- <e.g., "deterministic output — same input always produces same output">
- <e.g., "contract boundary is versioned JSON">

## Invariants & Safety Properties
Conditions that must remain true throughout and after implementation:
- <e.g., "all API responses include a correlation ID">
- <e.g., "no user data is logged at INFO level">

## Deviation Protocol
If reality forces a change from this approach during implementation:
- **Preserve:** <tenets and invariants that must not change>
- **Can change safely:** <implementation details that may vary>
- **Record:** deviations in plan.md → Implementation Notes → Deviations

## Testing Philosophy

### What good tests look like for this change
- <e.g., "tests assert on behavior output, not internal state">
- <e.g., "each test exercises one scenario end-to-end through the service layer">

### Bad-test avoidance
What would count as insufficient or brittle testing:
- <e.g., "source-reading tests that pass even if runtime behavior breaks">
- <e.g., "export-exists tests without behavioral proof">
- <e.g., "tests only covering happy path when the regression risk is in error handling">

## Patterns to Follow
- <Follow existing pattern in `src/path/` for X>
- <Use the same approach as `src/other/` for Y>

## Risks and Mitigations
| Risk | Impact | Mitigation |
|------|--------|-----------|
| <risk> | <what happens if it materializes> | <how to prevent or handle> |

## Open Questions (to resolve during planning)
- <Any remaining questions that detailed planning will answer>
