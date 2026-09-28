#!/usr/bin/env bash
# Regenerate nix/modules/pi/managed-packages/package-lock.json.
#
# The committed lock is generated with --install-strategy=nested: pi's
# extension loader resolves imports against the literal path, so every
# managed package must be self-contained (dependencies nested under its own
# directory, like npm's global-install layout). Peer entries stay in the
# lock so offline `npm ci` has complete resolution.
#
# Usage: nix/modules/pi/managed-packages/refresh-lock.sh [--reresolve-pi-core-peers]
#
# --reresolve-pi-core-peers: drop the lock's @earendil-works/pi-{agent-core,
#   ai,coding-agent,tui} peer nodes (and their nested trees) before resolving,
#   so npm picks versions satisfying every package's CURRENT peer ranges.
#   An incremental refresh keeps the old locked peer and fails ERESOLVE when a
#   new package's floor (e.g. pi-btw >=0.85.1) excludes it, even if another
#   version satisfies all ranges. These vendored copies are resolution
#   metadata only (pi injects its own core at load time; see config.nix
#   ensureSelfContained), so their versions need not match the runtime Pi.
#   npm `overrides` are NOT an alternative: offline `npm ci` re-fetches
#   registry metadata for overridden unmet peer edges (ENOTCACHED in Nix).
#   Run the refresh with the build's npm (pkgs.nodejs of this flake).
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$dir"
if [[ "${1:-}" == "--reresolve-pi-core-peers" ]]; then
  node -e '
    const fs = require("node:fs");
    const lock = JSON.parse(fs.readFileSync("package-lock.json", "utf8"));
    const core = /^node_modules\/@earendil-works\/pi-(agent-core|ai|coding-agent|tui)(\/|$)/;
    let dropped = 0;
    for (const key of Object.keys(lock.packages)) {
      if (core.test(key)) { delete lock.packages[key]; dropped += 1; }
    }
    fs.writeFileSync("package-lock.json", JSON.stringify(lock, null, 2) + "\n");
    console.log(`Dropped ${dropped} Pi core peer lock nodes for re-resolution.`);
  '
elif [[ -n "${1:-}" ]]; then
  echo "unknown option: $1" >&2
  exit 2
fi
npm install --package-lock-only --install-strategy=nested --ignore-scripts --no-audit --no-fund

# npm 10/11 lock-only resolution can omit `integrity` for registry packages it
# nests under a peer-only node (seen for pi-coding-agent's nested
# @earendil-works/* deps); prefetch-npm-deps/fetchNpmDeps then refuse the lock.
# Backfill from the registry's published dist.integrity. Safe: the Nix
# fixed-output fetch verifies every tarball against these values.
node -e '
  const fs = require("node:fs");
  const { execFileSync } = require("node:child_process");
  const lock = JSON.parse(fs.readFileSync("package-lock.json", "utf8"));
  let filled = 0;
  for (const [key, node] of Object.entries(lock.packages)) {
    if (!key || node.link || node.integrity || !node.resolved) continue;
    if (!node.resolved.startsWith("https://registry.npmjs.org/")) continue;
    const name = key.slice(key.lastIndexOf("node_modules/") + "node_modules/".length);
    const integrity = execFileSync("npm", ["view", `${name}@${node.version}`, "dist.integrity"], { encoding: "utf8" }).trim();
    if (!integrity.startsWith("sha512-")) throw new Error(`no sha512 integrity for ${name}@${node.version}`);
    node.integrity = integrity;
    filled += 1;
  }
  if (filled > 0) {
    fs.writeFileSync("package-lock.json", JSON.stringify(lock, null, 2) + "\n");
    console.log(`Backfilled integrity for ${filled} registry lock nodes.`);
  }
'

echo "Lock refreshed. Update npmDeps hash in nix/modules/pi/config.nix with:"
echo "  nix build nixpkgs#prefetch-npm-deps && ./result/bin/prefetch-npm-deps $dir/package-lock.json"
