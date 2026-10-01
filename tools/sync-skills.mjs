#!/usr/bin/env node
// sync-skills.mjs — compare an agent's installed skills against this repo's
// rendered tree for that agent's harness. READ-ONLY: it reports; the agent
// judges (take-upstream / keep-local / propose-upstream) and copies.
//
// Usage:
//   node tools/sync-skills.mjs --installed <dir> [--harness hermes] [--since <sha>] [--json]
//
// Report per skill: unchanged | upstream-new | locally-modified | locally-only
// plus `--json` machine output for the agent's sync-state file.

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import os from 'node:os';
import { execFileSync } from 'node:child_process';
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
    else if (argv[i] === '--since') args.since = argv[++i];
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
// Installed stores may be flat (<dir>/<skill>/SKILL.md) or nested by category
// (<dir>/<category>/<skill>/SKILL.md, as Hermes does). Find skills by SKILL.md.
const installedDirs = new Map();
(function find(dir, depth) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (!e.isDirectory() || e.name.startsWith('.')) continue;
    const full = path.join(dir, e.name);
    if (fs.existsSync(path.join(full, 'SKILL.md'))) installedDirs.set(e.name, full);
    else if (depth < 2) find(full, depth + 1);
  }
})(args.installed, 0);
const installedSkills = [...installedDirs.keys()];
// --since <sha>: the rendered tree at the last synced upstream commit, so an
// installed skill identical to it (but not to HEAD) is 'upstream-new'.
let sinceRoot = null;
if (args.since) {
  sinceRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'sync-skills-'));
  let tar;
  try {
    tar = execFileSync('git', ['archive', args.since, `dist/skills/${args.harness}`], { cwd: REPO_ROOT, maxBuffer: 1 << 28, stdio: ['ignore', 'pipe', 'ignore'] });
  } catch {
    fail(`--since ${args.since}: no rendered ${args.harness} tree at that commit (fetch it, or omit --since)`);
  }
  execFileSync('tar', ['-x', '-C', sinceRoot], { input: tar });
  sinceRoot = path.join(sinceRoot, 'dist', 'skills', args.harness);
}

// Per-skill hash: hash of the skill's own file set (relative to the skill dir).
function skillRoots(root, skills, dirs) {
  const map = new Map();
  for (const skill of skills) {
    const dir = dirs ? dirs.get(skill) : path.join(root, skill);
    if (!fs.existsSync(dir)) continue;
    map.set(skill, hashTree(dir));
  }
  return map;
}
const up = skillRoots(upstreamRoot, upstreamSkills);
const inst = skillRoots(args.installed, installedSkills, installedDirs);
const old = sinceRoot ? skillRoots(sinceRoot, upstreamSkills) : new Map();

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
    status = old.get(skill)?.root === inst.get(skill).root ? 'upstream-new' : 'locally-modified';
    const union = new Set([...Object.keys(up.get(skill).tree), ...Object.keys(inst.get(skill).tree)]);
    changedFiles = [...union].filter((rel) => up.get(skill).tree[rel] !== inst.get(skill).tree[rel]);
  }
  report.push({ skill, status, changed_files: changedFiles });
}

if (!args.json) {
  process.stdout.write(`Skill sync report — upstream: dist/skills/${args.harness}/ vs installed: ${args.installed}\n`);
  process.stdout.write(`Upstream tree: ${upstream.root}  (${upstreamSkills.length} skills)\n\n`);
  for (const row of report) {
    process.stdout.write(`${row.status.padEnd(18)} ${row.skill}${row.changed_files.length ? `  [${row.changed_files.length} file(s) differ]` : ''}\n`);
  }
  process.stdout.write(`\nDispositions are YOURS to make (see the skill-sync skill):\n`);
  process.stdout.write(`  take-upstream | keep-local (record reason) | propose-upstream (PR)\n`);
  if (!args.since) process.stdout.write(`Pass --since <last-synced-sha> to separate 'upstream-new' from 'locally-modified'.\n`);
} else {
  process.stdout.write(JSON.stringify({
    upstream_tree: upstream.root,
    harness: args.harness,
    skills: report,
  }, null, 2) + '\n');
}
