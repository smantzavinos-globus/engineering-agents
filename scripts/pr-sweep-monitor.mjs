#!/usr/bin/env node
/**
 * PR sweep monitor for Hermes cron `monitor_script`.
 *
 * Prints a byte-stable, sorted summary of actionable PR state across the
 * repos in PR_SWEEP_REPOS. Unchanged output between ticks = no LLM run;
 * changed output = Hermes injects the diff and runs the agent.
 *
 * Env:
 *   PR_SWEEP_REPOS   space-separated "owner/repo" list (required)
 *   PR_AGENT_HANDLE  GitHub handle whose mentions count as triggers
 *                    (default: none — no mention detection)
 *   PR_BABYSIT_STALE_MIN  minutes before a babysit heartbeat counts as stale
 *                    (default: 60)
 *   GH_TOKEN         optional; `gh api` is used when gh is on PATH,
 *                    otherwise curl + GH_TOKEN against api.github.com
 *
 * Output format (one line per actionable PR, sorted by repo then number):
 *   repo: <owner/repo>
 *     pr:<number> label=<label> head=<sha> stamp=<sha-or-none> comments-new=<n> mentioned=<yes|no> claim=<none|active|stale> babysit-request=<yes|no>
 *
 * Actionable means: label is pr:ready-review or pr:re-review; OR head SHA
 * differs from the last reviewed@ stamp with label not pr:in-review; OR a
 * comment newer than the last stamp mentions PR_AGENT_HANDLE.
 * pr:in-review PRs and quiet pr:ready-merge PRs are never actionable.
 *
 * Babysit coexistence: a PR labeled pr:babysat with a fresh
 * `babysit: session=<id> heartbeat=<iso>` comment has claim=active. New
 * comments alone do not make it actionable (the babysitter owns them). A
 * heartbeat older than PR_BABYSIT_STALE_MIN is claim=stale and always
 * actionable. A comment newer than the last stamp that contains
 * `@<handle> babysit` sets babysit-request=yes.
 *
 * Staleness is computed against the clock, so output changes exactly once
 * when a claim crosses the threshold and then stays stable.
 */
import { execFileSync } from "node:child_process";
import { pathToFileURL } from "node:url";

const repos = (process.env.PR_SWEEP_REPOS ?? "").split(/\s+/).filter(Boolean);
const handle = (process.env.PR_AGENT_HANDLE ?? "").replace(/^@/, "").toLowerCase();

function api(path) {
  if (process.env.PR_MONITOR_USE_CURL === "1") return apiCurl(path);
  return JSON.parse(execFileSync("gh", ["api", path], { encoding: "utf8", maxBuffer: 32 * 1024 * 1024 }));
}

function apiCurl(path) {
  const token = process.env.GH_TOKEN ?? "";
  const out = execFileSync(
    "curl",
    ["-sS", "-H", `Authorization: token ${token}`, "-H", "Accept: application/vnd.github+json", `https://api.github.com${path}`],
    { encoding: "utf8", maxBuffer: 32 * 1024 * 1024 },
  );
  return JSON.parse(out);
}

const staleMin = Number(process.env.PR_BABYSIT_STALE_MIN ?? "60");
const HEARTBEAT = /babysit: session=\S+ heartbeat=(\S+)/;

/** Classify the babysit claim on a PR: none | active | stale. */
export function claimState(labels, comments, nowMs, staleMinutes) {
  if (!labels.includes("pr:babysat")) return "none";
  const beats = comments.map(c => (c.body ?? "").match(HEARTBEAT)).filter(Boolean);
  const last = beats.at(-1);
  const t = last ? Date.parse(last[1]) : NaN;
  if (Number.isNaN(t)) return "stale"; // label without a readable heartbeat is drift
  return nowMs - t > staleMinutes * 60_000 ? "stale" : "active";
}

const ACTIONABLE_LABELS = new Set(["pr:ready-review", "pr:re-review"]);

function main() {
  if (repos.length === 0) {
    console.error("PR_SWEEP_REPOS is required");
    process.exit(1);
  }
  const lines = [];
  for (const repo of repos.sort()) {
    const pulls = api(`/repos/${repo}/pulls?state=open&per_page=100`);
    const actionable = [];
    for (const pr of pulls) {
      const labels = (pr.labels ?? []).map(l => l.name);
      const label =
        ["pr:in-review", "pr:re-review", "pr:ready-merge", "pr:escalated", "pr:ready-review"].find(l => labels.includes(l)) ?? "unlabeled";
      const head = pr.head?.sha ?? "unknown";

      // Cheap skips first: quiet reviewed/merged-advice states without comment fetch.
      const comments = api(`/repos/${repo}/issues/${pr.number}/comments?per_page=100`);
      const stamps = comments.filter(c => /reviewed@[0-9a-f]{7,40}/.test(c.body ?? ""));
      const lastStamp = stamps.at(-1) ?? null;
      const stampSha = lastStamp ? (lastStamp.body.match(/reviewed@([0-9a-f]{7,40})/) ?? [])[1] ?? "none" : "none";
      const after = lastStamp ? Date.parse(lastStamp.created_at) : Date.parse(pr.created_at);
      const recent = comments.filter(c => Date.parse(c.created_at) > after);
      const mentioned = handle !== "" && recent.some(c => (c.body ?? "").toLowerCase().includes("@" + handle));
      const babysitRequest = handle !== "" && recent.some(c => (c.body ?? "").toLowerCase().includes("@" + handle + " babysit"));
      const claim = claimState(labels, comments, Date.now(), staleMin);

      const labelActionable = ACTIONABLE_LABELS.has(label) || label === "unlabeled"; // unlabeled = drift; drift is actionable
      const staleApproval = label === "pr:ready-merge" && stampSha !== "none" && !head.startsWith(stampSha);
      const movedAfterReview = stampSha !== "none" && label !== "pr:in-review" && !head.startsWith(stampSha) && label !== "pr:ready-merge";
      const quietReadyMerge = label === "pr:ready-merge" && !staleApproval && recent.length === 0;

      // An active babysitter owns comment traffic; only reviewer-side signals count.
      const commentSignal = claim === "active" ? false : mentioned;
      const babysitSignal = babysitRequest && claim === "none";

      if (claim !== "stale" && !babysitSignal) {
        if (quietReadyMerge || (label === "pr:in-review" && !commentSignal)) continue;
        if (!(labelActionable || staleApproval || movedAfterReview || commentSignal)) continue;
      }

      actionable.push({
        n: pr.number, label, head: head.slice(0, 12), stamp: stampSha,
        // comment counts jitter while a babysitter works; pin to 0 under an active claim
        cn: claim === "active" ? 0 : recent.length,
        m: commentSignal ? "yes" : "no", claim, b: babysitSignal ? "yes" : "no",
      });
    }
    if (actionable.length === 0) continue;
    lines.push(`repo: ${repo}`);
    for (const a of actionable.sort((x, y) => x.n - y.n)) {
      lines.push(`  pr:${a.n} label=${a.label} head=${a.head} stamp=${a.stamp} comments-new=${a.cn} mentioned=${a.m} claim=${a.claim} babysit-request=${a.b}`);
    }
  }
  console.log(lines.length ? lines.join("\n") : "no actionable PRs");
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) main();
