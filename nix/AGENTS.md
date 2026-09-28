# Nix Directory Guide

Read this file before editing modules, generated-package helpers, or checked-in policy data under `nix/`.

## Module Boundaries
- Keep `nix/modules/pi/` focused on Pi installation, managed-package wiring, settings, and repo-shipped agent/skill assets.
- Keep `nix/modules/opencode/` focused on OpenCode configuration and plugin wiring.
- Do not move repo-process policy into Nix unless it materially affects generated configuration or installation behavior.

## Managed Package Sources (build-time materialization)
- Managed packages are materialized at BUILD time in `nix/modules/pi/config.nix` (`makePiManagedPackages`): an npm vendor bundle (`managed-packages/package.json` + lock, installed by offline `npm ci` from a fixed-output npm cache) plus `fetchzip`-pinned git tarballs, compiled into facades by `compile-managed-packages.mjs`. Nothing npm-shaped runs at activation time.
- Every `git`-source managed package must pin an immutable 40-hex commit in BOTH `managedPackages` (spec/installSpec) and `gitSources` (rev + tarball URL). `tests/specs/pi-vendor-spec.sh` enforces the pair stays in sync. To update a git-source package, bump both pins and `tests/fixtures/proof-set.json` in the same change. The `startup-staleness-warning` extension surfaces when an upstream branch has moved past the pin.
- To update an npm-source package: change the version in `managedPackages` AND in `managed-packages/package.json`, then run `nix/modules/pi/managed-packages/refresh-lock.sh`, update the `npmDeps` hash printed by `prefetch-npm-deps` in `config.nix`, and update `tests/fixtures/proof-set.json` if the package is in the proof set.
- The committed lock is generated with `--install-strategy=nested` and peer entries intact: pi's extension loader resolves imports against the literal (non-symlink-resolved) path, so every managed package must be self-contained; peers stay in the lock so offline `npm ci` never needs registry metadata. `refresh-lock.sh` owns both properties — do not hand-edit the lock.
- Run `refresh-lock.sh` with the build's npm (this flake's `pkgs.nodejs`). When a package raises its Pi core peer floor above the locked `@earendil-works/*` peer copies, use `refresh-lock.sh --reresolve-pi-core-peers` (the copies are resolution metadata only; Pi injects its own core). Do not use npm `overrides` for peer conflicts: offline `npm ci` re-fetches registry metadata for them. A package whose stale peer range blocks resolution can move to a pinned git source at its published `gitHead` (see `pi-subdir-context`).
- pi injects its bundled core at extension load time (`@earendil-works/*`, the legacy `@mariozechner/*` aliases, `typebox`); those must NOT be vendored (`pi-vendor-spec.sh` fails if they appear in `managed-packages/package.json`).
- External skills/extensions that are not npm managed packages (`visual-explainer`, `agent-kit`) come from pinned non-flake flake inputs (`visualExplainer`, `agentKit`) and are wired via store-path symlinks/copies in the activation script — never runtime `git clone`. Update them with `nix flake update <input>`. When wiring paths, verify the target exists in the pinned tree: agent-kit's Pi extensions live at `extensions/<name>/<name>.ts` (a stale `pi/extensions/...` path silently produces dangling symlinks).

## Compile Helper Behavior
- `nix/modules/pi/compile-managed-packages.mjs` is a contract helper, not a scratch script.
- Preserve its documented CLI surface, exit codes, deterministic ordering, and generated output shape when changing it.
- Update the related specs and fixtures in the same task whenever helper behavior intentionally changes.

## Guardrails Config
- `nix/modules/pi/guardrails.json` is checked-in policy data consumed by generated Pi config.
- Keep it valid JSON and treat rule IDs, protected patterns, and confirmation behavior as durable contract surface.
- Prefer narrow policy edits over broad rewrites so verification remains understandable.

## Generated Package Conventions
- Generated package directories should stay reproducible and path-safe.
- Preserve conventions such as generated package metadata, `_source` links, and selected-resource manifests unless a task explicitly changes that contract.
- When introducing a new generated package behavior, document it in the touched tests or helper comments.

## Anti-Patterns
- Do not mix Pi and OpenCode concerns in one module when the split already exists.
- Do not change generated package layout silently without matching regression coverage.
- Do not hand-edit derived outputs when the source declaration or helper should be fixed instead.
