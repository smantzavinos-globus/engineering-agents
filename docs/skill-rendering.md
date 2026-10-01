# Skill Rendering

This repository keeps **one canonical, harness-neutral source** for each skill and **generates** the final skill files for every supported harness (Pi, OpenCode, and Hermes). This removes the drift that came from hand-maintaining a separate adapted copy of each skill per harness.

## Why

Skills define reusable process. The *process* is identical across harnesses, but the *implementation details* differ:

- Delegation syntax: Pi uses `subagent({ agent, task, skill })`; OpenCode uses the `task` tool.
- Delegation target: a role may map to a named subagent on one harness and a task **category** on another.
- Skill-file paths and a few harness-specific UI phrases (e.g. "press Tab" vs. "start a Design session").
- Frontmatter `compatibility`.

Hand-maintaining a copy per harness let these drift apart in prose and even semantics. The render pipeline makes the shared content the single source of truth and confines harness differences to declarative profiles.

## Components

| Path | Role |
|------|------|
| `skills/<name>/SKILL.md` | Canonical, harness-neutral skill template (the single source you edit) |
| `harnesses/<id>.json` | Per-harness profile: `compatibility`, `skillPathPrefix`, role→implementation map, and `notes` |
| `skill-resources.json` | Canonical source→installed target mappings for shared framework resources |
| `tools/render-skills.mjs` | Deterministic renderer: canonical skills × harness profiles + shared resources → `dist/` |
| `dist/skills/<id>/<name>/` | Generated per-harness skill trees (committed, drift-tested, never hand-edited) |

The Nix modules link the generated trees: Pi from `dist/skills/pi/*`, OpenCode from `dist/skills/opencode/*`. Hermes agents are NOT nix-linked: they sync `dist/skills/hermes/*` into their own skill stores via the `skill-sync` skill (Hermes agents self-update their skills), so no Nix wiring is needed for Hermes.

## Canonical skill format

Canonical `SKILL.md` files are normal Markdown with YAML frontmatter, plus two rules:

1. **Do not include a `compatibility:` line.** The renderer injects the correct value per harness.
2. Use macros for anything harness-specific.

### Shared framework resources

Use `skill-resources.json` when multiple installed skills need the same framework-owned file.
Each entry maps a canonical repository `source` to a path inside the rendered skill tree. The
renderer materializes the file for every harness that receives that skill and rejects unknown
skills, missing or unsafe sources, duplicate targets, and collisions with local skill files.

Keep target-repository inputs out of this manifest. For example, the dynamic workflow packages
its execution reference and runtime modules, while each target repository still owns its testing
strategy and verification commands.

### Macros

**Delegation block** — expands to a harness-specific delegation call:

```
{{delegate:planReview skill=review-plan}}
Review the plan at [plan directory path]/plan.md for execution readiness.
{{/delegate}}
```

- `planReview` is a semantic **role**, mapped per harness in the profile.
- `skill=` is optional (omit it for roles like `fix` that load no skill).
- The text between the tags is the delegation prompt.

**Note** — expands to a harness-specific string:

```
- For standard work: "{{note:design-execute-standard}}"
```

### Optional frontmatter: `harnesses`

A skill may restrict itself to specific harnesses:

```yaml
harnesses: [opencode]
```

Absent ⇒ the skill renders for every harness. OpenCode-only skills include
`configure-opencode` and the team planning/execution skills.

## Harness profiles

Each `harnesses/<id>.json` declares:

- `compatibility` — value stamped into rendered frontmatter (`pi`, `opencode`, or `hermes`).
- `skillPathPrefix` — where skills live on that harness (used when a named-subagent delegation embeds a "read your skill file at …" instruction).
- `delegationStyle` — `pi-subagent`, `opencode-task`, or `hermes-delegate`
  (Hermes renders `delegate_task(tasks=[{goal: "Role: <role>. <prompt> Load
  and follow your skill '<skill>' (via skill_view)..."}])`; roles are prose
  lines — Hermes has no named subagent roster — and Hermes agents pick up
  skills by syncing `dist/skills/hermes/` into their own skill stores; see
  the `skill-sync` skill).
- `roles` — maps each role to an implementation: a named subagent (`{ "kind": "agent", "agent": "worker" }`), a task category (`{ "kind": "category", "category": "ultrabrain" }`), or a built-in subagent type (`{ "kind": "subagent_type", "subagent_type": "explore" }`).
- `notes` — harness-specific strings for `{{note:KEY}}`.

### Role → implementation mapping

| Role | Pi | OpenCode |
|------|----|----------|
| `planner` | `planner` subagent | `category="ultrabrain"` |
| `worklog`, `executeTask`, `fix` | `worker` subagent | `category="unspecified-high"` |
| `research` | `worker` subagent | `subagent_type="explore"` |
| `researchExternal` | `researcher` subagent | `subagent_type="librarian"` |
| `planReview`, `approachReview`, `epicReview` | `plan-reviewer` subagent | `category="ultrabrain"` |
| `codeReview` | `code-reviewer` subagent | `category="ultrabrain"` |
| `oracle` | `oracle` subagent | `category="ultrabrain"` |

**Pi** keeps the full named-subagent roster (`planner`, `worker`, `ui-worker`, `researcher`, `plan-reviewer`, `code-reviewer`, `oracle`).

**OpenCode** ships only the three primary mode agents (`discovery`, `design`, `execute`) and delegates every engineering sub-role through the `task` tool:
- Reasoning-heavy roles (planning, all reviews, oracle) → `category="ultrabrain"`.
- Implementation roles (worklog, task execution, fixes) → `category="unspecified-high"`. UI tasks use `category="visual-engineering"` (routed by the `ui-implementation-target` note, not a separate role).
- Research roles → the built-in `explore` (codebase) and `librarian` (external/docs) subagent types, which are purpose-built for those jobs.

> **Plan-agent visibility note:** OpenCode's native `plan` agent stays primary only when its OpenCode-native override keeps `mode: "primary"`. Under oh-my-openagent, overriding `agent.plan` without an explicit mode can cause the runtime loader to treat it as a subagent even if `sisyphus_agent.replace_plan = false`. Keep this in mind for generated config and repo-local `.opencode/opencode.jsonc` overrides.

> **Model-tier note:** OpenCode implementation roles use `category="unspecified-high"` (glm-5.2 by default). To increase quality for heavier tasks, point `executeTask` at `deep` or `ultrabrain` in `harnesses/opencode.json`, or retune the category model in `nix/modules/opencode/config.nix`.

### Team member routing

OpenCode team mode accepts category-backed members and eligible direct subagent types.

- Category members run through the Sisyphus-Junior runtime; the category still controls
  model, variant, temperature, and fallbacks.
- Eligible direct team types are `sisyphus`, `atlas`, `sisyphus-junior`, and `hephaestus`.
- Oracle, Prometheus, and other unlisted types remain external consultations.

| Role | Routing | Default model |
|---|---|---|
| mechanical implementer | `unspecified-low` | `zai-coding-plan/glm-5.2` |
| standard implementer / contract verifier / live reviewer | `unspecified-high` | `zai-coding-plan/glm-5.2`, GPT-5.5 fallback |
| UI implementer | `visual-engineering` | `zai-coding-plan/glm-5.2`, GPT-5.5 fallback |
| planned complex implementation | `deep` | `openai/gpt-5.5` xhigh |
| Strong rescue implementer | direct `hephaestus` | `openai/gpt-5.5` xhigh |
| fresh final reviewer | external `deep` (escalate to `ultrabrain`) | `openai/gpt-5.5` xhigh |

## Renderer commands

```bash
# Regenerate dist/ from canonical sources + harness profiles
node tools/render-skills.mjs --write

# Verify dist/ matches a fresh render (no writes); non-zero exit on drift
node tools/render-skills.mjs --check
```

The renderer fails hard on an unknown role, an unknown note, or any unexpanded `{{…}}` macro.

## Drift gate

`tests/specs/skill-render-spec.sh` (part of `./tests/run-tests.sh fast`) runs `--check`, asserts each harness tree uses the correct delegation syntax, asserts the review roles render as category delegation in OpenCode, and confirms `configure-opencode` stays OpenCode-only. If `dist/` is stale the suite fails with the fix command.

## How to add or change a skill

1. Edit (or create) `skills/<name>/SKILL.md` as harness-neutral content. Use `{{delegate:…}}` / `{{note:…}}` for any harness-specific delegation or phrasing. Do not add `compatibility:`.
2. If a delegation introduces a new role, add it to `harnesses/pi.json` and `harnesses/opencode.json`. If it needs a new note, add it to both profiles' `notes`.
3. If the skill is harness-specific, add `harnesses: [..]` to its frontmatter.
4. If it needs a shared framework-owned file, add a source→target mapping in
   `skill-resources.json`; do not hand-copy a second canonical source into the skill.
5. Run `node tools/render-skills.mjs --write` and commit the updated `dist/`.
6. If the skill is newly installed for a harness, add it to the appropriate Nix list (`nix/modules/pi/default.nix` and/or `openCodeSkills` in `nix/modules/opencode/config.nix`).
7. Run `./tests/run-tests.sh fast` (and `all` when a Nix host is available).

Never hand-edit anything under `dist/` — it is generated.
