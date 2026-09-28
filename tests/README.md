# Engineering Agents Test Suite

The canonical testing strategy for this repository lives in `docs/testing-strategy.md`.
Use this README for the current suite inventory, file layout, and adaptation notes.

## Test Tiers

| Tier | What | Requires | Runner |
|------|------|----------|--------|
| **Repo-local specs** | File structure, readiness docs, frontmatter, skill/agent refs, compiler, presets | `bash`, `jq`, `node` | `tests/run-tests.sh fast` |
| **Flake eval** | Nix module evaluation, package builds | `nix` | `tests/run-tests.sh all` |
| **Sandboxed Pi proof-set** | Current-checkout activation, facade/provenance snapshot, and behavioral `pi list` load smoke in `.pi-dev` | `nix`; network on first install | `scripts/pi-dev.sh --verify` |
| **Pi proof-set** | Live facade/provenance snapshot plus behavioral load smoke (`pi list`) | Pi installed, `home-manager switch` run | `tests/run-tests.sh all` |
| **CLI smoke** | `pi --help`, `pi list` output | Pi installed | `tests/run-tests.sh full` |

## Quick Commands

```bash
# Repo-local only (no Nix or Pi required)
./tests/run-tests.sh fast

# Repo-local + flake eval + proof-set
./tests/run-tests.sh all

# Everything including CLI smoke
./tests/run-tests.sh full

# Individual specs
bash tests/specs/repo-structure-spec.sh
bash tests/specs/repo-readiness-docs-spec.sh
bash tests/specs/proof-set-runtime-spec.sh
bash tests/specs/skill-content-spec.sh
bash tests/specs/skill-render-spec.sh
bash tests/specs/hermes-docs-spec.sh
bash tests/specs/flake-eval-spec.sh
bash tests/specs/preset-spec.sh
bash tests/specs/pi-module-content-spec.sh
bash tests/specs/pi-vendor-spec.sh
bash tests/specs/pi-preset-refresh-contract-spec.sh
bash tests/specs/pi-btw-refresh-contract-spec.sh
bash tests/specs/compiler-contract-spec.sh
bash tests/specs/managed-package-install-state-spec.sh
bash tests/specs/managed-package-status-spec.sh
bash tests/specs/pi-startup-wrapper-spec.sh
bash tests/specs/pi-dev-spec.sh
bash tests/specs/startup-warning-extension-spec.sh
bash tests/specs/pi-tasks-bridge-spec.sh
bash tests/specs/pi-startup-warning-contract-spec.sh
```

## Test Adaptation

This suite is adapted from `dotfiles/nix/tests/pi/`. The following were ported:

- **`resource-snapshot.mjs`** — Live Pi state snapshot from the filesystem and facade manifests (Pi >=0.80.8 ships as a compiled bundle with no importable module; schemaVersion 2 output unchanged)
- **`assert-contract.sh`** — Proof-set contract assertions (facade, provenance, resources)
- **`compiler-contract-spec.sh`** — Compile-managed-packages.mjs fixture tests
- **`hermes-docs-spec.sh`** — Hermes-agent operations docs and sweep-monitor contract
- **`proof-set.json`** — Representative proof-set expectations for the default Powerline profile (pi-ding, pi-subagents, pi-powerline-footer, catppuccin-mocha, pi-ext-leader-key, pi-ext-review)
- **Spec fixture directories** — Compiler declarations, resource-snapshot snapshots

New tests specific to this repo:

- **`repo-structure-spec.sh`** — All required files/dirs exist, README has key content
- **`repo-readiness-docs-spec.sh`** — Root AGENTS routing and canonical contributor docs exist with required anchors
- **`proof-set-runtime-spec.sh`** — Snapshot generator facade-manifest enumeration, deterministic ordering, missing-resource diagnostics, and environment-failure propagation
- **`skill-content-spec.sh`** — Skill frontmatter, references, templates, key sections
- **`skill-render-spec.sh`** — Skill render pipeline drift + per-harness delegation checks (canonical sources × `harnesses/*.json` → `dist/`)
- **`pi-module-content-spec.sh`** — Module skill/agent refs resolve, guardrails valid JSON, compile helper valid JS
- **`pi-vendor-spec.sh`** — Build-time vendor contracts: git pins match declarations, spec/installSpec normalized, injected core not vendored, nested lock shape
- **`pi-preset-refresh-contract-spec.sh`** — Paired `@richardgill/pi-preset` + `pi-config` 0.0.9 manifest, Nix declaration, and lockfile version alignment
- **`pi-btw-refresh-contract-spec.sh`** — `pi-btw` 0.6.1 declaration/manifest/lock contract, its Pi core peer compatibility, `pi-subdir-context` as a pinned git source (outside the npm graph), no npm `overrides`, and a fully integrity-complete lock.
- **`preset-spec.sh`** — All three modes (discovery/design/execute) defined, all 8 agents present
- **`flake-eval-spec.sh`** — All modules evaluate, docs package builds, dev shell works
- **`managed-package-install-state-spec.sh`** — Managed package install-state helper fixture tests
- **`managed-package-status-spec.sh`** — Shared managed package status engine + `check-updates` fixture tests
- **`pi-startup-wrapper-spec.sh`** — Repo-owned `pi` wrapper startup snapshot/env handoff tests
- **`pi-dev-spec.sh`** — Repo-local Pi development sandbox isolation and credential-copy tests
- **`startup-warning-extension-spec.sh`** — Startup notifier rendering, footer/status sync, and snapshot consumption tests
- **`pi-tasks-bridge-spec.sh`** — pi-tasks `TaskExecute` → managed pi-subagents RPC bridge (fake event bus; no model)
- **`pi-startup-warning-contract-spec.sh`** — Startup warning/helper/README workflow alignment and helper-install wiring tests

## File Layout

```
tests/
├── lib/common.sh                    # Shared utilities (paths, assertions)
├── fixtures/proof-set.json          # Proof-set expectations for live verification
├── scripts/
│   ├── assert-contract.sh           # Proof-set contract assertions
│   └── resource-snapshot.mjs        # Live Pi state snapshot generator
├── spec-fixtures/
│   ├── compiler/                    # compile-managed-packages.mjs test inputs
│   ├── managed-package-install-state/ # install-state helper test inputs
│   ├── managed-package-status/      # shared status engine + check-updates fixtures
│   ├── pi-startup-wrapper/          # repo-owned pi wrapper fixtures
│   ├── startup-warning-extension/   # startup notifier snapshot fixtures
│   ├── resource-snapshot.*          # Snapshot contract test fixtures
│   └── update-checker/              # Update checker test fixtures
├── specs/
│   ├── repo-structure-spec.sh       # File/dir existence checks
│   ├── repo-readiness-docs-spec.sh  # Root routing and core contributor docs
│   ├── proof-set-runtime-spec.sh    # Proof-set runtime contract regression checks
│   ├── skill-content-spec.sh        # Skill quality checks
│   ├── skill-render-spec.sh         # Skill render pipeline drift + delegation checks
│   ├── pi-module-content-spec.sh    # Module content integrity
│   ├── preset-spec.sh               # Preset configuration validation
│   ├── flake-eval-spec.sh           # Nix flake evaluation
│   ├── compiler-contract-spec.sh    # Compile helper contract tests
│   ├── managed-package-install-state-spec.sh # Install-state helper contract tests
│   ├── managed-package-status-spec.sh # Shared status engine + check-updates contract tests
│   ├── pi-startup-wrapper-spec.sh   # Repo-owned pi wrapper contract tests
│   ├── pi-dev-spec.sh               # Repo-local Pi development sandbox contract tests
│   ├── pi-preset-refresh-contract-spec.sh # Paired Pi preset/config vendor version contract
│   ├── pi-btw-refresh-contract-spec.sh # pi-btw 0.6.1 + Pi core peer resolution contract
│   ├── startup-warning-extension-spec.sh # Startup notifier contract tests
│   ├── pi-tasks-bridge-spec.sh # pi-tasks -> pi-subagents bridge contract
│   └── pi-startup-warning-contract-spec.sh # Startup warning/helper/docs contract tests
├── test-fast.sh                     # Read-only Pi proof-set verification
└── run-tests.sh                     # Main test runner (fast/all/full)
```
