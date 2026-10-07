# Change-oriented approach authoring

Use this contract when authoring, reviewing, or planning from an approach. It
applies to Design and the combined discovery/design paths. It does not change
stage gates, plan levels, requirement authority, or execution policy.

## Canonical package

| Artifact | Role |
| --- | --- |
| `approach.md` | Canonical main change map and consequential decisions |
| `approach_reference.md` (optional) | Canonical detailed engineering contracts when complexity warrants a separate reference |
| `assets/` (as needed) | Linked diagrams, annotated wireframes, and their editable sources |
| `approach.html`, `approach_reference.html` (when a reference exists) | Generated review views of the Markdown and linked assets; never independent authority |
| `approach_review.md` | Review findings, reviewed revision and artifact inventory, rendering/visual evidence |

A small approach can keep its contracts in `approach.md`; two Markdown documents
are not mandatory. For a complex feature, move detailed contracts into the linked
reference so the main document remains a usable review surface. Explicitly link
all meaning-bearing Markdown and assets from the package. Do not make reviewers
discover an unlisted appendix or approve an HTML-only decision.

Approval and review cover the explicitly linked canonical Markdown and
meaning-bearing assets at the reviewed revision, not just the main file. Planning
consumes that same accepted package. Record the exact inventory and revision in
`approach_review.md`: use a commit identifier for committed inputs, or content
digests per input for a working-tree revision. Identify generated outputs and the
inputs/renderer invocation they came from. Keep `state.json` minimal; it is not a
second inventory or approval ledger. Changed canonical inputs require regeneration
and review of the changed package before claiming that the previous approval
covers it. Editorial reorganization is not a new design decision or approval;
check semantic equivalence independently, including links and visual annotations.

Give each detailed constraint one authoritative statement. If a reference exists,
keep the exact invariant, schema rule, or algorithm there and link to its heading
from the main change card. The main document must still expose the consequential
decision, user outcome, tradeoff, and approval status. Do not duplicate the full
contract or bury permission, compatibility, migration, or scope decisions in a
reference. Resolve contradictions instead of choosing whichever copy is convenient.

## Main document: follow the change through the system

Start with an executive overview: problem, recommendation, user outcomes, scope,
and decisions still needed. For a longer document, add a reader map linking to
sections and the reference. Then follow this order:

1. **Change map.** Summarize significant current-to-proposed changes, unchanged
   behavior, and decision status. Use short descriptive change labels to trace
   the same change across layers. These labels are navigation aids, not new
   requirement IDs. Cite actual repository requirement IDs separately, if relevant.
2. **Domain/system model.** Explain concepts, relationships, lifecycle, ownership,
   and boundaries before storage details. Distinguish a conceptual rule change
   from a representation change. Use a simple before/after diagram when useful.
3. **Schema and backend reads/writes.** Show changed fields, constraints, query
   scope, write validation, transaction boundaries, and downstream effects.
   Identify the responsible layer and existing patterns with evidence links.
4. **Product interfaces.** Explain each changed UI, API, CLI, or Pi capability in
   user terms, not merely as a component tree or file inventory.
5. **Cross-cutting concerns and rollout.** Surface changed permissions, safety
   invariants, compatibility, migration/backfill, failure/retry, operations,
   dependencies, verification, and safe deferrals of day-2 needs.
6. **Pending decisions.** Name the owner, options, recommendation, consequence,
   and what the decision blocks. Planning must not silently settle an owner ruling.

For each significant change show current state with evidence, proposed state,
what stays, decision criteria, alternatives, rationale, consequences, and status.
Separate **existing** (observed behavior) from **proposed** (design), and
**confirmed** choices from **owner decision pending**. A recommendation is not a
confirmed choice. Do not put a load-bearing pending decision only at the end:
flag it in the affected change card and roll it up in Pending decisions.

Skip irrelevant layers with a short, reasoned `N/A`; omit unused template
subsections rather than leaving empty boilerplate. There is no fixed word limit,
mandatory second document, or requirement to create visual variants.

### Interface review

For UI changes, pair current/proposed descriptions with annotated low-fidelity
wireframes where they clarify behavior. Identify:

- What the user sees and can do, and who can do it.
- Data shown versus data mutated; the backend read/write each action uses.
- Entry navigation, result navigation, and relevant loading, empty, error,
  permission-denied, stale/conflict, and success states.

Label annotations with the shared change labels. Explain visuals in prose so
meaning is not available only through color or image text. Render and visually
inspect diagrams and wireframes; source syntax alone does not prove readability.
Record what was inspected and any limitations. Do not claim a mockup proves the
implemented UI works.

For CLI/Pi changes, cover selectors, capability deltas, output/error behavior, and
compatibility. Include executable syntax only after checking the installed tool's
help, repository implementation, or version-matched documentation; record the
source/version. Mark conceptual examples as non-executable. Do not guess flags,
slash commands, exit codes, or delegation syntax. Preserve harness-neutral macros
in canonical skills; rendering is not a reason to hardcode one harness upstream.

## Optional engineering reference

Organize `approach_reference.md` by meaningful contracts, with stable headings
linked from the main document. Include only relevant details:

- Exact model/schema constraints, query and mutation contracts, authorization,
  transaction boundaries, ordering, concurrency, idempotency, and failure recovery.
- Enforceable tenets and invariants, existing patterns/prior art with source paths,
  and which implementation details may vary. Record deviations durably; ask for
  owner approval when a consequential decision or invariant would change.
- Migration/backfill and rollback conditions, release sequencing, operational
  limits, observability, and dependency/compatibility contracts.
- Verification boundaries and negative/edge cases, realistic fixtures or harness
  preparation, and change-specific bad-test avoidance. Use the target repository's
  canonical test policy and commands; do not invent commands or require fake
  source-reading tests that merely pin new prose.
- Requirements alignment and draft requirement change proposals where relevant.
  Proposals do not modify canonical requirements without authorized approval.

When no reference is needed, retain the applicable contracts in clearly labeled
engineering sections of the main document. The change map still comes first.
Testing preparation is normal Standard feature work. Do not recommend Epic merely
because fixtures, harnesses, or stronger regression tests are needed. Base an Epic
on independently deliverable product/model workstreams and meaningful sequencing.

## Generated HTML, freshness, and delivery

Use the target repository's chosen repeatable Markdown-to-HTML renderer; record
its version, invocation, inputs, and any local stylesheet/template inputs. Reuse
existing tooling rather than introducing a renderer implementation or dependency
as part of this process contract. If no renderer is available, report that blocker
and obtain a repository choice; do not hand-author a competing HTML design.
The skill renderer that generates `dist/` packages skills, not approach HTML.

Generate HTML from the canonical Markdown and assets. Fix presentation in those
inputs or the chosen presentation configuration, then regenerate; never edit the
HTML authority independently. Regenerate whenever Markdown, assets, or rendering
inputs change. Check freshness against the reviewed revision, not just a timestamp.

Validate links, images, and heading anchors in both Markdown and HTML. Keep local
paths relative and usable from the delivered directory. Ensure cross-document
navigation reaches the intended content in the rendered views; do not blindly
rewrite every `.md` link when its destination has no HTML counterpart. Inspect
wide tables, diagrams, wireframes, and narrow-screen readability in the rendered
view. Record visual inspection separately from mechanical link/freshness checks.

Deliver the HTML with all referenced portable assets and canonical sources. Avoid
machine-local paths, secrets, and external scripts/network dependencies by
default. Prefer static diagrams to runtime script renderers. A generated review
view is not production code and proves no runtime behavior; report verification
limits plainly. Approval remains attached to the canonical package revision.

## Writing and review bar

Follow repository policy first, then the
[Google developer documentation style guide](https://developers.google.com/style).
Use active voice, sentence-case descriptive headings, defined terms, short
paragraphs, and concrete examples before abstract algorithms. Use tables for
comparisons and diagrams for relationships or flows, not dense paragraphs inside
cells. Avoid slash-chained jargon, repeated approval caveats, and audit-ledger
narration in the main design.

Review both readability and semantics: can a human see the consequential changes,
and can a planner find every required contract without inventing decisions?
Trace change labels across model, reads/writes, and interfaces; check brief
alignment, invariants, safe deferrals, contradictions, and pending owner rulings.
Verify the entire package inventory and rendered visual evidence before recording
a clean review. If visual inspection is unavailable, record the blocker rather
than claiming that rendered review passed.

## Worked example: project archive

This is a fictional, illustrative feature, not an accepted requirement or a claim
about any repository. **Archive** and **Hide archived** are change labels, not
requirement IDs. In a real approach, existing behavior must link to findings and
confirmed choices to the owner's decision record.

### Overview and change map

Project owners need to retire finished projects without deleting their history.
Recommend reversible archiving. Deletion and automatic retention are out of scope.

| Change | Existing | Proposed | What stays | Decision status |
| --- | --- | --- | --- | --- |
| Archive | A project remains active until deleted | Owners can archive and restore it | Historical records remain readable to authorized members | Confirmed in this example |
| Hide archived | Lists show all projects a member can access | Default lists hide archived projects | Authorization scope is unchanged | Owner decision pending: default filtering |

### Model, then storage and reads/writes

Model: `active → archived → active` adds a reversible lifecycle state; membership
and record ownership do not change. Storage: add nullable `archived_at` to Project;
`null` represents active. The archive mutation validates owner access and changes
that field in a transaction. List reads retain membership scoping and apply the
proposed active filter; detail reads allow authorized history access. This avoids
creating a second project type, but every default-list caller must be audited.

A complex version would put the exact concurrent-write and authorization contract
once under an Archive mutation heading in `approach_reference.md`; the main card
would link there while retaining the owner-only decision and its consequence.

### Interface: project detail and list

```text
CURRENT — Project detail          PROPOSED — Project detail (owner)
Projects > Apollo                Projects > Apollo
Apollo                           Apollo [Archived]              [1]
[Delete project]                 [Restore project]              [2]

CURRENT — Projects               PROPOSED — Projects
Apollo                           [Include archived: off]        [3]
Beacon                           Beacon
```

1. Archive shows the same project name and history plus an archived badge. A member
   sees the badge but no owner action. Direct links still reach authorized detail.
2. An active project instead shows Archive. Archive/Restore mutates `archived_at`,
   not membership or history. On success stay on detail and update the badge/action;
   on failure keep the prior state and show an error. Disable repeat submission
   while loading; an authorization failure must not imply success.
3. Hide archived changes only the list read filter. An empty active list offers
   Include archived. It does not mutate projects. Returning to the list may hide
   Apollo after archiving if the proposed default is accepted.

CLI/Pi: `N/A` — this illustrative feature has no command interface. No new syntax
or compatibility promise is implied.

### Cross-cutting concerns, rollout, and pending decision

Backfill leaves existing projects active (`archived_at = null`). Deploy compatible
reads before enabling mutations. Verify owner/member authorization, archive/restore,
list filtering, direct history access, and failed writes using realistic fixtures.
Archiving must not become a shortcut around membership checks. Rollback disables
the action without erasing archive data; the exact rollback/read contract belongs
in the reference if needed.

**Owner decision pending — Hide archived:** choose default-hidden versus an
explicit filter only. Recommend default-hidden to reduce clutter, but it changes
list discoverability. The owner must settle it before list behavior and acceptance
tests are planned. The confirmed reversible archive choice does not settle this
separate decision.
