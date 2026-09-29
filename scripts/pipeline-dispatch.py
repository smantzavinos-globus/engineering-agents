#!/usr/bin/env python3
"""Delivery-pipeline dispatcher: the Hermes cron ticks for backlog items (no LLM).

One script, three jobs (docs/references/delivery-pipeline.md §5, §7):

  pipeline-dispatch.py triage    every ~15 min: Inbox / answered Clarification items -> one triage session
  pipeline-dispatch.py work      every ~3 min: gate/unblock replies, dead sessions, Up next pickups
                                 under the WIP limit, worktree cleanup -> one work session per item
  pipeline-dispatch.py hygiene   weekly: report stale waiting states and unlabeled PRs (no sessions)

The tick decides WHO works on WHICH item, never how. Sessions run the `triage-backlog` and
`work-item` skills. stdout is the delivery to the human; empty stdout is a silent tick.

Install: copy this file and pipeline-prompts/ into $HERMES_HOME/scripts/, then e.g.
  hermes cron create "every 15m" --no-agent --script "pipeline-dispatch.py triage" --name pipeline-triage
  hermes cron create "every 3m"  --no-agent --script "pipeline-dispatch.py work"   --name pipeline-work
  hermes cron create "every 7d"  --no-agent --script "pipeline-dispatch.py hygiene" --name pipeline-hygiene

Environment:
  PIPELINE_REPO           owner/repo whose issues are the backlog (required)
  PIPELINE_CHECKOUT       local checkout of that repo (required; tracker commands run here)
  PIPELINE_LIST_CMD       prints the backlog as a JSON array (required), each item:
                          {"number", "title", "status", "stage", "track", "priority", "autonomy", "updatedAt"}
  PIPELINE_MOVE_CMD       moves an item (required); tokens {number} {status}; `--comment <text>` is
                          appended when a comment is required. Example:
                          "node scripts/backlog.mjs move {number} {status}"
  PIPELINE_OWNERS         logins whose comments count as replies (required)
  PR_AGENT_HANDLE         agent handles replies mention (required; same vocabulary as the PR sweep)
  PIPELINE_SHARED_ACCOUNT=1  the owner and the agent post from the same login. Replies are then
                          recognised by format alone: an owner-login comment counts only if it
                          carries no pipeline marker (`<!-- ... -->`, `work:`/`babysit:` claim lines).
                          Sessions must never start a comment with `@<handle> <verb>`.
  PIPELINE_BASE           base branch for new item branches (default main)
  PIPELINE_WORKTREE_ROOT  where item worktrees live (default <checkout>-worktrees)
  PIPELINE_WIP            In progress limit (default 2)
  PIPELINE_TRACKS         tracks eligible for pickup (default: all four)
  PIPELINE_PARK_LABEL     label that parks a `discuss` reply (default pipeline:discuss)
  PIPELINE_TRIAGE_MODEL, PIPELINE_TRIAGE_SKILLS (backlog,triage-backlog)
  PIPELINE_WORK_MODEL, PIPELINE_WORK_SKILLS (backlog,work-item), PIPELINE_REASONING (medium)
  PIPELINE_SESSION_PROVIDER, PIPELINE_STALE_DAYS (hygiene, default 3)
  PIPELINE_STATE          state dir (default $HERMES_HOME/state/pipeline)
  HERMES_BIN, GH_BIN, GH_TOKEN_FILE (token file used when GH_TOKEN is unset)
  PIPELINE_DRY=1          print intended actions; mutate nothing, record nothing
"""
import json
import os
import pathlib
import re
import shlex
import subprocess
import sys
import time
from datetime import datetime, timezone

ENV = os.environ


def _handles(raw):
    return tuple(h for h in (p.strip().lstrip("@").lower() for p in (raw or "").replace(",", " ").split()) if h)


REPO = ENV.get("PIPELINE_REPO", "")
CHECKOUT = pathlib.Path(ENV.get("PIPELINE_CHECKOUT", "."))
LIST_CMD = ENV.get("PIPELINE_LIST_CMD", "")
MOVE_CMD = ENV.get("PIPELINE_MOVE_CMD", "")
OWNERS = tuple(o.lower() for o in _handles(ENV.get("PIPELINE_OWNERS", "")))
HANDLES = _handles(ENV.get("PR_AGENT_HANDLE", ""))
SHARED = bool(ENV.get("PIPELINE_SHARED_ACCOUNT"))
AGENT_MARK = re.compile(r"<!--|^\s*(work|babysit):\s", re.M)
BASE = ENV.get("PIPELINE_BASE", "main")
WT_ROOT = pathlib.Path(ENV.get("PIPELINE_WORKTREE_ROOT", str(CHECKOUT) + "-worktrees"))
WIP = int(ENV.get("PIPELINE_WIP", "2"))
TRACKS = tuple(ENV.get("PIPELINE_TRACKS", "fast-path standard-implementation analysis-spike docs-process").split())
PARK = ENV.get("PIPELINE_PARK_LABEL", "pipeline:discuss")
TRIAGE_MODEL = ENV.get("PIPELINE_TRIAGE_MODEL", "")
TRIAGE_SKILLS = ENV.get("PIPELINE_TRIAGE_SKILLS", "backlog,triage-backlog")
WORK_MODEL = ENV.get("PIPELINE_WORK_MODEL", "")
WORK_SKILLS = ENV.get("PIPELINE_WORK_SKILLS", "backlog,work-item")
REASONING = ENV.get("PIPELINE_REASONING", "medium")
PROVIDER = ENV.get("PIPELINE_SESSION_PROVIDER", "")
STALE_DAYS = float(ENV.get("PIPELINE_STALE_DAYS", "3"))
DRY = bool(ENV.get("PIPELINE_DRY"))
HERMES = ENV.get("HERMES_BIN", "hermes")
GH = ENV.get("GH_BIN", "gh")
TOKEN_FILE = pathlib.Path(ENV.get("GH_TOKEN_FILE", "/nonexistent"))
HOME = pathlib.Path(ENV.get("HERMES_HOME", str(pathlib.Path.home())))
STATE = pathlib.Path(ENV.get("PIPELINE_STATE", str(HOME / "state" / "pipeline")))
DISPATCH, RESULTS, REPORTED, LOGS = STATE / "dispatches.jsonl", STATE / "results", STATE / "reported.json", STATE / "logs"
PROMPTS = pathlib.Path(__file__).resolve().parent / "pipeline-prompts"

MAX_FAILS = 3
PRIORITY_ORDER = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}
VERBS = ("approve", "revise:", "discuss", "reject", "unblock:")
GATE_RE = re.compile(r"<!--\s*gate stage=(\w+)((?:\s+\w+=\S+)*)\s*-->")
TRIAGE_RE = re.compile(r"<!--\s*triage outcome=(ready|clarify|left)\s*-->")

out = []  # lines delivered to the human


# ---------------------------------------------------------------- pure decisions

def parse_reply(comment, handles=HANDLES, owners=OWNERS, shared=None):
    """(verb, body) if the comment is an owner reply per the dispatch contract, else None.

    With a shared account (owner login == agent login), a comment from that login is a
    reply only if it carries no agent marker; agent sessions never write reply lines."""
    shared = SHARED if shared is None else shared
    login = ((comment.get("user") or {}).get("login") or "").lower()
    if login not in owners:
        return None
    if login in handles and not (shared and not AGENT_MARK.search(comment.get("body") or "")):
        return None
    lines = [l.strip() for l in (comment.get("body") or "").splitlines() if l.strip()]
    if not lines:
        return None
    m = re.match(r"^@(\S+)\s+(\S+)(.*)$", lines[0], re.I)
    if not m or m.group(1).lower() not in handles:
        return None
    word = m.group(2).lower()
    verb = next((v for v in VERBS if word == v or (v.endswith(":") and word.startswith(v))), None)
    if verb is None:
        return None
    rest = (m.group(2)[len(verb):] if verb.endswith(":") else "") + m.group(3)
    body = "\n".join([rest.strip(), *lines[1:]]).strip()
    return verb.rstrip(":"), body


SAFE_PATH = re.compile(r"^[A-Za-z0-9._/-]+$")


def by_agent(comment, handles=HANDLES):
    return ((comment.get("user") or {}).get("login") or "").lower() in handles


def latest_gate(comments, handles=HANDLES):
    """(comment, stage, attrs) of the newest gate marker posted by the agent itself, or None.

    Markers from anyone else are ignored, so a commenter cannot forge a gate; `plan`
    must be a plain relative path."""
    for c in reversed(comments):
        m = GATE_RE.search(c.get("body") or "") if by_agent(c, handles) else None
        if m:
            attrs = dict(kv.split("=", 1) for kv in m.group(2).split())
            plan = attrs.get("plan", "")
            if plan and (not SAFE_PATH.match(plan) or ".." in plan.split("/") or plan.startswith("/")):
                attrs["plan"] = ""
            return c, m.group(1), attrs
    return None


def pending_reply(comments, after_id, consumed, allowed):
    """The first unconsumed owner reply with an allowed verb posted after comment `after_id`.

    `consumed` holds comment IDs already acted on for this item."""
    for c in comments:
        if c["id"] <= after_id or c["id"] in consumed:
            continue
        r = parse_reply(c)
        if r and r[0] in allowed:
            return c, r[0], r[1]
    return None


def needs_triage(item, comments, owners=OWNERS):
    """Inbox with no triage marker yet, or Clarification needed with an owner comment after the last marker."""
    marks = [c["id"] for c in comments if by_agent(c) and TRIAGE_RE.search(c.get("body") or "")]
    if item["status"] == "Inbox":
        return not marks
    if item["status"] == "Clarification needed":
        last = marks[-1] if marks else 0
        return any(c["id"] > last and ((c.get("user") or {}).get("login") or "").lower() in owners for c in comments)
    return False


def pickup_order(items, tracks=TRACKS):
    """Up next items eligible for pickup: Priority, then oldest (lowest number) first."""
    ups = [i for i in items if i["status"] == "Up next" and (i.get("track") or "") in tracks]
    return sorted(ups, key=lambda i: (PRIORITY_ORDER.get(i.get("priority") or "", 9), i["number"]))


def free_slots(items, wip=WIP):
    return max(0, wip - sum(1 for i in items if i["status"] == "In progress"))


def next_step(stage, verb):
    """Human-readable step for the session prompt (the work-item skill holds the full table)."""
    if verb == "unblock":
        return f"continue the blocked {stage or 'current'} stage with the reply"
    if verb == "revise":
        return f"rerun the {stage} stage with the reply, then gate again"
    return {"Design": "Plan", "Plan": "Execute",
            "Findings": "capture the approved follow-ups, then close the item as Done",
            "Escalation": "continue the stage that escalated, using the recommended answers"}.get(stage, stage)


# ---------------------------------------------------------------- side effects

def env_clean():
    env = {k: v for k, v in ENV.items() if not k.startswith(("HERMES_CRON", "HERMES_SESSION"))}
    if "GH_TOKEN" not in env and TOKEN_FILE.exists():
        env["GH_TOKEN"] = TOKEN_FILE.read_text().strip()
    return env


def run(argv, cwd=None, parse=False):
    r = subprocess.run(argv, capture_output=True, text=True, env=env_clean(), cwd=cwd, timeout=300)
    if r.returncode != 0:
        raise RuntimeError(f"{' '.join(argv[:4])} failed: {(r.stderr or r.stdout).strip()[:300]}")
    return json.loads(r.stdout) if parse and r.stdout.strip() else r.stdout


def gh(*args, parse=True):
    return run([GH, *args], parse=parse)


def list_items():
    items = run(shlex.split(LIST_CMD), cwd=str(CHECKOUT), parse=True)
    for i in items:
        i["number"] = int(i["number"])
    return items


def comments_of(n):
    pages = gh("api", "--paginate", "--slurp", f"repos/{REPO}/issues/{n}/comments?per_page=100")
    return [c for page in pages for c in page] if pages and isinstance(pages[0], list) else (pages or [])


def labels_of(n):
    return [l["name"] for l in gh("api", f"repos/{REPO}/issues/{n}/labels")]


def move(n, status, comment=None):
    if DRY:
        out.append(f"DRY: would move #{n} to {status}" + (" with comment" if comment else ""))
        return
    argv = [t.format(number=n, status=status) for t in shlex.split(MOVE_CMD)]
    run(argv + (["--comment", comment] if comment else []), cwd=str(CHECKOUT))


def add_label(n, label):
    if DRY:
        out.append(f"DRY: would label #{n} {label}")
        return
    gh("api", "-X", "POST", f"repos/{REPO}/issues/{n}/labels", "-f", f"labels[]={label}", parse=False)


def alive(pid):
    try:
        return b"hermes" in pathlib.Path(f"/proc/{pid}/cmdline").read_bytes()
    except OSError:
        return False


def has_result(rec):
    return (RESULTS / f"{rec.get('tag')}.json").exists()


def worktree(n, reason):
    """Path of item n's worktree on item/<n>, created from the pushed branch or the base."""
    path = WT_ROOT / f"item-{n}"
    if DRY:
        return path
    git = ["git", "-C", str(CHECKOUT)]
    if path.exists():  # bring it up to the pushed branch (a live discuss session may have pushed)
        run(git + ["fetch", "--quiet", "origin"])
        if run(git + ["ls-remote", "--heads", "origin", f"item/{n}"]).strip():
            run(["git", "-C", str(path), "merge", "--ff-only", "--quiet", f"origin/item/{n}"])
        return path
    run(git + ["fetch", "--quiet", "origin"])
    remote = run(git + ["ls-remote", "--heads", "origin", f"item/{n}"]).strip()
    if reason != "start" and not remote:
        raise RuntimeError(f"item/{n} is not on origin; the gate should have pushed it")
    start = f"origin/item/{n}" if remote else f"origin/{BASE}"
    WT_ROOT.mkdir(parents=True, exist_ok=True)
    run(git + ["worktree", "add", "-B", f"item/{n}", str(path), start])
    return path


def spawn(kind, n, title, extra):
    tag = f"{kind}-item{n}-{int(time.time())}" if kind == "work" else f"triage-{int(time.time())}"
    if DRY:
        what = extra.get("reason") or extra.get("items")
        out.append(f"DRY: would spawn {kind} for #{n}" + (f" ({what})" if what else ""))
        return 0, tag
    if "reply_body" in extra:  # keep untrusted text inside its fence
        extra = {**extra, "reply_body": re.sub(r"(?m)^\s*~{3,}", "", extra["reply_body"])}
    prompt = (PROMPTS / f"{kind}.md").read_text().format(
        repo=REPO, number=n, title=title, handle=HANDLES[0] if HANDLES else "", tag=tag,
        result_file=str(RESULTS / f"{tag}.json"), checkout=str(CHECKOUT), **extra)
    pfile = LOGS / f"{tag}.prompt.md"
    pfile.write_text(prompt)
    name = f"Item #{n} {extra.get('reason', kind)} {tag} — {title[:50]}" if kind == "work" else f"Backlog triage {tag}"
    model, skills = (WORK_MODEL, WORK_SKILLS) if kind == "work" else (TRIAGE_MODEL, TRIAGE_SKILLS)
    with open(LOGS / f"{tag}.log", "w") as log:
        p = subprocess.Popen(
            [HERMES, "chat", "-Q", "--oneshot", "--query-file", str(pfile), "--source", "pipeline",
             "--continue", name, "--create-if-missing", "--reasoning", REASONING, "-s", skills,
             *(["-m", model] if model else []), *(["--provider", PROVIDER] if PROVIDER else [])],
            cwd=str(extra.get("worktree") or CHECKOUT), stdin=subprocess.DEVNULL, stdout=log,
            stderr=subprocess.STDOUT, env=env_clean(), start_new_session=True, close_fds=True)
    return p.pid, tag


def record(recs, rec):
    recs.append(rec)
    if not DRY:
        with DISPATCH.open("a") as f:
            f.write(json.dumps(rec, sort_keys=True) + "\n")


def report_once(reported, key, line):
    if key not in reported:
        reported.add(key)
        out.append(line)


# ---------------------------------------------------------------- jobs

def job_triage(items, recs, reported):
    if any(r["kind"] == "triage" and r.get("pid") and alive(r["pid"]) for r in recs):
        return
    due = [i for i in items if i["status"] in ("Inbox", "Clarification needed") and needs_triage(i, comments_of(i["number"]))]
    if not due:
        return
    nums = [i["number"] for i in due]
    rec = {"ts": time.time(), "kind": "triage", "items": nums}
    try:
        rec["pid"], rec["tag"] = spawn("triage", nums[0], "triage", {"items": " ".join(f"#{n}" for n in nums)})
    except Exception as e:  # noqa: BLE001 — recorded; retried next tick
        rec["error"] = str(e)[:300]
    record(recs, rec)


def dispatch_work(recs, item, reason, reply=None, reply_verb=None, stage=None, gate_attrs=None):
    n = item["number"]
    rec = {"ts": time.time(), "kind": "work", "item": n, "reason": reason, "stage": stage or item.get("stage"),
           "reply_id": reply["id"] if reply else None, "verb": reply_verb,
           "reply_body": (reply or {}).get("_body", ""), "plan": (gate_attrs or {}).get("plan", "")}
    try:
        wt = worktree(n, reason)
        if item["status"] != "In progress":
            move(n, "In progress")
        rec["pid"], rec["tag"] = spawn("work", n, item["title"], {
            "reason": reason, "worktree": str(wt), "branch": f"item/{n}", "track": item.get("track") or "",
            "stage": stage or item.get("stage") or "", "autonomy": item.get("autonomy") or "gated",
            "reply_verb": reply_verb or "", "reply_body": (reply or {}).get("_body", ""),
            "plan_dir": (gate_attrs or {}).get("plan", ""),
            "next_step": next_step(stage, reply_verb) if reply_verb else "first step of the track"})
    except Exception as e:  # noqa: BLE001
        rec["error"] = str(e)[:300]
    record(recs, rec)


def result_of(rec):
    try:
        return json.loads((RESULTS / f"{rec.get('tag')}.json").read_text())
    except (OSError, ValueError):
        return None


def failed(rec):
    """A dispatch failed: spawn error, or the session is gone with no result or an explicit failure."""
    if rec.get("error"):
        return True
    if rec.get("pid") and alive(rec["pid"]):
        return False
    res = result_of(rec)
    return res is None or res.get("outcome") == "failed"


def retry(recs, item, last):
    """Re-dispatch a failed session with everything it was given."""
    reply = {"id": last["reply_id"], "_body": last.get("reply_body", "")} if last.get("reply_id") else None
    dispatch_work(recs, item, last["reason"], reply=reply, reply_verb=last.get("verb"),
                  stage=last.get("stage"), gate_attrs={"plan": last.get("plan", "")})


def job_work(items, recs, reported):
    work = [r for r in recs if r["kind"] == "work"]
    running = {r["item"] for r in work if r.get("pid") and alive(r["pid"])}
    consumed = {(r["item"], r["reply_id"]) for r in recs if r.get("reply_id") and not r.get("error")}
    slots = free_slots(items)
    errors = []

    def guarded(n, fn):
        try:
            fn()
        except Exception as e:  # noqa: BLE001 — one item must not starve the rest of the tick
            errors.append(f"#{n}: {e}")

    # 1. In progress items nobody is working: retry failed sessions (bounded), flag the rest.
    for i in (i for i in items if i["status"] == "In progress" and i["number"] not in running):
        n = i["number"]
        mine = [r for r in work if r["item"] == n]
        if not mine:
            report_once(reported, f"orphan:{n}", f"#{n} is In progress with no dispatched session; "
                        "move it back to Up next to let the pipeline pick it up.")
            continue
        last = mine[-1]
        if not failed(last):
            res = result_of(last) or {}
            report_once(reported, f"stuck:{last.get('tag')}",
                        f"#{n}: session ended with outcome {res.get('outcome', '?')} but the item is still "
                        "In progress; check the item's status.")
            continue
        fails = [r for r in mine if r.get("stage") == last.get("stage") and r.get("reason") == last.get("reason")
                 and failed(r)]
        if len(fails) >= MAX_FAILS:
            report_once(reported, f"fails:{n}:{last.get('stage')}",
                        f"#{n}: work session failed {len(fails)}x at stage {last.get('stage')}; not retrying. "
                        f"Log {LOGS / (str(last.get('tag')) + '.log')}")
            continue
        guarded(n, lambda i=i, last=last: retry(recs, i, last))
        running.add(n)

    # 2. Replies on gated and blocked items. Resumes come before pickups and need a slot.
    for i in sorted(items, key=lambda i: i["number"]):
        n = i["number"]
        if n in running or i["status"] not in ("Awaiting approval", "Blocked"):
            continue

        def handle(i=i, n=n):
            nonlocal slots
            comments = comments_of(n)
            gate = latest_gate(comments)
            if i["status"] == "Awaiting approval":
                if PARK in labels_of(n):
                    return
                if not gate:
                    report_once(reported, f"nogate:{n}", f"#{n} is Awaiting approval but has no gate marker.")
                    return
                mine = {rid for (item_n, rid) in consumed if item_n == n}
                hit = pending_reply(comments, gate[0]["id"], mine, ("approve", "revise", "discuss", "reject"))
            else:
                mine = {rid for (item_n, rid) in consumed if item_n == n}
                hit = pending_reply(comments, 0, mine, ("unblock",))
            if not hit:
                return
            c, verb, body = hit
            c["_body"] = body
            if verb in ("discuss", "reject"):
                if verb == "discuss":
                    add_label(n, PARK)
                else:
                    move(n, "Canceled", body or "Rejected at the gate by the owner.")
                record(recs, {"ts": time.time(), "kind": "reply", "item": n, "reply_id": c["id"], "verb": verb})
                consumed.add((n, c["id"]))
                return
            if slots <= 0:
                return
            slots -= 1
            stage = gate[1] if gate and verb != "unblock" else i.get("stage")
            dispatch_work(recs, i, "unblock" if verb == "unblock" else "resume", reply=c, reply_verb=verb,
                          stage=stage, gate_attrs=gate[2] if gate else None)
            running.add(n)
        guarded(n, handle)

    # 3. New pickups; an item whose pickup keeps failing is skipped after MAX_FAILS and reported once.
    for i in pickup_order(items):
        if slots <= 0:
            break
        n = i["number"]
        if n in running:
            continue
        starts = [r for r in work if r["item"] == n and r["reason"] == "start" and r.get("error")]
        if len(starts) >= MAX_FAILS:
            report_once(reported, f"pickfail:{n}", f"#{n}: pickup failed {len(starts)}x ({starts[-1]['error']}); "
                        "not retrying.")
            continue
        slots -= 1
        guarded(n, lambda i=i: dispatch_work(recs, i, "start"))

    # 4. Worktree cleanup for finished items (never forced: a dirty tree is reported, not deleted).
    for i in items:
        path = WT_ROOT / f"item-{i['number']}"
        if i["status"] in ("Done", "Canceled") and path.exists() and i["number"] not in running:
            if DRY:
                out.append(f"DRY: would remove worktree {path}")
                continue
            try:
                run(["git", "-C", str(CHECKOUT), "worktree", "remove", str(path)])
            except Exception as e:  # noqa: BLE001
                report_once(reported, f"wt:{i['number']}", f"#{i['number']}: could not remove worktree {path}: {e}")

    # Surface dispatch errors once each.
    for r in recs:
        if r["kind"] == "work" and r.get("error"):
            report_once(reported, f"err:{r['item']}:{r['ts']}", f"#{r['item']}: dispatch error: {r['error']}")
    for e in errors:
        out.append(f"Pipeline dispatch error {e}")


def job_hygiene(items, reported):
    now = datetime.now(timezone.utc).timestamp()

    def age(i):
        try:
            return (now - datetime.fromisoformat(i["updatedAt"].replace("Z", "+00:00")).timestamp()) / 86400
        except (KeyError, ValueError, AttributeError):
            return 0
    lines = []
    for status in ("Awaiting approval", "Blocked", "Clarification needed"):
        stale = [i for i in items if i["status"] == status and age(i) > STALE_DAYS]
        if stale:
            lines.append(f"{status} for > {STALE_DAYS:g} days: " + ", ".join(f"#{i['number']}" for i in stale))
    parked = [i for i in items if i["status"] == "Awaiting approval" and PARK in labels_of(i["number"])]
    if parked:
        lines.append("Waiting for a live design chat (discuss): " + ", ".join(f"#{i['number']}" for i in parked))
    prs = gh("pr", "list", "-R", REPO, "--state", "open", "--limit", "100", "--json", "number,labels,isDraft")
    unlabeled = [p["number"] for p in prs if not p["isDraft"] and not any(l["name"].startswith("pr:") for l in p["labels"])]
    if unlabeled:
        lines.append("Open PRs outside the review flow (no pr: label): " + ", ".join(f"#{n}" for n in unlabeled))
    if lines:
        out.append("Pipeline hygiene:\n- " + "\n- ".join(lines))


def deliver(reported):
    for f in sorted(RESULTS.glob("*.json")):
        if f.name in reported:
            continue
        try:
            r = json.loads(f.read_text())
        except ValueError:
            continue
        reported.add(f.name)
        if r.get("notify", True):
            who = " ".join(f"#{n}" for n in r.get("items", [])) or f.stem
            what = r.get("outcome") or json.dumps(r.get("outcomes", {}))
            out.append(f"{who} [{what}] {r.get('summary', '').strip()} {r.get('url', '')}".strip())


def main(argv):
    job = argv[1] if len(argv) > 1 else ""
    if job not in ("triage", "work", "hygiene"):
        print("usage: pipeline-dispatch.py triage|work|hygiene")
        return 2
    missing = [k for k, v in (("PIPELINE_REPO", REPO), ("PIPELINE_CHECKOUT", ENV.get("PIPELINE_CHECKOUT")),
                              ("PIPELINE_LIST_CMD", LIST_CMD), ("PIPELINE_MOVE_CMD", MOVE_CMD),
                              ("PIPELINE_OWNERS", OWNERS), ("PR_AGENT_HANDLE", HANDLES)) if not v]
    if missing:
        print("Pipeline dispatch error: set " + ", ".join(missing))
        return 1
    for d in (STATE, RESULTS, LOGS):
        d.mkdir(parents=True, exist_ok=True)
    recs = [json.loads(l) for l in DISPATCH.read_text().splitlines() if l.strip()] if DISPATCH.exists() else []
    reported = set(json.loads(REPORTED.read_text())) if REPORTED.exists() else set()
    try:
        deliver(reported)
        items = list_items()
        {"triage": lambda: job_triage(items, recs, reported),
         "work": lambda: job_work(items, recs, reported),
         "hygiene": lambda: job_hygiene(items, reported)}[job]()
        code = 0
    except Exception as e:  # noqa: BLE001 — surface the failure; never crash silently
        out.append(f"Pipeline dispatch error ({job}): {e}")
        code = 1
    if not DRY:
        REPORTED.write_text(json.dumps(sorted(reported)))
    if out:
        print("\n".join(out))
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
