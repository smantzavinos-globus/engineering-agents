"""Unit tests for the pure decisions in scripts/pr-sweep-dispatch.py.

Replaces the claimState checks that lived with the retired monitor script.
Requirement: FR-001
"""
import importlib.util
import os
import pathlib
import tempfile
import unittest

os.environ.setdefault("PR_SWEEP_REPOS", "o/r")
os.environ.setdefault("HERMES_HOME", tempfile.mkdtemp(prefix="pr-sweep-dispatch-test-"))
_PATH = pathlib.Path(__file__).resolve().parents[2] / "scripts" / "pr-sweep-dispatch.py"
_spec = importlib.util.spec_from_file_location("dispatch", _PATH)
d = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(d)

NOW = 1767268800.0  # 2026-01-01T12:00:00Z


def beat(session, iso):
    return {"id": 1, "user": {"login": "a"}, "body": f"babysit: session={session} heartbeat={iso}"}


def comment(i, login, body):
    return {"id": i, "user": {"login": login}, "body": body}


class ClaimState(unittest.TestCase):
    def test_no_label_is_none_whatever_the_comments(self):
        self.assertEqual(d.claim_state([], [beat("s", "2026-01-01T11:59:00Z")], NOW, 60), "none")

    def test_fresh_heartbeat_is_active(self):
        self.assertEqual(d.claim_state(["pr:babysat"], [beat("s", "2026-01-01T11:30:00Z")], NOW, 60), "active")

    def test_old_heartbeat_is_stale(self):
        self.assertEqual(d.claim_state(["pr:babysat"], [beat("s", "2026-01-01T10:00:00Z")], NOW, 60), "stale")

    def test_latest_heartbeat_wins(self):
        cs = [beat("s", "2026-01-01T09:00:00Z"), beat("s", "2026-01-01T11:55:00Z")]
        self.assertEqual(d.claim_state(["pr:babysat"], cs, NOW, 60), "active")

    def test_label_without_heartbeat_is_stale(self):
        self.assertEqual(d.claim_state(["pr:babysat"], [comment(1, "a", "babysit: released")], NOW, 60), "stale")

    def test_sweep_ownership_follows_reserved_prefix(self):
        self.assertTrue(d.sweep_owned([beat("babysit-pr7-abc", "2026-01-01T11:00:00Z")]))
        self.assertFalse(d.sweep_owned([beat("20260101_chat", "2026-01-01T11:00:00Z")]))


class Verdicts(unittest.TestCase):
    def test_marker_parsed_in_order_and_prose_ignored(self):
        cs = [comment(1, "r", "**Verdict: FIX**\n<!-- pr-review verdict=FIX head=aaaaaaa -->"),
              comment(2, "h", "I think this is READY"),
              comment(3, "r", "<!-- pr-review verdict=READY head=bbbbbbb -->\nreviewed@bbbbbbb")]
        self.assertEqual([(v, h) for v, h, _ in d.verdicts(cs)], [("FIX", "aaaaaaa"), ("READY", "bbbbbbb")])


class StateLabel(unittest.TestCase):
    def test_opt_in_ignores_unlabeled(self):
        self.assertIsNone(d.state_label([], "ignore"))

    def test_drift_mode_reviews_unlabeled_but_not_babysat(self):
        self.assertEqual(d.state_label([], "review"), "pr:ready-review")
        self.assertIsNone(d.state_label(["pr:babysat"], "review"))

    def test_in_review_outranks_other_labels(self):
        self.assertEqual(d.state_label(["pr:ready-review", "pr:in-review"], "ignore"), "pr:in-review")


class BotRounds(unittest.TestCase):
    def test_round_returns_all_unhandled_ids(self):
        revs = [{"id": 701}, {"id": 702}]
        rev, capped, seen = d.bot_round_due(revs, set())
        self.assertEqual(rev["id"], 702)
        self.assertFalse(capped)
        self.assertEqual(seen, [701, 702])  # every unhandled review is consumed by this round
        rev, capped, seen = d.bot_round_due(revs, {701})
        self.assertEqual((rev["id"], capped, seen), (702, False, [702]))
        rev, capped, seen = d.bot_round_due(revs, {701, 702})
        self.assertEqual((rev, capped, seen), (None, False, []))
        six = [{"id": i} for i in range(700, 706)]
        rev, capped, seen = d.bot_round_due(six, set())
        self.assertEqual((rev, capped, seen), (None, True, []))


class CiRounds(unittest.TestCase):
    STAMP = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    HEAD = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

    def test_red_at_stamp_fires_once_per_conclusion_set(self):
        rollup = [{"name": "CI", "status": "COMPLETED", "conclusion": "SUCCESS"},
                  {"name": "E2E", "status": "COMPLETED", "conclusion": "FAILURE"}]
        fires, key, ok = d.ci_round_due(rollup, set(), self.STAMP, self.HEAD)
        self.assertEqual(fires, ["E2E (FAILURE)"])
        self.assertFalse(ok)
        # same conclusion set again -> handled, no re-fire
        fires, key, ok = d.ci_round_due(rollup, {key}, self.STAMP, self.HEAD)
        self.assertEqual((fires, key), ([], None))

    def test_green_restores(self):
        rollup = [{"name": "CI", "status": "COMPLETED", "conclusion": "SUCCESS"}]
        fires, key, ok = d.ci_round_due(rollup, set(), self.STAMP, self.HEAD)
        self.assertEqual((fires, ok), ([], True))
        self.assertTrue(key.endswith(":green"))

    def test_moved_head_out_of_scope(self):
        fires, key, ok = d.ci_round_due([{"name": "E2E", "status": "COMPLETED", "conclusion": "FAILURE"}],
                                        set(), self.STAMP, "bbbbbbbb" + self.HEAD[8:])
        self.assertEqual((fires, key, ok), ([], None, True))

    def test_no_stamp_out_of_scope(self):
        fires, key, ok = d.ci_round_due([], set(), None, self.HEAD)
        self.assertEqual((fires, key, ok), ([], None, True))

    def test_pending_checks_ignored(self):
        rollup = [{"name": "CI", "status": "IN_PROGRESS", "conclusion": None}]
        fires, key, ok = d.ci_round_due(rollup, set(), self.STAMP, self.HEAD)
        self.assertEqual((fires, ok), ([], True))


class CiTick(unittest.TestCase):
    """The tick's CI block end to end: one demotion, one round, one report.

    The demotion branch must mark the transition reported (no second line on
    the next tick) and dispatch the babysit round (no READY-stamped PR parked
    red with nobody on it).
    """
    HEAD8 = "8" * 40

    def make_pr(self):
        return {"number": 9, "title": "t", "headRefName": "b", "headRefOid": self.HEAD8,
                "labels": [{"name": "pr:ready-merge"}], "isDraft": False,
                "statusCheckRollup": [{"name": "E2E", "status": "COMPLETED", "conclusion": "FAILURE"}]}

    def test_one_round_one_report_over_two_ticks(self):
        ready_comment = [{"id": 91, "user": {"login": "rev"},
                          "body": f"<!-- pr-review verdict=READY head={self.HEAD8} -->"}]

        def fake_gh(*args):
            if args[:2] == ("pr", "list"):
                return [self.make_pr()]
            if args[0] == "api" and str(args[1]).startswith("repos/o/r/issues/9/comments"):
                return ready_comment
            return []

        orig_gh, orig_label, orig_dry, orig_out = d.gh, d.set_state_label, d.DRY, d.out
        seen_labels, recs, reported = [], [], set()
        tick_lines = []  # the injected out list, held past the restore below
        # Production-realistic ledger: the READY review's dispatch record with its
        # delivered result file — this is what suppresses the reviewer leg at tick 1.
        recs.append({"ts": 0, "kind": "review", "repo": "o/r", "pr": 9, "head": self.HEAD8,
                     "tag": "review-pr9-stamped"})
        d.RESULTS.mkdir(parents=True, exist_ok=True)
        (d.RESULTS / "review-pr9-stamped.json").write_text('{"status": "FIXED"}')
        d.gh = fake_gh
        d.DRY = True
        d.out = tick_lines
        d.set_state_label = lambda repo, n, label: seen_labels.append(label)
        try:
            d.sweep_repo("o/r", recs, reported)  # tick 1: demote + dispatch + one report
            first = len(tick_lines)
            labels_tick1 = list(seen_labels)
            seen_labels.clear()
            d.sweep_repo("o/r", recs, reported)  # tick 2: handled, silent
        finally:
            d.gh, d.set_state_label, d.DRY, d.out = orig_gh, orig_label, orig_dry, orig_out
        babysits = [r for r in recs if r["kind"] == "babysit"]
        self.assertEqual(len(babysits), 1, "exactly one babysit round for the red transition")
        self.assertEqual(babysits[0]["ci_key"], f"{self.HEAD8[:12]}:E2E (FAILURE)")
        self.assertEqual(labels_tick1, ["pr:re-review"], "tick 1 demotes the label and nothing else — the round itself claims (prompt step 1)")
        ci_keys = [k for k in reported if k.startswith("ci:")]
        self.assertEqual(ci_keys, [f"ci:o/r#9:{self.HEAD8[:12]}:E2E (FAILURE)"],
                         "the demotion branch must add the ci: key so tick 2 does not repeat the report")
        self.assertEqual(len(tick_lines), first, "tick 2 must not repeat the CI report")


class Mentions(unittest.TestCase):
    def test_review_fix_babysit_self_and_seen(self):
        cs = [comment(1, "h", "@bot review please"),
              comment(2, "h", "@bot fix the tests"),
              comment(3, "bot", "@bot review"),       # own comment: ignored
              comment(4, "h", "@bot babysit")]
        review, babysit = d.mentions(cs, ("bot",), seen_ids={4})
        self.assertEqual(review["id"], 1)
        self.assertEqual(babysit["id"], 2)

    def test_no_handle_means_no_mentions(self):
        self.assertEqual(d.mentions([comment(1, "h", "@bot review")], (), set()), (None, None))

    def test_parse_handles_splits_and_normalizes(self):
        self.assertEqual(d.parse_handles("Smantzavinos, @Agent"), ("smantzavinos", "agent"))
        self.assertEqual(d.parse_handles("  bot  "), ("bot",))
        self.assertEqual(d.parse_handles(""), ())
        self.assertEqual(d.parse_handles(None), ())

    def test_alias_handle_triggers_review_and_fix(self):
        # The live sweep configures PR_AGENT_HANDLE="smantzavinos agent": a mention of the
        # alias alone must fire, or `@agent review` is a silent no-op.
        cs = [comment(1, "h", "@agent review please"),
              comment(2, "h", "@agent fix the tests")]
        review, babysit = d.mentions(cs, ("smantzavinos", "agent"), set())
        self.assertEqual(review["id"], 1)
        self.assertEqual(babysit["id"], 2)

    def test_self_mention_ignored_for_every_configured_handle(self):
        cs = [comment(1, "Agent", "@agent review"),   # author IS a configured handle
              comment(2, "smantzavinos", "@smantzavinos review")]
        self.assertEqual(d.mentions(cs, ("smantzavinos", "agent"), set()), (None, None))


if __name__ == "__main__":
    unittest.main()
