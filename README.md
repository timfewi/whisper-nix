# Whisper Dictate (NixOS + Groq API)

Whisper Dictate is a lightweight NixOS module and shell script that records your microphone on GNOME/Wayland, sends audio to Groq Whisper for transcription, and inserts the text into your focused app.
You can expect a configuration.nix-only setup (no Home Manager), hotkey-driven start/stop dictation, and practical fallback behavior when direct paste is unavailable.

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
- Command: `whisper-dictate toggle-clipboard`
- Shortcut: `Super + D`

## 5) First test

```bash
whisper-dictate start
# speak for 3-5 seconds
whisper-dictate stop-clipboard
whisper-dictate status
```

Expected: status returns `Idle` and text is pasted (or copied to clipboard with notification fallback).

## 6) Environment variables

Configured by module:

- `GROQ_API_URL=https://api.groq.com/openai/v1/audio/transcriptions`
- `GROQ_MODEL=whisper-large-v3-turbo`
- `GROQ_RESPONSE_FORMAT=json`
- `GROQ_TEMPERATURE=0`
- `WHISPER_LANG=en`
- `YDOTOOL_SOCKET=/run/ydotoold/socket`

Required from you:

- `GROQ_API_KEY`

## 7) Troubleshooting

- `GROQ_API_KEY is not set` → export key in `~/.zshrc` and restart shell
- `Not currently recording` on stop → run start first, then stop
- No paste in some apps → use clipboard manually with `Ctrl+V`
- Check daemon: `systemctl status ydotoold`