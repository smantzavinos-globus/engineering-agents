#!/usr/bin/env python3
"""PR sweep dispatcher: a no-LLM Hermes cron tick that launches detached Hermes sessions.

The tick itself never reviews or fixes anything. It reads GitHub state, decides
what is actionable, and launches one detached `hermes chat` session per
job. Those sessions outlive the tick. Their verdicts go back to GitHub, and the
digest they write is printed by a later tick. stdout is delivered to the human;
empty stdout means a silent tick.

Reference implementation of docs/hermes/pr-automation.md (template A).
Install: copy this file plus pr-sweep-prompts/ into $HERMES_HOME/scripts/, then
  hermes cron create "every 2m" --no-agent --script pr-sweep-dispatch.py --name pr-sweep
Configuration is by environment; see the constants below. PR_SWEEP_DRY=1 prints
the actions it would take without mutating anything.

Opt-in by default: unlabeled PRs are ignored. Set PR_SWEEP_UNLABELED=review for
the monitor's drift behaviour, where an unlabeled PR is queued for review.
"""
import json
import os
import pathlib
import re
import subprocess
import sys
import time
from datetime import datetime, timezone

REPO = os.environ["PR_SWEEP_REPO"]
HANDLE = os.environ.get("PR_AGENT_HANDLE", "").lstrip("@").lower()
REVIEW_MODEL = os.environ.get("PR_REVIEW_MODEL", "")
REVIEW_REASONING = os.environ.get("PR_REVIEW_REASONING", "medium")
BABYSIT_MODEL = os.environ.get("PR_BABYSIT_MODEL", "")
STALE_MIN = int(os.environ.get("PR_BABYSIT_STALE_MIN", "60"))
STUCK_MIN = int(os.environ.get("PR_REVIEW_STUCK_MIN", "90"))
PROVIDER = os.environ.get("PR_SESSION_PROVIDER", "")
UNLABELED = os.environ.get("PR_SWEEP_UNLABELED", "ignore")  # ignore | review
REVIEW_SKILLS = os.environ.get("PR_REVIEW_SKILLS", "pull-request")
BABYSIT_SKILLS = os.environ.get("PR_BABYSIT_SKILLS", "babysit-pr")
MAX_FAILS = 3

HOME = pathlib.Path(os.environ.get("HERMES_HOME", pathlib.Path.home()))
STATE = HOME / "state" / "pr-automation"
DISPATCH = STATE / "dispatches.jsonl"
RESULTS = STATE / "results"
REPORTED = STATE / "reported.json"
LOGS = STATE / "logs"
CHECKOUT = os.environ.get("PR_SWEEP_CHECKOUT", str(pathlib.Path.home() / "repos" / REPO.split("/")[-1]))
PROMPTS = pathlib.Path(__file__).resolve().parent / "pr-sweep-prompts"
GH = os.environ.get("GH_BIN", "gh")
HERMES = os.environ.get("HERMES_BIN", "hermes")
# Optional file holding the GitHub token when the cron env lacks GH_TOKEN.
PAT = pathlib.Path(os.environ.get("GH_TOKEN_FILE", "/nonexistent"))

STATE_LABELS = ["pr:ready-review", "pr:in-review", "pr:re-review", "pr:ready-merge", "pr:escalated"]
VERDICT_RE = re.compile(r"<!--\s*pr-review verdict=(READY|FIX|BLOCKED) head=([0-9a-f]{7,40})\s*-->")
STAMP_RE = re.compile(r"reviewed@([0-9a-f]{7,40})")
HEARTBEAT_RE = re.compile(r"babysit: session=(\S+) heartbeat=(\S+)")

out = []  # lines delivered to the human


def now():
    return datetime.now(timezone.utc)


def gh_env():
    env = {k: v for k, v in os.environ.items() if not k.startswith(("HERMES_CRON", "HERMES_SESSION"))}
    if "GH_TOKEN" not in env and PAT.exists():
        env["GH_TOKEN"] = PAT.read_text().strip()
    return env


def gh(*args, parse=True):
    r = subprocess.run([GH, *args], capture_output=True, text=True, env=gh_env(), timeout=60)
    if r.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args[:3])} failed: {r.stderr.strip()[:300]}")
    return json.loads(r.stdout) if parse and r.stdout.strip() else r.stdout


def records():
    if not DISPATCH.exists():
        return []
    return [json.loads(l) for l in DISPATCH.read_text().splitlines() if l.strip()]


def append_record(rec):
    with DISPATCH.open("a") as f:
        f.write(json.dumps(rec, sort_keys=True) + "\n")


def alive(pid):
    try:
        cmd = pathlib.Path(f"/proc/{pid}/cmdline").read_bytes()
    except OSError:
        return False
    return b"hermes" in cmd


def set_state_label(n, label):
    if os.environ.get("PR_SWEEP_DRY"):
        out.append(f"DRY: would set PR #{n} label {label}")
        return
    cur = [l["name"] for l in gh("api", f"repos/{REPO}/issues/{n}/labels")]
    for l in cur:
        if l in STATE_LABELS and l != label:
            gh("api", "-X", "DELETE", f"repos/{REPO}/issues/{n}/labels/{l}", parse=False)
    if label and label not in cur:
        gh("api", "-X", "POST", f"repos/{REPO}/issues/{n}/labels", "-f", f"labels[]={label}", parse=False)


def spawn(kind, pr, head, template, model, reasoning, skills, extra=None):
    """Launch a detached Hermes session; return pid. The session outlives this tick."""
    if os.environ.get("PR_SWEEP_DRY"):
        out.append(f"DRY: would spawn {kind} for PR #{pr['number']} at {head[:8]}")
        return 0, f"dry-{kind}-{pr['number']}"
    LOGS.mkdir(parents=True, exist_ok=True)
    tag = f"{kind}-pr{pr['number']}-{head[:8]}-{int(time.time())}"
    prompt = (PROMPTS / template).read_text().format(
        checkout=CHECKOUT, hermes=HERMES, repo=REPO, number=pr["number"], head=head, short_head=head[:7], title=pr["title"], branch=pr["headRefName"],
        result_file=str(RESULTS / f"{tag}.json"), tag=tag, handle=HANDLE, **(extra or {}))
    pfile = LOGS / f"{tag}.prompt.md"
    pfile.write_text(prompt)
    env = {k: v for k, v in os.environ.items()
           if not k.startswith(("HERMES_CRON", "HERMES_SESSION"))}
    log = open(LOGS / f"{tag}.log", "w")
    title = f"PR #{pr['number']} {kind} @{head[:7]} — {pr['title'][:50]}"
    p = subprocess.Popen(
        [HERMES, "chat", "-Q", "--oneshot", "--query-file", str(pfile), "--source", "pr-automation",
         "--continue", title, "--create-if-missing", "--reasoning", reasoning, "-s", skills,
         *(["-m", model] if model else []), *(["--provider", PROVIDER] if PROVIDER else [])],
        stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT, env=env,
        start_new_session=True, close_fds=True)
    return p.pid, tag


def main():
    global STATE, DISPATCH, RESULTS, REPORTED, LOGS
    if os.environ.get("PR_SWEEP_DRY"):
        STATE = pathlib.Path("/tmp/pr-sweep-dry")
        DISPATCH, RESULTS, REPORTED, LOGS = STATE / "d.jsonl", STATE / "results", STATE / "r.json", STATE / "logs"
    for d in (STATE, RESULTS, LOGS):
        d.mkdir(parents=True, exist_ok=True)
    recs = records()
    reported = set(json.loads(REPORTED.read_text())) if REPORTED.exists() else set()

    # 1. Deliver finished-session digests (READY / BLOCKED / ESCALATE / babysit exits; FIX is silent).
    for f in sorted(RESULTS.glob("*.json")):
        if f.name in reported:
            continue
        try:
            r = json.loads(f.read_text())
        except ValueError:
            continue
        reported.add(f.name)
        if r.get("notify", True) and r.get("verdict") != "FIX":
            out.append(f"PR #{r.get('pr')} [{r.get('verdict', r.get('status', '?'))}] {r.get('summary', '').strip()} {r.get('url', '')}".strip())

    pulls = gh("pr", "list", "-R", REPO, "--state", "open", "--limit", "100",
               "--json", "number,title,headRefName,headRefOid,labels,isDraft")
    for pr in sorted(pulls, key=lambda p: p["number"]):
        n, head = pr["number"], pr["headRefOid"]
        labels = [l["name"] for l in pr["labels"]]
        label = next((l for l in ["pr:in-review", "pr:re-review", "pr:ready-merge", "pr:escalated", "pr:ready-review"] if l in labels), None)
        if label is None and UNLABELED == "review" and "pr:babysat" not in labels:
            label = "pr:ready-review"  # drift mode: unlabeled counts as awaiting review
        comments = gh("api", f"repos/{REPO}/issues/{n}/comments?per_page=100")
        verdicts = [(m.group(1), m.group(2), c) for c in comments for m in [VERDICT_RE.search(c.get("body") or "")] if m]
        last_v = verdicts[-1] if verdicts else None
        mine = [r for r in recs if r["pr"] == n]
        running = [r for r in mine if r.get("pid") and alive(r["pid"])]

        # Stuck detection: a live session older than STUCK_MIN.
        for r in running:
            age = (time.time() - r["ts"]) / 60
            key = f"stuck:{r['tag']}"
            if age > STUCK_MIN and key not in reported:
                reported.add(key)
                out.append(f"PR #{n}: {r['kind']} session {r['tag']} still running after {int(age)} min (pid {r['pid']}); log {LOGS / (r['tag'] + '.log')}")

        # Mechanical push demotion: stamped state whose branch moved.
        if label in ("pr:ready-merge", "pr:escalated") and last_v and not head.startswith(last_v[1]):
            set_state_label(n, "pr:re-review")
            label = "pr:re-review"
            if last_v[0] == "READY":
                out.append(f"PR #{n}: new commits after READY at {last_v[1][:8]}; moved back to pr:re-review.")

        # Explicit mentions newer than any dispatch for this PR.
        seen_comment_ids = {r.get("comment_id") for r in mine}
        mention_review = mention_babysit = None
        for c in comments:
            body = (c.get("body") or "").lower()
            if not HANDLE or c["id"] in seen_comment_ids or f"@{HANDLE}" not in body or c["user"]["login"].lower() == HANDLE:
                continue
            if f"@{HANDLE} babysit" in body:
                mention_babysit = c
            elif f"@{HANDLE} review" in body or f"@{HANDLE}" in body:
                mention_review = c

        # Babysit claim state.
        beats = [HEARTBEAT_RE.search(c.get("body") or "") for c in comments]
        beats = [b for b in beats if b]
        claim = "none"
        sweep_owned = bool(beats) and beats[-1].group(1).startswith("babysit-pr")
        if "pr:babysat" in labels:
            try:
                t = datetime.fromisoformat(beats[-1].group(2).replace("Z", "+00:00")).timestamp()
                claim = "stale" if time.time() - t > STALE_MIN * 60 else "active"
            except (IndexError, ValueError):
                claim = "stale"
        babysitter_running = any(r["kind"] == "babysit" for r in running)
        if claim == "stale" and not babysitter_running:
            if not os.environ.get("PR_SWEEP_DRY"):
                gh("api", "-X", "DELETE", f"repos/{REPO}/issues/{n}/labels/pr:babysat", parse=False)
            out.append(f"PR #{n}: babysit claim went stale (> {STALE_MIN} min without heartbeat); claim removed, PR back to normal sweep handling.")
            claim = "none"

        # 2. Review dispatch (reviewer-side; runs regardless of any babysit claim).
        # A dispatch counts as done only if it wrote a result file; a dead session with no result
        # (crash, gateway restart) counts as a failure and is retried, up to MAX_FAILS per head.
        reviewer_running = any(r["kind"] == "review" for r in running)
        at_head = [r for r in mine if r["kind"] == "review" and r["head"] == head]
        review_done_at_head = any((RESULTS / f"{r.get('tag')}.json").exists() for r in at_head)
        fails = sum(1 for r in at_head if r.get("error") or (
            r.get("pid") and not alive(r["pid"]) and not (RESULTS / f"{r.get('tag')}.json").exists()))
        want_review = (label in ("pr:ready-review", "pr:re-review") and not review_done_at_head) or mention_review
        if label == "pr:in-review" and not reviewer_running and not review_done_at_head:
            want_review = True  # drift: in-review with nobody working it
        if want_review and not reviewer_running and not pr["isDraft"]:
            if fails >= MAX_FAILS:
                key = f"fails:{n}:{head}"
                if key not in reported:
                    reported.add(key)
                    out.append(f"PR #{n}: review dispatch failed {fails}x at {head[:8]}; not retrying.")
            else:
                rec = {"ts": time.time(), "kind": "review", "pr": n, "head": head,
                       "comment_id": mention_review["id"] if mention_review else None}
                try:
                    set_state_label(n, "pr:in-review")
                    rec["pid"], rec["tag"] = spawn("review", pr, head, "review.md", REVIEW_MODEL, REVIEW_REASONING,
                                                   REVIEW_SKILLS)
                except Exception as e:  # noqa: BLE001 — record and retry next tick
                    rec["error"] = str(e)[:300]
                append_record(rec)
                recs.append(rec)

        # 3. Babysit dispatch (author-side, one round per session). Only continue claims this sweep
        # owns; a chat-started babysitter has its own watcher and must not get a twin.
        fix_at_head = last_v and last_v[0] == "FIX" and head.startswith(last_v[1])
        round_done = any(r["kind"] == "babysit" and r["head"] == head and r.get("verdict_id") == (last_v[2]["id"] if last_v else None) for r in mine)
        want_babysit = (mention_babysit and claim == "none") or (claim == "active" and sweep_owned and fix_at_head and not round_done)
        if want_babysit and not babysitter_running:
            fix_loops = sum(1 for v in verdicts if v[0] == "FIX")
            rec = {"ts": time.time(), "kind": "babysit", "pr": n, "head": head,
                   "comment_id": mention_babysit["id"] if mention_babysit else None,
                   "verdict_id": last_v[2]["id"] if last_v else None}
            try:
                rec["pid"], rec["tag"] = spawn("babysit", pr, head, "babysit.md", BABYSIT_MODEL, "medium",
                                               BABYSIT_SKILLS,
                                               {"fix_loops": fix_loops})
            except Exception as e:  # noqa: BLE001
                rec["error"] = str(e)[:300]
            append_record(rec)
            recs.append(rec)

    REPORTED.write_text(json.dumps(sorted(reported)))
    if out:
        print("\n".join(out))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # noqa: BLE001 — surface the failure; never crash silently
        print(f"PR sweep error: {e}")
        sys.exit(1)
