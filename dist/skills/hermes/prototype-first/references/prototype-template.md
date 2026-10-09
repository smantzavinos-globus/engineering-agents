# PROTOTYPE — <slug>

**Branch:** `prototype/<slug>` · **Item:** <#N or tracker ID> · **Date:** YYYY-MM-DD · **Session:** human-paired prototype-first

## Verdict

<!-- One of: build / build-with-changes / don't build -->
<!-- A "don't build" verdict is a successful session. Say why. -->
<!-- build-with-changes: list each change; each becomes a success criterion
     alongside the scenarios below. -->

**Verdict:** <build | build-with-changes | don't build>

**One-line result:** <what the demo shows>

**Changes required (build-with-changes only):**

- <change>

## Acceptance scenarios

<!-- The definition of done for behavior. Numbered, observable, written as
     the human accepted them (not as first attempted). Each one becomes a
     brief success criterion and at least one fresh e2e/acceptance test in
     the real build. Name where it applies ("on every page", "for all item
     kinds") — the prototype may have only done one. -->

1. **<short name>** — Given <state>, when <action>, then <visible result>.
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
