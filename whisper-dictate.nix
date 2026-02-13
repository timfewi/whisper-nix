{ config, pkgs, lib, ... }:

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
    jq                   # Parse Groq JSON response
    ydotool              # Simulate keyboard input on Wayland
    pipewire             # Audio capture (pw-record)
    wl-clipboard         # Clipboard support (fallback mode)
    libnotify            # Desktop notifications (notify-send)
    curl                 # Groq API requests

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
      ExecStart = "${pkgs.ydotool}/bin/ydotoold --socket-path=/run/ydotoold/socket --socket-perm=0666";
      Restart = "on-failure";
      # Grant access to the current user
      # The socket will be at /run/ydotoold/socket
    };
  };

  # --- Environment variables --------------------------------------------------
  environment.sessionVariables = {
    WHISPER_LANG = "en";
    GROQ_API_URL = "https://api.groq.com/openai/v1/audio/transcriptions";
    GROQ_MODEL = "whisper-large-v3-turbo";
    GROQ_RESPONSE_FORMAT = "json";
    GROQ_TEMPERATURE = "0";
    # ydotool socket path
    YDOTOOL_SOCKET = "/run/ydotoold/socket";
  };

  # --- Permissions for ydotool ------------------------------------------------
  # Allow users in the "input" group to use ydotool
  users.groups.input = {};
  # Add your user to the input group (replace "tim" with your username)
  # users.users.tim.extraGroups = [ "input" ];

  # udev rule to allow input group access to uinput
  services.udev.extraRules = ''
    KERNEL=="uinput", GROUP="input", MODE="0660"
  '';
}
