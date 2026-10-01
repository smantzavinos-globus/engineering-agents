#!/usr/bin/env node
// Skill renderer: composes harness-specific skill trees from one canonical source.
//
// Canonical skills live in `skills/<name>/` and are harness-neutral. They may use
// two macros:
//   {{delegate:ROLE skill=SKILL}}prompt text{{/delegate}}  (block; SKILL optional)
//   {{note:KEY}}                                            (inline)
// Frontmatter must NOT hardcode `compatibility:` — the renderer injects it per harness.
//
// Harness profiles live in `harnesses/<id>.json` and map semantic roles to a concrete
// implementation (named subagent vs category) plus harness-specific notes.
// `skill-resources.json` maps shared canonical files into self-contained rendered skills.
//
// Output is written to `dist/skills/<harness-id>/<name>/` (checked in, drift-tested).
//
// Usage:
//   node tools/render-skills.mjs --write    Regenerate dist/ from canonical sources
//   node tools/render-skills.mjs --check    Verify dist/ matches a fresh render (no writes)

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');
const SKILLS_DIR = path.join(REPO_ROOT, 'skills');
const HARNESS_DIR = path.join(REPO_ROOT, 'harnesses');
const DIST_DIR = path.join(REPO_ROOT, 'dist', 'skills');
const RESOURCE_MANIFEST = path.join(REPO_ROOT, 'skill-resources.json');

const DELEGATE_RE = /^[ \t]*\{\{delegate:([A-Za-z0-9_-]+)(?:\s+skill=([A-Za-z0-9_-]+))?\}\}[ \t]*\n([\s\S]*?)\n[ \t]*\{\{\/delegate\}\}[ \t]*$/gm;
const NOTE_RE = /\{\{note:([A-Za-z0-9_-]+)\}\}/g;
const LEFTOVER_RE = /\{\{[^}]*\}\}/;

function fail(message) {
  process.stderr.write(`render-skills: ${message}\n`);
  process.exit(1);
}

function listDirs(dir) {
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort((a, b) => a.localeCompare(b));
}

function loadSkillResources(skills) {
  if (!fs.existsSync(RESOURCE_MANIFEST)) return new Map();

  let manifest;
  try {
    manifest = JSON.parse(fs.readFileSync(RESOURCE_MANIFEST, 'utf8'));
  } catch (error) {
    fail(`cannot parse skill-resources.json: ${error.message}`);
  }
  if (!manifest || Array.isArray(manifest) || typeof manifest !== 'object') {
    fail('skill-resources.json must be an object keyed by skill name');
  }

  const resources = new Map();
  for (const [skill, entries] of Object.entries(manifest)) {
    if (!skills.includes(skill)) fail(`skill-resources.json references unknown skill "${skill}"`);
    if (!Array.isArray(entries)) fail(`skill-resources.json entry "${skill}" must be an array`);

    const targets = new Set();
    resources.set(skill, entries.map((entry, index) => {
      if (!entry || typeof entry.source !== 'string' || typeof entry.target !== 'string') {
        fail(`skill-resources.json entry "${skill}"[${index}] needs string source and target paths`);
      }
      const source = path.normalize(entry.source);
      const target = path.normalize(entry.target);
      const unsafe = (value) => path.isAbsolute(value) || value === '..' || value.startsWith(`..${path.sep}`);
      if (!source || unsafe(source)) fail(`skill-resources.json has unsafe source path "${entry.source}"`);
      if (!target || unsafe(target)) fail(`skill-resources.json has unsafe target path "${entry.target}"`);
      if (targets.has(target)) fail(`skill-resources.json repeats target "${entry.target}" for "${skill}"`);
      targets.add(target);

      const sourcePath = path.join(REPO_ROOT, source);
      if (!fs.existsSync(sourcePath) || !fs.statSync(sourcePath).isFile()) {
        fail(`skill-resources.json source does not exist: ${entry.source}`);
      }
      return { sourcePath, target };
    }));
  }
  return resources;
}

function loadHarnesses() {
  const harnesses = [];
  for (const file of fs.readdirSync(HARNESS_DIR).sort()) {
    if (!file.endsWith('.json')) continue;
    const profile = JSON.parse(fs.readFileSync(path.join(HARNESS_DIR, file), 'utf8'));
    if (!profile.id) fail(`harness profile ${file} is missing "id"`);
    if (profile.hiddenSkills !== undefined && !Array.isArray(profile.hiddenSkills)) {
      fail(`harness profile ${file} has a non-array "hiddenSkills"`);
    }
    harnesses.push(profile);
  }
  if (harnesses.length === 0) fail('no harness profiles found in harnesses/');
  return harnesses;
}

function normalizePrompt(body) {
  return body
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .join(' ');
}

// Delegation prompts are authored prose and may legitimately contain quotes,
// backslashes or newlines. Interpolating them raw produced syntactically invalid
// delegation snippets, so every embedded prompt goes through a real string-literal
// encoder.
function jsString(value) {
  return JSON.stringify(String(value));
}

function renderDelegate(harness, skillName, role, skill, prompt) {
  const def = harness.roles?.[role];
  if (!def) {
    fail(`skill "${skillName}": harness "${harness.id}" has no mapping for delegate role "${role}"`);
  }
  if (harness.delegationStyle === 'pi-subagent') {
    if (def.kind !== 'agent') {
      fail(`skill "${skillName}": harness "${harness.id}" role "${role}" must map to an agent for pi-subagent style`);
    }
    const lines = ['subagent({', `  agent: ${jsString(def.agent)},`];
    if (skill) {
      lines.push(`  task: ${jsString(prompt)},`);
      lines.push(`  skill: ${jsString(skill)}`);
    } else {
      lines.push(`  task: ${jsString(prompt)}`);
    }
    lines.push('})');
    return lines.join('\n');
  }
  if (harness.delegationStyle === 'hermes-pi') {
    // Hermes's standard mode is driving pi subprocesses
    // (docs/hermes/execution-modes.md): fresh session per stage/task,
    // session reuse only for small follow-ups within a stage, never across
    // the implementer/reviewer boundary. <session-id> is a placeholder the
    // agent fills at invocation (<plan-slug>-<stage>[-review-<N>] per the
    // convention; reviews ALWAYS get a fresh id — never the author's). -p
    // is mandatory: without it pi launches the interactive TUI and blocks.
    const roleLine = def.role ? `Role: ${def.role}. ` : '';
    let fullPrompt = `${roleLine}${prompt}`;
    if (skill) {
      fullPrompt += ` Follow the loaded skill '${skill}' as the process for this work; if it did not load, stop and report.`;
    }
    const isReview = /review/i.test(role);
    const stage = (def.role ?? skillName).replace(/-reviewer$/, '').replace(/^worker(-high|-low)?$/, 'task-<N>').replace(/^planner$/, 'plan').replace(/^researcher$/, 'research-<topic>');
    const sid = isReview ? `<plan-slug>-${stage}-review-<N>` : `<plan-slug>-${stage}`;
    if (isReview) fullPrompt += ' (Fresh session: never reuse the author\'s session id.)';
    // --model: pi has no role roster, so the tier/role is selected by model.
    // <model-for-ROLE> is resolved from the repo's role->model mapping
    // (AGENTS.md roles table / .pi/settings.json agentOverrides).
    // --skill: load the stage skill directly by path; <skills-dir> is the
    // orchestrator's real skill store (Hermes stores may nest by category).
    const modelArg = def.role ? ` --model <model-for-${def.role}>` : '';
    const skillArg = skill ? ` --skill ${harness.skillPathPrefix}${skill}` : '';
    return `pi -p --session-id ${sid} --name "${def.role ?? skillName}"${modelArg}${skillArg} ${jsString(fullPrompt)}`;
  }
  if (harness.delegationStyle === 'hermes-delegate') {
    // Hermes agents delegate via delegate_task(tasks=[{goal, context}]).
    // Roles are rendered as a Role line inside the goal (Hermes has no named
    // subagent roster; the role sentence orients the child). A `skill=` macro
    // argument points the child at the rendered skill by name — Hermes agents
    // load skills by name via their skill_view tool.
    const roleLine = def.role ? `Role: ${def.role}. ` : '';
    let goal = `${roleLine}${prompt}`;
    if (skill) {
      goal += ` Load and follow your skill '${skill}' (via skill_view) as the process for this task.`;
    }
    return `delegate_task(tasks=[{goal: ${jsString(goal)}}])`;
  }
  if (harness.delegationStyle === 'opencode-task') {
    if (def.kind === 'category') {
      const loadSkills = skill ? `[${jsString(skill)}]` : '[]';
      return `task(category=${jsString(def.category)}, load_skills=${loadSkills}, prompt=${jsString(prompt)})`;
    }
    if (def.kind === 'subagent_type') {
      const loadSkills = skill ? `[${jsString(skill)}]` : '[]';
      return `task(subagent_type=${jsString(def.subagent_type)}, load_skills=${loadSkills}, prompt=${jsString(prompt)})`;
    }
    if (def.kind === 'agent') {
      let message = prompt;
      if (skill) {
        message += ` Read your skill file at ${harness.skillPathPrefix}${skill}/SKILL.md and follow its process.`;
      }
      return ['task({', `  agent: ${jsString(def.agent)},`, `  message: ${jsString(message)}`, '})'].join('\n');
    }
    fail(`skill "${skillName}": harness "${harness.id}" role "${role}" has unknown kind "${def.kind}"`);
  }
  fail(`harness "${harness.id}" has unknown delegationStyle "${harness.delegationStyle}"`);
  return '';
}

function splitFrontmatter(source, skillName) {
  if (!source.startsWith('---\n')) {
    fail(`skill "${skillName}": SKILL.md must start with YAML frontmatter`);
  }
  const end = source.indexOf('\n---\n', 4);
  if (end === -1) fail(`skill "${skillName}": unterminated frontmatter`);
  return {
    fmLines: source.slice(4, end + 1).split('\n'),
    rest: source.slice(end + 5),
  };
}

// Optional `harnesses: [a, b]` frontmatter restricts a skill to specific harnesses.
// Absent => the skill renders for every harness.
function skillHarnesses(source, skillName) {
  const { fmLines } = splitFrontmatter(source, skillName);
  for (const line of fmLines) {
    const match = line.match(/^harnesses:\s*\[(.*)\]\s*$/);
    if (match) {
      return match[1]
        .split(',')
        .map((value) => value.trim())
        .filter((value) => value.length > 0);
    }
  }
  return null;
}

function injectCompatibility(source, harness, skillName) {
  const { fmLines, rest } = splitFrontmatter(source, skillName);
  const kept = [];
  let descIndex = -1;
  for (const line of fmLines) {
    if (/^compatibility:/.test(line)) continue; // renderer owns compatibility
    if (/^harnesses:/.test(line)) continue; // applicability is build-time only
    if (/^disable-model-invocation:/.test(line)) continue; // renderer owns discoverability
    kept.push(line);
    if (/^description:/.test(line)) descIndex = kept.length - 1;
  }
  if (descIndex === -1) fail(`skill "${skillName}": frontmatter missing "description"`);
  const injected = [`compatibility: ${harness.compatibility}`];
  // Per-harness discoverability. A skill listed in a harness profile's
  // `hiddenSkills` is kept out of that harness's system prompt but stays
  // loadable via `/skill:<name>`. Declared per harness rather than in canonical
  // frontmatter so hiding a skill from one harness cannot alter another
  // harness's rendered output.
  if (Array.isArray(harness.hiddenSkills) && harness.hiddenSkills.includes(skillName)) {
    injected.push('disable-model-invocation: true');
  }
  kept.splice(descIndex + 1, 0, ...injected);
  // kept ends with a trailing empty string from the split; rebuild cleanly.
  const fmText = kept.filter((line, idx) => !(idx === kept.length - 1 && line === '')).join('\n');
  return `---\n${fmText}\n---\n${rest}`;
}

function renderSkill(source, harness, skillName) {
  let out = injectCompatibility(source, harness, skillName);
  out = out.replace(DELEGATE_RE, (match, role, skill, body) => {
    const prompt = normalizePrompt(body);
    return renderDelegate(harness, skillName, role, skill, prompt);
  });
  out = out.replace(NOTE_RE, (match, key) => {
    const value = harness.notes?.[key];
    if (value === undefined) {
      fail(`skill "${skillName}": harness "${harness.id}" has no note "${key}"`);
    }
    return value;
  });
  const leftover = out.match(LEFTOVER_RE);
  if (leftover) {
    fail(`skill "${skillName}": unexpanded macro "${leftover[0]}" for harness "${harness.id}"`);
  }
  return out;
}

// Build the in-memory rendered tree: { "<harness>/<name>/<relpath>": contents }
function buildRenderTree() {
  const harnesses = loadHarnesses();
  const skills = listDirs(SKILLS_DIR).filter((name) =>
    fs.existsSync(path.join(SKILLS_DIR, name, 'SKILL.md')),
  );
  const skillResources = loadSkillResources(skills);
  const tree = new Map();
  for (const harness of harnesses) {
    for (const skill of skills) {
      const skillDir = path.join(SKILLS_DIR, skill);
      const source = fs.readFileSync(path.join(skillDir, 'SKILL.md'), 'utf8');
      const applicable = skillHarnesses(source, skill);
      if (applicable && !applicable.includes(harness.id)) continue;
      const rendered = renderSkill(source, harness, skill);
      tree.set(path.join(harness.id, skill, 'SKILL.md'), rendered);
      // Copy supporting files (references/, templates/, etc.) verbatim.
      for (const rel of walkFiles(skillDir)) {
        if (rel === 'SKILL.md') continue;
        tree.set(path.join(harness.id, skill, rel), fs.readFileSync(path.join(skillDir, rel)));
      }
      // Materialize shared framework-owned resources into self-contained skill trees.
      for (const resource of skillResources.get(skill) ?? []) {
        const outputPath = path.join(harness.id, skill, resource.target);
        if (tree.has(outputPath)) {
          fail(`skill "${skill}" resource target collides with a local file: ${resource.target}`);
        }
        tree.set(outputPath, fs.readFileSync(resource.sourcePath));
      }
    }
  }
  return tree;
}

function walkFiles(root, prefix = '') {
  const result = [];
  for (const entry of fs.readdirSync(path.join(root, prefix), { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
    const rel = prefix ? path.join(prefix, entry.name) : entry.name;
    if (entry.isDirectory()) result.push(...walkFiles(root, rel));
    else if (entry.isFile()) result.push(rel);
  }
  return result;
}

function writeTree(tree) {
  fs.rmSync(DIST_DIR, { recursive: true, force: true });
  for (const [rel, contents] of [...tree.entries()].sort((a, b) => a[0].localeCompare(b[0]))) {
    const dest = path.join(DIST_DIR, rel);
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.writeFileSync(dest, contents);
  }
  process.stdout.write(`render-skills: wrote ${tree.size} file(s) to dist/skills/\n`);
}

function checkTree(tree) {
  const drift = [];
  for (const [rel, contents] of tree.entries()) {
    const dest = path.join(DIST_DIR, rel);
    if (!fs.existsSync(dest)) {
      drift.push(`missing: dist/skills/${rel}`);
      continue;
    }
    const onDisk = fs.readFileSync(dest);
    const expected = Buffer.isBuffer(contents) ? contents : Buffer.from(contents);
    if (!onDisk.equals(expected)) drift.push(`changed: dist/skills/${rel}`);
  }
  // Detect stray files in dist that the render no longer produces.
  const expectedPaths = new Set([...tree.keys()].map((rel) => path.join(DIST_DIR, rel)));
  for (const file of existingDistFiles()) {
    if (!expectedPaths.has(file)) drift.push(`stale: ${path.relative(REPO_ROOT, file)}`);
  }
  if (drift.length > 0) {
    process.stderr.write('render-skills: dist/ is out of date. Run `node tools/render-skills.mjs --write`.\n');
    for (const line of drift.sort()) process.stderr.write(`  ${line}\n`);
    process.exit(1);
  }
  process.stdout.write(`render-skills: dist/skills/ is up to date (${tree.size} file(s)).\n`);
}

function existingDistFiles() {
  if (!fs.existsSync(DIST_DIR)) return [];
  const result = [];
  const stack = [DIST_DIR];
  while (stack.length > 0) {
    const dir = stack.pop();
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) stack.push(full);
      else result.push(full);
    }
  }
  return result;
}

function main() {
  const mode = process.argv[2];
  if (mode !== '--write' && mode !== '--check') {
    fail('usage: render-skills.mjs --write | --check');
  }
  const tree = buildRenderTree();
  if (mode === '--write') writeTree(tree);
  else checkTree(tree);
}

main();
