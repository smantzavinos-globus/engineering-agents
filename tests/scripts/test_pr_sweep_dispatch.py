"""Unit tests for the pure decisions in scripts/pr-sweep-dispatch.py.

Replaces the claimState checks that lived with the retired monitor script.
Requirement: FR-001
"""
import importlib.util
import os
import pathlib
import unittest

os.environ.setdefault("PR_SWEEP_REPOS", "o/r")
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


class Mentions(unittest.TestCase):
    def test_review_fix_babysit_self_and_seen(self):
        cs = [comment(1, "h", "@bot review please"),
              comment(2, "h", "@bot fix the tests"),
              comment(3, "bot", "@bot review"),       # own comment: ignored
              comment(4, "h", "@bot babysit")]
        review, babysit = d.mentions(cs, "bot", seen_ids={4})
        self.assertEqual(review["id"], 1)
        self.assertEqual(babysit["id"], 2)

    def test_no_handle_means_no_mentions(self):
        self.assertEqual(d.mentions([comment(1, "h", "@bot review")], "", set()), (None, None))


if __name__ == "__main__":
    unittest.main()
