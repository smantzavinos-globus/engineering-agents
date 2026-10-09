# PROTOTYPE — <slug>

**Branch:** `prototype/<slug>` · **Item:** <#N or tracker ID> · **Date:** YYYY-MM-DD · **Session:** human-paired prototype-first

## Verdict

<!-- One of: build / build-with-changes / don't build -->
<!-- A "don't build" verdict is a successful session. Say why. -->
<!-- build-with-changes: list each required difference below; each becomes a
     success criterion alongside the scenarios. -->

**Verdict:** <build | build-with-changes | don't build>

**One-line result:** <what the demo shows>

**Required differences from the prototype (build-with-changes only):**

- <what the real build must do differently from what was prototyped>

## What was prototyped

<!-- The changes made in this session, one entry per distinct change — there
     is usually more than one. This is the primary record of intent: the code
     shows WHAT was done (hackily); this says what it was FOR, so the real
     build reproduces the goal, not the hack. Describe each change as a
     product/user-facing change, then point at where it lives. -->

### C1 — <short name of the change>

- **Objective:** <what this change is meant to achieve, in user terms>
- **Before:** <how it worked before the prototype>
- **After (as accepted):** <how it works in the prototype>
- **Where:** <files/components touched on the prototype branch>
- **Scenarios:** <acceptance scenario numbers that demonstrate it>

### C2 — ...

## Acceptance scenarios

<!-- The definition of done for behavior. Numbered, observable, written as
     the human accepted them (not as first attempted). Each one becomes a
     brief success criterion and at least one fresh e2e/acceptance test in
     the real build. Name where it applies ("on every page", "for all item
     kinds") — the prototype may have only done one. -->

<!-- Every change above is covered by at least one scenario. -->

1. **<short name>** (C<n>) — Given <state>, when <action>, then <visible result>.
   Applies to: <scope>. Prototype coverage: <full | partial: what was skipped>.
2. ...

## How to run it

```bash
<exact commands>
```

Evidence: <paths under prototype-evidence/ — screenshots for UI work>

## What is faked / hardcoded

<!-- Everything a reader must not trust as real. Be exhaustive — this list is
     what keeps the prototype from being mistaken for a starting implementation. -->

- <fake data, stubbed service, hardcoded value, missing auth, ...>

## Known shortcuts

<!-- Structural compromises: no error handling, single-user assumptions, sync where
     the real build needs async, schema shortcuts, ... These drive the disposal decision. -->

- <shortcut>

## Disposal recommendation

<!-- wipe-and-rebuild (default) or refine-in-place — with the reason.
     Refine-in-place is justified ONLY when the architecture is sound and the
     shortcuts above are localized and enumerable. -->

**Recommendation:** <wipe-and-rebuild | refine-in-place>

**Why:** <rationale>

## Open questions for the brief

<!-- Things the demo surfaced but did not settle: overlooked needs, error paths,
     lifecycle, scale questions. Mark any the human considers a design decision
     they want to approve as **[owner]**. -->

- <question>
