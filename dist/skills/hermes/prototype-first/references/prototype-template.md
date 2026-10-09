# PROTOTYPE — <slug>

**Branch:** `prototype/<slug>` · **Date:** YYYY-MM-DD · **Session:** human-paired prototype-first

## Verdict

<!-- One of: build / build-with-changes / don't build -->
<!-- A "don't build" verdict is a successful session. Say why. -->

**Verdict:** <build | build-with-changes | don't build>

**One-line result:** <what the demo shows>

## What it demonstrates

<!-- The behaviors/scenarios the prototype proves out. Point at what to click/run. -->

- <behavior 1>
- <behavior 2>

## How to run it

```bash
<exact commands>
```

<Screenshots for UI work: attach or link paths.>

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
     lifecycle, scale questions. -->

- <question>
