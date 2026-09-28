# nix/modules/pi/pi-lens-tools.nix — Nix-supplied binaries for pi-lens
#
# pi-lens auto-installs its language servers, linters and scanners at
# runtime (npm/pip/go install, GitHub release downloads). The managed policy
# (extensions/pi-lens-policy) disables that and instead appends this
# environment's bin/ to pi's own PATH, so pi-lens finds pinned binaries on
# every launch path (terminal, Hermes service, subagent children) without
# changing the user's shell PATH. Project/devshell tools earlier on PATH
# (e.g. a repo's node_modules/.bin biome) still win.
#
# Selection:
# - Language servers and linters for the languages pi-lens dispatches.
#   Most linters are config-gated: they only run when a project has their
#   config or dependency, so shipping them is inert elsewhere.
# - Scanners: gitleaks, govulncheck (runs only with go.mod; needs the
#   project's Go toolchain), ast-grep, opengrep; knip/jscpd/madge come from
#   the managed npm vendor tree.
# - nixfmt is deliberately absent: pi-lens has no lint use for it and would
#   run it as the .nix formatter whenever it is on PATH, restyling whole
#   files once a repo opts into format (format/autofix stay a per-project
#   opt-in, see pi-lens.json). shfmt is included: its lint check is a
#   read-only `shfmt --diff`, and as a formatter it keeps the file's own
#   indentation.
{ pkgs, pkgsUnstable, piVendor }:

let
  # opengrep ships a Nuitka onefile self-extractor. The upstream flake is a
  # full OCaml/opam development build, so package the signed release binary
  # instead: extract once at build time, then patch the unpacked standalone
  # tree for NixOS (glibc interpreter + zlib, which binascii.so links but the
  # bundle does not carry). Its other shared libraries are bundled.
  opengrep = pkgs.stdenv.mkDerivation rec {
    pname = "opengrep";
    version = "1.30.0";

    src = pkgs.fetchurl {
      url = "https://github.com/opengrep/opengrep/releases/download/v${version}/opengrep_manylinux_x86";
      hash = "sha256-NXeb3XLpISnI3yp38MVejAg1aAHqklke8yEI1rKNVkw=";
    };

    dontUnpack = true;
    nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.makeBinaryWrapper ];
    buildInputs = [ pkgs.zlib pkgs.stdenv.cc.cc.lib ];

    buildPhase = ''
      runHook preBuild
      export HOME="$NIX_BUILD_TOP/home"
      install -m 0755 "$src" onefile
      # The loader itself needs the glibc interpreter to run in the sandbox
      # (patching it keeps the appended payload intact).
      patchelf --set-interpreter "$(cat "$NIX_CC/nix-support/dynamic-linker")" onefile
      # The loader extracts to $HOME/.cache/opengrep/v<version>/ and then
      # execs the unpatched payload, which fails here; only the extraction
      # matters.
      ./onefile --version >/dev/null 2>&1 || true
      test -x "$HOME/.cache/opengrep/v${version}/opengrep.bin"
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib" "$out/bin"
      cp -r "$HOME/.cache/opengrep/v${version}" "$out/lib/opengrep"
      makeBinaryWrapper "$out/lib/opengrep/opengrep.bin" "$out/bin/opengrep"
      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      export HOME="$NIX_BUILD_TOP/check-home"
      test "$("$out/bin/opengrep" --version)" = "${version}"
    '';

    meta = {
      description = "Opengrep static analysis CLI (release binary)";
      homepage = "https://github.com/opengrep/opengrep";
      license = pkgs.lib.licenses.lgpl21Only;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
    };
  };

  # npm bin scripts use `#!/usr/bin/env node`; wrap them with Nix's node
  # so they also run where PATH has no node (e.g. the Hermes service).
  # Copy only the three packages plus the root-hoisted packages they resolve
  # (Node resolution: nested node_modules first, then the vendor root), so
  # the tool env does not keep the whole ~700 MiB vendor tree alive next to
  # the copy inside the managed-packages output.
  collectRootDeps = pkgs.writeText "collect-root-deps.mjs" ''
    import fs from "node:fs";
    import path from "node:path";
    const [root, ...tools] = process.argv.slice(2);
    const rootModules = path.join(root, "node_modules");
    const needed = new Set(tools);
    const seen = new Set();
    const visit = (pkgDir) => {
      if (seen.has(pkgDir)) return;
      seen.add(pkgDir);
      const manifest = JSON.parse(fs.readFileSync(path.join(pkgDir, "package.json"), "utf8"));
      const deps = { ...manifest.dependencies, ...manifest.optionalDependencies, ...manifest.peerDependencies };
      for (const dep of Object.keys(deps)) {
        let dir = pkgDir, found;
        while (dir.startsWith(rootModules) || dir === root) {
          const candidate = path.join(dir, "node_modules", dep);
          if (fs.existsSync(path.join(candidate, "package.json"))) { found = candidate; break; }
          if (dir === root) break;
          dir = path.dirname(dir);
        }
        if (!found) continue; // optional/peer not installed
        if (path.dirname(found) === rootModules || path.dirname(path.dirname(found)) === rootModules && dep.startsWith("@")) needed.add(dep);
        visit(found);
      }
      const nested = path.join(pkgDir, "node_modules");
      if (!fs.existsSync(nested)) return;
      for (const entry of fs.readdirSync(nested)) {
        if (entry.startsWith(".")) continue;
        const names = entry.startsWith("@") ? fs.readdirSync(path.join(nested, entry)).map((n) => path.join(entry, n)) : [entry];
        for (const name of names) if (fs.existsSync(path.join(nested, name, "package.json"))) visit(path.join(nested, name));
      }
    };
    for (const tool of tools) visit(path.join(rootModules, tool));
    process.stdout.write([...needed].sort().join("\n") + "\n");
  '';

  vendorBins = pkgs.runCommand "pi-lens-vendor-bins" {
    nativeBuildInputs = [ pkgs.makeBinaryWrapper pkgs.nodejs ];
    disallowedReferences = [ piVendor ];
  } ''
    mkdir -p "$out/bin" "$out/lib/node_modules"
    node ${collectRootDeps} "${piVendor}" knip jscpd madge > needed.txt
    while IFS= read -r pkg; do
      [ -n "$pkg" ] || continue
      mkdir -p "$out/lib/node_modules/$(dirname "$pkg")"
      cp -a "${piVendor}/node_modules/$pkg" "$out/lib/node_modules/$pkg"
    done < needed.txt
    for tool in knip jscpd madge; do
      script="$(readlink -f "${piVendor}/node_modules/.bin/$tool")"
      script="$out/lib/node_modules/''${script#${piVendor}/node_modules/}"
      test -f "$script"
      makeBinaryWrapper "${pkgs.nodejs}/bin/node" "$out/bin/$tool" --add-flags "$script"
      "$out/bin/$tool" --version >/dev/null
    done
  '';

  u = pkgsUnstable;
in
pkgs.buildEnv {
  name = "pi-lens-tools";
  pathsToLink = [ "/bin" ];
  paths = [
    # Language servers. Those the host commonly installs itself come from
    # the consumer's pkgs so they dedupe with the system copy (unstable nixd
    # alone would add ~540 MiB of LLVM).
    pkgs.typescript-language-server
    pkgs.svelte-language-server
    pkgs.nixd
    pkgs.lua-language-server
    u.typescript
    u.vue-language-server
    u.vscode-langservers-extracted
    u.yaml-language-server
    u.bash-language-server
    u.dockerfile-language-server
    u.pyright
    u.taplo
    u.typos-lsp
    # pi-lens' only Markdown server (the bundled vscode-markdown-language-server
    # is unused by pi-lens). Adds a .NET runtime (~95 MiB).
    u.marksman
    # Linters (mostly config-gated)
    u.biome
    u.ruff
    u.shellcheck
    u.shfmt
    u.oxlint
    u.zizmor
    u.yamllint
    u.actionlint
    u.hadolint
    u.markdownlint-cli2
    u.stylelint
    u.htmlhint
    u.sqlfluff
    u.tflint
    u.golangci-lint
    # Scanners
    u.gitleaks
    u.govulncheck
    u.ast-grep
    opengrep
    vendorBins
  ];
  # gitleaks also ships a generic `config` helper; keep it off PATH.
  postBuild = ''
    rm -f "$out/bin/config"
  '';
  passthru = { inherit opengrep; };
}
