# Whisper Dictate (NixOS + Groq API)

**Fast, free, and private voice-to-text for NixOS.** Dictate into any app with a hotkey and get transcription back in seconds, powered by Groq’s free-tier Whisper API. No paid subscription, no cloud lock-in, no heavy background service.

- **Lightning fast** — WAV is compressed before upload for lower latency and faster responses
- **Free to use** — built around Groq’s generous free API tier (no credit card required)
- **20+ languages with translation** — speak in supported languages and transcribe into your configured target language (for example, set `WHISPER_LANG="en"` to get English output)
- **Pure NixOS** — single `configuration.nix` import, no Home Manager required
- **Wayland-native** — built on PipeWire + ydotool; works on GNOME, Hyprland, Sway, and similar desktops
- **Reliable** — adaptive insertion (GNOME Text Editor type-first, other apps paste-first), retry on network errors, and error-only popups

## 1) Import module in configuration.nix

```nix
imports = [
  /home/<user>/projects/whisper-nix/whisper-dictate.nix
];
```

## 2) Set your Groq API key

Create API key: https://console.groq.com/keys

Add to your shell profile (recommended):

```bash
echo 'export GROQ_API_KEY="YOUR_KEY_HERE"' >> ~/.zshrc
source ~/.zshrc
```

## 3) Apply system config

```bash
sudo nixos-rebuild switch
```

## 4) Add GNOME hotkey

Settings → Keyboard → Custom Shortcuts

- Name: `whisper-dictate-toggle`
- Command: `whisper-dictate toggle`
- Shortcut: `Super + D`

## 5) First test

```bash
whisper-dictate start
# speak for 3-5 seconds
whisper-dictate stop
whisper-dictate status
```

Expected: status returns `Idle` and text is inserted automatically.

Insertion behavior is now fixed (no mode switching):

- GNOME Text Editor focused → type-first insertion
- Other windows → paste-first insertion
- If both fail → text remains in clipboard and an error popup is shown

## Visual feedback (hybrid)

- Normal operation is silent (no popup spam)
- Errors show a desktop popup (`notify-send`) so users understand what failed
- Runtime state is written to `$XDG_RUNTIME_DIR/whisper-dictate.state` with values:
  - `idle`
  - `recording`
  - `transcribing`

If you have a panel/icon integration, read this state file to show the current mode.

## 6) Environment variables

Configured by module:

- `GROQ_API_URL=https://api.groq.com/openai/v1/audio/transcriptions`
- `GROQ_MODEL=whisper-large-v3-turbo`
- `GROQ_TEMPERATURE=0`
- `WHISPER_LANG=en`
- `WHISPER_NOTIFY_ON_ERROR=1` (show only failure notifications)
- `WHISPER_ERROR_NOTIFY_TIMEOUT=2200` (milliseconds)
- `WHISPER_PASTE_INITIAL_DELAY=0.45` (seconds before first paste try)
- `WHISPER_PASTE_RETRY_DELAY=0.12` (seconds between retry actions)
- `WHISPER_PASTE_ATTEMPTS=2` (small retry batch)
- `YDOTOOL_SOCKET=/run/ydotoold/socket`

Required from you:

- `GROQ_API_KEY`

## 7) Troubleshooting

- `GROQ_API_KEY is not set` → export key in `~/.zshrc` and restart shell
- `Not currently recording` on stop → run start first, then stop
- Check daemon: `sudo systemctl status ydotoold`
- API timeout → check internet connection; curl retries automatically (2x)
- Ensure your user is in the `input` group: `sudo usermod -aG input $USER` then re-login
- GNOME Text Editor behavior → insertion is type-first automatically when GNOME Text Editor is focused; no mode switch needed.

## 8) Using on other Linux distros (Ubuntu, Fedora, Arch, etc.)

The shell script works standalone on any Wayland Linux distro. Just install the dependencies manually:

| Dependency | Ubuntu/Debian | Fedora | Arch |
|---|---|---|---|
| `pw-record` | `pipewire` | `pipewire` | `pipewire` |
| `ydotool` + `ydotoold` | `ydotool` | `ydotool` | `ydotool` |
| `wl-copy` | `wl-clipboard` | `wl-clipboard` | `wl-clipboard` |
| `notify-send` (error popups) | `libnotify-bin` | `libnotify` | `libnotify` |
| `curl` | `curl` | `curl` | `curl` |
| `flac` | `flac` | `flac` | `flac` |

Then:

```bash
# 1. Start the ydotool daemon
sudo ydotoold --socket-path=/run/ydotoold/socket --socket-perm=0660 &

# 2. Set your API key and language
export GROQ_API_KEY="YOUR_KEY_HERE"
export WHISPER_LANG="en"
export YDOTOOL_SOCKET="/run/ydotoold/socket"

# 3. Run directly
./whisper-dictate.sh toggle
```

Bind the toggle command to a hotkey in your desktop environment's settings.

## 9) Windows & macOS

This tool is **Linux/Wayland-only**. Windows and macOS lack the required components:

- **Windows**: no PipeWire, no ydotool, no wl-clipboard. WSL2 audio passthrough is unreliable. A native port would require a full rewrite using e.g. `ffmpeg` + `AutoHotkey` + PowerShell.
- **macOS**: would need `sox`/`ffmpeg` instead of `pw-record`, `pbcopy` instead of `wl-clipboard`, and `osascript` instead of `ydotool`.

If there's interest, a cross-platform port could be built — contributions welcome!

## License

MIT. See `LICENSE`.

## Contributing

See `CONTRIBUTING.md`.

## Security

See `SECURITY.md` for private vulnerability reporting guidance.
