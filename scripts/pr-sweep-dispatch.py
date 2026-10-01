#!/usr/bin/env python3
"""PR sweep dispatcher: the Hermes cron tick for PR automation (no LLM).

Each tick reads GitHub state for the owned repos, applies the rules in
docs/hermes/pr-automation.md, and launches one detached `hermes chat` session
per job: an independent Reviewer, or one author-side babysit round. The sessions
outlive the tick. Their verdicts land on GitHub, and a later tick delivers their
result files. stdout is the delivery to the human; empty stdout means a silent,
zero-token tick.

Install: copy this file and pr-sweep-prompts/ into $HERMES_HOME/scripts/, then
  hermes cron create "every 2m" --no-agent --script pr-sweep-dispatch.py --name pr-sweep

Environment:
  PR_SWEEP_REPOS          space-separated owner/repo list (required; PR_SWEEP_REPO also accepted)
  PR_AGENT_HANDLE         handles whose mentions trigger: `@h review` dispatches the Reviewer; any
                          other mention (`@h <instruction>`) dispatches an author-side babysit round
                          (space/comma-separated list: the account handle AND its natural aliases)
  PR_SHARED_ACCOUNT       1 when the human and the agent post as the same login: a comment by a
                          handle counts as a mention only if it carries no pipeline marker
                          (`<!-- ... -->` or a `babysit:` claim line)
  PR_SWEEP_CHECKOUT_ROOT  directory holding local checkouts named by repo (default ~/repos)
  PR_REVIEW_MODEL, PR_REVIEW_REASONING (medium), PR_REVIEW_SKILLS (pull-request)
  PR_BABYSIT_MODEL, PR_BABYSIT_SKILLS (babysit-pr)
  PR_SESSION_PROVIDER     provider passed to `hermes chat`
  PR_SWEEP_UNLABELED      ignore (default: opt-in) | review (drift: unlabeled = awaiting review)
  PR_BABYSIT_STALE_MIN    (60; chat-started claims only)   PR_REVIEW_STUCK_MIN (90)
  PR_BOT_REVIEWERS        bot logins whose reviews trigger sweep-owned babysit rounds
                          (default copilot-pull-request-reviewer[bot])
  PR_BOT_REVIEW_CAP       max bot-review rounds per PR (default 5)
  PR_SWEEP_STATE          state dir (default $HERMES_HOME/state/pr-automation)
  HERMES_BIN, GH_BIN, GH_TOKEN_FILE (token file used when GH_TOKEN is unset)
  PR_SWEEP_DRY=1          print the intended actions; mutate nothing, record nothing
"""
import json
import os
import pathlib
import re
import subprocess
import sys
import time
from datetime import datetime

ENV = os.environ
REPOS = (ENV.get("PR_SWEEP_REPOS") or ENV.get("PR_SWEEP_REPO") or "").split()
def parse_handles(raw):
    """PR_AGENT_HANDLE vocabulary: handles on whitespace or commas; '@' and case are normalized."""
    return tuple(h for h in (p.strip().lstrip("@").lower() for p in (raw or "").replace(",", " ").split()) if h)


HANDLES = parse_handles(ENV.get("PR_AGENT_HANDLE", ""))
HANDLE = HANDLES[0] if HANDLES else ""  # primary handle, for prompt templates
CHECKOUT_ROOT = pathlib.Path(ENV.get("PR_SWEEP_CHECKOUT_ROOT", str(pathlib.Path.home() / "repos")))
REVIEW_MODEL = ENV.get("PR_REVIEW_MODEL", "")
REVIEW_REASONING = ENV.get("PR_REVIEW_REASONING", "medium")
REVIEW_SKILLS = ENV.get("PR_REVIEW_SKILLS", "pull-request")
BABYSIT_MODEL = ENV.get("PR_BABYSIT_MODEL", "")
BABYSIT_SKILLS = ENV.get("PR_BABYSIT_SKILLS", "babysit-pr")
PROVIDER = ENV.get("PR_SESSION_PROVIDER", "")
UNLABELED = ENV.get("PR_SWEEP_UNLABELED", "ignore")
STALE_MIN = int(ENV.get("PR_BABYSIT_STALE_MIN", "60"))
BOT_REVIEWERS = tuple(ENV.get("PR_BOT_REVIEWERS", "copilot-pull-request-reviewer[bot]").split())
BOT_CAP = int(ENV.get("PR_BOT_REVIEW_CAP", "5"))
STUCK_MIN = int(ENV.get("PR_REVIEW_STUCK_MIN", "90"))
SHARED_ACCOUNT = ENV.get("PR_SHARED_ACCOUNT", "") not in ("", "0")
DRY = bool(ENV.get("PR_SWEEP_DRY"))
HERMES = ENV.get("HERMES_BIN", "hermes")
GH = ENV.get("GH_BIN", "gh")
TOKEN_FILE = pathlib.Path(ENV.get("GH_TOKEN_FILE", "/nonexistent"))
HOME = pathlib.Path(ENV.get("HERMES_HOME", str(pathlib.Path.home())))
STATE = pathlib.Path(ENV.get("PR_SWEEP_STATE", str(HOME / "state" / "pr-automation")))
DISPATCH, RESULTS, REPORTED, LOGS = STATE / "dispatches.jsonl", STATE / "results", STATE / "reported.json", STATE / "logs"
PROMPTS = pathlib.Path(__file__).resolve().parent / "pr-sweep-prompts"

MAX_FAILS = 3
STATE_LABELS = ["pr:ready-review", "pr:in-review", "pr:re-review", "pr:ready-merge", "pr:escalated"]
LABEL_PRIORITY = ["pr:in-review", "pr:re-review", "pr:ready-merge", "pr:escalated", "pr:ready-review"]
SWEEP_CLAIM_PREFIX = "babysit-pr"  # session ids of sweep-started babysits (see Babysit coexistence rule 7)
VERDICT_RE = re.compile(r"<!--\s*pr-review verdict=(READY|FIX|BLOCKED) head=([0-9a-f]{7,40})\s*-->")
HEARTBEAT_RE = re.compile(r"babysit: session=(\S+) heartbeat=(\S+)")

out = []  # lines delivered to the human


# ---------------------------------------------------------------- pure decisions

def state_label(labels, unlabeled=UNLABELED):
    """The PR's one state label, or None. Drift mode reads 'no label' as awaiting review."""
    label = next((l for l in LABEL_PRIORITY if l in labels), None)
    if label is None and unlabeled == "review" and "pr:babysat" not in labels:
        return "pr:ready-review"
    return label


def verdicts(comments):
    """[(verdict, head, comment)] in comment order, from the machine-readable marker."""
    return [(m.group(1), m.group(2), c) for c in comments
            for m in [VERDICT_RE.search(c.get("body") or "")] if m]


def claim_state(labels, comments, now_s, stale_min=STALE_MIN):
    """Babysit claim: 'none' | 'active' | 'stale'. A label with no readable heartbeat is stale.

    Sweep-owned claims never age: between rounds nobody runs by design, and the
    sweep tracks their sessions through its own dispatch records."""
    if "pr:babysat" not in labels:
        return "none"
    beats = [m for c in comments for m in [HEARTBEAT_RE.search(c.get("body") or "")] if m]
    if not beats:
        return "stale"
    if beats[-1].group(1).startswith(SWEEP_CLAIM_PREFIX):
        return "active"
    try:
        t = datetime.fromisoformat(beats[-1].group(2).replace("Z", "+00:00")).timestamp()
    except ValueError:
        return "stale"
    return "stale" if now_s - t > stale_min * 60 else "active"


def sweep_owned(comments):
    beats = [m for c in comments for m in [HEARTBEAT_RE.search(c.get("body") or "")] if m]
    return bool(beats) and beats[-1].group(1).startswith(SWEEP_CLAIM_PREFIX)


def bot_reviews(reviews, bots=BOT_REVIEWERS):
    """Completed reviews by configured bot accounts, oldest first."""
    return sorted((r for r in reviews if (r.get("user") or {}).get("login") in bots
                   and r.get("state") not in (None, "PENDING") and r.get("submitted_at")),
                  key=lambda r: r["id"])


def bot_round_due(bot_revs, handled_ids, cap=BOT_CAP):
    """(review, capped, seen_ids): the newest unhandled bot review if a round is due,
    whether the cap is hit, and ALL unhandled ids to record with the round.

    GitHub's review list is the counter: the cap counts completed bot reviews on the
    PR. The dispatch record carries every unhandled review id, not just the dispatched
    one, so several bot reviews landing between ticks are all consumed by the single
    round they trigger instead of queuing one no-op round each."""
    capped = len(bot_revs) > cap
    pending = [r for r in bot_revs if r["id"] not in handled_ids]
    if not pending or capped:
        return None, capped, []
    return pending[-1], False, [r["id"] for r in pending]


def ci_round_due(rollup, handled_keys, stamp_head, head):
    """(fires, key, ok): CI conclusions at the stamped READY head.

    key identifies (head, conclusion-set); None when out of scope — no READY
    verdict at this head, or the head moved past the stamp (push demotion owns
    that). fires is non-empty only when key is new AND some completed check
    failed. ok is overall health, used to restore a CI demotion once green.

    Red is an engine-level fact here: ANY completed failing check. The
    required-vs-advisory split lives in each repo's merge-gate manifest row
    and binds the Reviewer's verdict (docs/references/pr-review.md, Merge),
    not this demotion. Only check-run rollups (name/status/conclusion) are
    read; classic commit statuses (context/state) are ignored.
    """
    if not stamp_head or not head.startswith(stamp_head):
        return [], None, True
    bad = sorted(f"{c.get('name')} ({c.get('conclusion')})" for c in (rollup or [])
                 if c.get("status") == "COMPLETED" and c.get("conclusion") != "SUCCESS")
    key = f"{head[:12]}:" + (",".join(bad) if bad else "green")
    if key in handled_keys:
        return [], None, not bad
    if bad:
        return bad, key, False
    return [], key, True


def has_marker(body):
    """True for agent-authored comments: an HTML pipeline marker or a babysit claim line."""
    return "<!--" in body or bool(HEARTBEAT_RE.search(body))


def mentions(comments, handles, seen_ids, shared=SHARED_ACCOUNT):
    """Newest unprocessed (review_comment, babysit_comment) across the handle vocabulary.

    `@h review` is the only phrase that dispatches the Reviewer; any other mention
    is an instruction for the author-side babysit round. A comment by one of the
    configured handles is ignored (self-mention) unless the account is shared with
    the human (`shared`) and the comment carries no pipeline marker.
    """
    review = babysit = None
    if not handles:
        return None, None
    tags = [f"@{h}" for h in handles]
    for c in comments:
        body = (c.get("body") or "").lower()
        if c["id"] in seen_ids:
            continue
        if c["user"]["login"].lower() in handles and not (shared and not has_marker(body)):
            continue
        hit = next((t for t in tags if t in body), None)
        if hit is None:
            continue
        if re.search(re.escape(hit) + r"[\s,:]+review\b", body):
            review = c
        else:
            babysit = c
    return review, babysit


def fixed_without_push(rec):
    """A babysit round that handled findings (status FIXED) and left the head unchanged."""
    try:
        return json.loads((RESULTS / f"{rec.get('tag')}.json").read_text()).get("status") == "FIXED"
    except (OSError, ValueError):
        return False


# ---------------------------------------------------------------- side effects

def gh(*args, parse=True):
    env = {k: v for k, v in ENV.items() if not k.startswith(("HERMES_CRON", "HERMES_SESSION"))}
    if "GH_TOKEN" not in env and TOKEN_FILE.exists():
        env["GH_TOKEN"] = TOKEN_FILE.read_text().strip()
    r = subprocess.run([GH, *args], capture_output=True, text=True, env=env, timeout=60)
    if r.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args[:3])} failed: {r.stderr.strip()[:300]}")
    return json.loads(r.stdout) if parse and r.stdout.strip() else r.stdout


def alive(pid):
    try:
        return b"hermes" in pathlib.Path(f"/proc/{pid}/cmdline").read_bytes()
    except OSError:
        return False


def has_result(rec):
    return (RESULTS / f"{rec.get('tag')}.json").exists()


def set_state_label(repo, n, label):
    if DRY:
        out.append(f"DRY: would set {repo}#{n} label {label}")
        return
    cur = [l["name"] for l in gh("api", f"repos/{repo}/issues/{n}/labels")]
    for l in cur:
        if l in STATE_LABELS and l != label:
            gh("api", "-X", "DELETE", f"repos/{repo}/issues/{n}/labels/{l}", parse=False)
    if label and label not in cur:
        gh("api", "-X", "POST", f"repos/{repo}/issues/{n}/labels", "-f", f"labels[]={label}", parse=False)


def remove_label(repo, n, label):
    if not DRY:
        gh("api", "-X", "DELETE", f"repos/{repo}/issues/{n}/labels/{label}", parse=False)


def spawn(kind, repo, pr, head, model, reasoning, skills, extra=None):
    """Launch a detached Hermes session (new session, stdin closed); it outlives this tick."""
    n = pr["number"]
    tag = f"{kind}-pr{n}-{head[:8]}-{int(time.time())}"
    if DRY:
        out.append(f"DRY: would spawn {kind} for {repo}#{n} at {head[:8]}")
        return 0, tag
    prompt = (PROMPTS / f"{kind}.md").read_text().format(
        repo=repo, number=n, head=head, short_head=head[:7], title=pr["title"], branch=pr["headRefName"],
        checkout=str(CHECKOUT_ROOT / repo.split("/")[-1]), hermes=HERMES, handle=HANDLE,
        result_file=str(RESULTS / f"{tag}.json"), tag=tag, **(extra or {}))
    pfile = LOGS / f"{tag}.prompt.md"
    pfile.write_text(prompt)
    title = f"PR #{n} {kind} @{head[:7]} — {repo.split('/')[-1]}: {pr['title'][:50]}"
    env = {k: v for k, v in ENV.items() if not k.startswith(("HERMES_CRON", "HERMES_SESSION"))}
    with open(LOGS / f"{tag}.log", "w") as log:
        p = subprocess.Popen(
            [HERMES, "chat", "-Q", "--oneshot", "--query-file", str(pfile), "--source", "pr-automation",
             "--continue", title, "--create-if-missing", "--reasoning", reasoning, "-s", skills,
             *(["-m", model] if model else []), *(["--provider", PROVIDER] if PROVIDER else [])],
            stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT, env=env,
            start_new_session=True, close_fds=True)
    return p.pid, tag


def record(recs, rec):
    recs.append(rec)
    if not DRY:
        with DISPATCH.open("a") as f:
            f.write(json.dumps(rec, sort_keys=True) + "\n")


# ---------------------------------------------------------------- the tick

def sweep_repo(repo, recs, reported):
    pulls = gh("pr", "list", "-R", repo, "--state", "open", "--limit", "100",
               "--json", "number,title,headRefName,headRefOid,labels,isDraft,statusCheckRollup")
    for pr in sorted(pulls, key=lambda p: p["number"]):
        n, head = pr["number"], pr["headRefOid"]
        labels = [l["name"] for l in pr["labels"]]
        label = state_label(labels)
        comments = gh("api", f"repos/{repo}/issues/{n}/comments?per_page=100")
        # Inline review-thread comments are mention surfaces too; "r"-prefixed ids keep the two
        # comment id spaces apart in the dispatch record.
        inline = [dict(c, id=f"r{c['id']}") for c in gh("api", f"repos/{repo}/pulls/{n}/comments?per_page=100")]
        reviews = gh("api", f"repos/{repo}/pulls/{n}/reviews?per_page=100")
        vs = verdicts(comments)
        last_v = vs[-1] if vs else None
        mine = [r for r in recs if r.get("repo") == repo and r["pr"] == n]
        running = [r for r in mine if r.get("pid") and alive(r["pid"])]

        for r in running:  # stuck: a live session past its budget, reported once
            age = (time.time() - r["ts"]) / 60
            key = f"stuck:{r['tag']}"
            if age > STUCK_MIN and key not in reported:
                reported.add(key)
                out.append(f"{repo}#{n}: {r['kind']} session {r['tag']} still running after {int(age)} min "
                           f"(pid {r['pid']}); log {LOGS / (r['tag'] + '.log')}")

        # Push demotion: a verdict whose head is not the PR head is stale.
        if label in ("pr:ready-merge", "pr:escalated") and last_v and not head.startswith(last_v[1]):
            set_state_label(repo, n, "pr:re-review")
            label = "pr:re-review"
            if last_v[0] == "READY":
                out.append(f"{repo}#{n}: new commits after READY at {last_v[1][:8]}; moved back to pr:re-review.")

        # CI gate (merge contract): required checks red at the stamped READY head
        # invalidate mergeable advice; the babysitting author owns the fix; green
        # restores. A CI fix round is maintenance, not a verdict response.
        ci_fires, ci_key, ci_ok = ci_round_due(pr.get("statusCheckRollup"),
                                               {r.get("ci_key") for r in mine if r["kind"] == "babysit"},
                                               last_v[1] if last_v else None, head)
        if ci_fires:
            if label == "pr:ready-merge":
                set_state_label(repo, n, "pr:re-review")
                label = "pr:re-review"
                reported.add(f"ci:{repo}#{n}:{ci_key}")
                out.append(f"{repo}#{n}: CI red at the READY head ({'; '.join(ci_fires)}); moved back to pr:re-review until green.")
            elif label in ("pr:in-review", "pr:re-review"):
                rkey = f"ci:{repo}#{n}:{ci_key}"
                if rkey not in reported:
                    reported.add(rkey)
                    out.append(f"{repo}#{n}: CI red ({'; '.join(ci_fires)}); the babysitting author owns the fix.")
        elif ci_ok and ci_key and label == "pr:re-review" and last_v and last_v[0] == "READY":
            set_state_label(repo, n, "pr:ready-merge")
            label = "pr:ready-merge"
            out.append(f"{repo}#{n}: CI green at the READY head; restored pr:ready-merge.")

        mention_review, mention_babysit = mentions(comments + inline, HANDLES, {r.get("comment_id") for r in mine})

        claim = claim_state(labels, comments, time.time())
        babysitter_running = any(r["kind"] == "babysit" for r in running)
        if claim == "stale" and not babysitter_running:
            remove_label(repo, n, "pr:babysat")
            out.append(f"{repo}#{n}: babysit claim went stale (> {STALE_MIN} min without heartbeat); "
                       "claim removed, PR back to normal sweep handling.")
            claim = "none"

        # Reviewer side: runs regardless of any babysit claim. A dispatch is done only when it wrote a
        # result file; a dead session without one is a failed dispatch, retried up to MAX_FAILS per head.
        reviewer_running = any(r["kind"] == "review" for r in running)
        at_head = [r for r in mine if r["kind"] == "review" and r["head"] == head]
        done_at_head = any(has_result(r) for r in at_head)
        fails = sum(1 for r in at_head if r.get("error") or (r.get("pid") and not alive(r["pid"]) and not has_result(r)))
        # A babysit round that resolved findings without pushing leaves the head unchanged, so no push
        # demotion fires; the same head is re-reviewed once after such a round.
        last_review_ts = max((r["ts"] for r in at_head), default=0)
        babysat_after = label == "pr:re-review" and any(
            r["kind"] == "babysit" and r["head"] == head and r["ts"] > last_review_ts and fixed_without_push(r)
            for r in mine)
        want_review = (label in ("pr:ready-review", "pr:re-review") and (not done_at_head or babysat_after)) or bool(mention_review)
        if label == "pr:in-review" and not reviewer_running and not done_at_head:
            want_review = True  # drift: in-review with nobody working it
        if want_review and not reviewer_running and not pr["isDraft"]:
            if fails >= MAX_FAILS:
                key = f"fails:{repo}#{n}:{head}"
                if key not in reported:
                    reported.add(key)
                    out.append(f"{repo}#{n}: review dispatch failed {fails}x at {head[:8]}; not retrying.")
            else:
                rec = {"ts": time.time(), "kind": "review", "repo": repo, "pr": n, "head": head,
                       "comment_id": mention_review["id"] if mention_review else None}
                try:
                    set_state_label(repo, n, "pr:in-review")
                    rec["pid"], rec["tag"] = spawn("review", repo, pr, head, REVIEW_MODEL, REVIEW_REASONING, REVIEW_SKILLS)
                except Exception as e:  # noqa: BLE001 — recorded; retried next tick
                    rec["error"] = str(e)[:300]
                record(recs, rec)

        # Author side: one babysit round per session. Only continue sweep-owned claims; a chat-started
        # babysitter runs its own watcher and must not get a twin.
        fix_at_head = bool(last_v) and last_v[0] == "FIX" and head.startswith(last_v[1])
        verdict_id = last_v[2]["id"] if last_v else None
        round_done = any(r["kind"] == "babysit" and r["head"] == head and r.get("verdict_id") == verdict_id for r in mine)
        owned = claim == "active" and sweep_owned(comments)
        # A CI red is author-ownable maintenance even with nobody on the PR: a
        # READY-stamped head may not sit red unclaimed until green. The round
        # posts its own sweep-owned claim (prompt step 1); chat-started
        # claims still get no twin, and a stale claim recovers above.
        ci_round = (owned or claim == "none") and bool(ci_fires)
        handled_bots = set()
        for r in mine:
            if r.get("bot_review_id"):
                handled_bots.add(r["bot_review_id"])
            handled_bots.update(r.get("bot_review_ids") or [])
        bot_rev, capped, bot_seen = bot_round_due(bot_reviews(reviews), handled_bots)
        if capped and owned:
            key = f"botcap:{repo}#{n}"
            if key not in reported:
                reported.add(key)
                out.append(f"{repo}#{n}: bot-review cap ({BOT_CAP}) reached; no more bot rounds.")
        fix_round = owned and fix_at_head and not round_done
        bot_round = owned and bot_rev is not None and not fix_round
        # A mention is an explicit instruction: it runs under no claim or a sweep-owned one, never twinning a chat watcher.
        mention_round = bool(mention_babysit) and (claim == "none" or owned)
        want_babysit = mention_round or fix_round or bot_round or ci_round
        if want_babysit and not babysitter_running:
            rec = {"ts": time.time(), "kind": "babysit", "repo": repo, "pr": n, "head": head,
                   "comment_id": mention_babysit["id"] if mention_round else None,
                   "verdict_id": verdict_id if fix_round or mention_round else None,
                   "bot_review_id": bot_rev["id"] if bot_round else None,
                   "bot_review_ids": bot_seen if bot_round else [],
                   "ci_key": ci_key if ci_round else None}
            try:
                rec["pid"], rec["tag"] = spawn("babysit", repo, pr, head, BABYSIT_MODEL, "medium", BABYSIT_SKILLS,
                                               {"fix_loops": sum(1 for v in vs if v[0] == "FIX"),
                                                "bot_rounds": len(bot_reviews(reviews)), "bot_cap": BOT_CAP,
                                                "trigger": "mention" if mention_round else "CI red" if ci_round else ("bot review" if bot_round else "verdict"),
                                                "mention_ref": str(mention_babysit["id"]) if mention_round else ""})
            except Exception as e:  # noqa: BLE001
                rec["error"] = str(e)[:300]
            record(recs, rec)


def main():
    if not REPOS:
        print("PR sweep error: set PR_SWEEP_REPOS")
        return 1
    for d in (STATE, RESULTS, LOGS):
        d.mkdir(parents=True, exist_ok=True)
    recs = [json.loads(l) for l in DISPATCH.read_text().splitlines() if l.strip()] if DISPATCH.exists() else []
    reported = set(json.loads(REPORTED.read_text())) if REPORTED.exists() else set()

    # Deliver finished sessions: READY / BLOCKED / ESCALATE / babysit exits. FIX stays silent.
    for f in sorted(RESULTS.glob("*.json")):
        if f.name in reported:
            continue
        try:
            r = json.loads(f.read_text())
        except ValueError:
            continue
        reported.add(f.name)
        if r.get("notify", True) and r.get("verdict") != "FIX":
            out.append(f"{r.get('repo', '')}#{r.get('pr')} [{r.get('verdict', r.get('status', '?'))}] "
                       f"{r.get('summary', '').strip()} {r.get('url', '')}".strip())

    errors = []
    for repo in sorted(REPOS):
        try:
            sweep_repo(repo, recs, reported)
        except Exception as e:  # noqa: BLE001 — one repo failing must not starve the others
            errors.append(f"PR sweep error ({repo}): {e}")
    if not DRY:
        REPORTED.write_text(json.dumps(sorted(reported)))
    lines = out + errors
    if lines:
        print("\n".join(lines))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
