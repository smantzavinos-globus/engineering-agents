{
  description = "Engineering Agents — Autonomous coding agent process, skills, agents, and Nix-managed Pi/OpenCode installation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Match the reviewed dotfiles llmAgents pin (Pi 0.86.1) for standalone
    # development and managed-package compatibility. Upstream main currently
    # resolves a newer Pi; do not float the core runtime without its own audit.
    # Historical Copilot Enterprise compaction issue to re-test before apply:
    # https://github.com/earendil-works/pi/issues/6768
    # Review temporary overlays before future Pi bumps:
    # `rg -n "PI-VERSION-OVERLAY" .`
    llmAgents = {
      url = "github:numtide/llm-agents.nix/4e06012de602e51d03b0d482c2ddec420151cb9d";
    };

    # Visual Explainer skill (external, non-flake source)
    visualExplainer = {
      url = "github:nicobailon/visual-explainer";
      flake = false;
    };

    # agent-kit: Pi extensions (direnv, ast-grep) + ast-grep skill (external, non-flake source)
    agentKit = {
      url = "github:aldoborrero/agent-kit/16b100a70195852b291720e7213eed51c714d230";
      flake = false;
    };

  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, llmAgents, visualExplainer, agentKit }:
    let
      # System types to support
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      forAllSystems = fn: nixpkgs.lib.genAttrs supportedSystems (system: fn {
        inherit system;
        pkgs = nixpkgs.legacyPackages.${system};
        pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
      });

      # Default Pi/OpenCode configuration options
      defaultConfig = {
        # Pi model configuration
        pi = {
          defaultProvider = "zai-coding-plan";
          defaultModel = "glm-5.2";
          defaultThinkingLevel = "medium";
          theme = "catppuccin-mocha";
        };

        # OpenCode model configuration
        opencode = {
          model = "openai/gpt-5.5";
        };
      };
    in
    {
      # ============================================================
      # Home Manager Modules
      # ============================================================
      # Import these in your home-manager config:
      #   imports = [ engineering-agents.homeManagerModules.pi engineering-agents.homeManagerModules.opencode ];
      #
      # Or use the unified module:
      #   imports = [ engineering-agents.homeManagerModules.default ];
      # ============================================================
      homeManagerModules = {
        # Unified module that imports Pi, OpenCode, and Claude Code
        default = { config, lib, pkgs, ... }: {
          imports = [
            self.homeManagerModules.pi
            self.homeManagerModules.opencode
            self.homeManagerModules.claude-code
          ];
        };

        # Pi coding agent module
        pi = import ./nix/modules/pi { inherit self llmAgents visualExplainer agentKit; };

        # OpenCode CLI module
        opencode = import ./nix/modules/opencode { inherit self llmAgents visualExplainer; };

        # Claude Code CLI module
        claude-code = import ./nix/modules/claude-code { inherit self llmAgents; };
      };

      # ============================================================
      # NixOS Modules (for system service users without Home Manager)
      # ============================================================
      nixosModules = {
        # OpenCode config delivery for system users via activation script
        opencode-for-user = import ./nix/modules/opencode/nixos-user.nix { inherit self llmAgents visualExplainer; };

        # Pi config + managed package delivery for system users via activation
        # script (hermes agent profiles). Consumes the same build-time
        # managed-packages derivation as homeManagerModules.pi.
        pi-for-user = import ./nix/modules/pi/nixos-user.nix { inherit self llmAgents visualExplainer; };
      };

      # ============================================================
      # Overlays
      # ============================================================
      overlays.default = final: prev: {
        engineering-agents-scripts = final.runCommand "engineering-agents-scripts" { } ''
          mkdir -p $out/bin
          cp ${./scripts/check-updates.sh} $out/bin/check-updates
          cp ${./scripts/pi-launch-wrapper.sh} $out/bin/pi-launch-wrapper
          chmod +x $out/bin/check-updates $out/bin/pi-launch-wrapper
        '';
      };

      # ============================================================
      # Library functions (for external consumers to build custom configs)
      # ============================================================
      lib = forAllSystems ({ system, pkgs, ... }: {
        inherit (import ./nix/modules/opencode/config.nix {
          lib = pkgs.lib;
          inherit pkgs self;
        }) makeOpenCodeConfig;
        inherit (import ./nix/modules/pi/config.nix {
          lib = pkgs.lib;
          inherit pkgs self;
        }) makePiConfig makePiManagedPackages;
      });

      # ============================================================
      # Packages
      # ============================================================
      packages = forAllSystems ({ system, pkgs, ... }: {
        default = self.packages.${system}.engineering-agents-docs;

        # Pre-built default OpenCode config derivation for inspection/testing.
        # See nix/modules/opencode/config.nix for the makeOpenCodeConfig function.
        opencode-config-default = (import ./nix/modules/opencode/config.nix {
          lib = pkgs.lib;
          inherit pkgs self;
        }).makeOpenCodeConfig {};

        # Build-time managed Pi packages (vendor tree + facades + install
        # state). Same derivation the HM module and pi-for-user deliver.
        pi-managed-packages = self.lib.${system}.makePiManagedPackages { };

        # Pre-built default Pi static agent tree for inspection/testing.
        # See nix/modules/pi/config.nix for the makePiConfig function.
        pi-agent-config-default = self.lib.${system}.makePiConfig { };

        # Documentation bundle
        engineering-agents-docs = pkgs.runCommand "engineering-agents-docs" { } ''
          mkdir -p $out/share/doc/engineering-agents
          cp -r ${./docs} $out/share/doc/engineering-agents/docs
          cp -r ${./skills} $out/share/doc/engineering-agents/skills
          cp -r ${./agents} $out/share/doc/engineering-agents/agents
          cp ${./README.md} $out/share/doc/engineering-agents/README.md
        '';

        check-updates = pkgs.writeShellScriptBin "check-updates" ''
          export PI_UPDATE_CHECKER_HELPER="''${PI_UPDATE_CHECKER_HELPER:-${self}/nix/modules/pi/check-managed-package-status.mjs}"
          export PI_UPDATE_CHECKER_NODE_BIN="''${PI_UPDATE_CHECKER_NODE_BIN:-${pkgs.nodejs}/bin/node}"
          export PI_UPDATE_CHECKER_NPM_BIN="''${PI_UPDATE_CHECKER_NPM_BIN:-${pkgs.nodejs}/bin/npm}"
          export PI_UPDATE_CHECKER_GIT_BIN="''${PI_UPDATE_CHECKER_GIT_BIN:-${pkgs.git}/bin/git}"
          export PI_UPDATE_CHECKER_PYTHON_BIN="''${PI_UPDATE_CHECKER_PYTHON_BIN:-${pkgs.python3}/bin/python3}"
          exec ${self}/scripts/check-updates.sh "$@"
        '';

        pi-launch-wrapper = pkgs.writeShellScriptBin "pi" ''
          export PI_WRAPPER_REAL_PI_BIN="${llmAgents.packages.${system}.pi}/bin/pi"
          export PI_WRAPPER_NODE_BIN="${pkgs.nodejs}/bin/node"
          export PI_WRAPPER_STATUS_HELPER="${self}/nix/modules/pi/check-managed-package-status.mjs"
          export PI_WRAPPER_NPM_BIN="${pkgs.nodejs}/bin/npm"
          export PI_WRAPPER_GIT_BIN="${pkgs.git}/bin/git"
          exec ${self}/scripts/pi-launch-wrapper.sh "$@"
        '';

        # A disposable Home Manager activation package for scripts/pi-dev.sh.
        # The script overrides HOME and skips the generated fixed-home sanity
        # check, so the activation materializes into repo-local .pi-dev/.
        pi-dev-activation = (home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            self.homeManagerModules.pi
            {
              home.username = "pi-dev";
              home.homeDirectory = "/pi-dev";
              home.stateVersion = "25.05";
              engineering-agents.pi.enable = true;
              engineering-agents.pi.enableAgentKit = true;
              engineering-agents.pi.enableVisualExplainer = true;
            }
          ];
        }).activationPackage;
      });

      # ============================================================
      # Dev Shell
      # ============================================================
      devShells = forAllSystems ({ system, pkgs, ... }: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            nodejs
            jq
            git
            python3
          ];
        };
      });

      # ============================================================
      # Templates
      # ============================================================
      templates = {
        default = {
          path = ./templates/default;
          description = "Starter configuration for using engineering-agents with Pi";
        };
      };

      # ============================================================
      # Checks — build-without-apply module instantiation tests
      # ============================================================
      # `nix flake check` builds these. They prove the modules can be
      # imported and instantiated by home-manager without errors, and
      # that the expected files appear in the activation package.
      # ============================================================
      checks = forAllSystems ({ system, pkgs, ... }: let
        testUser = "testuser";
        testHome = "/home/${testUser}";
      in {
        # OpenCode config derivation produces the expected file tree
        opencode-config-shape = pkgs.runCommand "opencode-config-shape-check" {} ''
          cfgd=${self.packages.${system}.opencode-config-default}
          test -f "$cfgd/opencode/opencode.json" || { echo "MISSING: opencode.json"; exit 1; }
          test -f "$cfgd/opencode/oh-my-openagent.json" || { echo "MISSING: oh-my-openagent.json"; exit 1; }
          test -f "$cfgd/opencode/tui.json" || { echo "MISSING: tui.json"; exit 1; }
          test -f "$cfgd/opencode/agents/discovery.md" || { echo "MISSING: agents/discovery.md"; exit 1; }
          test -f "$cfgd/opencode/agents/design.md" || { echo "MISSING: agents/design.md"; exit 1; }
          test -f "$cfgd/opencode/agents/execute.md" || { echo "MISSING: agents/execute.md"; exit 1; }
          # Every rendered OpenCode skill must be installed (no hardcoded
          # subset — mirrors the Pi check below; a rendered-but-unlinked
          # skill fails here).
          for s in $(ls ${self}/dist/skills/opencode); do
            test -d "$cfgd/opencode/skills/$s" || { echo "MISSING: skills/$s"; exit 1; }
          done
          touch $out
        '';

        # Parameterization: zai-only strips google/openai providers, minimal strips plugins
        opencode-config-parameterization = pkgs.runCommand "opencode-config-parameterization-check" {} ''
          zaiOnly=${self.lib.${system}.makeOpenCodeConfig { providers = "zai-only"; }}
          minimal=${self.lib.${system}.makeOpenCodeConfig { plugins = "minimal"; }}

          # zai-only: opencode.json must NOT have google or openai provider keys
          if ${pkgs.jq}/bin/jq -e '.provider | has("google")' "$zaiOnly/opencode/opencode.json" >/dev/null 2>&1; then
            echo "FAIL: zai-only config still has google provider"; exit 1
          fi
          if ${pkgs.jq}/bin/jq -e '.provider | has("openai")' "$zaiOnly/opencode/opencode.json" >/dev/null 2>&1; then
            echo "FAIL: zai-only config still has openai provider"; exit 1
          fi

          # minimal: opencode.json plugin list must have exactly 1 entry (oh-my-openagent)
          pluginCount=$(${pkgs.jq}/bin/jq '.plugin | length' "$minimal/opencode/opencode.json")
          if [ "$pluginCount" != "1" ]; then
            echo "FAIL: minimal plugins should have 1 entry, got $pluginCount"; exit 1
          fi

          touch $out
        '';

        # Pi static agent tree produces the expected file set and settings body
        pi-agent-config-shape = pkgs.runCommand "pi-agent-config-shape-check" {} ''
          cfgd=${self.packages.${system}.pi-agent-config-default}
          ${pkgs.jq}/bin/jq -e '.settings.allowInstall == false and .settings.scriptMode == true and .settings.toolPrefix == "server"' \
            "$cfgd/agent/mcp.json" >/dev/null || { echo "FAIL: MCP adapter must disable installs, keep scripting enabled, and preserve server tool prefix"; exit 1; }
          for f in settings.json models.json mcp.json keybindings.json guardrails.json \
                   preset.jsonc CLAUDE.md CODEX.md themes/catppuccin-mocha.json \
                   extensions/startup-staleness-warning/index.ts; do
            test -e "$cfgd/agent/$f" || { echo "MISSING: agent/$f"; exit 1; }
          done
          for a in planner plan-reviewer code-reviewer worker worker-high worker-low ui-worker researcher vision oracle; do
            test -f "$cfgd/agent/agents/$a.md" || { echo "MISSING: agents/$a.md"; exit 1; }
          done
          for s in $(ls ${self}/dist/skills/pi); do
            test -d "$cfgd/agent/skills/$s" || { echo "MISSING: skills/$s"; exit 1; }
          done
          ${pkgs.jq}/bin/jq -e '.defaultProvider == "zai-coding-plan" and .defaultModel == "glm-5.2"' \
            "$cfgd/agent/settings.json" >/dev/null || { echo "FAIL: default settings body"; exit 1; }
          ${pkgs.jq}/bin/jq -e '(.packages | index("./packages/pi-powerline-footer")) != null' \
            "$cfgd/agent/settings.json" >/dev/null || { echo "FAIL: powerline not in runtime packages"; exit 1; }
          ${pkgs.jq}/bin/jq -e '(.packages | index("./packages/pi-zentui")) == null' \
            "$cfgd/agent/settings.json" >/dev/null || { echo "FAIL: zentui must not be a runtime package by default"; exit 1; }
          for id in glm-5.3 glm-5.2 glm-5 glm-5-turbo; do
            ${pkgs.jq}/bin/jq -e --arg id "$id" '.providers["zai-coding-plan"].models[] | select(.id == $id)' \
              "$cfgd/agent/models.json" >/dev/null || { echo "FAIL: zai catalog missing $id"; exit 1; }
          done
          touch $out
        '';

        # makePiConfig agentOverrides patch shipped agent frontmatter at build
        # time and subagent settings pass through to settings.json.
        pi-agent-config-agent-overrides = pkgs.runCommand "pi-agent-config-agent-overrides-check" {} ''
          cfgd=${self.lib.${system}.makePiConfig {
            agentOverrides = {
              worker.model = "zai-coding-plan/glm-5.3";
              oracle.thinking = "low";
            };
            subagentDefaultModel = "zai-coding-plan/glm-5";
            subagentOverrides = { researcher.model = "zai-coding-plan/glm-5-turbo"; };
          }}
          # Patched frontmatter: model replaced, thinking patched.
          grep -Fqx 'model: zai-coding-plan/glm-5.3' "$cfgd/agent/agents/worker.md" \
            || { echo "FAIL: worker model patch missing"; exit 1; }
          # fallbackModels is unsupported in agent frontmatter (hard load
          # error): no shipped or patched agent may carry it.
          if grep -l '^fallbackModels:' "$cfgd"/agent/agents/*.md; then
            echo "FAIL: agent frontmatter declares unsupported fallbackModels"; exit 1
          fi
          grep -Fqx 'model: zai-coding-plan/glm-5.2' "$cfgd/agent/agents/code-reviewer.md" \
            || { echo "FAIL: unspecified fields must pass through (code-reviewer model)"; exit 1; }
          grep -Fqx 'thinking: low' "$cfgd/agent/agents/oracle.md" \
            || { echo "FAIL: oracle thinking patch missing"; exit 1; }
          # Untouched agent keeps its shipped frontmatter.
          grep -Fqx 'model: openai-codex/gpt-5.5' "$cfgd/agent/agents/planner.md" \
            || { echo "FAIL: planner must remain unpatched without an override"; exit 1; }
          # Settings passthrough.
          ${pkgs.jq}/bin/jq -e '.subagents.disableBuiltins == true and .subagents.defaultModel == "zai-coding-plan/glm-5" and .subagents.agentOverrides.researcher.model == "zai-coding-plan/glm-5-turbo"' \
            "$cfgd/agent/settings.json" >/dev/null || { echo "FAIL: subagent settings passthrough"; exit 1; }
          touch $out
        '';

        # Managed packages tree: facades exist, sources resolve, theme is
        # patched, git metadata present, install-state is well-formed.
        pi-managed-packages-shape = pkgs.runCommand "pi-managed-packages-shape-check" {} ''
          tree=${self.packages.${system}.pi-managed-packages}
          for id in pi-subagents pi-hooks pi-agent-guidance pi-mcp-adapter \
                    pi-web-access pi-powerline-footer pi-zentui \
                    pi-subdir-context pi-ding pi-notify pi-session-autoname pi-ext-leader-key \
                    pi-guardrails pi-preset pi-btw; do
            test -f "$tree/agent/packages/$id/package.json" || { echo "MISSING facade: $id"; exit 1; }
          done
          test ! -e "$tree/agent/packages/pi-gitnexus" || { echo "FAIL: retired pi-gitnexus must be absent"; exit 1; }
          test ! -e "$tree/agent/packages/pi-auto-rename" || { echo "FAIL: replaced pi-auto-rename must be absent"; exit 1; }
          # Removed with team mode / code-mode consolidation; must not come back.
          for id in pi-messenger pi-prompt-template-model pi-ext-review pi-interactive-shell; do
            test ! -e "$tree/agent/packages/$id" || { echo "FAIL: $id must not be installed"; exit 1; }
          done

          # Facade source links must resolve to reachable files.
          test -f "$tree/agent/packages/pi-subagents/_source/index.ts" || { echo "FAIL: pi-subagents _source unreachable"; exit 1; }
          test -f "$tree/agent/packages/pi-session-autoname/_source/src/index.ts" || { echo "FAIL: pi-session-autoname _source unreachable"; exit 1; }
          test -f "$tree/agent/packages/pi-powerline-footer/_source/index.ts" || { echo "FAIL: powerline _source unreachable"; exit 1; }

          # Check the shipped facade source, not the vendored input: the nested
          # naming request must allow enough output for reasoning models.
          autoname_source="$tree/agent/packages/pi-session-autoname/_source/src/extension.ts"
          test -f "$autoname_source" || { echo "FAIL: pi-session-autoname extension source unreachable"; exit 1; }
          naming_request=$(sed -n '/const response = await ctx\.modelRegistry\.complete(/,/^[[:space:]]*);/p' "$autoname_source")
          test -n "$naming_request" || { echo "FAIL: pi-session-autoname nested naming request missing"; exit 1; }
          printf '%s\n' "$naming_request" | grep -Eq '^[[:space:]]*maxTokens:[[:space:]]*512,[[:space:]]*$' \
            || { echo "FAIL: pi-session-autoname nested naming request must use maxTokens: 512"; exit 1; }
          if printf '%s\n' "$naming_request" | grep -Eq '^[[:space:]]*maxTokens:[[:space:]]*64,[[:space:]]*$'; then
            echo "FAIL: pi-session-autoname nested naming request still uses maxTokens: 64"
            exit 1
          fi

          # Git sources carry install metadata for the staleness checker.
          test -f "$tree/vendor/node_modules/pi-subagents/.pi-managed-install.json" || { echo "FAIL: git install metadata missing"; exit 1; }

          # Powerline theme override applied at build time.
          ${pkgs.jq}/bin/jq -e '.colors.model == "#cba6f7"' \
            "$tree/vendor/node_modules/pi-powerline-footer/theme.json" >/dev/null \
            || { echo "FAIL: powerline theme not patched"; exit 1; }

          # Install state covers every declared facade package and no GitNexus.
          count=$(${pkgs.jq}/bin/jq '.sources | map(.packageIds[]) | unique | length' "$tree/agent/managed-packages.install-state.json")
          [ "$count" = "15" ] || { echo "FAIL: install-state covers $count packageIds, expected 15"; exit 1; }
          touch $out
        '';

        # NixOS pi-for-user module instantiates and emits the activation
        # script that materializes config + managed packages into targetDir.
        pi-for-user-module =
          let
            mockBaseModule = { config, lib, ... }: {
              options.system.activationScripts = lib.mkOption {
                type = lib.types.attrsOf (lib.types.submodule {
                  options.text = lib.mkOption { type = lib.types.str; default = ""; };
                  options.deps = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
                });
                default = {};
              };
            };
            eval = nixpkgs.lib.evalModules {
              modules = [
                mockBaseModule
                self.nixosModules.pi-for-user
                {
                  _module.args.pkgs = pkgs;
                  engineering-agents.pi-for-user = {
                    enable = true;
                    user = "testuser";
                    group = "testgroup";
                    targetDir = "/tmp/test-pi";
                    args = {};
                  };
                }
              ];
            };
            scriptText = eval.config.system.activationScripts."pi-for-user".text;
          in
          pkgs.runCommand "pi-for-user-module-check" {
            inherit scriptText;
          } ''
            echo "$scriptText" | grep -qF 'agent="/tmp/test-pi/agent"' || {
              echo "FAIL: activation script must target the configured targetDir/agent"
              exit 1
            }
            echo "$scriptText" | grep -qF 'settings.json|guardrails.json) continue' || {
              echo "FAIL: activation script must keep settings.json and guardrails.json as real files"
              exit 1
            }
            echo "$scriptText" | grep -qF 'cp "$static/guardrails.json" "$agent/extensions/guardrails.json"' || {
              echo "FAIL: activation script must install guardrails.json where Guardrails reads it (agent/extensions/)"
              exit 1
            }
            echo "$scriptText" | grep -qF 'managed/packages' || {
              echo "FAIL: activation script must link managed packages"
              exit 1
            }
            echo "$scriptText" | grep -qF 'managed-packages.install-state.json' || {
              echo "FAIL: activation script must link the install-state manifest"
              exit 1
            }
            echo "$scriptText" | grep -qF 'chown testuser:testgroup' || {
              echo "FAIL: activation script must chown to the configured user/group"
              exit 1
            }
            touch $out
          '';

        # NixOS opencode-for-user module instantiates and emits the activation
        # script that materializes the config into targetDir.
        opencode-for-user-module =
          let
            mockBaseModule = { config, lib, ... }: {
              options.system.activationScripts = lib.mkOption {
                type = lib.types.attrsOf (lib.types.submodule {
                  options.text = lib.mkOption { type = lib.types.str; default = ""; };
                  options.deps = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
                });
                default = {};
              };
            };
            eval = nixpkgs.lib.evalModules {
              modules = [
                mockBaseModule
                self.nixosModules.opencode-for-user
                {
                  _module.args.pkgs = pkgs;
                  engineering-agents.opencode-for-user = {
                    enable = true;
                    user = "testuser";
                    group = "testgroup";
                    targetDir = "/tmp/test-opencode";
                    args = {};
                  };
                }
              ];
            };
            scriptText = eval.config.system.activationScripts."opencode-for-user".text;
          in
          pkgs.runCommand "opencode-for-user-module-check" {
            inherit scriptText;
          } ''
            # The script uses a shell `$target` var, so assert on invariants
            # that actually appear in the text, not expanded paths.
            echo "$scriptText" | grep -q 'ln -sfn' || {
              echo "FAIL: activation script must use ln -sfn to materialize config"
              echo "Script: $scriptText"
              exit 1
            }
            echo "$scriptText" | grep -q 'target="/tmp/test-opencode/opencode"' || {
              echo "FAIL: activation script must target the configured targetDir/opencode"
              echo "Script: $scriptText"
              exit 1
            }
            echo "$scriptText" | grep -q '/opencode.json' || {
              echo "FAIL: activation script must symlink opencode.json"
              echo "Script: $scriptText"
              exit 1
            }
            echo "$scriptText" | grep -q '/agents' || {
              echo "FAIL: activation script must symlink the agents directory"
              echo "Script: $scriptText"
              exit 1
            }
            touch $out
          '';

        # Co-evolution guard: scan agent markdown for plugin references and
        # assert any referenced plugin is in the default plugin set. Prevents
        # a future agent from silently depending on a plugin that consumers
        # using plugins = "minimal" (e.g., hermes) don't have.
        opencode-agent-plugin-deps = pkgs.runCommand "opencode-agent-plugin-deps-check" {} ''
          # Plugin names we manage (without @version suffix)
          knownPlugins="oh-my-openagent opencode-openai-codex-auth opencode-ignore opencode-direnv opencode-md-table-formatter"

          # Grep agent markdown for plugin-like references (@scope/name or name@version patterns)
          # and extract unique plugin names found
          found=$(${pkgs.gnugrep}/bin/grep -rohE '(@[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+|[a-zA-Z0-9_-]+)@[0-9]' ${./nix/modules/opencode/agents}/ 2>/dev/null | sed 's/@[0-9].*//' | sort -u || true)

          if [ -z "$found" ]; then
            # No plugin references found in agent files — baseline passes
            touch $out
            exit 0
          fi

          # Check each found plugin against known list
          for plugin in $found; do
            # Strip @scope/ prefix for comparison
            baseName=$(echo "$plugin" | sed 's/^@[^/]*\///')
            if ! echo "$knownPlugins" | grep -qw "$baseName"; then
              echo "FAIL: agent file references plugin '$plugin' which is not in the managed plugin set"
              echo "Managed plugins: $knownPlugins"
              echo "If this plugin is needed, add it to defaultPlugins in nix/modules/opencode/config.nix"
              exit 1
            fi
          done

          touch $out
        '';

        # Pi module builds a valid activation package
        pi-module = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            self.homeManagerModules.pi
            {
              home.username = testUser;
              home.homeDirectory = testHome;
              home.stateVersion = "25.05";
              engineering-agents.pi.enable = true;
              engineering-agents.pi.enableAgentKit = true;
              engineering-agents.pi.enableVisualExplainer = true;
            }
          ];
        };

        # Alternate Pi footer profile builds independently and must load only
        # Zentui, never the mutually exclusive Powerline UI extension.
        pi-zentui-module = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            self.homeManagerModules.pi
            {
              home.username = testUser;
              home.homeDirectory = testHome;
              home.stateVersion = "25.05";
              engineering-agents.pi.enable = true;
              engineering-agents.pi.footer = "zentui";
              engineering-agents.pi.enableAgentKit = true;
              engineering-agents.pi.enableVisualExplainer = true;
            }
          ];
        };

        # OpenCode module builds a valid activation package
        opencode-module = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            self.homeManagerModules.opencode
            {
              home.username = testUser;
              home.homeDirectory = testHome;
              home.stateVersion = "25.05";
              engineering-agents.opencode.enable = true;
            }
          ];
        };

        # Claude Code module builds a valid activation package
        claude-code-module = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            self.homeManagerModules.claude-code
            {
              home.username = testUser;
              home.homeDirectory = testHome;
              home.stateVersion = "25.05";
              engineering-agents.claude-code.enable = true;
            }
          ];
        };

        # Both modules together
        both-modules = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            self.homeManagerModules.default
            {
              home.username = testUser;
              home.homeDirectory = testHome;
              home.stateVersion = "25.05";
              engineering-agents.pi.enable = true;
              engineering-agents.pi.enableAgentKit = true;
              engineering-agents.pi.enableVisualExplainer = true;
              engineering-agents.opencode.enable = true;
              engineering-agents.claude-code.enable = true;
            }
          ];
        };
      });
    };
}
