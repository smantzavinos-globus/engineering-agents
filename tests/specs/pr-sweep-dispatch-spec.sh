#!/usr/bin/env bash
# Dry-run smoke test for scripts/pr-sweep-dispatch.py against a fake `gh`.
# Proves: opt-in ignores unlabeled PRs; pr:ready-review dispatches a review;
# a stale verdict on pr:ready-merge is demoted; drift mode reviews unlabeled PRs.
# Requirement: FR-001
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP" /tmp/pr-sweep-dry' EXIT
cat > "$TMP/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "pr list"*) cat <<'J'
[{"number":1,"title":"unlabeled","headRefName":"a","headRefOid":"1111111111111111111111111111111111111111","labels":[],"isDraft":false},
 {"number":2,"title":"wants review","headRefName":"b","headRefOid":"2222222222222222222222222222222222222222","labels":[{"name":"pr:ready-review"}],"isDraft":false},
 {"number":3,"title":"moved after READY","headRefName":"c","headRefOid":"3333333333333333333333333333333333333333","labels":[{"name":"pr:ready-merge"}],"isDraft":false}]
J
  ;;
  *"issues/3/comments"*) echo '[{"id":9,"user":{"login":"bot"},"body":"<!-- pr-review verdict=READY head=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa -->"}]' ;;
  *"/comments"*) echo '[]' ;;
  *) echo '[]' ;;
esac
EOF
chmod +x "$TMP/gh"
PY="$(command -v python3 || true)"
if [[ -z "$PY" ]]; then echo "SKIP: python3 not available"; exit 0; fi
run() { env -u GH_TOKEN PR_SWEEP_DRY=1 PR_SWEEP_REPO=o/r GH_BIN="$TMP/gh" HERMES_HOME="$TMP" "$@" "$PY" "$ROOT/scripts/pr-sweep-dispatch.py"; }
PASS=0 FAIL=0
check() { if grep -Fq "$2" <<<"$1"; then PASS=$((PASS+1)); echo "  PASS: $3"; else FAIL=$((FAIL+1)); echo "  FAIL: $3 (missing: $2)" >&2; fi; }
refute() { if grep -Fq "$2" <<<"$1"; then FAIL=$((FAIL+1)); echo "  FAIL: $3 (unexpected: $2)" >&2; else PASS=$((PASS+1)); echo "  PASS: $3"; fi; }

OUT="$(run)"
refute "$OUT" "spawn review for PR #1" "opt-in: unlabeled PR is ignored"
check  "$OUT" "would spawn review for PR #2" "pr:ready-review dispatches a detached review"
check  "$OUT" "would set PR #2 label pr:in-review" "dispatch marks the PR in-review"
check  "$OUT" "would set PR #3 label pr:re-review" "push after READY demotes to re-review"
check  "$OUT" "new commits after READY" "stale READY is reported to the human"
rm -rf /tmp/pr-sweep-dry
OUT="$(PR_SWEEP_UNLABELED=review run)"
check  "$OUT" "would spawn review for PR #1" "drift mode: unlabeled PR is reviewed"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
