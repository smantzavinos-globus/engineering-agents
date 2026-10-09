---
name: prototype-first
description: Build-to-learn entry path — when requirements are discovery-shaped, run a human-paired throwaway prototype session BEFORE the brief, then feed the result (branch + PROTOTYPE.md) into the normal pipeline as primary evidence. Use instead of starting at discovery when the fastest way to specify the work is to see it working.
compatibility: opencode
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
  dirty version", "I want to feel the final thing working".

Do NOT choose it when the question is feasibility (spike), when the
change is obvious (discover-and-design-simple), or when requirements are
already concrete (discover-and-design).

## Session contract

- **Human-paired.** This is the one entry skill that is explicitly the
  human's session — a 1:1 build-together in pi or an equivalent live
  harness. It is never dispatched unattended; the feedback loop IS the
  method.
- **Timebox:** one session, hard cap of one day. If it needs more, the
  scope of the prototype is wrong — cut it down.
- **Safety:** no real secrets, no customer data, nothing deployed, no
  irreversible actions. The prototype runs locally on fake or fixture data.
- **No TDD in the prototype.** Tests are deliberately skipped here; TDD
  applies in full to the real build (see Hard rules).
- Hacks are expected: hardcoded values, missing error handling, fake
  latency, whatever gets to the demo fastest. That is the point. Do not
  "clean up as you go" — that converts throwaway code into unreviewed
  production code, the worst of both worlds.

## Branch contract

- The prototype is committed on `prototype/<slug>`, branched off the
  default branch. A prototype that only exists in a session dies with
  the session; commit it.
- The prototype branch **never merges** to the default branch.
- Disposal paths (decided at approach review, see below):
  - **wipe-and-rebuild (default):** the real work branches off the
    default branch, so the eventual PR diff carries zero prototype
    churn. The prototype branch survives as reference until the real PR
    merges, then is deleted.
  - **refine-in-place (exception):** the real work branches
    `feat/<slug>` off `prototype/<slug>`. Only when the architecture is
    sound and the shortcuts are localized and enumerable.

## Session exit artifacts (mandatory, every session)

The session is not done until BOTH exist:

1. **A runnable demo.** Someone who wasn't in the session can run or
   click it. Screenshots for UI work.
2. **`PROTOTYPE.md`** at the repo root (or the agreed plan directory),
   from [references/prototype-template.md](references/prototype-template.md):
   what it demonstrates, what is faked, known shortcuts, and the verdict
   — **build / build-with-changes / don't build**.

A prototype that kills the idea is a successful session. It still ends
with the artifacts; the verdict is the decision record.

## Handoff to the pipeline

1. Copy `PROTOTYPE.md` into the plan directory as
   `findings/prototype.md`.
2. Enter the pipeline at Brief (`discovery` — or `discover-and-design`
   when the prototype demo already settled the discussion). The brief
   records `Path: prototype-first`.
3. The prototype is *primary evidence, not a spec*: it shows what was
   thought to build, and silently ignores everything that wasn't. The
   brief's overlooked-needs scan pays extra attention to error paths,
   failure modes, and lifecycle the prototype never exercised.
4. Approach (`design`) records the disposal decision — wipe-and-rebuild
   by default; refine-in-place only with justification — and the branch
   topology that follows from it.
5. All tests in the real build are authored fresh, informed by the demo.
   The normal contract-TDD flow applies unchanged.

## Hard rules

- **No test authored in the prototype session may be carried forward as
  a contract.** Prototype tests encode the prototype's accidents. E2E
  and acceptance tests for the real build are written fresh in the real
  branch, against the behavior the demo showed.
- The prototype branch never merges to the default branch.
- Nothing in the prototype session deploys, spends, or touches
  production. (The usual human gates for those actions still apply and
  are not waived by this skill.)
- Skipping the exit artifacts skips the handoff — a prototype without
  `PROTOTYPE.md` is chat context, and chat context is not a brief.
