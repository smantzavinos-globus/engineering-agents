#!/usr/bin/env bash
# Verify the Hermes-agent operations docs and the sweep monitor contract.
# Requirement: FR-001
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(repo_root)"
PASS=0 FAIL=0

pass() { PASS=$((PASS + 1)); printf '  PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL: %s\n' "$1" >&2; }

assert_contains() {
  if grep -Fq "$2" "$1" 2>/dev/null; then
    pass "$3"
  else
    fail "$3 (missing: $2 in $1)"
  fi
}

# Docs exist and carry their contract anchors
HERMES_README="$REPO_ROOT/docs/hermes/README.md"
HERMES_AUTO="$REPO_ROOT/docs/hermes/pr-automation.md"

assert_contains "$HERMES_README" "# Hermes Agent Operations" "Hermes ops index has title"
assert_contains "$HERMES_README" "Agent self-setup checklist" "Hermes ops index has the self-setup checklist"
assert_contains "$HERMES_README" "../references/pr-review.md" "Hermes ops index routes to the canonical PR review process"
assert_contains "$HERMES_README" "the canonical doc wins" "Hermes ops index states canonical precedence"

assert_contains "$HERMES_AUTO" "Label state machine" "PR automation doc defines the label state machine"
assert_contains "$HERMES_AUTO" "pr:ready-review" "PR automation doc defines ready-review label"
assert_contains "$HERMES_AUTO" "pr:ready-merge" "PR automation doc defines ready-merge label"
assert_contains "$HERMES_AUTO" "pr:escalated" "PR automation doc defines escalated label"
assert_contains "$HERMES_AUTO" "monitor_script" "PR automation doc specifies the monitor guard"
assert_contains "$HERMES_AUTO" "3 minutes" "PR automation doc records the cron interrupt constraint"
assert_contains "$HERMES_AUTO" "Never half-post" "PR automation doc defines the failure policy"
assert_contains "$HERMES_AUTO" "Agents never merge" "PR automation doc states the merge boundary"
assert_contains "$HERMES_AUTO" "pr-sweep-monitor.mjs" "PR automation doc references the monitor script"
assert_contains "$HERMES_AUTO" "docs/references/pr-review.md" "PR automation doc points at the canonical process, not a restatement"

HERMES_MODES="$REPO_ROOT/docs/hermes/execution-modes.md"
assert_contains "$HERMES_MODES" "Investigation continuity is the second exception" "Execution modes define the investigation-continuity session exception"
assert_contains "$HERMES_MODES" "continuity: <reason>" "Investigation continuity is recorded in the worklog"

# Monitor script: syntax-valid and deterministic-contract anchors present
if nix develop --command node --check "$REPO_ROOT/scripts/pr-sweep-monitor.mjs" >/dev/null 2>&1; then
  pass "pr-sweep-monitor.mjs parses"
else
  fail "pr-sweep-monitor.mjs does not parse"
fi
assert_contains "$REPO_ROOT/scripts/pr-sweep-monitor.mjs" "PR_SWEEP_REPOS" "Monitor script documents the repo list env var"
assert_contains "$REPO_ROOT/scripts/pr-sweep-monitor.mjs" "no actionable PRs" "Monitor script has a stable empty state"

printf '\n'
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
