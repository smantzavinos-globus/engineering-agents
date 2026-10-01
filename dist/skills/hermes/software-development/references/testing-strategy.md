# Testing Strategy

## Standard Level Mapping

| Standard level | Repo command | Scope | Typical timing | Typical duration | What it proves |
|---|---|---|---|---|---|
| Fast feedback | `bash tests/specs/repo-readiness-docs-spec.sh` or `bash tests/specs/proof-set-runtime-spec.sh` | touched-files | While working a task | seconds | The touched readiness docs or proof-set helper behavior changed as intended without waiting for the whole suite |
| Integration / task completion gate | `./tests/run-tests.sh fast` | package-wide | Before marking a task complete | under a minute | The repo-local shell spec suite, runner wiring, and doc/helper contracts still agree |
| Local Pi deployment verification | `./scripts/pi-dev.sh --verify` | current checkout | Before pushing Pi-module, package, skill, or extension changes | minutes; network on first run | The sandboxed Home Manager activation, generated facades, snapshot contract, and behavioral `pi list` load pass work from the working tree |
| Build / final plan gate | `./tests/run-tests.sh all` | repo-wide | Before declaring the plan complete | minutes | Repo-local specs, flake evaluation, and Pi proof-set verification are all trustworthy together |
| Full verification | `./tests/run-tests.sh full` | repo-wide | Optional release smoke after the final gate | minutes | Everything in `all` plus live Pi CLI smoke coverage still works |

## Scope, Timing, and Prerequisites

### `bash tests/specs/repo-readiness-docs-spec.sh`
- **Standard level:** Fast feedback
- **Scope:** touched-files
- **When to run:** while working a task that touches repo-local operational docs
- **Prerequisites:** `bash`
- **What it catches:** missing routes, missing canonical docs, stale anchors, and inconsistent task/final gate references

### `bash tests/specs/proof-set-runtime-spec.sh`
- **Standard level:** Fast feedback
- **Scope:** touched-files
- **When to run:** while working a task that touches proof-set verification helpers
- **Prerequisites:** `bash`, `jq`, `node`
- **What it catches:** facade-manifest snapshot enumeration (extensions/skills/themes, provenance, `_source` resolution), missing-resource diagnostics, deterministic snapshot ordering, and explicit non-zero proof-set environment failures

### `./tests/run-tests.sh fast`
- **Standard level:** Integration / task completion gate
- **Scope:** package-wide
- **When to run:** at a fence-group boundary, or before recording a sequential task completion gate
- **Prerequisites:** `bash`, `jq`, `node`
- **What it catches:** shell-spec aggregation drift, broken runner wiring, doc/test contract mismatches, and repo-local packaging contract regressions

### `./scripts/pi-dev.sh --verify`
- **Standard level:** Local Pi deployment verification
- **Scope:** current checkout
- **When to run:** before pushing changes to the Pi module, managed packages, extensions, skills, or their activation wiring
- **Prerequisites:** `nix`; network access on the first sandbox activation
- **What it catches:** generated-facade, managed-package installation, snapshot contract failures, and behavioral load failures (`pi list`) using the current working tree under `.pi-dev/`
- **Boundary:** this is an isolated sandbox and does not replace `./tests/run-tests.sh all`, which verifies the active Home Manager installation and its production wrapper path

### `./tests/run-tests.sh all`
- **Standard level:** Build / final plan gate
- **Scope:** repo-wide
- **When to run:** at the final gate, before the plan is marked complete
- **Prerequisites:** everything required for `fast`, plus `nix`, `pi`, and a completed `home-manager switch --flake .#<hostname>` so the proof-set environment exists
- **What it catches:** flake evaluation failures, proof-set verification failures, and broader repo-wide integration drift that the fast suite cannot see

### `./tests/run-tests.sh full`
- **Standard level:** Full verification
- **Scope:** repo-wide
- **When to run:** optional post-plan or release smoke
- **Prerequisites:** everything required for `all`, plus a working `pi` CLI on PATH
- **What it catches:** CLI help/list smoke regressions on top of the final plan gate

## Targeted Shell Specs
- `bash tests/specs/repo-structure-spec.sh` — repo structure and required file presence
- `bash tests/specs/repo-readiness-docs-spec.sh` — root routing and canonical repo-operating docs
- `bash tests/specs/proof-set-runtime-spec.sh` — proof-set runtime contract regression coverage
- `bash tests/specs/skill-content-spec.sh` — skill frontmatter and content checks
- `bash tests/specs/pi-module-content-spec.sh` — Pi module content integrity
- `bash tests/specs/preset-spec.sh` — preset configuration validation
- `bash tests/specs/compiler-contract-spec.sh` — compile helper and fixture contract validation
- `bash tests/specs/wave-engine-spec.sh` — Parallel graph helpers: validation, fence groups, failure classification, generated DAG workflowScript
- `bash tests/specs/plan-check-spec.sh` — plan gate: tasks.json schema, verification classes, intra-wave write-set collisions, plan drift
- `bash tests/specs/flake-eval-spec.sh` — Nix flake evaluation (included by `./tests/run-tests.sh all`)
- `bash tests/specs/pi-dev-spec.sh` — repo-local Pi sandbox isolation and credential-copy contract

## Gate Roles
- **Task completion gate:** `./tests/run-tests.sh fast`
- **Final plan gate:** `./tests/run-tests.sh all`
- **Optional release smoke:** `./tests/run-tests.sh full`

### Verification classes

Verification classes apply to every plan, sequential included. Each task
declares one **verification class** when the plan is written:

| Class | When | What proves it |
|---|---|---|
| `contract` | new or changed observable behaviour | a test authored first, by an agent other than the implementer, then frozen |
| `characterization` | refactor with no behaviour change | the existing suite, scoped |
| `check` | config, wiring, generated artifacts, schema | a structural check command |
| `none` | prose with no structural contract | the repo's existing docs spec |

The test that decides the class: *can this fail because of a change in the behaviour or
artifact the task modifies, without a manual edit of the oracle?* If not, it is a `check`, or
honestly `none`. A test asserting a document contains a sentence the same task just wrote is
not a test. TDD catches legitimate regressions; it does not pin volatile content (config
values, documentation wording, copy that is meant to change).

**There is no mandatory break-it step.** A break-it demonstration is reserved for
high-risk invariant tests — money, auth, data loss, irreversible operations — where a
false green is expensive. It is reviewer-initiated, on a specific suspicious test, never
a default per-task ritual.

For `contract` tasks the frozen tests are protected mechanically, not by trust:

```
git diff --exit-code <contract-commit> -- <testPaths> && <verify command>
```

A passing test therefore cannot mean an edited test.

### Ownership

- **Contract author:** writes failing tests before implementation, observes red once, with evidence. Never the implementer.
- **Implementer:** makes the frozen test pass. Runs its own task-scoped check only.
- **Orchestrator:** runs all verification on the host at task and plan boundaries, classifies failures, commits checkpoints. Verification is never delegated away from the host.
- **Code reviewer:** per-task and final-diff review; may demand a break-it demonstration on a specific suspicious test.
- **Fresh final reviewer:** full-diff review with no knowledge of how the tasks went.

## Related Docs
- `docs/approaches/parallel.md` — Parallel scheduler, fences, and verification classes.
- `docs/execution-patterns.md` — runtime sandbox constraints and the parent-driven loop.
- `plans/README.md` — tells plans where to source these commands and gate roles.
- `tests/README.md` — suite inventory, file layout, and individual spec entry points.
- `docs/issues_learnings.md` — place recurring verification surprises or lessons here when they should stay visible.

`tests/README.md` remains the suite inventory and file-layout companion document. This file is the canonical mapping from the repo's command surface to the standard testing levels, and the canonical statement of who owns which verification.
