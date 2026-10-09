# Pi coding agent Home Manager module
#
# Thin shim over nix/modules/pi/config.nix. Static agent files link from the
# makePiConfig store tree; managed packages link from the
# makePiManagedPackages store tree (built at build time — no npm at
# activation). settings.json stays a real, user-owned file merged by the
# activation script (pi persists runtime selections into it); guardrails.json
# stays an out-of-store symlink so the extension can persist confirmations
# into the repo file.
#
# Usage in your home-manager config:
#   imports = [ engineering-agents.homeManagerModules.pi ];
#   engineering-agents.pi.enable = true;
#
# Then: home-manager switch --flake .#<hostname>
#
{ self, llmAgents, visualExplainer, agentKit }:

{ config, lib, pkgs, ... }:

let
  cfg = config.engineering-agents.pi;

  inherit (import ./config.nix { inherit lib pkgs self; })
    makePiConfig
    makePiManagedPackages
    defaultEnabledModels
    defaultPowerlineConfig
    defaultPowerlineShortcuts
    defaultPowerlineTheme
    piAgentNames
    piSkillNames;

  # Repository root path for referencing skills and agents
  repoRoot = "${self}";

  piPkg = llmAgents.packages.${pkgs.system}.pi;
  checkUpdatesPkg = self.packages.${pkgs.system}.check-updates;
  piWrapperPkg = lib.hiPrio self.packages.${pkgs.system}.pi-launch-wrapper;
  # Static agent tree (settings.json here is the declarative body; the
  # activation merges it into the user's writable settings.json).
  piConfigTree = makePiConfig {
    inherit (cfg) defaultProvider defaultModel defaultThinkingLevel theme footer enabledModels;
    inherit (cfg.powerline) config shortcuts;
  };

  # Build-time managed package materialization (vendor tree + facades +
  # declarations/report/install-state). Same derivation hermes profiles
  # consume via nixosModules.pi-for-user — identical bits in both places.
  piManagedTree = makePiManagedPackages {
    powerlineTheme = cfg.powerline.theme;
  };

  visualExplainerSkill = "${visualExplainer}/plugins/visual-explainer";
  agentKitSrc = agentKit;

in
{
  options.engineering-agents.pi = {
    enable = lib.mkEnableOption "Pi coding agent with engineering-agents skills, agents, and presets";

    defaultProvider = lib.mkOption {
      type = lib.types.str;
      default = "zai-coding-plan";
      description = "Default Pi model provider";
    };

    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "glm-5.2";
      description = "Default Pi model";
    };

    defaultThinkingLevel = lib.mkOption {
      type = lib.types.str;
      default = "medium";
      description = "Default thinking level";
    };

    theme = lib.mkOption {
      type = lib.types.str;
      default = "catppuccin-mocha";
      description = "Pi theme";
    };

    footer = lib.mkOption {
      type = lib.types.enum [ "powerline" "zentui" ];
      default = "powerline";
      description = "Footer/editor profile to load. Both profiles are managed, but only the selected profile is loaded by Pi.";
    };

    powerline = {
      config = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = defaultPowerlineConfig;
        description = "pi-powerline-footer settings written to Pi settings.json when the Powerline profile is selected.";
      };

      shortcuts = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = defaultPowerlineShortcuts;
        description = "Powerline shortcut settings written to Pi settings.json when the Powerline profile is selected.";
      };

      nerdFonts = lib.mkOption {
        type = lib.types.enum [ "auto" "force" "disable" ];
        default = "force";
        description = "Nerd Font detection mode for Powerline. Force is the default because tmux cannot reliably report the outer terminal font.";
      };

      theme = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = defaultPowerlineTheme;
        description = "pi-powerline-footer theme.json override applied at build time to the vendored powerline package.";
      };
    };

    enabledModels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = defaultEnabledModels;
      description = "Models available for Ctrl+P cycling";
    };

    enableAgentKit = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the agent-kit direnv extension";
    };

    enableVisualExplainer = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install visual-explainer skill";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      checkUpdatesPkg
      piWrapperPkg
      piPkg
      pkgs.ast-grep
    ];

    home.file = {
      # Static agent files, linked per-entry from the makePiConfig tree.
      # The parent ~/.pi/agent/ stays a real dir: pi writes settings.json,
      # auth.json, models-store.json, and session state at runtime.
      ".pi/agent/keybindings.json".source = "${piConfigTree}/agent/keybindings.json";
      ".pi/agent/models.json".source = "${piConfigTree}/agent/models.json";
      ".pi/agent/mcp.json".source = "${piConfigTree}/agent/mcp.json";
      ".pi/agent/tasks-config.json".source = "${piConfigTree}/agent/tasks-config.json";
      ".pi/agent/pi-lens.json".source = "${piConfigTree}/agent/pi-lens.json";
      ".pi/agent/pi-lens-tools".source = "${piConfigTree}/agent/pi-lens-tools";
      ".pi/agent/themes/catppuccin-mocha.json".source = "${piConfigTree}/agent/themes/catppuccin-mocha.json";
      ".pi/agent/CLAUDE.md".source = "${piConfigTree}/agent/CLAUDE.md";
      ".pi/agent/CODEX.md".source = "${piConfigTree}/agent/CODEX.md";
      ".pi/agent/preset.jsonc".source = "${piConfigTree}/agent/preset.jsonc";

      # Guardrails config (out-of-store symlink for runtime writes)
      ".pi/agent/extensions/guardrails.json".source =
        config.lib.file.mkOutOfStoreSymlink "${repoRoot}/nix/modules/pi/guardrails.json";

      # Repo-owned startup notifier extension
      ".pi/agent/extensions/startup-staleness-warning/index.ts".source =
        "${piConfigTree}/agent/extensions/startup-staleness-warning/index.ts";

      # Repo-owned pi-lens runtime policy (no auto-install, managed config)
      ".pi/agent/extensions/pi-lens-policy/index.ts".source =
        "${piConfigTree}/agent/extensions/pi-lens-policy/index.ts";

      # Repo-owned bridge: pi-tasks TaskExecute -> managed pi-subagents RPC
      ".pi/agent/extensions/pi-tasks-subagents-bridge/index.ts".source =
        "${piConfigTree}/agent/extensions/pi-tasks-subagents-bridge/index.ts";
    } // builtins.listToAttrs (map (name:
      lib.nameValuePair ".pi/agent/agents/${name}.md" {
        source = "${piConfigTree}/agent/agents/${name}.md";
      }
    ) [ "planner" "plan-reviewer" "code-reviewer" "worker" "worker-high" "worker-low" "ui-worker" "researcher" "vision" "oracle" ]
    ) // builtins.listToAttrs (map (name:
      lib.nameValuePair ".pi/agent/skills/${name}" {
        source = "${piConfigTree}/agent/skills/${name}";
      }
    ) piSkillNames
    );

    # ============================================================
    # Activation Scripts
    # ============================================================
    home.activation = {
      # settings.json is real and user-owned (pi persists runtime model/theme
      # selections); Nix settings are merged over it with Nix winning on
      # conflicts.
      installPiSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        SETTINGS_FILE="$HOME/.pi/agent/settings.json"
        NIX_SETTINGS="${piConfigTree}/agent/settings.json"
        mkdir -p "$(dirname "$SETTINGS_FILE")"

        if [ -f "$SETTINGS_FILE" ]; then
          ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$SETTINGS_FILE" "$NIX_SETTINGS" > "$SETTINGS_FILE.tmp" \
            && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
          echo "Merged Nix settings into $SETTINGS_FILE"
        else
          cp "$NIX_SETTINGS" "$SETTINGS_FILE"
          chmod 644 "$SETTINGS_FILE"
          echo "Created $SETTINGS_FILE from Nix defaults"
        fi

        rm -f "$SETTINGS_FILE.backup" "$SETTINGS_FILE.bak"
      '';

      # Materialize managed packages from the build-time tree: facades,
      # sources, and the install-state manifests are per-entry symlinks into
      # ${piManagedTree}. Replaces the former npm-install-at-activation flow;
      # `rm -rf` before each link also migrates npm-era real directories.
      materializePiManagedPackages = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        AGENT_DIR="$HOME/.pi/agent"
        TREE="${piManagedTree}/agent"
        mkdir -p "$AGENT_DIR/packages" "$AGENT_DIR/sources" "$AGENT_DIR/skills" "$AGENT_DIR/prompts" "$AGENT_DIR/agents" "$AGENT_DIR/extensions"

        for path in "$TREE"/packages/*; do
          name="$(basename "$path")"
          rm -rf "$AGENT_DIR/packages/$name"
          ln -sfn "$path" "$AGENT_DIR/packages/$name"
        done
        for path in "$TREE"/sources/*; do
          name="$(basename "$path")"
          rm -rf "$AGENT_DIR/sources/$name"
          ln -sfn "$path" "$AGENT_DIR/sources/$name"
        done

        # Prune artifacts that are no longer declared (mirrors the compiler's
        # stale-artifact pruning from the npm-install era).
        for entry in "$AGENT_DIR"/packages/*; do
          name="$(basename "$entry")"
          [ -e "$TREE/packages/$name" ] || rm -rf "$entry"
        done
        for entry in "$AGENT_DIR"/sources/*; do
          name="$(basename "$entry")"
          [ -e "$TREE/sources/$name" ] || rm -rf "$entry"
        done

        for f in managed-packages.declarations.json managed-packages.report.json managed-packages.install-state.json; do
          rm -f "$AGENT_DIR/$f"
          ln -sfn "$TREE/$f" "$AGENT_DIR/$f"
        done

        echo "managed Pi packages materialized from ${piManagedTree}"
      '';

      installVisualExplainer = lib.mkIf cfg.enableVisualExplainer (lib.hm.dag.entryAfter [ "writeBoundary" "materializePiManagedPackages" ] ''
        VISUAL_EXPLAINER_DIR="$HOME/.pi/agent/skills/visual-explainer"

        echo "Installing visual-explainer skill from pinned source..."
        rm -rf "$VISUAL_EXPLAINER_DIR"
        mkdir -p "$(dirname "$VISUAL_EXPLAINER_DIR")"
        cp -r ${visualExplainerSkill} "$VISUAL_EXPLAINER_DIR"
        chmod -R u+w "$VISUAL_EXPLAINER_DIR"

        # Slash-command prompts ship under commands/ in the upstream skill.
        if [ -d "$VISUAL_EXPLAINER_DIR/commands" ]; then
          mkdir -p "$HOME/.pi/agent/prompts"
          cp "$VISUAL_EXPLAINER_DIR/commands/"*.md "$HOME/.pi/agent/prompts/" 2>/dev/null || true
        fi

        echo "visual-explainer installed"
      '');

      installAgentKit = lib.mkIf cfg.enableAgentKit (lib.hm.dag.entryAfter [ "writeBoundary" "materializePiManagedPackages" ] ''
        DIRENV_EXT="$HOME/.pi/agent/extensions/direnv"

        echo "Installing agent-kit extensions from pinned source..."
        mkdir -p "$HOME/.pi/agent/extensions"

        rm -rf "$DIRENV_EXT"
        mkdir -p "$DIRENV_EXT"
        ln -sf ${agentKitSrc}/extensions/direnv/direnv.ts "$DIRENV_EXT/index.ts"

        # ast-grep moved to pi-lens (ast_grep_* tools + pi-lens-ast-grep
        # skill); remove the retired agent-kit tool and skill links.
        rm -rf "$HOME/.pi/agent/extensions/ast-grep" "$HOME/.pi/agent/skills/ast-grep"

        echo "agent-kit extensions installed"
      '');
    };

    home.sessionVariables = lib.optionalAttrs (cfg.footer == "powerline" && cfg.powerline.nerdFonts == "force") {
      POWERLINE_NERD_FONTS = "1";
    } // lib.optionalAttrs (cfg.footer == "powerline" && cfg.powerline.nerdFonts == "disable") {
      POWERLINE_NERD_FONTS = "0";
    };
  };
}
