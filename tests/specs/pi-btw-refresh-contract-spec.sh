#!/usr/bin/env bash
# Contract for the managed pi-btw 0.6.1 refresh and Pi 0.86.1 compatibility.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

require_commands node jq >/dev/null

REPO_ROOT="$(repo_root)"
PI_CONFIG="$REPO_ROOT/nix/modules/pi/config.nix"
VENDOR_DIR="$REPO_ROOT/nix/modules/pi/managed-packages"
EXPECTED_VERSION="0.6.1"
PI_VERSION="0.86.1"

PASS=0 FAIL=0
pass() { PASS=$((PASS + 1)); printf '  PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL: %s\n' "$1" >&2; }

assert_value() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label is $expected"
  else
    fail "$label is '$actual' (expected $expected)"
  fi
}

printf 'Pi BTW 0.6.1 refresh contract\n'
printf '==============================\n\n'

# Extract the actual managedPackages.pi-btw source declaration without taking
# a whole-file formatting snapshot. This also lets the test distinguish an
# absent/disabled-by-removal stanza from a stale pin.
NIX_BTW_JSON="$(node - "$PI_CONFIG" <<'NODE'
const fs = require("node:fs");
const source = fs.readFileSync(process.argv[2], "utf8");

function attrsetAfter(text, marker) {
  const markerAt = text.indexOf(marker);
  if (markerAt < 0) return null;
  const open = text.indexOf("{", markerAt + marker.length);
  if (open < 0) return null;
  let depth = 0;
  let inString = false;
  let escaped = false;
  let inLineComment = false;
  for (let i = open; i < text.length; i++) {
    const ch = text[i];
    if (inLineComment) {
      if (ch === "\n") inLineComment = false;
      continue;
    }
    if (inString) {
      if (escaped) escaped = false;
      else if (ch === "\\") escaped = true;
      else if (ch === '"') inString = false;
      continue;
    }
    if (ch === '"') inString = true;
    else if (ch === "#") inLineComment = true;
    else if (ch === "{") depth++;
    else if (ch === "}" && --depth === 0) return text.slice(open + 1, i);
  }
  return null;
}

function field(body, name) {
  const match = body && body.match(new RegExp(`(?:^|\\n)\\s*${name}\\s*=\\s*"([^"]*)"\\s*;`));
  return match ? match[1] : null;
}

const managed = attrsetAfter(source, "managedPackages =");
const declaration = managed && attrsetAfter(managed, "pi-btw =");
const sourceBlock = declaration && attrsetAfter(declaration, "source =");
const footerMatch = source.match(/footerPackageIds\s*=\s*\[([^\]]*)\]/);
const footerIds = footerMatch ? [...footerMatch[1].matchAll(/"([^"]+)"/g)].map((match) => match[1]) : [];
console.log(JSON.stringify({
  declared: Boolean(declaration),
  type: field(sourceBlock, "type"),
  packageName: field(sourceBlock, "packageName"),
  spec: field(sourceBlock, "spec"),
  installSpec: field(sourceBlock, "installSpec"),
  version: field(declaration, "version"),
  allPackagesEnabledForBuild: source.includes("enabledPackages = managedPackages;"),
  runtimeUsesManagedPackageIds: source.includes("enabledIds = lib.attrNames managedPackages;"),
  runtimeEligibleSourceFilter: source.includes("managedPackages.${packageId}.source.type != \"local\""),
  footerIds,
}));
NODE
)"

assert_value "$(jq -r '.declared' <<<"$NIX_BTW_JSON")" "true" "config.nix pi-btw managed-package declaration"
assert_value "$(jq -r '.type // "<missing>"' <<<"$NIX_BTW_JSON")" "npm" "config.nix pi-btw source type"
assert_value "$(jq -r '.packageName // "<missing>"' <<<"$NIX_BTW_JSON")" "pi-btw" "config.nix pi-btw packageName"
assert_value "$(jq -r '.spec // "<missing>"' <<<"$NIX_BTW_JSON")" "pi-btw@$EXPECTED_VERSION" "config.nix pi-btw source spec"
assert_value "$(jq -r '.installSpec // "<missing>"' <<<"$NIX_BTW_JSON")" "pi-btw@$EXPECTED_VERSION" "config.nix pi-btw source installSpec"
assert_value "$(jq -r '.version // "<missing>"' <<<"$NIX_BTW_JSON")" "$EXPECTED_VERSION" "config.nix pi-btw declaration version"

# The module derives the enabled package set from managedPackages; confirm the
# declaration remains on that default path and is not a footer-only package.
assert_value "$(jq -r '.allPackagesEnabledForBuild' <<<"$NIX_BTW_JSON")" "true" "all managed declarations remain enabled for the build"
assert_value "$(jq -r '.runtimeUsesManagedPackageIds' <<<"$NIX_BTW_JSON")" "true" "runtime package IDs remain derived from managedPackages"
assert_value "$(jq -r '.runtimeEligibleSourceFilter' <<<"$NIX_BTW_JSON")" "true" "npm declarations remain eligible for Pi runtime settings"
if jq -e --arg id pi-btw '.footerIds | index($id) == null' <<<"$NIX_BTW_JSON" >/dev/null; then
  pass "pi-btw is not excluded as a footer variant"
else
  fail "pi-btw must remain outside the footer-only package selection"
fi

MANIFEST="$VENDOR_DIR/package.json"
LOCK="$VENDOR_DIR/package-lock.json"
assert_value "$(jq -r '.dependencies["pi-btw"] // "<missing>"' "$MANIFEST")" \
  "$EXPECTED_VERSION" "package.json dependency pi-btw"
assert_value "$(jq -r '.packages[""].dependencies["pi-btw"] // "<missing>"' "$LOCK")" \
  "$EXPECTED_VERSION" "package-lock root dependency pi-btw"
assert_value "$(jq -r '.packages["node_modules/pi-btw"].version // "<missing>"' "$LOCK")" \
  "$EXPECTED_VERSION" "package-lock installed pi-btw version"
assert_value "$(jq -r '.packages["node_modules/pi-btw"].resolved // "<missing>" | split("/")[-1]' "$LOCK")" \
  "pi-btw-$EXPECTED_VERSION.tgz" "package-lock pi-btw tarball"

# The locked extension must accept Pi's 0.86.1 core APIs across all three
# injected peers. Support the comparator form emitted by pi-btw's npm metadata.
peer_compatible() {
  local range="$1"
  node - "$range" "$PI_VERSION" <<'NODE'
const [range, target] = process.argv.slice(2);
const match = range.match(/^>=([0-9]+)\.([0-9]+)\.([0-9]+)\s+<([0-9]+)(?:\.([0-9]+)\.([0-9]+))?$/);
if (!match) process.exit(1);
const tuple = (major, minor = 0, patch = 0) => [Number(major), Number(minor), Number(patch)];
const compare = (left, right) => {
  for (let i = 0; i < 3; i++) if (left[i] !== right[i]) return left[i] < right[i] ? -1 : 1;
  return 0;
};
const floor = tuple(match[1], match[2], match[3]);
const upper = tuple(match[4], match[5], match[6]);
const version = target.split(".").map(Number);
process.exit(compare(floor, version) <= 0 && compare(version, upper) < 0 ? 0 : 1);
NODE
}

for peer in \
  "@earendil-works/pi-ai" \
  "@earendil-works/pi-coding-agent" \
  "@earendil-works/pi-tui"; do
  range="$(jq -r --arg peer "$peer" '.packages["node_modules/pi-btw"].peerDependencies[$peer] // "<missing>"' "$LOCK")"
  if peer_compatible "$range"; then
    pass "locked peer $peer accepts Pi $PI_VERSION ($range)"
  else
    fail "locked peer $peer has incompatible range '$range' for Pi $PI_VERSION"
  fi
done

# BTW's >=0.85.1 peer floor only resolves once pi-subdir-context's stale
# `pi-coding-agent ^0.74.0` peer leaves the npm graph: it is a git source
# pinned to the commit npm 1.1.7 was published from. The vendor must not use
# npm `overrides` (offline npm ci re-fetches registry metadata for them).
SDC_REV="5d58a8b0533689eb91105b89f31d182199188d4e"
assert_value "$(jq -r '.dependencies | has("pi-subdir-context")' "$MANIFEST")" "false" "package.json omits npm pi-subdir-context"
assert_value "$(jq -r '.packages | has("node_modules/pi-subdir-context")' "$LOCK")" "false" "package-lock omits npm pi-subdir-context"
assert_value "$(jq -r 'has("overrides")' "$MANIFEST")" "false" "package.json has no npm overrides"
if grep -Fq "spec = \"github:default-anton/pi-subdir-context#$SDC_REV\";" "$PI_CONFIG" \
  && grep -Fq "rev = \"$SDC_REV\";" "$PI_CONFIG"; then
  pass "config.nix pins pi-subdir-context as a git source at $SDC_REV (declaration + gitSources)"
else
  fail "config.nix must pin pi-subdir-context as git source $SDC_REV in managedPackages and gitSources"
fi
# The committed lock must be fetchable by prefetch-npm-deps/fetchNpmDeps.
assert_value "$(jq -r '[.packages | to_entries[] | select(.key != "" and (.value.link | not) and (.value.integrity | not))] | length' "$LOCK")" \
  "0" "package-lock registry nodes missing integrity"
# Every locked Pi core peer copy must admit BTW's floor.
for peer in pi-ai pi-coding-agent pi-tui; do
  version="$(jq -r --arg p "node_modules/@earendil-works/$peer" '.packages[$p].version // "<missing>"' "$LOCK")"
  range="$(jq -r --arg peer "@earendil-works/$peer" '.packages["node_modules/pi-btw"].peerDependencies[$peer] // "<missing>"' "$LOCK")"
  if node - "$range" "$version" <<'NODE'
const [range, v] = process.argv.slice(2);
const m = range.match(/^>=([0-9]+)\.([0-9]+)\.([0-9]+)\s+<([0-9]+)$/);
const t = v.split(".").map(Number);
if (!m || t.length !== 3) process.exit(1);
const floor = [Number(m[1]), Number(m[2]), Number(m[3])];
const cmp = (a, b) => { for (let i = 0; i < 3; i++) if (a[i] !== b[i]) return a[i] < b[i] ? -1 : 1; return 0; };
process.exit(cmp(floor, t) <= 0 && t[0] < Number(m[4]) ? 0 : 1);
NODE
  then pass "locked root @earendil-works/$peer $version satisfies pi-btw peer $range"
  else fail "locked root @earendil-works/$peer $version does not satisfy pi-btw peer $range"
  fi
done

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
