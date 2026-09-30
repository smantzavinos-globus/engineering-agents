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
# PR 8: READY stamped at its head; rollup controlled by CI_ROLLUP (red|green|pending|none)
mk8() {
  case "${CI_ROLLUP:-red}" in
    red)     R='[{"name":"E2E","status":"COMPLETED","conclusion":"FAILURE"},{"name":"CI","status":"COMPLETED","conclusion":"SUCCESS"}]';;
    green)   R='[{"name":"CI","status":"COMPLETED","conclusion":"SUCCESS"}]';;
    pending) R='[{"name":"CI","status":"IN_PROGRESS","conclusion":null}]';;
    none)    R='[]';;
  esac
  if [ "${PR8_LABEL:-pr:ready-merge}" = "pr:babysat" ]; then
    L='[{"name":"pr:babysat"},{"name":"pr:in-review"}]'
  else
    L="[{\"name\":\"${PR8_LABEL:-pr:ready-merge}\"}]"
  fi
  printf '{"number":8,"title":"ready+ci","headRefName":"item/8","headRefOid":"8888888888888888888888888888888888888888","labels":%s,"isDraft":false,"statusCheckRollup":%s}' "$L" "$R"
}
case "$*" in
  "pr list"*) echo "[$old, $(mk8)]" ;;
  *"issues/7/comments"*) echo '[{"id":70,"user":{"login":"agent"},"body":"babysit: session=babysit-pr-item7-x heartbeat=2000-01-01T00:00:00Z"}]' ;;
  *"issues/8/comments"*)
    C='[{"id":80,"user":{"login":"agent"},"body":"<!-- pr-review verdict=READY head=8888888888888888888888888888888888888888 -->"}'
    if [ "${PR8_LABEL:-}" = "pr:babysat" ]; then
      C="$C,{\"id\":81,\"user\":{\"login\":\"agent\"},\"body\":\"babysit: session=${PR8_SESSION:-babysit-pr-item8-x} heartbeat=${PR8_HEARTBEAT:-2000-01-01T00:00:00Z}\"}"
    fi
    echo "$C]" ;;
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

# A round consumes EVERY bot review it saw: the dispatch record's bot_review_ids are
# read back as handled, so two bot reviews between ticks cost one round, not two.
mkdir -p "$TMP/state"
printf '%s\n' '{"ts":0,"kind":"babysit","repo":"o/r","pr":7,"head":"7777777777777777777777777777777777777777","bot_review_id":702,"bot_review_ids":[701,702]}' > "$TMP/state/dispatches.jsonl"
OUT="$(run BOT_REVIEWS=2 GH_BIN="$BOT")"
refute "$OUT" "would spawn babysit for o/r#7" "bot-review batching: a record carrying all seen ids suppresses the follow-up round"
printf '%s\n' '{"ts":0,"kind":"babysit","repo":"o/r","pr":7,"head":"7777777777777777777777777777777777777777","bot_review_id":701}' > "$TMP/state/dispatches.jsonl"
OUT="$(run BOT_REVIEWS=2 GH_BIN="$BOT")"
check  "$OUT" "would spawn babysit for o/r#7" "bot-review batching: a pre-fix single-id record still gets the round for the second review"

# CI gate: red at the stamped READY head demotes; green restores; pending/none are not red.
OUT="$(run GH_BIN="$BOT")"
check  "$OUT" "would spawn babysit for o/r#8" "CI gate: red at READY head demotes, round dispatched"
check  "$OUT" "would set o/r#8 label pr:re-review" "CI gate: red at READY head demotes the label"
check  "$OUT" "CI red at the READY head (E2E (FAILURE)); moved back to pr:re-review" "CI gate: demotion is reported once"
# tick 2 (live-mode ledger seeded with the record's ci_key): label is now pr:re-review —
# no re-dispatch and no second human-facing line for the same transition.
mkdir -p "$TMP/state"
printf '%s\n' '{"ts":0,"kind":"babysit","repo":"o/r","pr":8,"head":"8888888888888888888888888888888888888888","ci_key":"888888888888:E2E (FAILURE)"}' > "$TMP/state/dispatches.jsonl"
OUT="$(run PR8_LABEL=pr:re-review GH_BIN="$BOT")"
refute "$OUT" "would spawn babysit for o/r#8" "CI gate: the CI round fires once per red transition"
refute "$OUT" "CI red" "CI gate: no second human-facing line for the same transition"
rm -f "$TMP/state/dispatches.jsonl"
OUT="$(run PR8_LABEL=pr:in-review GH_BIN="$BOT")"
check  "$OUT" "CI red (E2E (FAILURE)); the babysitting author owns the fix." "CI gate: red under review reports ownership"
OUT="$(run PR8_LABEL=pr:re-review CI_ROLLUP=green GH_BIN="$BOT")"
check  "$OUT" "CI green at the READY head; restored pr:ready-merge" "CI gate: green restores pr:ready-merge"
OUT="$(run CI_ROLLUP=green GH_BIN="$BOT")"
refute "$OUT" "restored pr:ready-merge" "CI gate: green at pr:ready-merge is silent"
OUT="$(run CI_ROLLUP=pending GH_BIN="$BOT")"
refute "$OUT" "CI red" "CI gate: pending checks are ignored"
OUT="$(run CI_ROLLUP=none GH_BIN="$BOT")"
refute "$OUT" "CI red" "CI gate: no checks yet is not a red"

# A sweep-owned babysitter takes the CI round when one is due.
OUT="$(run PR8_LABEL=pr:babysat CI_ROLLUP=red GH_BIN="$BOT")"
check  "$OUT" "would spawn babysit for o/r#8" "CI gate: sweep-owned claim gets a CI-fix round"

# CI red with NO claim at all also gets the CI round: the sweep posts its own claim per the
# prompt, so "nobody on the PR" must not leave a READY-stamped PR parked red until green.
OUT="$(run PR8_LABEL=pr:ready-merge CI_ROLLUP=red GH_BIN="$BOT")"
check  "$OUT" "would spawn babysit for o/r#8" "CI gate: red at READY head with no claim dispatches the round"

# A chat-started claim must NOT get a sweep twin: only sweep-owned sessions (prefix babysit-pr)
# are eligible for the CI round — the heartbeat must be FRESH so the claim is active, not stale.
OUT="$(run PR8_LABEL=pr:babysat PR8_SESSION=20260101_chat PR8_HEARTBEAT="$(date -u +%Y-%m-%dT%H:%M:%SZ)" CI_ROLLUP=red GH_BIN="$BOT")"
refute "$OUT" "would spawn babysit for o/r#8" "CI gate: chat-started claim gets no sweep twin"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
