#!/usr/bin/env bash
# Verify repo structure: required files exist, valid SKILL.md frontmatter, etc.
# Requirement: FR-007
# Requirement: FR-008
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(repo_root)"
PASS=0 FAIL=0

pass() { PASS=$((PASS + 1)); printf '  PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL: %s\n' "$1" >&2; }

assert_file_exists() {
  local path="$1" desc="$2"
  if [[ -f "$path" ]]; then pass "$desc"; else fail "$desc (missing: $path)"; fi
}

assert_dir_exists() {
  local path="$1" desc="$2"
  if [[ -d "$path" ]]; then pass "$desc"; else fail "$desc (missing: $path)"; fi
}

assert_file_contains() {
  local path="$1" needle="$2" desc="$3"
  if [[ ! -f "$path" ]]; then fail "$desc (file missing: $path)"; return; fi
  if grep -Fq "$needle" "$path"; then pass "$desc"; else fail "$desc (missing: $needle in $path)"; fi
}

assert_skill_frontmatter() {
  local path="$1" desc="$2"
  if [[ ! -f "$path" ]]; then fail "$desc (missing: $path)"; return; fi
  # SKILL.md must start with --- and have a name field
  if head -1 "$path" | grep -q '^---' && grep -q '^name:' "$path"; then
    pass "$desc"
  else
    fail "$desc (invalid frontmatter in $path)"
  fi
}

assert_agent_frontmatter() {
  local path="$1" desc="$2"
  if [[ ! -f "$path" ]]; then fail "$desc (missing: $path)"; return; fi
  # Agent .md files must have frontmatter with name and description
  if head -1 "$path" | grep -q '^---' && grep -q '^name:' "$path" && grep -q '^description:' "$path"; then
    pass "$desc"
  else
    fail "$desc (missing frontmatter in $path)"
  fi
}

# ============================================================
printf 'Repo structure verification\n'
printf '============================\n\n'

# Core files
assert_file_exists "$REPO_ROOT/README.md" "Root README exists"
assert_file_exists "$REPO_ROOT/flake.nix" "Flake exists"
assert_file_exists "$REPO_ROOT/.gitignore" ".gitignore exists"
assert_file_exists "$REPO_ROOT/templates/default/flake.nix" "Template flake exists"

# Documentation
for doc in process orchestration plan-levels plan-directory-structure repo-setup agent_architecture_and_workflow extension-spec; do
  assert_file_exists "$REPO_ROOT/docs/${doc}.md" "Doc: ${doc}.md exists"
done
assert_dir_exists "$REPO_ROOT/docs/references" "docs/references/ exists"
assert_file_exists "$REPO_ROOT/docs/references/requirements.md" "references/requirements.md exists"
assert_file_exists "$REPO_ROOT/docs/references/standard-test-levels.md" "references/standard-test-levels.md exists"
assert_file_exists "$REPO_ROOT/docs/references/task-tracking.md" "references/task-tracking.md exists"
assert_file_exists "$REPO_ROOT/docs/references/delivery-pipeline.md" "references/delivery-pipeline.md exists"

# Skills (19 total)
SKILLS=(
  discovery design research
  create-plan review-plan
  create-worklog
  execute-task execution-orchestrator
  review-code review-approach review-epic
  assess-repo create-skills pull-request
  configure-opencode
)
for skill in "${SKILLS[@]}"; do
  assert_file_exists "$REPO_ROOT/skills/${skill}/SKILL.md" "Skill: ${skill}/SKILL.md exists"
  assert_skill_frontmatter "$REPO_ROOT/skills/${skill}/SKILL.md" "Skill: ${skill} has valid frontmatter"
done

# Agents (8 + preset)
AGENTS=(planner plan-reviewer code-reviewer worker worker-high worker-low ui-worker researcher vision oracle)
for agent in "${AGENTS[@]}"; do
  assert_file_exists "$REPO_ROOT/agents/${agent}.md" "Agent: ${agent}.md exists"
  assert_agent_frontmatter "$REPO_ROOT/agents/${agent}.md" "Agent: ${agent} has valid frontmatter"
done
assert_file_exists "$REPO_ROOT/agents/preset.jsonc" "agents/preset.jsonc exists"
assert_file_exists "$REPO_ROOT/agents/README.md" "agents/README.md exists"

# Nix modules
assert_file_exists "$REPO_ROOT/nix/modules/pi/default.nix" "Pi module exists"
assert_file_exists "$REPO_ROOT/nix/modules/opencode/default.nix" "OpenCode module exists"
assert_file_exists "$REPO_ROOT/nix/modules/pi/compile-managed-packages.mjs" "Compile helper exists"
assert_file_exists "$REPO_ROOT/nix/modules/pi/guardrails.json" "Guardrails config exists"
assert_file_exists "$REPO_ROOT/scripts/check-updates.sh" "check-updates.sh exists"

# Key content checks
assert_file_contains "$REPO_ROOT/README.md" "engineering-agents" "README mentions engineering-agents"
assert_file_contains "$REPO_ROOT/README.md" "homeManagerModules" "README documents homeManagerModules"
assert_file_contains "$REPO_ROOT/flake.nix" "homeManagerModules" "Flake exposes homeManagerModules"
assert_file_contains "$REPO_ROOT/flake.nix" "llmAgents" "Flake references llmAgents input"
assert_file_contains "$REPO_ROOT/flake.nix" "opencode" "Flake references OpenCode module"
assert_file_contains "$REPO_ROOT/docs/process.md" "Opportunistic Parallel Dispatch" "Process documents opportunistic parallel dispatch (ADR 0006)"

# ============================================================
printf '\n'
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
