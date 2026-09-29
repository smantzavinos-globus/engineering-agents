#!/usr/bin/env bash
# Verify Pi module content: keybindings, models, MCP, skills, agents all declared
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

require_commands nix jq >/dev/null

REPO_ROOT="$(repo_root)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0 FAIL=0

pass() { PASS=$((PASS + 1)); printf '  PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL: %s\n' "$1" >&2; }

# Extract the Pi module's home.file entries by evaluating with a mock config
# We check the source files exist rather than trying to instantiate the module
# (which would require llmAgents input resolution).

# ============================================================
printf 'Pi module content verification\n'
printf '==============================\n\n'

# Verify guardrails.json is valid JSON
if jq -e '.' "$REPO_ROOT/nix/modules/pi/guardrails.json" >/dev/null 2>&1; then
  pass "guardrails.json is valid JSON"
else
  fail "guardrails.json is not valid JSON"
fi

if jq -e '
  .features.pathAccess == true
  and .pathAccess.mode == "ask"
  and any(.pathAccess.allowedPaths[]; .kind == "file" and .path == "/dev/null")
  and any(.permissionGate.patterns[]; .regex == true and (.pattern | test("git push")))
  and any(.permissionGate.autoDenyPatterns[]; .regex == true and (.pattern | test("git push")))
  and all(.permissionGate.patterns[]; .pattern != "git push")
  and all(.permissionGate.autoDenyPatterns[]; .pattern != "git push")
' "$REPO_ROOT/nix/modules/pi/guardrails.json" >/dev/null 2>&1; then
  pass "guardrails enables ask-mode path access and auto-denies force pushes only"
else
  fail "guardrails policy must enable ask-mode path access and deny force pushes without blocking normal pushes"
fi

if GUARDRAILS_CONFIG="$REPO_ROOT/nix/modules/pi/guardrails.json" node <<'NODE'
const fs = require("fs");
const config = JSON.parse(fs.readFileSync(process.env.GUARDRAILS_CONFIG, "utf8"));
const entry = config.permissionGate.autoDenyPatterns.find((pattern) => pattern.regex);
if (!entry) process.exit(1);
const matcher = new RegExp(entry.pattern);
const cases = [
  [["git", "push", "origin", "main"], false],
  [["git", "push", "origin", "main", "--force"], true],
  [["git", "push", "-f", "origin", "main"], true],
  [["git", "push", "origin", "main", "--force-with-lease"], true],
  [["git", "push", "+main:main"], true],
  [["git", "push", "origin", "+main:main"], true],
];
for (const [parts, expected] of cases) {
  const actual = matcher.test(parts.join(" "));
  if (actual !== expected) {
    throw new Error(`${parts.join(" ")}: expected ${expected}, got ${actual}`);
  }
}
NODE
then
  pass "force-push matcher covers flags and +refspec syntax without blocking normal pushes"
else
  fail "force-push matcher does not distinguish normal pushes from force-push syntax"
fi

# Verify compile-managed-packages.mjs is valid JS (syntax check)
if node --check "$REPO_ROOT/nix/modules/pi/compile-managed-packages.mjs" 2>/dev/null; then
  pass "compile-managed-packages.mjs has valid syntax"
else
  fail "compile-managed-packages.mjs has syntax errors"
fi

PI_MODULE="$REPO_ROOT/nix/modules/pi/default.nix"
PI_CONFIG="$REPO_ROOT/nix/modules/pi/config.nix"
# Team mode was replaced by code-mode execution. pi-messenger, the pi-team
# profile, and the pi-team PATH command must stay removed.
if ! grep -Fq 'pi-messenger' "$PI_CONFIG" &&
   ! grep -Fq 'messenger/team-profiles' "$PI_CONFIG" &&
   ! grep -Fq 'messenger/team-profiles' "$PI_MODULE"; then
  pass "Pi module declares no pi-messenger or pi-team profile wiring"
else
  fail "Pi module declares no pi-messenger or pi-team profile wiring"
fi

if grep -Fq 'id = "grok-4.7"' "$PI_CONFIG" \
  && grep -Fq 'api = "openai-responses"' "$PI_CONFIG" \
  && grep -Fq 'https://pi.dev/api/models/providers/github-copilot' "$PI_CONFIG" \
  && grep -Fq 'pi update --models' "$PI_CONFIG"; then
  pass "Pi module overlays Copilot Grok 4.7 until pi.dev/baked catalogs include it"
else
  fail "Pi module overlays Copilot Grok 4.7 until pi.dev/baked catalogs include it"
fi

# The pi-team PATH command and its repo tool were removed with team mode.
if ! grep -Fq 'piTeamPkg' "$PI_MODULE" && [[ ! -e "$REPO_ROOT/tools/pi-team.mjs" ]]; then
  pass "Pi module no longer installs the removed pi-team command"
else
  fail "Pi module no longer installs the removed pi-team command"
fi

# Verify the module references skills that actually exist
SKILL_REFS=(
  "skills/discovery" "skills/design" "skills/research"
  "skills/create-plan" "skills/review-plan"
  "skills/review-code" "skills/review-approach" "skills/assess-repo"
  "skills/create-skills" "skills/configure-pi" "skills/pull-request"
)
for ref in "${SKILL_REFS[@]}"; do
  skill_name="$(basename "$ref")"
  if [[ -f "$REPO_ROOT/${ref}/SKILL.md" ]]; then
    pass "Module skill ref '${skill_name}' resolves to existing SKILL.md"
  else
    fail "Module skill ref '${skill_name}' does not resolve (missing $REPO_ROOT/${ref}/SKILL.md)"
  fi
done

# Verify agent refs
AGENT_REFS=(
  "agents/planner.md" "agents/plan-reviewer.md" "agents/code-reviewer.md"
  "agents/worker.md" "agents/worker-high.md" "agents/worker-low.md" "agents/ui-worker.md" "agents/researcher.md"
  "agents/vision.md" "agents/oracle.md"
)
for ref in "${AGENT_REFS[@]}"; do
  agent_name="$(basename "$ref" .md)"
  if [[ -f "$REPO_ROOT/${ref}" ]]; then
    pass "Module agent ref '${agent_name}' resolves to existing file"
  else
    fail "Module agent ref '${agent_name}' does not resolve (missing $REPO_ROOT/${ref})"
  fi
done

# Rosters remain the single source for what is linked into ~/.pi/agent, and
# the retired team surfaces must not reappear in them.
if grep -Fq 'piAgentNames' "$PI_MODULE" \
  && grep -Fq 'piSkillNames' "$PI_MODULE" \
  && ! grep -Fq '"pi-team-plan"' "$PI_CONFIG" \
  && ! grep -Fq '"pi-team-lead"' "$PI_CONFIG" \
  && ! grep -Fq '"pi-team-worker"' "$PI_CONFIG" \
  && ! grep -Fq '"pi-team-reviewer"' "$PI_CONFIG"; then
  pass "Pi module rosters are roster-driven and free of retired team surfaces"
else
  fail "Pi module rosters are roster-driven and free of retired team surfaces"
fi

# Verify preset.jsonc is valid JSONC (stripping comments and trailing commas)
if node -e "JSON.parse(require('fs').readFileSync('$REPO_ROOT/agents/preset.jsonc','utf8').replace(/\/\/.*$/gm,'').replace(/,\s*([}\]])/g,'\$1'))" 2>/dev/null; then
  pass "preset.jsonc is parseable as JSONC"
else
  fail "preset.jsonc fails to parse"
fi

# Verify check-updates.sh is executable
if [[ -x "$REPO_ROOT/scripts/check-updates.sh" ]]; then
  pass "check-updates.sh is executable"
else
  fail "check-updates.sh is not executable"
fi

# ============================================================
printf '\n'
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
