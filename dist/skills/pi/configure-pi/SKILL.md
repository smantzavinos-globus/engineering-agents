---
name: configure-pi
description: Configure Pi safely for the current repository through `.pi/settings.json`, repository-local Guardrails in `.pi/extensions/guardrails.json`, and session naming in `.pi/session-autoname.json`, including project-specific models, resources, subagent role overrides, and safety policy. Use when a user asks to change Pi behavior for one project or diagnose why a project Pi setting is not taking effect.
compatibility: pi
disable-model-invocation: true
metadata:
  domain: pi
---

## What I do
- Create or update the committed, project-local Pi settings file: `.pi/settings.json`.
- Create or update repository-local Guardrails policy in `.pi/extensions/guardrails.json`, including path access, protected-file policies, and dangerous-command gates.
- Configure the managed `@camillof/pi-session-autoname` extension through `.pi/session-autoname.json` without changing Pi's main settings or silently routing naming to another provider.
- Configure project-specific model defaults, model cycling, resource paths, `subagents.agentOverrides`, and Pi-team Crew lane routing without inventing model IDs or overwriting unrelated settings.
- Diagnose project trust, invalid JSON, precedence, and reload/restart requirements when a project setting appears ignored.
- Explain when a requested behavior belongs to a user-wide extension configuration rather than this project skill's scope.

## When to use me
Use this when a user asks to:
- Make this repository use a different Pi default provider, model, thinking level, UI behavior, resource path, or subagent role model.
- Configure repository-local Guardrails, including outside-workspace path access or dangerous-command policies.
- Override the automatic session naming model for this repository.
- Configure Pi settings that should be committed with this repository.
- Diagnose why `.pi/settings.json`, `.pi/extensions/guardrails.json`, or `.pi/session-autoname.json` is not taking effect in this project.

Do not use this skill to configure every Pi project, edit `~/.pi/agent/`, author an extension, skill, theme, or prompt template. Use the specialized skill or Pi documentation for those surfaces.

## Scope and precedence

This skill changes **only**:

```text
.pi/settings.json
.pi/extensions/guardrails.json
.pi/session-autoname.json
config/pi-team/team-profile.json (when the repository uses Pi-team)
```

Pi loads `~/.pi/agent/settings.json` as the user-wide base and merges `.pi/settings.json` as the current project's override. Guardrails separately loads `~/.pi/agent/extensions/guardrails.json` and merges `.pi/extensions/guardrails.json` as the project override. Nested objects merge, so add only the keys that differ for this repository. Guardrails combines `pathAccess.allowedPaths` and merges named `policies.rules` by ID; other Guardrails arrays, such as permission-gate patterns, replace the inherited array at the higher-priority scope. Do not copy the user's entire global configuration into either project file.

Project-local Pi settings and resources require Pi to trust the project. **Exception:** the globally installed session-autoname extension reads `.pi/session-autoname.json` directly from the workspace; its current published version does not check Pi's project-trust state before applying the override. Inspect this file before running in an unfamiliar repository. In non-interactive runs, use an existing trust decision or the appropriate explicit trust flag for Pi-managed project settings rather than assuming all `.pi/` content was loaded.

## Repository-local session naming

The managed `@camillof/pi-session-autoname` package is separate from Pi's `settings.json`. The user's writable global `<agent-dir>/session-autoname.json` sets the default naming model; this project may override selected keys in `.pi/session-autoname.json` (project values win). The personal Home Manager config seeds `github-copilot/gpt-6-luna` only when the global file does not already exist, so `/autoname model ...` can persist user changes. No naming model is inferred from `enabledModels` or the current conversation model.

```json
{
  "enabled": true,
  "model": "github-copilot/gpt-6-luna",
  "timeoutMs": 30000,
  "debug": false
}
```

Use an authenticated, available `provider/model-id`, verified with `pi --list-models` and `/autoname status`. The configured model is the **only** naming model: if missing, unauthenticated, or failing, the extension leaves the session unnamed rather than falling back to another provider. A repository may intentionally select a different provider, so inspect and approve that provider's data boundary before adding a local override. Do not assume `enabledModels` restricts a model selected by this extension. The extension sends a redacted, bounded excerpt of the first user/assistant exchange to the configured provider, preserves an existing manually set session name, and updates the terminal title on success.

Prefer a narrow project override (for example only `"model"`) instead of copying the global file. Do not commit credentials or private conversation text. Validate with `jq -e . .pi/session-autoname.json`, restart Pi or run `/reload`, and confirm `/autoname status` reports the intended effective model. `/autoname model <provider/model-id> --local` writes this project file; do not use that command without approval when it would route excerpts to another provider.

## Repository-local Guardrails

Guardrails configuration is separate from Pi's main settings. Use `.pi/extensions/guardrails.json` for policy that should travel with this repository; do not put Guardrails keys in `.pi/settings.json`.

The supported top-level areas are:

- `features.policies`, `features.permissionGate`, and `features.pathAccess` — enable or disable checks.
- `pathAccess.mode` — `allow`, `ask`, or `block` for paths outside the current working directory.
- `pathAccess.allowedPaths` — explicit `{ "kind": "file"|"directory", "path": "..." }` entries. Do not use the legacy string/trailing-slash form.
- `policies.rules` — protected file patterns with `none`, `readOnly`, or `noAccess` protection.
- `permissionGate.patterns` — dangerous command patterns that require confirmation.
- `permissionGate.autoDenyPatterns` — command patterns that are blocked without confirmation.
- `permissionGate.allowedPatterns` — command patterns exempted from the permission gate.

Minimal example enabling interactive outside-workspace checks:

```json
{
  "features": {
    "pathAccess": true
  },
  "pathAccess": {
    "mode": "ask",
    "allowedPaths": [
      { "kind": "file", "path": "/dev/null" },
      { "kind": "directory", "path": "/path/to/shared-tooling" }
    ]
  }
}
```

Use `ask` unless the repository has a deliberate strict policy. `block` rejects outside-workspace access, while `allow` disables path-access prompts. Pi documentation and loaded skill paths receive dynamic grants from current Guardrails versions; do not broadly allow `~/.pi/agent` just to make those resources work.

For a force-push-only command policy, leave ordinary pushes out of the pattern lists and use a regex in both `patterns` and `autoDenyPatterns`:

```json
{
  "permissionGate": {
    "patterns": [
      {
        "pattern": "git push (?:\\+[^\\s]+|.*(?:-f\\b|--force(?!-with-lease)|--force-with-lease|\\s\\+[^\\s]+))",
        "regex": true,
        "description": "Git force push (flags or +refspec)"
      }
    ],
    "autoDenyPatterns": [
      {
        "pattern": "git push (?:\\+[^\\s]+|.*(?:-f\\b|--force(?!-with-lease)|--force-with-lease|\\s\\+[^\\s]+))",
        "regex": true,
        "description": "Git force push (flags or +refspec)"
      }
    ]
  }
}
```

When overriding `permissionGate.patterns`, `permissionGate.allowedPatterns`, or `permissionGate.autoDenyPatterns`, include the complete intended list because those arrays replace the inherited list. After editing repository-local Guardrails, validate it with `jq -e . .pi/extensions/guardrails.json` and restart Pi. Guardrails may add a `$schema` field when the settings UI saves the file.

## What I need before editing
- The project behavior that should differ from the user's normal Pi defaults.
- The current `.pi/settings.json`, if it exists.
- The current `.pi/extensions/guardrails.json`, if it exists, when changing repository safety policy.
- The current `.pi/session-autoname.json`, if it exists, and the effective global model when changing project session naming.
- The requested Guardrails feature mode, path grants, protected-file rules, or command policy.
- Available model IDs when changing model routing. Inspect the current Pi model list or existing valid configuration; never invent a provider/model ID.
- Any error message or evidence that the setting is being ignored.

Ask a clarifying question if the desired project behavior is not clear. Do not turn a project-local request into a global configuration change.

## Supported project settings

Use `.pi/settings.json` for settings such as:

- `defaultProvider`, `defaultModel`, `defaultThinkingLevel`, and `enabledModels`.
- `thinkingBudgets`, display settings, compaction, retry, and session settings when they must differ for this repository.
- Project-local `extensions`, `skills`, `prompts`, and `themes` paths.
- `subagents.agentOverrides` for repository-specific subagent model, thinking, tool, fallback-chain, or role behavior.
- `subagents.defaultModel` to give subagents without an explicit model their own default model (separate from the session model).

Example: keep the project's default model and route a reviewer to a verified stronger model:

```json
{
  "defaultProvider": "github-copilot",
  "defaultModel": "github-copilot/gpt-5.6-terra",
  "subagents": {
    "agentOverrides": {
      "code-reviewer": {
        "model": "github-copilot/gpt-5.6-sol",
        "thinking": "medium"
      }
    }
  }
}
```

Use only model IDs available in the current environment. Keep every project configuration secret-free.

### Subagent override precedence

Settings-level `subagents.agentOverrides` fields replace the agent file's frontmatter values (pi-subagents >=0.73; earlier releases skipped frontmatter-declared fields). Project overrides beat user overrides. In engineering-agents-managed deployments, the `agentOverrides` argument of `makePiConfig`/`engineering-agents.pi-for-user.args` patches the shipped agent frontmatter at build time instead.

`fallbackModels` was removed in pi-subagents 0.68: an agent file or override that still sets it fails to load. Configure one model per agent.

`subagents.defaultModel` applies only to agents **without** an explicit model (frontmatter `model:` and any per-agent override win).

### Pi-team Crew lane models

Pi-team model routing is separate from `subagents.agentOverrides`. Configure the five Crew lanes
in the repository's `config/pi-team/team-profile.json`; the installed `pi` wrapper automatically
sets `PI_MESSENGER_TEAM_PROFILE_DIR` to the current repository's `config/pi-team` when the
repository provides `config/pi-team/pi-team.json`. Keep that entry as a relative symlink to the
canonical profile so the profile remains one authored source.

Example profile roles:

```json
{
  "name": "pi-team",
  "roles": {
    "worker-cheap": {
      "model": "github-copilot/gpt-5.6-luna",
      "thinking": "high",
      "skills": ["pi-team-worker"]
    },
    "worker-std": {
      "model": "github-copilot/gpt-5.6-terra",
      "thinking": "medium",
      "skills": ["pi-team-worker"]
    },
    "worker-complex": {
      "model": "github-copilot/gpt-5.6-sol",
      "thinking": "medium",
      "skills": ["pi-team-worker"]
    },
    "worker-visual": {
      "model": "github-copilot/claude-sonnet-5",
      "thinking": "medium",
      "skills": ["pi-team-worker"]
    },
    "worker-visual-complex": {
      "model": "github-copilot/claude-opus-5",
      "thinking": "medium",
      "skills": ["pi-team-worker"]
    }
  }
}
```

The exact role choices are repository policy, not universal defaults. Verify model availability
with `pi --list-models` before committing a profile. Keep rescue and final-review policy in the
Pi-team lead contract; do not silently replace the configured lane model from a worker packet.

## Out-of-scope: subagent runtime limits

`pi-subagents` has extension runtime configuration that is separate from Pi's main settings. In particular, `maxSubagentSpawnsPerSession` does **not** belong in `.pi/settings.json`; putting it there has no effect.

The extension defaults to 40 child spawns per parent session. That count includes single launches, parallel children, chain steps, and bounded dynamic fanout, and it resets only in a new parent session.

Because changing that limit requires a user-wide extension configuration or process environment variable, do not edit it with this skill. Explain the boundary and direct the user to their Pi/global-configuration maintainer if they need a persistent different limit.

For a one-process override, tell the user to start Pi with a finite cap in the environment:

```bash
PI_SUBAGENT_MAX_SPAWNS_PER_SESSION=100 pi
```

This affects only that Pi process and does not modify project files or global configuration. `0` blocks new child launches. A new parent session has a fresh spawn budget.

## Process
1. Confirm that the request is for the current repository and identify the exact project behavior.
2. Inspect `.pi/settings.json`, `.pi/extensions/guardrails.json`, `.pi/session-autoname.json` when present, any relevant project-local resources, and `config/pi-team/team-profile.json` when the repository uses Pi-team.
3. Verify project trust if local settings or resources are not loading.
4. Preserve unrelated configuration and make the smallest valid JSON change.
5. Validate each changed JSON file with `jq -e .`.
6. Restart Pi after startup-loaded setting changes. `/reload` is appropriate for reloadable resources, but a restart is the reliable default for settings changes.
7. Report the modified file and changed keys, and state any required Pi restart or Home Manager activation.

## Examples
- “Make this repo use a different default Pi model.” → inspect `.pi/settings.json` and available models, then add the minimal project override.
- “Use stronger reviewers but keep workers cheap in this repo.” → update only `subagents.agentOverrides` in `.pi/settings.json` with verified model IDs; if Pi-team is also enabled, update its five lane models in `config/pi-team/team-profile.json`.
- “Use Luna for cheap work, Terra for standard work, Sol for complex work, Sonnet 5 for visual work, and Opus 5 for complex visual work.” → update the repository's Pi-team profile with those verified IDs and thinking levels; do not change unrelated subagent overrides.
- “Name sessions in this repo with a different model.” → inspect `.pi/session-autoname.json`, verify the target model and provider, then add only the approved `model` override; no fallback or implicit provider switch.
- “Configure outside-workspace access for this repository.” → update `.pi/extensions/guardrails.json` with `features.pathAccess`, an explicit `pathAccess.mode`, and narrow object-form `allowedPaths` entries.
- “Allow normal pushes but deny force pushes.” → keep ordinary pushes out of the Guardrails patterns and add a force-push regex to both `permissionGate.patterns` and `permissionGate.autoDenyPatterns`.
- “My project settings do nothing.” → verify project trust, configuration path, JSON validity, precedence, and whether a restart is required.
- “Raise the subagent cap above 40.” → explain that the cap is user-wide extension runtime configuration and is outside this project-scoped skill.

## Non-goals
- I will not edit `~/.pi/agent/settings.json`, `~/.pi/agent/extensions/`, or any other user-wide Pi configuration.
- I will not place extension runtime keys such as `maxSubagentSpawnsPerSession` in `.pi/settings.json`.
- I will not edit Nix/Home Manager-managed global configuration.
- I will not overwrite unrelated project settings, invent provider/model IDs, or commit credentials.
