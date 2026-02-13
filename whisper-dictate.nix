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

  download-model = pkgs.writeShellScriptBin "whisper-dictate-download-model" (
    builtins.readFile ./download-model.sh
  );
in
{
  # --- System packages --------------------------------------------------------
  environment.systemPackages = with pkgs; [
    # Core dependencies
    whisper-cpp          # Speech-to-text engine
    ydotool              # Simulate keyboard input on Wayland
    pipewire             # Audio capture (pw-record)
    wl-clipboard         # Clipboard support (fallback mode)
    libnotify            # Desktop notifications (notify-send)
    curl                 # Model download

    # Our scripts
    whisper-dictate
    download-model
  ];

  # --- ydotool daemon ---------------------------------------------------------
  # ydotool needs a background daemon with root access to /dev/uinput
  systemd.services.ydotoold = {
    description = "ydotool daemon";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.ydotool}/bin/ydotoold";
      Restart = "on-failure";
      # Grant access to the current user
      # The socket will be at /run/.ydotoold/socket
    };
  };

  # --- Environment variables --------------------------------------------------
  environment.sessionVariables = {
    WHISPER_MODEL = "$HOME/.local/share/whisper-dictate/ggml-large-v3-turbo.bin";
    WHISPER_LANG = "de";  # Change to "en" for English, "auto" for auto-detect
    WHISPER_THREADS = "4"; # Adjust based on your CPU cores
    # ydotool socket path
    YDOTOOL_SOCKET = "/run/.ydotoold/socket";
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
