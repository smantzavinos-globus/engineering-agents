# Plan: Hermes skill rendering + cross-agent skill sync + process entry skill

**Status:** draft — awaiting Spiros review
**Created:** 2026-09-30
**Origin:** 2026-09-30 process-failure audit (agent wrote plan.md skipping
brief/approach; root cause = no canonical process-skill surface on Hermes
agents) + Spiros rulings in-thread.

## Decisions already ruled

| Decision | Ruling |
| --- | --- |
| Render Hermes skills like pi/OpenCode? | **YES — render.** Single folder (`dist/skills/hermes/`) is the sync source; no hand-maintained list (list = the drift failure mode we are eliminating). |
| Sync skill for Hermes agents? | **YES** — one standard sync procedure + judgment calls, used by all agents. |
| Top-level software-development entry skill? | **YES** — upstream, harness-neutral; owns the stage-gate table; consistent trigger phrase. |
| `lls-implementation-epics` (Hermes monolith)? | **Replace** with canonical stage skills + entry skill + slim LLS overlay. |

## Checklist

### A. engineering-agents (upstream changes)

- [ ] **A1. Renderer: Hermes harness target.** Add `harnesses/hermes.json`
  (role→mechanism bindings: delegation macros → Hermes `delegate_task`;
  notes resolved) + renderer support so `node tools/render-skills.mjs
  --write` emits `dist/skills/hermes/`. Update `docs/skill-rendering.md`.
  Renderer tests extended per repo conventions.
- [ ] **A2. NEW canonical skill `skills/software-development/`** — the
  top-level entry. Contents: the STAGE-GATE TABLE (normative: which
  artifacts must exist before each stage starts — brief.md gates research;
  approach.md gates planning; plan review + human approval gate execution);
  how the stage skills chain; the agent's role at each human gate; autonomy
  defaults; the trigger phrase (`follow the dev process`) in the
  description so fresh sessions load it. Owns NO stage content — routes.
- [ ] **A3. NEW canonical skill `skills/skill-sync/`** — the sync
  procedure: record upstream SHA, diff installed vs `dist/skills/hermes/`,
  per-file disposition rules (`take-upstream` / `keep-local` (repo-local
  change, recorded) / `propose-upstream` (worth an upstream PR)),
  report format, bootstrap note (first sync happens by hand-copy per the
  procedure — chicken-and-egg acknowledged).
- [ ] **A4. Sync tool `tools/sync-skills.mjs`** — standard, upstream: given
  the installed-skills dir + repo, emits the sync report (unchanged /
  upstream-new / locally-modified / locally-only + suggested disposition).
  Hash-diff only; dispositions are the agent's judgment, surfaced not made.
- [ ] **A5. Propose-upstream intake** — agents batch `propose-upstream`
  candidates as PRs to this repo; Spiros reviews. (First batch already
  identified — see B4.)
- [ ] **A6. Autonomy defaults encoded in A2** — proposed (NEEDS CONFIRM):
  auto WITHIN an approved plan; human gates at (a) plan approval,
  (b) contract freezes, (c) owner-ruling classes (irreversible/external
  contact/spend), (d) PR merge (agents never merge).

### B. Hermes agents (all LLS agents)

- [ ] **B1. Bootstrap install:** hand-copy `dist/skills/hermes/` at a
  PINNED upstream SHA into each agent's skill store; record the SHA.
- [ ] **B2. Ongoing:** run `tools/sync-skills.mjs` per `skill-sync`
  procedure on a cadence (per-session check is cheap; full review weekly).
- [ ] **B3. Decompose `lls-implementation-epics`:** DELETE the monolith;
  create `lls-dev-overlay` with ONLY the LLS-specific content: epic
  artifact layout (EPIC_STATUS.md, state.json, child numbering), IMP
  register convention (IMP-NNN as DoD tracker + the TASK-XXXX mapping),
  freeze-checkpoint machinery (cumulative manifests, SHA recording),
  owner-ruling conventions (RD-N delegated rulings, STOP-AND-ASK fences,
  option-bearing decision format), infra execution lessons (compose/
  capstone gates, podman deviations, Clerk dev instance, CI-greenness,
  parent-gate driver reuse, nix-container pitfalls).
- [ ] **B4. Propose-upstream batch #1** (agent-general lessons currently
  trapped in the monolith — belong in `execute-task`/`pull-request`
  upstream): commit-before-dispatching-reviewers; byte-verify claimed fixes
  before dispositions; externally verify child side-effect claims;
  stacked-PR + squash-merge mechanics; same-turn execution/authorization
  discipline.
- [ ] **B5. Regression test for the original failure:** fresh-session check
  — "follow the dev process" loads the entry skill → agent locates its
  stage (new work → discovery; existing epic → review-epic/execute; review
  → review-*) → stage gates enforced before plan.md.
- [ ] **B6. Apply to all agents** (dean first as pilot; propagate the
  pinned-SHA + overlay pattern to other Hermes agents).

### C. Redo the interrupted work (process-correct)

- [ ] **C1. Deployment planning REDONE through the restored pipeline:**
  brief.md → approach.md → approach review (2-3 pi reviewers) → child
  plans re-cut from the reviewed approach (draft `plan.md` at
  `agent-runtime/docs/engineering/plans/20260930_aws_serverless_deployment/`
  is salvage: its decisions table → approach.md; its T0-T14 graph →
  re-cut into ~5 children). DOGFOODS the restored process — first real use.

## Order & dependencies

A1 → (A2, A3) → render → A4 → B1 → (B2..B6 parallel) → C1.
A1–A5 land as PRs to this repo (Spiros reviews). B-side lands per agent.
C1 blocked until B5 passes (the point of the exercise).

## Open rulings

1. Autonomy defaults (A6) — confirm the four human gates.
2. Trigger phrase — `follow the dev process` (or Spiros picks).
3. ID mapping — upstream TASK-XXXX vs LLS IMP-NNN: overlay records the
   mapping (IMP is the LLS DoD tracker; upstream IDs used in upstream-only
   work). Confirm.
4. Configure-* skills (configure-pi/opencode): not rendered for Hermes
   (harness-specific) — confirm exclusion in `harnesses/hermes.json`.
