---
name: prototype-first
description: Build-to-learn entry path — when requirements are discovery-shaped, run a human-paired throwaway prototype session BEFORE the brief, then hand off (pushed branch + PROTOTYPE.md + linked issue) so the pipeline can take the prototype to a clean PR. Use instead of starting at discovery when the fastest way to specify the work is to see it working.
compatibility: hermes
---

# Prototype-First Entry

An ENTRY path into the standard pipeline, chosen like a plan level: by
signal plus the human's call. It answers "is this the right thing to
build?" by building a quick, throwaway version of it — then hands the
result to the normal process. The pipeline is never skipped; it starts
better-informed.

A prototype is the most honest requirements document that exists. It is
also the least trustworthy *implementation* — it hides error paths, and
its structure encodes haste. This skill exists to capture the first
property while containing the second.

**The prototype is the definition of done for behavior.** Every behavior
the accepted demo shows becomes an acceptance criterion of the real build.
The real build adds what the prototype ignored (error paths, lifecycle,
safety); it never drops or reinterprets demonstrated behavior without the
human's say-so.

Contrast with feasibility spikes: a spike answers "can this work?"
(feasibility, verdict, throwaway). A prototype-first session answers
"is this what we want?" (specification by demonstration). When the open
question is feasibility, spike instead.

## When to choose this path

Signals (any of these, plus the human agrees):

- The work is a user-facing surface where "correct" is a property you can
  only recognize by seeing it — UI, workflow, output shape, interaction feel.
- Requirements conversations keep circling because nobody can articulate
  the target without pointing at something.
- The human says variants of: "let me just see it", "build a quick and
  dirty version", "proof of concept", "I want to feel the final thing
  working".

Do NOT choose it when the question is feasibility (spike), when the
change is obvious (discover-and-design-simple), or when requirements are
already concrete (discover-and-design).

## Intake

The session starts from either:

- **An existing backlog item** (e.g. a GitHub issue): read it and its
  comments; the item is the prototype's starting intent. Record its ID.
- **Conversation only**: no item yet. One is created at exit (below) so
  the handoff always has a tracker anchor. Do not create it up front — a
  `don't build` verdict may make it moot, and the verdict belongs in it.

Restate the target in two or three bullets of *visible behavior* ("tests
appear as rows in the trace table on every page"; "any row expands to show
its content") and confirm them before building. These bullets seed the
acceptance scenarios.

## Session contract

- **Human-paired.** This is the one entry skill that is explicitly the
  human's session — a 1:1 build-together in pi or an equivalent live
  harness. It is never dispatched unattended; the feedback loop IS the
  method.
- **Speed is the only objective.** Get the demonstrated behavior working
  as fast as possible. No tests, no full correctness, no refactoring of
  surrounding code, no abstractions "for later". Prefer the smallest edit
  in the place the behavior shows up.
- **Timebox:** one session, hard cap of one day. If it needs more, the
  scope of the prototype is wrong — cut it down.
- **Safety:** no real secrets, no customer data, nothing deployed, no
  irreversible actions. The prototype runs locally on fake or fixture data.
- **No TDD in the prototype.** Tests are deliberately skipped here; TDD
  applies in full to the real build (see Hard rules).
- Hacks are expected: hardcoded values, missing error handling, fake
  latency, whatever gets to the demo fastest. Do not "clean up as you go"
  — that converts throwaway code into unreviewed production code, the
  worst of both worlds. Instead, **note each hack as you make it**; the
  list becomes PROTOTYPE.md's "faked" and "shortcuts" sections.
- When the human reacts to the demo ("no, put it inside the table"),
  update both the code and the acceptance-scenario bullets. The final
  bullets describe the accepted behavior, not the first attempt.

## Branch contract

- The prototype is committed on `prototype/<slug>`, branched off the
  default branch, and **pushed** (`git push -u origin prototype/<slug>`).
  Another machine or agent picks it up from the remote; a prototype that
  only exists locally dies with the session.
- The prototype branch **never merges** to the default branch.
- Disposal paths (decided at approach, see below):
  - **wipe-and-rebuild (default):** the real work branches off the
    default branch, so the eventual PR diff carries zero prototype
    churn. The prototype branch survives as reference until the real PR
    merges, then is deleted with the owner's OK.
  - **refine-in-place (exception):** the real work branches
    `feat/<slug>` off `prototype/<slug>`. Only when the architecture is
    sound and the shortcuts are localized and enumerable.

## Session exit (mandatory, every session)

The session is not done until ALL of these exist:

1. **A runnable demo.** Someone who wasn't in the session can run or
   click it from the pushed branch. Screenshots for UI work, committed
   under `prototype-evidence/` on the prototype branch.
2. **`PROTOTYPE.md`** at the repo root of the prototype branch, from
   [references/prototype-template.md](references/prototype-template.md):
   verdict (**build / build-with-changes / don't build**), numbered
   acceptance scenarios, how to run it, what is faked, known shortcuts,
   disposal recommendation, open questions, and the backlog item ID.
3. **The pushed branch.**
4. **A linked backlog item** (via the `backlog` skill's tracker
   operations; on GitHub, an issue):
   - Existing item: post the handoff comment (below) on it.
   - No item: the human's choice to run this session pre-authorizes
     capture — create one titled after the feature, body = the verdict,
     the acceptance scenarios, and a `Source: prototype/<slug>` backlink;
     then write its ID into PROTOTYPE.md and push again.
   - Set fields: `Track: standard-implementation`. Ask the human for
     `Autonomy` — `auto` means "take it to a PR without a Design or Plan
     gate unless a stop trigger fires" (see the `software-development`
     skill, Prototype handoff). Leave status for the human to move to
     `Up next`, unless they say "go" in-session.

Handoff comment (one comment, so a fresh session finds everything):

```
**Prototype handoff** — verdict: <build | build-with-changes | don't build>

- Branch: `prototype/<slug>` @ <sha7>
- Spec: `PROTOTYPE.md` on that branch (<N> acceptance scenarios)
- Run: <one-line command>
- Disposal recommendation: <wipe-and-rebuild | refine-in-place> — <why>

<!-- prototype branch=prototype/<slug> head=<full sha> -->
```

A `don't build` verdict is a successful session: still write the
artifacts, post the comment, and close the item as not planned with the
verdict as the reason. Delete nothing — the branch is the record.

## Handoff to the pipeline

What happens next is in the `software-development` skill (Prototype
handoff) and, for dispatched items, `work-item`. In short:

1. `PROTOTYPE.md` is copied into the plan directory as
   `findings/prototype.md`; the brief records `Path: prototype-first` and
   turns every acceptance scenario into a success criterion.
2. The brief's overlooked-needs scan pays extra attention to error paths,
   failure modes, and lifecycle the prototype never exercised.
3. Approach records the disposal decision and branch topology.
4. All tests in the real build are authored fresh, informed by the demo.
   Each acceptance scenario gets at least one end-to-end or acceptance
   test. The normal contract-TDD flow applies unchanged.
5. The PR demonstrates parity: each scenario, its test, and (for UI)
   before/after or prototype-vs-real screenshots.

## Hard rules

- **No test authored in the prototype session may be carried forward as
  a contract.** Prototype tests encode the prototype's accidents. E2E
  and acceptance tests for the real build are written fresh in the real
  branch, against the behavior the demo showed.
- The prototype branch never merges to the default branch.
- Nothing in the prototype session deploys, spends, or touches
  production. (The usual human gates for those actions still apply and
  are not waived by this skill.)
- Skipping the exit artifacts skips the handoff — a prototype without a
  pushed branch, `PROTOTYPE.md`, and a linked item is chat context, and
  chat context is not a brief.
