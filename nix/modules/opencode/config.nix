# nix/modules/opencode/config.nix — Pure config-building function for OpenCode
#
# Produces a store-path derivation containing the complete opencode/ directory
# tree (opencode.json, oh-my-openagent.json, tui.json, agents/, skills/).
#
# Consumed by:
#   - nix/modules/opencode/default.nix (Home Manager shim, individual file links)
#   - nix/modules/opencode/nixos-user.nix (NixOS shim, tmpfiles delivery)
#
# Usage:
#   makeOpenCodeConfig {}                           # full default config
#   makeOpenCodeConfig { providers = "zai-only"; }  # strip OAuth providers
#   makeOpenCodeConfig { plugins = "minimal"; }     # oh-my-openagent only
#
{ lib, pkgs, self }:

let
  # ============================================================
  # Plugin version pins
  # ============================================================
  pluginVersions = {
    ohMyOpenAgent = "4.13.0";
    openaiCodexAuth = "4.4.0";
    opencodeIgnore = "1.1.0";
    opencodeDirenv = "2025.1211.9";
    opencodeMdTableFormatter = "0.0.6";
  };

  # ============================================================
  # OpenAI model tables (for ChatGPT Plus/Pro OAuth via codex-auth)
  # ============================================================
  openaiBaseOptions = {
    include = [ "reasoning.encrypted_content" ];
    store = false;
  };

  openaiReasoningVariants = {
    none = { reasoningEffort = "none"; reasoningSummary = "auto"; textVerbosity = "medium"; };
    low = { reasoningEffort = "low"; reasoningSummary = "auto"; textVerbosity = "medium"; };
    medium = { reasoningEffort = "medium"; reasoningSummary = "auto"; textVerbosity = "medium"; };
    high = { reasoningEffort = "high"; reasoningSummary = "detailed"; textVerbosity = "medium"; };
    xhigh = { reasoningEffort = "xhigh"; reasoningSummary = "detailed"; textVerbosity = "medium"; };
  };

  openaiLegacyReasoningVariants = {
    none = { reasoningEffort = "none"; reasoningSummary = "auto"; textVerbosity = "medium"; };
    low = { reasoningEffort = "low"; reasoningSummary = "auto"; textVerbosity = "low"; };
    medium = { reasoningEffort = "medium"; reasoningSummary = "auto"; textVerbosity = "medium"; };
    high = { reasoningEffort = "high"; reasoningSummary = "detailed"; textVerbosity = "high"; };
  };

  openaiCodexReasoningVariants = {
    low = { reasoningEffort = "low"; reasoningSummary = "auto"; textVerbosity = "medium"; };
    medium = { reasoningEffort = "medium"; reasoningSummary = "auto"; textVerbosity = "medium"; };
    high = { reasoningEffort = "high"; reasoningSummary = "detailed"; textVerbosity = "medium"; };
    xhigh = { reasoningEffort = "xhigh"; reasoningSummary = "detailed"; textVerbosity = "medium"; };
  };

  openaiCodexMiniReasoningVariants = {
    medium = { reasoningEffort = "medium"; reasoningSummary = "auto"; textVerbosity = "medium"; };
    high = { reasoningEffort = "high"; reasoningSummary = "detailed"; textVerbosity = "medium"; };
  };

  openaiModel = name: variants: {
    inherit name variants;
    limit = { context = 272000; output = 128000; };
    modalities = { input = [ "text" "image" ]; output = [ "text" ]; };
  };

  openaiOAuthModels = {
    "gpt-5.5" = openaiModel "GPT 5.5 (ChatGPT Pro OAuth)" openaiReasoningVariants;
    "gpt-5.2" = openaiModel "GPT 5.2 (ChatGPT Pro OAuth)" openaiReasoningVariants;
    "gpt-5.2-codex" = openaiModel "GPT 5.2 Codex (ChatGPT Pro OAuth)" openaiCodexReasoningVariants;
    "gpt-5.1-codex-max" = openaiModel "GPT 5.1 Codex Max (ChatGPT Pro OAuth)" openaiCodexReasoningVariants;
    "gpt-5.1-codex" = openaiModel "GPT 5.1 Codex (ChatGPT Pro OAuth)" {
      low = { reasoningEffort = "low"; reasoningSummary = "auto"; textVerbosity = "medium"; };
      medium = { reasoningEffort = "medium"; reasoningSummary = "auto"; textVerbosity = "medium"; };
      high = { reasoningEffort = "high"; reasoningSummary = "detailed"; textVerbosity = "medium"; };
    };
    "gpt-5.1-codex-mini" = openaiModel "GPT 5.1 Codex Mini (ChatGPT Pro OAuth)" openaiCodexMiniReasoningVariants;
    "gpt-5.1" = openaiModel "GPT 5.1 (ChatGPT Pro OAuth)" openaiLegacyReasoningVariants;
  };

  # ============================================================
  # Default configuration values
  # ============================================================

  defaultPlugins = [
    "oh-my-openagent@${pluginVersions.ohMyOpenAgent}"
    "opencode-openai-codex-auth@${pluginVersions.openaiCodexAuth}"
    "opencode-ignore@${pluginVersions.opencodeIgnore}"
    "@simonwjackson/opencode-direnv@${pluginVersions.opencodeDirenv}"
    "@franlol/opencode-md-table-formatter@${pluginVersions.opencodeMdTableFormatter}"
  ];

  minimalPlugins = [
    "oh-my-openagent@${pluginVersions.ohMyOpenAgent}"
  ];

  defaultProviders = {
    google = {
      models = {
        "gemini-3-pro-high" = {
          name = "Gemini 3 Pro High";
          limit = { context = 1048576; output = 65535; };
          modalities = { input = [ "text" "image" "pdf" ]; output = [ "text" ]; };
        };
        "gemini-3-pro-low" = {
          name = "Gemini 3 Pro Low";
          limit = { context = 1048576; output = 65535; };
          modalities = { input = [ "text" "image" "pdf" ]; output = [ "text" ]; };
        };
        "gemini-3-flash" = {
          name = "Gemini 3 Flash";
          limit = { context = 1048576; output = 65536; };
          modalities = { input = [ "text" "image" "pdf" ]; output = [ "text" ]; };
        };
        "claude-sonnet-4-5" = {
          name = "Claude Sonnet 4.5";
          limit = { context = 200000; output = 64000; };
          modalities = { input = [ "text" "image" "pdf" ]; output = [ "text" ]; };
        };
        "claude-sonnet-4-5-thinking-low" = {
          name = "Claude Sonnet 4.5 Thinking Low";
          limit = { context = 200000; output = 64000; };
          modalities = { input = [ "text" "image" "pdf" ]; output = [ "text" ]; };
        };
        "claude-sonnet-4-5-thinking-medium" = {
          name = "Claude Sonnet 4.5 Thinking Medium";
          limit = { context = 200000; output = 64000; };
          modalities = { input = [ "text" "image" "pdf" ]; output = [ "text" ]; };
        };
        "claude-sonnet-4-5-thinking-high" = {
          name = "Claude Sonnet 4.5 Thinking High";
          limit = { context = 200000; output = 64000; };
          modalities = { input = [ "text" "image" "pdf" ]; output = [ "text" ]; };
        };
        "claude-opus-4-5-thinking-low" = {
          name = "Claude Opus 4.5 Thinking Low";
          limit = { context = 200000; output = 64000; };
          modalities = { input = [ "text" "image" "pdf" ]; output = [ "text" ]; };
        };
        "claude-opus-4-5-thinking-medium" = {
          name = "Claude Opus 4.5 Thinking Medium";
          limit = { context = 200000; output = 64000; };
          modalities = { input = [ "text" "image" "pdf" ]; output = [ "text" ]; };
        };
        "claude-opus-4-5-thinking-high" = {
          name = "Claude Opus 4.5 Thinking High";
          limit = { context = 200000; output = 64000; };
          modalities = { input = [ "text" "image" "pdf" ]; output = [ "text" ]; };
        };
      };
    };

    # `openai` is reserved for ChatGPT Plus/Pro OAuth via
    # opencode-openai-codex-auth. The plugin is hard-coded to this
    # provider ID and skips itself when API-key auth is selected.
    openai = {
      options = openaiBaseOptions;
      models = openaiOAuthModels;
    };
  };

  defaultMcp = {
    "web-search-prime" = {
      type = "remote";
      url = "https://api.z.ai/api/mcp/web_search_prime/mcp";
      oauth = false;
      headers = { Authorization = "Bearer {env:ZAI_API_KEY}"; };
    };
    "web-reader" = {
      type = "remote";
      url = "https://api.z.ai/api/mcp/web_reader/mcp";
      oauth = false;
      headers = { Authorization = "Bearer {env:ZAI_API_KEY}"; };
    };
    "zread" = {
      type = "remote";
      url = "https://api.z.ai/api/mcp/zread/mcp";
      oauth = false;
      headers = { Authorization = "Bearer {env:ZAI_API_KEY}"; };
    };
    "zai-vision" = {
      type = "local";
      command = [ "npx" "-y" "@z_ai/mcp-server" ];
      environment = {
        Z_AI_API_KEY = "{env:ZAI_API_KEY}";
        Z_AI_MODE = "ZAI";
      };
      enabled = false;
    };
  };

  # Default agent model overrides in opencode.json
  defaultAgentConfig = {
    build = {
      model = "openai/gpt-5.5";
    };
    plan = {
      model = "openai/gpt-5.5";
      # Keep the native OpenCode plan agent visible. oh-my-openagent's
      # runtime loader defaults config-defined agents to subagent mode when
      # mode is omitted, even when sisyphus_agent.replace_plan = false.
      mode = "primary";
    };
  };

  # oh-my-openagent agent roster
  defaultAgentRoster = {
    sisyphus = {
      model = "zai-coding-plan/glm-5.2";
      fallback_models = [ "openai/gpt-5.5" ];
    };
    "sisyphus-junior" = {
      model = "zai-coding-plan/glm-5.2";
      fallback_models = [ "openai/gpt-5.5" ];
    };
    atlas = {
      model = "zai-coding-plan/glm-5.2";
      fallback_models = [ "openai/gpt-5.5" ];
    };
    hephaestus = {
      model = "openai/gpt-5.5";
      variant = "xhigh";
      fallback_models = [ "zai-coding-plan/glm-5.2" ];
    };
    build = {
      model = "zai-coding-plan/glm-5.2";
      fallback_models = [ "openai/gpt-5.5" ];
    };
    plan = {
      model = "openai/gpt-5.5";
      variant = "xhigh";
      fallback_models = [ "zai-coding-plan/glm-5.2" ];
    };
    oracle = {
      model = "openai/gpt-5.5";
      variant = "xhigh";
      fallback_models = [ "zai-coding-plan/glm-5.2" ];
    };
    prometheus = {
      model = "openai/gpt-5.5";
      variant = "xhigh";
      fallback_models = [ "zai-coding-plan/glm-5.2" ];
    };
    metis = {
      model = "openai/gpt-5.5";
      variant = "xhigh";
      fallback_models = [ "zai-coding-plan/glm-5.2" ];
    };
    momus = {
      model = "openai/gpt-5.5";
      variant = "xhigh";
      fallback_models = [ "zai-coding-plan/glm-5.2" ];
    };
    "OpenCode-Builder" = {
      model = "zai-coding-plan/glm-5.2";
      fallback_models = [ "openai/gpt-5.5" ];
    };
    librarian = {
      model = "zai-coding-plan/glm-5.2";
      fallback_models = [ "openai/gpt-5.5" ];
    };
    explore = {
      model = "zai-coding-plan/glm-5.2";
      fallback_models = [ "openai/gpt-5.5" ];
    };
    "multimodal-looker" = {
      model = "zai-coding-plan/glm-5v-turbo";
      fallback_models = [ "zai-coding-plan/glm-5.2" ];
    };
  };

  defaultCategories = {
    visual-engineering = { model = "zai-coding-plan/glm-5.2"; fallback_models = [ "openai/gpt-5.5" ]; temperature = 0.7; };
    ultrabrain = { model = "openai/gpt-5.5"; variant = "xhigh"; fallback_models = [ "zai-coding-plan/glm-5.2" ]; temperature = 0.1; };
    deep = { model = "openai/gpt-5.5"; variant = "xhigh"; fallback_models = [ "zai-coding-plan/glm-5.2" ]; temperature = 0.2; };
    artistry = { model = "zai-coding-plan/glm-5.2"; fallback_models = [ "openai/gpt-5.5" ]; temperature = 0.9; };
    quick = { model = "zai-coding-plan/glm-5.2"; temperature = 0.3; };
    writing = { model = "zai-coding-plan/glm-5.2"; fallback_models = [ "openai/gpt-5.5" ]; temperature = 0.5; };
    unspecified-low = { model = "zai-coding-plan/glm-5.2"; temperature = 0.3; };
    unspecified-high = { model = "zai-coding-plan/glm-5.2"; fallback_models = [ "openai/gpt-5.5" ]; temperature = 0.3; };
  };

  # OpenCode primary mode agents (live in ./agents/ relative to this file).
  # All engineering sub-roles are delegated via task categories and built-in
  # subagent types (see harnesses/opencode.json), so no custom engineering
  # subagents (planner/worker/ui-worker/researcher/plan-reviewer/code-reviewer/
  # oracle) are shipped for OpenCode.
  agentFiles = [
    "discovery" "design" "execute"
  ];

  # OpenCode skill set, rendered from canonical sources by tools/render-skills.mjs
  # into dist/skills/opencode/. No hand-maintained OpenCode forks.
  # Every skill rendered for OpenCode is installed; exclude via the canonical
  # skill's `harnesses: [..]` frontmatter (see docs/skill-rendering.md).
  openCodeSkills = builtins.attrNames (lib.filterAttrs (_: t: t == "directory")
    (builtins.readDir "${self}/dist/skills/opencode"));

in
{
  makeOpenCodeConfig = args@{
    model ? "zai-coding-plan/glm-5.2",
    plugins ? "default",
    providers ? "default",
    mcp ? "default",
    agentModelOverrides ? {},
    categoryOverrides ? {},
    enableTmux ? true,
    extraAgents ? {},
    extraSkills ? {},
    ...
  }:
  let
    resolvedPlugins =
      if plugins == "default" then defaultPlugins
      else if plugins == "minimal" then minimalPlugins
      else plugins;

    resolvedProviders =
      if providers == "default" then defaultProviders
      else if providers == "zai-only" then (removeAttrs defaultProviders [ "google" "openai" ])
      else providers;

    resolvedMcp =
      if mcp == "default" then defaultMcp
      else mcp;

    resolvedAgents = lib.recursiveUpdate defaultAgentRoster agentModelOverrides;
    resolvedCategories = lib.recursiveUpdate defaultCategories categoryOverrides;

    opencodeJson = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      inherit model;
      plugin = resolvedPlugins;
      provider = resolvedProviders;
      mcp = resolvedMcp;
      agent = defaultAgentConfig;
    };

    tuiJson = builtins.toJSON {
      "$schema" = "https://opencode.ai/tui.json";
      plugin = [ "oh-my-openagent/tui" ];
      keybinds.app_exit = "ctrl+c,<leader>q";
    };

    ohMyJson = builtins.toJSON {
      "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json";

      tmux = {
        enabled = enableTmux;
        layout = "main-vertical";
        main_pane_size = 60;
        main_pane_min_width = 120;
        agent_pane_min_width = 40;
        isolation = "inline";
      };

      disabled_mcps = [ "websearch" ];
      disabled_hooks = [ "keyword-detector" ];

      background_task = {
        defaultConcurrency = 5;
        staleTimeoutMs = 180000;
      };

      runtime_fallback = {
        enabled = true;
        retry_on_errors = [ 400 429 503 529 ];
        max_fallback_attempts = 3;
        cooldown_seconds = 60;
        notify_on_fallback = true;
      };

      git_master = {
        commit_footer = false;
        include_co_authored_by = false;
        git_env_prefix = "GIT_MASTER=1";
      };

      sisyphus_agent = {
        disabled = false;
        default_builder_enabled = true;
        planner_enabled = true;
        replace_plan = false;
      };

      team_mode = {
        enabled = true;
        tmux_visualization = enableTmux;
        max_parallel_members = 4;
        max_members = 8;
        max_messages_per_run = 10000;
        max_wall_clock_minutes = 120;
        max_member_turns = 500;
        message_payload_max_bytes = 32768;
        recipient_unread_max_bytes = 262144;
        mailbox_poll_interval_ms = 3000;
      };

      ralph_loop = {
        enabled = true;
      };

      agents = resolvedAgents;
      categories = resolvedCategories;
    };
  in
  pkgs.runCommand "opencode-config" {} ''
    mkdir -p $out/opencode/{agents,skills}

    cp ${pkgs.writeText "opencode.json" opencodeJson} $out/opencode/opencode.json
    cp ${pkgs.writeText "tui.json" tuiJson} $out/opencode/tui.json
    cp ${pkgs.writeText "oh-my-openagent.json" ohMyJson} $out/opencode/oh-my-openagent.json

    ${lib.concatMapStringsSep "\n  " (name:
      "ln -s ${./agents}/${name}.md $out/opencode/agents/${name}.md"
    ) agentFiles}

    ${lib.concatMapStringsSep "\n  " (name:
      "ln -s ${self}/dist/skills/opencode/${name} $out/opencode/skills/${name}"
    ) openCodeSkills}

    ${lib.concatMapStringsSep "\n  " (name:
      "ln -s ${extraAgents.${name}} $out/opencode/agents/${name}.md"
    ) (lib.attrNames extraAgents)}

    ${lib.concatMapStringsSep "\n  " (name:
      "ln -s ${extraSkills.${name}} $out/opencode/skills/${name}"
    ) (lib.attrNames extraSkills)}
  '';
}
