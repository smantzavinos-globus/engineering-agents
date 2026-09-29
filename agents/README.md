# Agent & Preset Configuration

This directory contains the Pi agent definitions and preset configurations that implement the three-mode development process.

## Setup

### Presets (Pi preset extension)

The three workflow modes are configured as **presets**. Placed at `~/.pi/agent/preset.jsonc` (handled by Nix).

Presets control your current session's model, tools, and behavior:
- **discovery** — Socratic challenge mode for clarifying intent
- **design** — Collaborative research and approach development
- **execute** — Autonomous orchestration that delegates to sub-agents

### Agents (Pi subagents extension)

Sub-agents are called by the presets to do the actual work. Placed at `~/.pi/agent/agents/` (handled by Nix).

## Agent Set

| Agent | Model Tier | Role |
|-------|-----------|------|
| `planner` | Frontier (reasoning) | Create detailed plans from brief + approach |
| `plan-reviewer` | Frontier (reasoning) | Review approaches, epic decompositions, and plans for logic, completeness, consistency |
| `code-reviewer` | Frontier (code) | Review code diffs against plan requirements |
| `worker-high` | Execution (high tier) | Plan tasks with `Execution tier: high` (non-UI) |
| `worker-low` | Execution (low tier) | Plan tasks with `Execution tier: low` (mechanical, non-UI) |
| `worker` | Execution | Worklog creation, codebase research, general fixes |
| `ui-worker` | Execution (UI) | Frontend/UI implementation |
| `researcher` | Execution | Web/external documentation research |
| `vision` | Visual | Screenshot/mockup/visual analysis |
| `oracle` | Frontier (highest) | Read-only second opinion |

## Files

### Presets
- `preset.jsonc` — Three mode definitions (discovery, design, execute)

### Agents
- `planner.md` — Plan creation (Frontier reasoning)
- `plan-reviewer.md` — Plan quality review (Frontier reasoning)
- `code-reviewer.md` — Code quality review (Frontier code)
- `worker-high.md` — High-tier task implementation
- `worker-low.md` — Low-tier task implementation
- `worker.md` — Worklog, research, general fixes (Execution)
- `ui-worker.md` — Frontend/UI implementation (Execution UI)
- `researcher.md` — Web/external research (Execution)
- `vision.md` — Visual analysis (Visual/multimodal)
- `oracle.md` — Read-only second opinion (Frontier highest)

## Usage

### Start a Discovery session
```
/preset discovery
```
Then talk through your idea. Challenges assumptions, surfaces tradeoffs.

### Start a Design session
```
/preset design
```
Reads the brief, delegates research, presents options, writes approach.md, and for epics also writes `epic.md` (workstreams + child plans).

### Start Execution
```
/preset execute
```
Then:
- standard: "Execute the plan at plans/2026_05_01_my_feature/. Auto-continue."
- epic: "Execute the epic at plans/2026_05_01_my_epic/." (the orchestrator should select or propose the next child plan from `epic.md`)

## Per-Repo Model Overrides

Repos should override models or thinking levels in `.pi/settings.json` using `subagents.agentOverrides` rather than copying agent files into `.pi/agents/`. That keeps the canonical checked-in agent prompts centralized while still allowing repo-local tuning. See the orchestration doc's "Per-Repository Model Configuration" section for details.
