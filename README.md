# Whisper Dictate (NixOS + Home Manager)

Offline voice dictation on Wayland/GNOME using:

- `whisper-cpp` for speech-to-text
- `pw-record` (PipeWire) for microphone capture
- `ydotool` for typing text into the focused window

This guide covers everything from setup to first dictation.

## 1) Choose your setup mode

You can use either:

1. **NixOS module only** (`whisper-dictate.nix`), or
2. **Home Manager module** (`home-manager.nix`) **plus** required system-level parts.

### Recommended for most users

Use both:

- System-level config from `whisper-dictate.nix` (for `ydotoold`, udev, permissions)
- User-level config from `home-manager.nix` (for packages, env vars, GNOME keybinding)

## 2) System setup (required)

Edit your `configuration.nix` and import this module:

```nix
imports = [
  /home/<user>/projects/wisper-cpp-nix/whisper-dictate.nix
];
```

Then make sure your user is in the `input` group. In `whisper-dictate.nix`, replace the commented example with your username:

```nix
users.users.<user>.extraGroups = [ "input" ];
```

Apply system changes:

```bash
sudo nixos-rebuild switch
```

## 3) Home Manager setup (optional but convenient)

If you use Home Manager, import this module in your `home.nix`:

```nix
imports = [
  /home/<user>>/projects/wisper-cpp-nix/home-manager.nix
];
```

Apply Home Manager changes:

```bash
home-manager switch
```

This gives you:

- session variables (`WHISPER_MODEL`, `WHISPER_LANG`, `WHISPER_THREADS`)
- GNOME custom keybinding: `Super + D`

## 4) Download a Whisper model

Run:

```bash
whisper-dictate-download-model large-v3-turbo
```

Default model path used by this project:

```text
~/.local/share/whisper-dictate/ggml-large-v3-turbo.bin
```

If you use a different model, set `WHISPER_MODEL` accordingly.

## 5) Verify required services and access

Check the ydotool daemon:

```bash
systemctl status ydotoold
```

Check that your shell sees the socket variable:

```bash
echo "$YDOTOOL_SOCKET"
```

Expected value:

```text
/run/.ydotoold/socket
```

If group membership was just changed, log out and log back in.

## 6) First dictation test (manual)

Open any text field (for example a text editor), then run:

```bash
whisper-dictate start
```

Speak clearly into your microphone, then stop and transcribe:

```bash
whisper-dictate stop
```

The transcribed text should be typed into the currently focused window.

## 7) Daily usage (hotkey)d

If using the provided Home Manager settings:

- Press `Super + D` once to start recording
- Speak
- Press `Super + D` again to stop, transcribe, and type

That is the normal workflow.

## 8) Useful commands

```bash
whisper-dictate toggle          # start/stop with one command
whisper-dictate status          # shows Idle or Recording
whisper-dictate stop-clipboard  # fallback: copy + paste instead of direct typing
```

## 9) Common customizations

### Change language

Set in Home Manager or environment:

```bash
export WHISPER_LANG=en
```

Examples:

- `de` = German
- `en` = English
- `auto` = language auto-detect

### Change CPU threads

```bash
export WHISPER_THREADS=8
```

Higher can be faster, depending on your CPU.

### Use a smaller/faster model

```bash
whisper-dictate-download-model small
export WHISPER_MODEL="$HOME/.local/share/whisper-dictate/ggml-small.bin"
```

## 10) Troubleshooting

### Nothing gets typed

- Confirm `ydotoold` is running: `systemctl status ydotoold`
- Confirm user is in `input` group
- Log out/in after group changes
- Try fallback mode: `whisper-dictate stop-clipboard`

### “No audio recorded” or empty transcription

- Verify microphone is working in another app
- Check PipeWire tools are installed (`pw-record` available)
- Speak closer/louder and try again

### Model file not found

- Re-run `whisper-dictate-download-model large-v3-turbo`
- Verify `WHISPER_MODEL` path points to an existing `.bin` file

---

## Quick start summary

1. Import `whisper-dictate.nix` in system config
2. Add your user to `input` group
3. Rebuild: `sudo nixos-rebuild switch`
4. (Optional) Import `home-manager.nix`, run `home-manager switch`
5. Download model: `whisper-dictate-download-model large-v3-turbo`
6. Press `Super + D`, speak, press `Super + D` again