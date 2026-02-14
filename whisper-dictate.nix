{ config, pkgs, ... }:

# =============================================================================
# whisper-dictate.nix - NixOS module for voice-to-text dictation
#
# Add this to your configuration.nix imports:
#   imports = [ ./whisper-dictate.nix ];
# =============================================================================

let
  whisper-dictate = pkgs.writeShellScriptBin "whisper-dictate" (
    builtins.readFile ./whisper-dictate.sh
  );
in
{
  # --- System packages --------------------------------------------------------
  environment.systemPackages = with pkgs; [
    # Core dependencies
    ydotool              # Simulate keyboard input on Wayland
    wtype                # Virtual-keyboard key simulation (paste fallback)
    pipewire             # Audio capture (pw-record)
    wl-clipboard         # Clipboard support (fallback mode)
    libnotify            # Error popups only (notify-send)
    curl                 # Groq API requests
    flac                 # Compress WAV→FLAC before upload

    # Our scripts
    whisper-dictate
  ];

  # --- ydotool daemon ---------------------------------------------------------
  # ydotool needs a background daemon with root access to /dev/uinput
  systemd.services.ydotoold = {
    description = "ydotool daemon";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      RuntimeDirectory = "ydotoold";
      ExecStart = "${pkgs.ydotool}/bin/ydotoold --socket-path=/run/ydotoold/socket --socket-perm=0660";
      ExecStartPost = "/run/current-system/sw/bin/chgrp input /run/ydotoold/socket";
      Restart = "on-failure";
      # Socket restricted to root + input group (0660)
      # Add your user to the input group for access
    };
  };

  # --- Environment variables --------------------------------------------------
  environment.sessionVariables = {
    # Language for transcription (ISO 639-1 code). Supported languages:
    #   en = English,  de = German,   fr = French,   es = Spanish,
    #   it = Italian,  pt = Portuguese, nl = Dutch,   pl = Polish,
    #   ja = Japanese, zh = Chinese,  ko = Korean,   ru = Russian,
    #   ar = Arabic,   hi = Hindi,    sv = Swedish,  uk = Ukrainian,
    #   tr = Turkish,  cs = Czech,    da = Danish,   fi = Finnish
    # Full list: https://github.com/openai/whisper#available-models-and-languages
    WHISPER_LANG = "en";
    GROQ_API_URL = "https://api.groq.com/openai/v1/audio/transcriptions";
    GROQ_MODEL = "whisper-large-v3-turbo";
    GROQ_TEMPERATURE = "0";
    # Hybrid feedback: normal flow is silent; only errors show popups.
    WHISPER_NOTIFY_ON_ERROR = "1";
    WHISPER_ERROR_NOTIFY_TIMEOUT = "2200";
    # Paste pacing for better focus/app readiness.
    WHISPER_PASTE_INITIAL_DELAY = "0.45";
    WHISPER_PASTE_RETRY_DELAY = "0.12";
    WHISPER_PASTE_ATTEMPTS = "2";
    # ydotool socket path
    YDOTOOL_SOCKET = "/run/ydotoold/socket";
  };

  # --- Permissions for ydotool ------------------------------------------------
  # Allow users in the "input" group to use ydotool
  users.groups.input = {};
  # Add your user to the input group (replace "<your-user>" with your username)
  # users.users.<your-user>.extraGroups = [ "input" ];

  # udev rule to allow input group access to uinput
  services.udev.extraRules = ''
    KERNEL=="uinput", GROUP="input", MODE="0660"
  '';
}
