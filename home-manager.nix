{ config, pkgs, lib, ... }:

# =============================================================================
# home-manager.nix - Home Manager module for whisper-dictate
#
# Use this if you prefer Home Manager over system-level NixOS config.
# Add to your home.nix imports:
#   imports = [ ./path/to/whisper-dictate/home-manager.nix ];
#
# NOTE: You still need the ydotoold systemd service and udev rule
#       at the system level (see whisper-dictate.nix for those parts).
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
  # --- User packages ----------------------------------------------------------
  home.packages = with pkgs; [
    whisper-cpp
    ydotool
    pipewire
    wl-clipboard
    libnotify
    curl
    whisper-dictate
    download-model
  ];

  # --- Environment variables --------------------------------------------------
  home.sessionVariables = {
    WHISPER_MODEL = "${config.home.homeDirectory}/.local/share/whisper-dictate/ggml-large-v3-turbo.bin";
    WHISPER_LANG = "de";
    WHISPER_THREADS = "4";
    YDOTOOL_SOCKET = "/run/.ydotoold/socket";
  };

  # --- GNOME keybinding -------------------------------------------------------
  # Bind Super+D to toggle dictation
  dconf.settings = {
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/whisper-dictate/"
      ];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/whisper-dictate" = {
      name = "Whisper Dictate Toggle";
      command = "whisper-dictate toggle";
      binding = "<Super>d";  # Change to your preferred hotkey
    };
  };
}
