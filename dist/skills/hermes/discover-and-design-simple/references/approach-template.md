# Approach template

Read [Change-oriented approach authoring](design-approach-authoring.md) before
using this scaffold. Adapt it to the change: omit unused subsections, state a
reasoned `N/A` for irrelevant layers, and leave no empty placeholders in the
finished artifact. A separate reference is optional, not a second required doc.

## Main document: `approach.md`

```markdown
# Approach: <change>

**Created:** YYYY-MM-DD
**Brief:** [Brief](brief.md)
**Evidence:** [Current state](findings/current_state.md)

## Overview
<Problem, recommendation, user outcomes, scope/non-goals, pending decisions.>
<Reader map and explicit links to reference/meaning-bearing assets, if present.>

## Change map
| Change label | Current → proposed | What stays | Decision status |
| --- | --- | --- | --- |
| <descriptive label, not a requirement ID> | <delta> | <non-regression> | <confirmed or owner decision pending> |

## Domain and system model
<Concepts, relationships, lifecycle and ownership before storage details.>
<Current evidence, proposed boundaries; before/after diagram if useful.>

## Schema and backend reads/writes
<Trace the same change labels into fields, constraints, scoped reads, validated
writes, transaction boundaries and downstream effects. Link exact contracts.>

## Product interfaces
<For each changed interface: current/proposed capabilities and unchanged behavior.>
<UI: annotated low-fidelity wireframes, see/do, shown/mutated data, navigation,
permissions and relevant states. CLI/Pi: verified syntax source, selectors,
output/error deltas and compatibility, or conceptual non-executable examples.>

## Cross-cutting concerns and rollout
<Consequential permissions, invariants, compatibility, migration/backfill,
failure/retry, operations, dependencies, rollout/rollback and verification.>
<Included day-2 needs and safe deferrals. Link detailed contracts if separated.>
<Relevant repository requirement IDs and alignment; draft change proposals only
when needed, clearly not canonical until authorized.>

## Pending decisions
| Change label | Owner | Options and recommendation | Consequence / blocks |
| --- | --- | --- | --- |
| <label also flagged in affected section> | <owner> | <choice> | <impact> |

## Engineering contracts
<When there is no separate reference: applicable detailed contracts go here,
with descriptive headings, not a duplicate of the main change narrative.>
```

In the relevant change cards, include decision criteria, alternatives, rationale,
consequences, and revisit conditions. Keep existing/proposed behavior distinct
from confirmed/pending decision status. Do not reduce the approach to a file list.

## Optional document: `approach_reference.md`

Use for contracts that would overwhelm the main review narrative. Link each
contract heading from its consequential decision in `approach.md` and include
this reference in the reviewed package inventory.

```markdown
# Engineering reference: <change>

**Main approach:** [Change map](approach.md#change-map)

## <Descriptive contract heading>
<Exact model/schema, read/write, authorization, transaction, concurrency,
ordering, idempotency and error rules relevant to this change.>

## Safety and deviations
<Enforceable tenets/invariants; implementation details that may vary; approval
and durable recording required when consequential decisions must change.>

## Migration and operations
<Backfill, rollout/rollback conditions, operational limits and observability.>

## Verification boundaries
<Test layers, realistic fixtures/harness preparation, negative/edge cases,
change-specific bad-test avoidance, and canonical verification command sources.>

## Patterns and risks
<Evidenced prior art/source paths, specific risks and actionable mitigations.>
```

Rename or omit these reference headings as appropriate. Give detailed constraints
one authoritative home; link rather than repeat them. Generate HTML views from
the Markdown and assets following the shared contract; do not author independent
HTML decisions. The review record carries revision, artifact inventory, generation
and visual inspection evidence, not `state.json`.
