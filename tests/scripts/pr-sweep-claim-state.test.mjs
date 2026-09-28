// Unit checks for the babysit-claim classifier in scripts/pr-sweep-monitor.mjs.
// Requirement: FR-001
import assert from "node:assert/strict";
import { claimState } from "../../scripts/pr-sweep-monitor.mjs";

const now = Date.parse("2026-01-01T12:00:00Z");
const beat = iso => ({ body: `babysit: session=s1 heartbeat=${iso}` });

// No label: never claimed, whatever the comments say.
assert.equal(claimState([], [beat("2026-01-01T11:59:00Z")], now, 60), "none");
// Fresh heartbeat under the label is active.
assert.equal(claimState(["pr:babysat"], [beat("2026-01-01T11:30:00Z")], now, 60), "active");
// Heartbeat past the threshold is stale.
assert.equal(claimState(["pr:babysat"], [beat("2026-01-01T10:00:00Z")], now, 60), "stale");
// Latest heartbeat wins over an older one.
assert.equal(
  claimState(["pr:babysat"], [beat("2026-01-01T09:00:00Z"), beat("2026-01-01T11:55:00Z")], now, 60),
  "active",
);
// Label with no readable heartbeat is drift, which counts as stale.
assert.equal(claimState(["pr:babysat"], [{ body: "babysit: released" }], now, 60), "stale");

console.log("pr-sweep claimState: 5 passed");
