{
  config,
  lib,
  pkgs,
  ...
}:

# =============================================================================
# whisper-dictate.nix - NixOS module for voice-to-text dictation
#
# Add this to your configuration.nix imports:
#   imports = [ ./whisper-dictate.nix ];
# =============================================================================

let
  cfg = config.programs.whisperDictate;

  whisper-dictate = pkgs.writeShellScriptBin "whisper-dictate" (
    builtins.readFile ./whisper-dictate.sh
  );
in
{
  options.programs.whisperDictate.openRouterApiKeyFile = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "/run/agenix/openrouter-api-key";
    description = ''
      Runtime path to a file containing the OpenRouter API key.
    '';
  };
  # options.programs.whisperDictate.groqApiKeyFile = lib.mkOption {
  #   type = lib.types.nullOr lib.types.str;
  #   default = null;
  #   example = "/run/agenix/groq-api-key";
  #   description = ''
  #     Runtime path to a file containing the Groq API key.
  #   '';
  # };

  config = {
    environment.systemPackages = with pkgs; [
      ydotool
      wtype
      pipewire
      wl-clipboard
      libnotify
      curl
      flac
      whisper-dictate
    ];

    systemd.services.ydotoold = {
      description = "ydotool daemon";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        RuntimeDirectory = "ydotoold";
        ExecStart = "${pkgs.ydotool}/bin/ydotoold --socket-path=/run/ydotoold/socket --socket-perm=0660";
        ExecStartPost = "/run/current-system/sw/bin/chgrp input /run/ydotoold/socket";
        Restart = "on-failure";
      };
    };

    environment.sessionVariables = {
      WHISPER_LANG = "en";
      OPENROUTER_API_URL = "https://openrouter.ai/api/v1/audio/transcriptions";
      OPENROUTER_MODEL = "qwen/qwen3-asr-flash-2026-02-10";
      OPENROUTER_TEMPERATURE = "0";
      # GROQ_API_URL = "https://api.groq.com/openai/v1/audio/transcriptions";
      # GROQ_MODEL = "whisper-large-v3-turbo";
      # GROQ_TEMPERATURE = "0";
      WHISPER_NOTIFY_ON_ERROR = "1";
      WHISPER_ERROR_NOTIFY_TIMEOUT = "2200";
      WHISPER_PASTE_INITIAL_DELAY = "0.45";
      WHISPER_PASTE_RETRY_DELAY = "0.12";
      WHISPER_PASTE_ATTEMPTS = "2";
      YDOTOOL_SOCKET = "/run/ydotoold/socket";
    }
    // lib.optionalAttrs (cfg.openRouterApiKeyFile != null) {
      OPENROUTER_API_KEY_FILE = cfg.openRouterApiKeyFile;
    };
    # // lib.optionalAttrs (cfg.groqApiKeyFile != null) {
    #   GROQ_API_KEY_FILE = cfg.groqApiKeyFile;
    # };

    # --- Permissions for ydotool ------------------------------------------------
    # Allow users in the "input" group to use ydotool
    users.groups.input = { };
    # Add your user to the input group (replace "<your-user>" with your username)
    # users.users.<your-user>.extraGroups = [ "input" ];

    # udev rule to allow input group access to uinput
    services.udev.extraRules = ''
      KERNEL=="uinput", GROUP="input", MODE="0660"
    '';
  };
}
