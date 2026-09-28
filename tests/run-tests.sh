#!/usr/bin/env bash
# Engineering Agents test runner
#
# Modes:
#   fast     - Repo-local checks only (no Pi/OpenCode required) [default]
#   all      - Repo-local + nix eval + proof-set verification
#   full     - All of the above + CLI smoke tests
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

EXIT_SPEC=1
EXIT_ENVIRONMENT=2

mode="${1:-fast}"

usage() {
  cat <<'EOF' >&2
Usage: tests/run-tests.sh [fast|all|full]

  fast  - Repo-local spec checks only (no Nix or Pi required)
  all   - Repo-local + Nix flake eval + Pi proof-set verification
  full  - All checks including Pi CLI smoke tests

Prerequisites:
  fast:  bash, jq, node (for JSONC parsing)
  all:   above + nix, pi installed, home-manager switch run at least once
  full:  above + pi CLI functional
EOF
  exit "$EXIT_ENVIRONMENT"
}

normalize_status() {
  case "$1" in
    0|1|2|3)
      printf '%s\n' "$1"
      ;;
    *)
      printf '%s\n' "$EXIT_SPEC"
      ;;
  esac
}

run_specs() {
  local pass=true
  local overall_status=0
  local status normalized_status
  printf 'Running repo-local specs...\n\n'

  for spec in "$SCRIPT_DIR/specs/repo-structure-spec.sh" \
              "$SCRIPT_DIR/specs/repo-readiness-docs-spec.sh" \
              "$SCRIPT_DIR/specs/proof-set-runtime-spec.sh" \
              "$SCRIPT_DIR/specs/skill-content-spec.sh" \
              "$SCRIPT_DIR/specs/skill-render-spec.sh" \
              "$SCRIPT_DIR/specs/preset-spec.sh" \
              "$SCRIPT_DIR/specs/compiler-contract-spec.sh" \
              "$SCRIPT_DIR/specs/pi-preset-refresh-contract-spec.sh" \
              "$SCRIPT_DIR/specs/pi-btw-refresh-contract-spec.sh" \
              "$SCRIPT_DIR/specs/managed-package-install-state-spec.sh" \
              "$SCRIPT_DIR/specs/managed-package-status-spec.sh" \
              "$SCRIPT_DIR/specs/pi-startup-wrapper-spec.sh" \
              "$SCRIPT_DIR/specs/pi-dev-spec.sh" \
              "$SCRIPT_DIR/specs/hermes-docs-spec.sh" \
              "$SCRIPT_DIR/specs/startup-warning-extension-spec.sh" \
              "$SCRIPT_DIR/specs/pi-tasks-bridge-spec.sh" \
              "$SCRIPT_DIR/specs/pi-startup-warning-contract-spec.sh"; do
    if [[ -x "$spec" ]]; then
      printf '%s\n' "--- $(basename "$spec") ---"
      if bash "$spec"; then
        printf '  OK\n\n'
      else
        status=$?
        normalized_status="$(normalize_status "$status")"
        if [[ "$normalized_status" -gt "$overall_status" ]]; then
          overall_status="$normalized_status"
        fi
        printf '  FAILED (exit %s)\n\n' "$normalized_status" >&2
        pass=false
      fi
    else
      # A listed spec that is not executable used to be skipped in silence.
      # pi-startup-wrapper-spec.sh was skipped that way from af4ad40 until
      # 2026-08-18. Never skip quietly again: an unrunnable spec is a failure.
      printf '%s\n' "--- $(basename "$spec") ---"
      printf '  FAILED (listed but not executable: %s)\n\n' "$spec" >&2
      if [[ "$EXIT_SPEC" -gt "$overall_status" ]]; then
        overall_status="$EXIT_SPEC"
      fi
      pass=false
    fi
  done

  if [[ "$pass" != "true" ]]; then
    return "${overall_status:-$EXIT_SPEC}"
  fi
}

run_flake_eval() {
  local status normalized_status
  printf 'Running flake evaluation spec...\n\n'
  if bash "$SCRIPT_DIR/specs/flake-eval-spec.sh"; then
    printf '  OK\n\n'
  else
    status=$?
    normalized_status="$(normalize_status "$status")"
    printf '  FAILED (exit %s)\n\n' "$normalized_status" >&2
    return "$normalized_status"
  fi
}

run_proof_set() {
  local status normalized_status
  printf 'Running Pi proof-set verification...\n\n'
  if bash "$SCRIPT_DIR/test-fast.sh"; then
    printf '  OK\n\n'
  else
    status=$?
    normalized_status="$(normalize_status "$status")"
    printf '  FAILED (exit %s)\n\n' "$normalized_status" >&2
    return "$normalized_status"
  fi
}

run_cli_smoke() {
  local pi_bin
  pi_bin="$(pi_bin)"

  if ! command -v "$pi_bin" >/dev/null 2>&1; then
    printf 'WARNING: pi not found, skipping CLI smoke\n\n'
    return 0
  fi

  printf 'Running Pi CLI smoke tests...\n\n'

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  if ! PI_OFFLINE=1 "$pi_bin" --help >"$tmp_dir/help.out" 2>"$tmp_dir/help.err"; then
    printf '  FAILED: pi --help\n' >&2
    return "$EXIT_SPEC"
  fi

  if grep -Eq '^Usage:|^pi - AI coding assistant' "$tmp_dir/help.out"; then
    printf '  PASS: pi --help produces expected output\n'
  else
    printf '  FAILED: pi --help output unexpected\n' >&2
    return "$EXIT_SPEC"
  fi

  if ! PI_OFFLINE=1 "$pi_bin" list >"$tmp_dir/list.out" 2>"$tmp_dir/list.err"; then
    printf '  FAILED: pi list\n' >&2
    return "$EXIT_SPEC"
  fi

  if grep -Eq 'User packages:|Local packages:|pi-subagents|pi-hooks' "$tmp_dir/list.out" "$tmp_dir/list.err"; then
    printf '  PASS: pi list shows managed packages\n'
  else
    printf '  FAILED: pi list output unexpected\n' >&2
    return "$EXIT_SPEC"
  fi

  printf '\n'
}

case "$mode" in
  fast)
    run_specs
    printf 'All fast tests passed.\n'
    ;;
  all)
    run_specs
    run_flake_eval
    run_proof_set
    printf 'All tests passed.\n'
    ;;
  full)
    run_specs
    run_flake_eval
    run_proof_set
    run_cli_smoke
    printf 'All tests passed.\n'
    ;;
  ''|--help|-h)
    usage
    ;;
  *)
    printf 'Unsupported mode: %s\n' "$mode" >&2
    usage
    ;;
esac
