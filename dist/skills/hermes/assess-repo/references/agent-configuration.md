# Agent Configuration Per Repository

This document defines how to configure agent models for a specific repository using `.pi/settings.json` → `subagents.agentOverrides`.

## Why Per-Repo Configuration

Default agent definitions use general-purpose models. Repos benefit from overriding models when:
- The repo is primarily frontend (use UI-specialized models for workers)
- Cost constraints require cheaper models for implementation
- A specific provider works better for the repo's language/framework
- The team has preferences based on experience

## How It Works

Agent overrides live in `.pi/settings.json` at the project root under `subagents.agentOverrides`. They modify specific fields of your user-level agents **without copying the full agent file**. This means:

- Agent system prompts, skills, and tools stay centralized in `~/.pi/agent/agents/`
- Updates to agent definitions automatically apply to all repos
- Repos only override what's different (typically just `model` and `thinking`)

## Configuration

### `.pi/settings.json` — Project-level overrides

```json
{
  "subagents": {
    "agentOverrides": {
      "worker": {
        "model": "anthropic/claude-sonnet-4",
        "thinking": "high"
      },
      "ui-worker": {
        "model": "anthropic/claude-sonnet-4",
        "thinking": "high"
      },
      "code-reviewer": {
        "model": "anthropic/claude-opus-4",
        "thinking": "high"
      }
    }
  }
}
```

### Supported override fields

| Field | What it does |
|-------|-------------|
| `model` | Override the model for this agent |
| `thinking` | Override thinking level |
| `skills` | Override injected skills |
| `tools` | Override tool allowlist |
| `systemPrompt` | Replace the system prompt entirely (avoid — use only if necessary) |
| `systemPromptMode` | `replace` or `append` |
| `inheritProjectContext` | Whether agent sees AGENTS.md/CLAUDE.md |
| `inheritSkills` | Whether agent sees the skills catalog |
| `disabled` | Set `true` to hide an agent from this project |

### Priority

Project overrides (`.pi/settings.json`) beat user overrides (`~/.pi/agent/settings.json`).

Override fields replace the agent file's frontmatter values.

`fallbackModels` is unsupported: an agent file or override that sets it fails to load. Configure one model per agent.

## Standard Agent Set

| Agent | Role | Default Model Tier | Override when... |
|-------|------|-------------------|-----------------|
| `planner` | Create detailed implementation plans | Frontier (reasoning) | Different frontier model preferred |
| `plan-reviewer` | Review plans + approaches | Frontier (reasoning) | Different review model preferred |
| `code-reviewer` | Review code diffs against plan | Frontier (code) | Code-specialized model preferred |
| `worker-high` | High-tier task implementation (Implementer, high) | Execution (high) | Set to the repo's high-tier model |
| `worker-low` | Low-tier task implementation (Implementer, low) | Execution (low) | Set to the repo's low-tier (cheaper) model |
| `worker` | Worklog, codebase research, general fixes | Execution | Language-specialized or cheaper model needed |
| `ui-worker` | Frontend/UI implementation | Execution (UI) | Different UI-strong model needed |
| `researcher` | Web/docs research | Execution | Rarely needs override |
| `vision` | Visual analysis | Visual | Rarely needs override |
| `oracle` | Second opinion / architecture | Frontier (highest) | Maximum quality reasoning needed |

## Common Configurations

### Budget-conscious
```json
{
  "subagents": {
    "agentOverrides": {
      "worker": { "model": "fireworks/accounts/fireworks/models/deepseek-v4-pro" },
      "ui-worker": { "model": "fireworks/accounts/fireworks/models/deepseek-v4-pro" },
      "planner": { "model": "openai-codex/gpt-5.4", "thinking": "high" },
      "plan-reviewer": { "model": "openai-codex/gpt-5.4", "thinking": "high" },
      "code-reviewer": { "model": "openai-codex/gpt-5.4", "thinking": "high" }
    }
  }
}
```

### Quality-maximized
```json
{
  "subagents": {
    "agentOverrides": {
      "worker": { "model": "anthropic/claude-sonnet-4", "thinking": "high" },
      "ui-worker": { "model": "anthropic/claude-sonnet-4", "thinking": "high" },
      "planner": { "model": "anthropic/claude-opus-4", "thinking": "high" },
      "plan-reviewer": { "model": "anthropic/claude-opus-4", "thinking": "high" },
      "code-reviewer": { "model": "anthropic/claude-opus-4", "thinking": "high" }
    }
  }
}
```

### Frontend-focused repo
```json
{
  "subagents": {
    "agentOverrides": {
      "ui-worker": { "model": "anthropic/claude-sonnet-4", "thinking": "high" },
      "code-reviewer": { "model": "anthropic/claude-opus-4", "thinking": "high" }
    }
  }
}
```

### Python/ML repo
```json
{
  "subagents": {
    "agentOverrides": {
      "worker": { "model": "openai-codex/gpt-5.4", "thinking": "high" },
      "planner": { "model": "openai-codex/gpt-5.5", "thinking": "high" }
    }
  }
}
```

## Key Advantages of This Approach

1. **Automatic updates** — When you update agent definitions (system prompts, skills, tools) in `~/.pi/agent/agents/`, all repos automatically get the new behavior. No per-repo sync needed.
2. **Minimal configuration** — Repos only specify what's different (usually just model choices).
3. **No drift** — There's no copy of the agent prompt to go stale.
4. **Easy to audit** — One small JSON block shows exactly what's customized per repo.

## What Goes in `.pi/settings.json` vs `~/.pi/agent/settings.json`

| Location | Use for |
|----------|---------|
| `~/.pi/agent/settings.json` | Global defaults: `disableBuiltins`, default model preferences |
| `.pi/settings.json` (project) | Per-repo `subagents.agentOverrides`, disable unused agents for this repo |

## Disabling Agents Per-Repo

If a repo doesn't need certain agents (e.g., no frontend = no `ui-worker`):

```json
{
  "subagents": {
    "agentOverrides": {
      "ui-worker": { "disabled": true },
      "vision": { "disabled": true }
    }
  }
}
```
