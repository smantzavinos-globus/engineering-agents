#!/usr/bin/env bash
# Dry-run smoke test for scripts/pr-sweep-dispatch.py against a fake `gh`.
# Proves: opt-in ignores unlabeled PRs; pr:ready-review dispatches a review;
# a stale verdict on pr:ready-merge is demoted; drift mode reviews unlabeled PRs.
# Requirement: FR-001
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
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
if [[ -z "$PY" ]]; then echo "  FAIL: python3 not on PATH (run inside nix develop)" >&2; exit 1; fi
run() { env -u GH_TOKEN PR_SWEEP_DRY=1 PR_SWEEP_REPOS=o/r PR_SWEEP_STATE="$TMP/state" GH_BIN="$TMP/gh" HERMES_HOME="$TMP" "$@" "$PY" "$ROOT/scripts/pr-sweep-dispatch.py"; }
PASS=0 FAIL=0
check() { if grep -Fq "$2" <<<"$1"; then PASS=$((PASS+1)); echo "  PASS: $3"; else FAIL=$((FAIL+1)); echo "  FAIL: $3 (missing: $2)" >&2; fi; }
refute() { if grep -Fq "$2" <<<"$1"; then FAIL=$((FAIL+1)); echo "  FAIL: $3 (unexpected: $2)" >&2; else PASS=$((PASS+1)); echo "  PASS: $3"; fi; }

OUT="$(run)"
refute "$OUT" "spawn review for o/r#1" "opt-in: unlabeled PR is ignored"
check  "$OUT" "would spawn review for o/r#2" "pr:ready-review dispatches a detached review"
check  "$OUT" "would set o/r#2 label pr:in-review" "dispatch marks the PR in-review"
check  "$OUT" "would set o/r#3 label pr:re-review" "push after READY demotes to re-review"
check  "$OUT" "new commits after READY" "stale READY is reported to the human"
OUT="$(PR_SWEEP_UNLABELED=review run)"
check  "$OUT" "would spawn review for o/r#1" "drift mode: unlabeled PR is reviewed"


# Babysit on open: a sweep-owned claim gets a round on a new bot review, never ages,
# and stops at the bot-review cap.
BOT="$TMP/gh-bot"
cat > "$BOT" <<'EOF'
#!/usr/bin/env bash
old='{"number":7,"title":"owned","headRefName":"item/7","headRefOid":"7777777777777777777777777777777777777777","labels":[{"name":"pr:babysat"},{"name":"pr:in-review"}],"isDraft":false}'
case "$*" in
  "pr list"*) echo "[$old]" ;;
  *"issues/7/comments"*) echo '[{"id":70,"user":{"login":"agent"},"body":"babysit: session=babysit-pr-item7-x heartbeat=2000-01-01T00:00:00Z"}]' ;;
  *"pulls/7/reviews"*)
    n="${BOT_REVIEWS:-1}"; printf '['
    for i in $(seq 1 "$n"); do [[ $i -gt 1 ]] && printf ','; printf '{"id":%d,"user":{"login":"copilot-pull-request-reviewer[bot]"},"state":"COMMENTED","submitted_at":"2026-01-01T00:00:00Z"}' "$((700+i))"; done
    printf ']\n' ;;
  *) echo '[]' ;;
esac
EOF
chmod +x "$BOT"
OUT="$(run GH_BIN="$BOT")"
check  "$OUT" "would spawn babysit for o/r#7" "sweep-owned claim: new bot review dispatches a babysit round"
refute "$OUT" "claim went stale" "sweep-owned claim does not age by heartbeat"
OUT="$(run BOT_REVIEWS=6 GH_BIN="$BOT")"
refute "$OUT" "would spawn babysit for o/r#7" "bot-review cap: no round past 5 bot reviews"
check  "$OUT" "bot-review cap (5) reached" "bot-review cap is reported once"
OUT="$(run BOT_REVIEWS=5 GH_BIN="$BOT")"
check  "$OUT" "would spawn babysit for o/r#7" "bot-review cap: the 5th bot review still gets a round"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
