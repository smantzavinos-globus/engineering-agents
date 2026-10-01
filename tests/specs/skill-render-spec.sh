#!/usr/bin/env bash
# Verify the skill render pipeline: dist/ is up to date with canonical sources,
# and each harness tree uses the correct harness-specific delegation syntax.
# Requirement: FR-007
# Requirement: FR-008
# Requirement: NFR-003
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

require_commands node >/dev/null

REPO_ROOT="$(repo_root)"
PASS=0 FAIL=0

pass() { PASS=$((PASS + 1)); printf '  PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL: %s\n' "$1" >&2; }

# ============================================================
printf 'Skill render pipeline verification\n'
printf '==================================\n\n'

# Harness profiles exist and are valid JSON
for harness in pi opencode hermes; do
  profile="$REPO_ROOT/harnesses/${harness}.json"
  if node -e "JSON.parse(require('fs').readFileSync('$profile','utf8'))" 2>/dev/null; then
    pass "Harness profile '${harness}.json' is valid JSON"
  else
    fail "Harness profile '${harness}.json' is missing or invalid JSON"
  fi
done

# Renderer has valid syntax
if node --check "$REPO_ROOT/tools/render-skills.mjs" 2>/dev/null; then
  pass "render-skills.mjs has valid syntax"
else
  fail "render-skills.mjs has syntax errors"
fi

# dist/ must match a fresh render (drift gate). This is the core contract:
# canonical skills + harness profiles are the single source of truth.
if node "$REPO_ROOT/tools/render-skills.mjs" --check >/dev/null 2>&1; then
  pass "dist/skills/ is up to date with canonical sources + harness profiles"
else
  fail "dist/skills/ is stale — run: node tools/render-skills.mjs --write"
fi

# Skills that declare packaged references in skill-resources.json must render them
for packaged in discover-and-design discover-and-design-simple; do
  for resource in references/brief-template.md references/approach-template.md; do
    if grep -q "skills/discovery/references/brief-template.md\|skills/design/references/approach-template.md" skill-resources.json \
       && [[ -f "$REPO_ROOT/dist/skills/pi/${packaged}/${resource}" ]]; then
      pass "${packaged} packages ${resource}"
    else
      fail "${packaged} is missing packaged ${resource} — check skill-resources.json entries for discover-and-design*"
    fi
  done
done

# Retired parallel-machinery skills must not be rendered anywhere
for retired in dynamic-create-plan dynamic-execute-plan dynamic-review-plan dynamic-review-code direct-plan create-team-plan review-team-plan create-team-worklog execution-orchestrator-team; do
  if [[ -e "$REPO_ROOT/dist/skills/pi/${retired}" || -e "$REPO_ROOT/dist/skills/opencode/${retired}" ]]; then
    fail "${retired} is retired but still rendered"
  else
    pass "${retired} is not rendered (retired with ADR 0006)"
  fi
done

# Canonical sources must NOT hardcode compatibility in their frontmatter block
# (the renderer injects it per harness). Body documentation may still mention it.
if node -e '
  const fs=require("fs"),path=require("path");
  const dir=path.join(process.argv[1],"skills");
  let bad=[];
  for(const name of fs.readdirSync(dir)){
    const f=path.join(dir,name,"SKILL.md");
    if(!fs.existsSync(f))continue;
    const src=fs.readFileSync(f,"utf8");
    if(!src.startsWith("---\n"))continue;
    const end=src.indexOf("\n---\n",4);
    const fm=src.slice(4,end);
    if(/^compatibility:/m.test(fm))bad.push(name);
  }
  if(bad.length){console.error(bad.join(","));process.exit(1);}
' "$REPO_ROOT" 2>/dev/null; then
  pass "canonical skills/ leave compatibility to the renderer"
else
  fail "canonical skills/ hardcode 'compatibility:' in frontmatter (renderer injects it)"
fi

# No unexpanded macros may survive into any rendered tree
if grep -rn '{{' "$REPO_ROOT/dist/skills/" >/dev/null 2>&1; then
  fail "rendered dist/ contains unexpanded {{...}} macros"
else
  pass "rendered dist/ has no unexpanded macros"
fi

# Pi tree uses Pi delegation syntax (subagent), never the OpenCode task tool
if grep -rn 'task(category=\|task({' "$REPO_ROOT/dist/skills/pi/" >/dev/null 2>&1; then
  fail "Pi tree must not contain OpenCode 'task(...)' delegation"
else
  pass "Pi tree uses only Pi-style delegation"
fi
if grep -rln 'subagent({' "$REPO_ROOT/dist/skills/pi/design/SKILL.md" >/dev/null 2>&1; then
  pass "Pi design renders subagent({...}) delegation"
else
  fail "Pi design is missing subagent({...}) delegation"
fi

# OpenCode tree must not contain Pi-style subagent() calls
if grep -rn 'subagent(' "$REPO_ROOT/dist/skills/opencode/" >/dev/null 2>&1; then
  fail "OpenCode tree must not contain Pi 'subagent(...)' delegation"
else
  pass "OpenCode tree uses only OpenCode-style delegation"
fi

# The review/oracle roles must render as category delegation in OpenCode
# (replacing the former plan-reviewer / code-reviewer / oracle subagents).
for skill_check in \
  "execution-orchestrator:review-plan" \
  "execution-orchestrator:review-code" \
  "design:review-approach"; do
  skill="${skill_check%%:*}"
  loadskill="${skill_check##*:}"
  if grep -q "task(category=\"deep\", load_skills=\[\"${loadskill}\"\]" \
      "$REPO_ROOT/dist/skills/opencode/${skill}/SKILL.md"; then
    pass "OpenCode ${skill} delegates ${loadskill} via category"
  else
    fail "OpenCode ${skill} does not delegate ${loadskill} via category"
  fi
done

# OpenCode plan creation and implementation roles delegate via task categories
if grep -q 'task(category="deep", load_skills=\["create-plan"\]' \
    "$REPO_ROOT/dist/skills/opencode/execution-orchestrator/SKILL.md"; then
  pass "OpenCode execution-orchestrator delegates planning via category"
else
  fail "OpenCode execution-orchestrator does not delegate planning via category"
fi
if grep -q 'task(category="unspecified-high", load_skills=\["execute-task"\]' \
    "$REPO_ROOT/dist/skills/opencode/execution-orchestrator/SKILL.md"; then
  pass "OpenCode execution-orchestrator delegates task execution via category"
else
  fail "OpenCode execution-orchestrator does not delegate task execution via category"
fi

# OpenCode research roles delegate to built-in explore/librarian subagent types
if grep -q 'task(subagent_type="explore", load_skills=\["research"\]' \
    "$REPO_ROOT/dist/skills/opencode/design/SKILL.md"; then
  pass "OpenCode design delegates codebase research to the explore subagent"
else
  fail "OpenCode design does not delegate codebase research to explore"
fi
if grep -q 'task(subagent_type="librarian", load_skills=\["research"\]' \
    "$REPO_ROOT/dist/skills/opencode/design/SKILL.md"; then
  pass "OpenCode design delegates external research to the librarian subagent"
else
  fail "OpenCode design does not delegate external research to librarian"
fi

# Pi keeps named subagents for those same roles
if grep -q 'agent: "worker"' "$REPO_ROOT/dist/skills/pi/design/SKILL.md"; then
  pass "Pi design keeps the worker subagent for research"
else
  fail "Pi design lost the worker subagent for research"
fi

# configure-opencode is OpenCode-only and must not leak into the Pi tree
if [[ -e "$REPO_ROOT/dist/skills/pi/configure-opencode" ]]; then
  fail "configure-opencode (opencode-only) leaked into the Pi tree"
else
  pass "configure-opencode is excluded from the Pi tree"
fi
if [[ -f "$REPO_ROOT/dist/skills/opencode/configure-opencode/SKILL.md" ]]; then
  pass "configure-opencode is present in the OpenCode tree"
else
  fail "configure-opencode is missing from the OpenCode tree"
fi

# configure-pi is Pi-only, project-scoped, and preserves the spawn-limit boundary.
if [[ -f "$REPO_ROOT/dist/skills/pi/configure-pi/SKILL.md" ]] \
  && grep -Fq '`.pi/settings.json`' "$REPO_ROOT/dist/skills/pi/configure-pi/SKILL.md" \
  && grep -Fq '`.pi/extensions/guardrails.json`' "$REPO_ROOT/dist/skills/pi/configure-pi/SKILL.md" \
  && grep -Fq '`.pi/session-autoname.json`' "$REPO_ROOT/dist/skills/pi/configure-pi/SKILL.md" \
  && grep -Fq 'seeds `github-copilot/gpt-6-luna`' "$REPO_ROOT/dist/skills/pi/configure-pi/SKILL.md" \
  && grep -Fq 'pathAccess.allowedPaths' "$REPO_ROOT/dist/skills/pi/configure-pi/SKILL.md" \
  && grep -Fq 'autoDenyPatterns' "$REPO_ROOT/dist/skills/pi/configure-pi/SKILL.md" \
  && grep -Fq 'maxSubagentSpawnsPerSession' "$REPO_ROOT/dist/skills/pi/configure-pi/SKILL.md" \
  && grep -Fq 'PI_SUBAGENT_MAX_SPAWNS_PER_SESSION=100 pi' "$REPO_ROOT/dist/skills/pi/configure-pi/SKILL.md" \
  && grep -Fq 'outside this project-scoped skill' "$REPO_ROOT/dist/skills/pi/configure-pi/SKILL.md"; then
  pass "configure-pi documents project settings, repository Guardrails, session naming, and spawn-limit boundaries"
else
  fail "configure-pi is missing Pi project settings, repository Guardrails, session naming, or spawn-limit boundaries"
fi
if [[ -e "$REPO_ROOT/dist/skills/opencode/configure-pi" ]]; then
  fail "configure-pi (pi-only) leaked into the OpenCode tree"
else
  pass "configure-pi is excluded from the OpenCode tree"
fi

# Team mode was replaced by code-mode execution: the Pi-only team skills are gone,
# and the retired orchestration skills render for OpenCode only.
for gone in pi-team-plan pi-team-lead pi-team-worker; do
  if [[ ! -e "$REPO_ROOT/dist/skills/pi/${gone}" ]]; then
    pass "${gone} is absent from the Pi tree"
  else
    fail "${gone} must be absent from the Pi tree"
  fi
done
# The sequential pipeline is universal (Spiros ruling on PR#25: the wave
# approach is no longer used by any harness) — pipeline skills render for
# every harness. Still harness-scoped: configure-* and the Hermes-process
# skills (skill-sync, software-development).
for oc_only in execution-orchestrator execute-task create-worklog \
                create-plan review-plan review-code; do
  if [[ -f "$REPO_ROOT/dist/skills/pi/${oc_only}/SKILL.md" ]] \
     && [[ -f "$REPO_ROOT/dist/skills/opencode/${oc_only}/SKILL.md" ]] \
     && [[ -f "$REPO_ROOT/dist/skills/hermes/${oc_only}/SKILL.md" ]]; then
    pass "${oc_only} renders for every harness (universal pipeline)"
  else
    fail "${oc_only} must render in all three trees (universal pipeline)"
  fi
done
for hermes_only in skill-sync software-development; do
  if [[ -e "$REPO_ROOT/dist/skills/pi/${hermes_only}" || -e "$REPO_ROOT/dist/skills/opencode/${hermes_only}" ]]; then
    fail "${hermes_only} (hermes-only) leaked into pi/opencode trees"
  else
    pass "${hermes_only} is excluded from the pi/opencode trees"
  fi
  if [[ -f "$REPO_ROOT/dist/skills/hermes/${hermes_only}/SKILL.md" ]]; then
    pass "${hermes_only} is present in the Hermes tree"
  else
    fail "${hermes_only} is missing from the Hermes tree"
  fi
done

# Per-harness discoverability: hiddenSkills in harnesses/pi.json must render
# disable-model-invocation for Pi only, never for OpenCode.
for hidden in discovery design discover-and-design discover-and-design-simple research; do
  if grep -Fq 'disable-model-invocation: true' "$REPO_ROOT/dist/skills/pi/${hidden}/SKILL.md"; then
    pass "${hidden} is hidden from the Pi system prompt"
  else
    fail "${hidden} should be hidden from the Pi system prompt"
  fi
  if [[ -f "$REPO_ROOT/dist/skills/opencode/${hidden}/SKILL.md" ]] \
     && grep -Fq 'disable-model-invocation' "$REPO_ROOT/dist/skills/opencode/${hidden}/SKILL.md"; then
    fail "${hidden} discoverability must not leak into the OpenCode tree"
  else
    pass "${hidden} discoverability does not leak into the OpenCode tree"
  fi
done
for shown in assess-repo; do
  if grep -Fq 'disable-model-invocation' "$REPO_ROOT/dist/skills/pi/${shown}/SKILL.md"; then
    fail "${shown} must remain discoverable in Pi"
  else
    pass "${shown} remains discoverable in Pi"
  fi
done

# The team-mode execution skills are OpenCode-only and must not leak into Pi
# Retired team skills must not appear in either harness tree (covered above), and
# the retired parallel resources must not be referenced by any rendered skill.
if grep -rqE 'dynamic-(create|execute|review)|execution-orchestrator-team|create-team-plan' "$REPO_ROOT/dist/skills/pi" "$REPO_ROOT/dist/skills/opencode" 2>/dev/null; then
  fail "rendered skills must not reference retired parallel machinery"
else
  pass "rendered skills reference no retired parallel machinery"
fi

# Every rendered SKILL.md must carry the harness-correct compatibility value
for harness in pi opencode hermes; do
  bad=0
  while IFS= read -r f; do
    if ! grep -q "^compatibility: ${harness}$" "$f"; then bad=$((bad + 1)); fi
  done < <(find "$REPO_ROOT/dist/skills/${harness}" -name SKILL.md)
  if [[ "$bad" -eq 0 ]]; then
    pass "All ${harness} skills declare compatibility: ${harness}"
  else
    fail "${bad} ${harness} skill(s) have wrong compatibility frontmatter"
  fi
done

# ============================================================
# Every rendered Pi delegation block must be syntactically valid JavaScript.
# Prompts are prose and may contain quotes or backslashes; raw interpolation
# silently emitted broken snippets before the renderer encoded them properly.
if node -e '
const fs = require("fs"), path = require("path");
let bad = 0, n = 0;
const root = path.join(process.argv[1], "dist", "skills", "pi");
for (const d of fs.readdirSync(root)) {
  const f = path.join(root, d, "SKILL.md");
  if (!fs.existsSync(f)) continue;
  for (const m of fs.readFileSync(f, "utf8").matchAll(/^subagent\(\{[\s\S]*?^\}\)$/gm)) {
    n += 1;
    try { new Function("subagent", "return " + m[0]); }
    catch (e) { bad += 1; console.error(`invalid subagent block in ${d}: ${e.message}`); }
  }
}
if (n === 0) { console.error("no subagent blocks found to check"); process.exit(1); }
process.exit(bad === 0 ? 0 : 1);
' "$REPO_ROOT"; then
  pass "every rendered Pi subagent block is valid JavaScript"
else
  fail "a rendered Pi subagent block is not valid JavaScript"
fi

printf '\n'
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
