#!/usr/bin/env bash
# Verify skill content quality: templates exist, skills have required sections
# Requirement: FR-007
# Requirement: FR-008
# Requirement: NFR-003
# Requirement: OPR-003
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(repo_root)"
PASS=0 FAIL=0

pass() { PASS=$((PASS + 1)); printf '  PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL: %s\n' "$1" >&2; }

assert_skill_has_section() {
  local skill_path="$1" section="$2" desc="$3"
  if grep -qi "^## *${section}" "$skill_path" 2>/dev/null || grep -qi "^# *${section}" "$skill_path" 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc (missing '## ${section}' in $(basename "$(dirname "$skill_path")"))"
  fi
}

assert_references_valid() {
  local skill_dir="$1" skill_name="$2"
  local ref_dir="$skill_dir/references"
  if [[ ! -d "$ref_dir" ]]; then
    return 0  # References are optional
  fi
  local count
  count=$(find "$ref_dir" -type f | wc -l)
  if [[ "$count" -gt 0 ]]; then
    pass "Skill '${skill_name}' has ${count} reference file(s)"
    for ref in "$ref_dir"/*; do
      if [[ -s "$ref" ]]; then
        pass "Skill '${skill_name}' reference $(basename "$ref") is non-empty"
      else
        fail "Skill '${skill_name}' reference $(basename "$ref") is empty"
      fi
    done
  fi
}

# ============================================================
printf 'Skill content verification\n'
printf '==========================\n\n'

# Skills that should have references
SKILLS_WITH_REFS=(discovery design create-plan create-worklog review-plan review-approach review-code assess-repo)
for skill in "${SKILLS_WITH_REFS[@]}"; do
  assert_references_valid "$REPO_ROOT/skills/$skill" "$skill"
done

# Verify key skills have essential sections
# Discovery should reference brief (case-insensitive, anywhere in file)
if grep -qi 'brief' "$REPO_ROOT/skills/discovery/SKILL.md"; then
  pass "discovery references brief"
else
  fail "discovery does not reference brief"
fi

# Design should reference approach (case-insensitive, anywhere in file)
if grep -qi 'approach' "$REPO_ROOT/skills/design/SKILL.md"; then
  pass "design references approach"
else
  fail "design does not reference approach"
fi

# Execute-task should mention "TDD" or "test"
if grep -qi "tdd\|test" "$REPO_ROOT/skills/execute-task/SKILL.md"; then
  pass "execute-task references TDD/testing"
else
  fail "execute-task does not reference TDD/testing"
fi

# Review-code should mention "plan"
if grep -qi "plan" "$REPO_ROOT/skills/review-code/SKILL.md"; then
  pass "review-code references plan"
else
  fail "review-code does not reference plan"
fi

# Team mode was retired (ADR-0006); review-code no longer distinguishes
# execution modes, but it still requires per-task verification evidence.
if grep -Fq 'per-task verification evidence' "$REPO_ROOT/skills/review-code/SKILL.md"; then
  pass "review-code checks per-task verification evidence"
else
  fail "review-code is missing per-task verification evidence semantics"
fi


# Verify approach template has expected structure
if [[ -f "$REPO_ROOT/skills/design/references/approach-template.md" ]]; then
  pass "Design approach template exists"
else
  fail "Design approach template missing"
fi

# Verify plan template has expected structure
if [[ -f "$REPO_ROOT/skills/create-plan/references/plan-template.md" ]]; then
  pass "Plan template exists"
else
  fail "Plan template missing"
fi

# Team mode was replaced by code-mode execution: the Pi-only team skills and
# the team task reviewer are removed.
for gone in pi-team-plan pi-team-lead pi-team-worker; do
  if [[ ! -e "$REPO_ROOT/skills/$gone" ]]; then
    pass "${gone} is removed with team mode"
  else
    fail "${gone} is removed with team mode"
  fi
done
if [[ ! -e "$REPO_ROOT/agents/pi-team-reviewer.md" ]]; then
  pass "pi-team-reviewer agent is removed with team mode"
else
  fail "pi-team-reviewer agent is removed with team mode"
fi
# Team mode and the wave pipeline were retired (ADR-0006): the six
# sequential-pipeline skills are harness-neutral — they carry no
# `harnesses:` restriction and render to every harness.
for neutral in execution-orchestrator execute-task create-worklog \
                create-plan review-plan review-code; do
  if ! grep -q '^harnesses:' "$REPO_ROOT/skills/$neutral/SKILL.md"; then
    pass "${neutral} is harness-neutral (renders to every harness)"
  else
    fail "${neutral} must not restrict harnesses (harness-neutral since the wave retirement)"
  fi
done

if grep -Fq 'General model suggestion' "$REPO_ROOT/docs/orchestration.md" \
  && grep -Fq 'GitHub Copilot suggestion' "$REPO_ROOT/docs/orchestration.md" \
  && grep -Fq 'Role-to-runtime mapping' "$REPO_ROOT/docs/orchestration.md"; then
  pass "Orchestration docs separate role routing from general and Copilot model suggestions"
else
  fail "Orchestration docs are missing role or model recommendation tables"
fi

# Verify worklog template exists
if [[ -f "$REPO_ROOT/skills/create-worklog/references/worklog-template.md" ]]; then
  pass "Worklog template exists"
else
  fail "Worklog template missing"
fi

# Task review toggle: the plan decides per-task review; the orchestrator obeys it
TPL="$REPO_ROOT/skills/create-plan/references/plan-template.md"
ORCH="$REPO_ROOT/skills/execution-orchestrator/SKILL.md"
if grep -q '^\*\*Task review default:\*\*' "$TPL" && [[ "$(grep -c '^\*\*Task review:\*\*' "$TPL")" -ge 2 ]]; then
  pass "Plan template has a plan-level Task review default and a per-task Task review field"
else
  fail "Plan template missing 'Task review default' or per-task 'Task review' field"
fi
if grep -q 'Task review' "$ORCH" && grep -q 'review skipped per plan' "$ORCH" && ! grep -q 'optional but recommended' "$ORCH"; then
  pass "Orchestrator obeys the plan's Task review fields"
else
  fail "Orchestrator does not read the plan's Task review fields"
fi
if grep -q 'Task review' "$REPO_ROOT/skills/review-plan/SKILL.md" && grep -q 'Task review' "$REPO_ROOT/skills/create-plan/SKILL.md"; then
  pass "create-plan and review-plan both cover Task review"
else
  fail "create-plan or review-plan does not cover Task review"
fi

# ============================================================
printf '\n'
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
