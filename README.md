# Whisper Dictate (NixOS + Groq API)

**Fast, free, and private voice-to-text for NixOS.** Dictate into any app at the press of a hotkey — transcription comes back in under a second, powered by Groq's free-tier Whisper API. No paid subscription, no cloud lock-in, no background daemon eating your RAM.

- **Lightning fast** — audio is compressed before upload; results stream back in ~500ms
- **Free to use** — runs on Groq's generous free API tier (no credit card required)
- **20+ languages with translation** — speak in any supported language (e.g. German) and get the transcription in your configured target language (e.g. English). Set `WHISPER_LANG="en"` and Whisper translates your speech into English text, no matter what language you speak
- **Pure NixOS** — single `configuration.nix` import, no Home Manager needed
- **Wayland-native** — uses PipeWire + ydotool; works on GNOME, Hyprland, Sway, etc.
- **Reliable** — automatic clipboard fallback, retry on network errors, actionable notifications

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
- `GROQ_RESPONSE_FORMAT=text`
- `GROQ_TEMPERATURE=0`
- `WHISPER_LANG=en`
- `YDOTOOL_SOCKET=/run/ydotoold/socket`

Required from you:

- `GROQ_API_KEY`

## 7) Troubleshooting

- `GROQ_API_KEY is not set` → export key in `~/.zshrc` and restart shell
- `Not currently recording` on stop → run start first, then stop
- No paste in some apps → use clipboard manually with `Ctrl+V`
- Check daemon: `sudo systemctl status ydotoold`
- API timeout → check internet connection; curl retries automatically (2x)
- Ensure your user is in the `input` group: `sudo usermod -aG input $USER` then re-login