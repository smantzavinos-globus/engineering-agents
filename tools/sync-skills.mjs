#!/usr/bin/env node
// sync-skills.mjs — compare an agent's installed skills against this repo's
// rendered tree for that agent's harness. READ-ONLY: it reports; the agent
// judges (take-upstream / keep-local / propose-upstream) and copies.
//
// Usage:
//   node tools/sync-skills.mjs --installed <dir> [--harness hermes] [--json]
//
// Report per skill: unchanged | upstream-new | locally-modified | locally-only
// plus `--json` machine output for the agent's sync-state file.

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');
const DIST_DIR = path.join(REPO_ROOT, 'dist', 'skills');

function fail(message) {
  process.stderr.write(`sync-skills: ${message}\n`);
  process.exit(1);
}

function parseArgs(argv) {
  const args = { harness: 'hermes', json: false };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--installed') args.installed = argv[++i];
    else if (argv[i] === '--harness') args.harness = argv[++i];
    else if (argv[i] === '--json') args.json = true;
    else fail(`unknown argument: ${argv[i]}`);
  }
  if (!args.installed) fail('missing --installed <dir>');
  return args;
}

function walkFiles(dir, base = dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walkFiles(full, base));
    else out.push(path.relative(base, full));
  }
  return out;
}

function hashTree(root) {
  const files = walkFiles(root);
  const hash = crypto.createHash('sha256');
  const manifest = {};
  for (const rel of files) {
    const digest = crypto.createHash('sha256').update(fs.readFileSync(path.join(root, rel))).digest('hex');
    manifest[rel] = digest;
    hash.update(`${rel}:${digest}\n`);
  }
  return { tree: manifest, root: hash.digest('hex').slice(0, 16) };
}

const args = parseArgs(process.argv.slice(2));
const upstreamRoot = path.join(DIST_DIR, args.harness);
if (!fs.existsSync(upstreamRoot)) fail(`no rendered tree for harness "${args.harness}" at ${upstreamRoot}`);
if (!fs.existsSync(args.installed)) fail(`installed skills dir does not exist: ${args.installed}`);

const upstream = hashTree(upstreamRoot);
const installed = hashTree(args.installed);

const upstreamSkills = fs.readdirSync(upstreamRoot, { withFileTypes: true })
  .filter((e) => e.isDirectory()).map((e) => e.name);
const installedSkills = fs.readdirSync(args.installed, { withFileTypes: true })
  .filter((e) => e.isDirectory() && !e.name.startsWith('.')).map((e) => e.name);

// Per-skill hash: hash of the skill's own file set (relative to the skill dir).
function skillRoots(root, skills) {
  const map = new Map();
  for (const skill of skills) {
    const dir = path.join(root, skill);
    map.set(skill, hashTree(dir));
  }
  return map;
}
const up = skillRoots(upstreamRoot, upstreamSkills);
const inst = skillRoots(args.installed, installedSkills);

const report = [];
for (const skill of [...new Set([...upstreamSkills, ...installedSkills])].sort()) {
  const hasUp = up.has(skill);
  const hasIn = inst.has(skill);
  let status;
  let changedFiles = [];
  if (hasUp && !hasIn) status = 'not-installed';
  else if (!hasUp && hasIn) status = 'locally-only';
  else if (up.get(skill).root === inst.get(skill).root) status = 'unchanged';
  else {
    status = 'locally-modified';
    // If the installed tree matches an OLDER upstream tree verbatim, this is
    // simply upstream-new; distinguish via the union diff below.
    const union = new Set([...Object.keys(up.get(skill).tree), ...Object.keys(inst.get(skill).tree)]);
    changedFiles = [...union].filter((rel) => up.get(skill).tree[rel] !== inst.get(skill).tree[rel]);
  }
  report.push({ skill, status, changed_files: changedFiles });
}

// upstream-new = identical content exists in git history? The script cannot
// know history; it reports locally-modified and the agent consults git
// (`git log -- <skill>`) to see if upstream moved without local edits.
if (!args.json) {
  process.stdout.write(`Skill sync report — upstream: dist/skills/${args.harness}/ vs installed: ${args.installed}\n`);
  process.stdout.write(`Upstream tree: ${upstream.root}  (${upstreamSkills.length} skills)\n\n`);
  for (const row of report) {
    process.stdout.write(`${row.status.padEnd(18)} ${row.skill}${row.changed_files.length ? `  [${row.changed_files.length} file(s) differ]` : ''}\n`);
  }
  process.stdout.write(`\nDispositions are YOURS to make (see the skill-sync skill):\n`);
  process.stdout.write(`  take-upstream | keep-local (record reason) | propose-upstream (PR)\n`);
  process.stdout.write(`For 'locally-modified', check git first: git log --oneline -- dist/skills/${args.harness}/<skill>\n`);
  process.stdout.write(`to distinguish 'upstream moved' from 'local edits exist'.\n`);
} else {
  process.stdout.write(JSON.stringify({
    upstream_tree: upstream.root,
    harness: args.harness,
    skills: report,
  }, null, 2) + '\n');
}
