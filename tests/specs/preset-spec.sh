#!/usr/bin/env bash
# Verify preset.jsonc structure: has discovery, design, execute modes
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

require_commands node jq >/dev/null

REPO_ROOT="$(repo_root)"
PASS=0 FAIL=0

pass() { PASS=$((PASS + 1)); printf '  PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL: %s\n' "$1" >&2; }

# Parse JSONC by stripping comments and trailing commas
PRESET_JSON=$(node -e "
  const raw = require('fs').readFileSync('$REPO_ROOT/agents/preset.jsonc', 'utf8');
  const cleaned = raw.replace(/\/\/.*$/gm, '').replace(/,\s*([}\]])/g, '\$1');
  console.log(cleaned);
")

# ============================================================
printf 'Preset configuration verification\n'
printf '=================================\n\n'

# Verify all three modes exist
for mode in discovery design execute; do
  if echo "$PRESET_JSON" | jq -e --arg mode "$mode" '.presets[$mode]' >/dev/null 2>&1; then
    pass "Preset mode '${mode}' exists"
  else
    fail "Preset mode '${mode}' missing"
  fi
done

# Verify each mode has essential fields
for mode in discovery design execute; do
  if echo "$PRESET_JSON" | jq -e --arg mode "$mode" '.presets[$mode].model // .presets[$mode].systemPrompt' >/dev/null 2>&1; then
    pass "Mode '${mode}' has model or systemPrompt"
  else
    fail "Mode '${mode}' missing model and systemPrompt"
  fi
done

# Verify agent definition files exist (agents are separate .md files)
for agent in planner plan-reviewer code-reviewer worker worker-high worker-low ui-worker researcher vision oracle; do
  if [[ -f "$REPO_ROOT/agents/${agent}.md" ]]; then
    pass "Agent '${agent}' definition file exists"
  else
    fail "Agent '${agent}' definition file missing"
  fi
done

# Every skill a preset tells the model to read must actually be installed for Pi.
# The execute preset previously pointed at execution-orchestrator, which had been
# removed from the Pi tree; nothing caught it because no spec checked the link.
REFERENCED_SKILLS="$(printf '%s' "$PRESET_JSON" \
  | jq -r '.presets[].instructions // ""' \
  | grep -o '~/\.pi/agent/skills/[A-Za-z0-9._-]*' \
  | sed 's|.*/||' | sort -u)"
if [[ -z "$REFERENCED_SKILLS" ]]; then
  fail "no preset references a skill path; the check would be vacuous"
else
  for skill in $REFERENCED_SKILLS; do
    if [[ -f "$REPO_ROOT/dist/skills/pi/${skill}/SKILL.md" ]]; then
      pass "preset-referenced skill '${skill}' is installed for Pi"
    else
      fail "preset references skill '${skill}' which is not in the Pi tree"
    fi
  done
fi

# ============================================================
printf '\n'
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
