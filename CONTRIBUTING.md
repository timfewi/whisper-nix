# Contribution Guide

Thanks for your interest in contributing to Whisper Dictate.

## How to contribute

- Open an issue first for bugs, regressions, or larger feature ideas.
- Keep pull requests focused and small when possible.
- Update docs (`README.md` and/or this file) when behavior changes.
- Test changes locally before submitting.

## Local development

1. Clone the repository.
2. Ensure runtime dependencies are installed (PipeWire, ydotool/ydotoold, wl-clipboard, curl, flac, notify-send).
3. Export required environment variables:

```bash
export GROQ_API_KEY="YOUR_KEY_HERE"
export WHISPER_LANG="en"
export YDOTOOL_SOCKET="/run/ydotoold/socket"
```

4. Run the script directly while iterating:

```bash
./whisper-dictate.sh toggle
```

## Reporting issues

Please include:

- Your distro and desktop/session type (for example: NixOS + GNOME Wayland)
- Exact command used (`start`, `stop`, `toggle`, etc.)
- Error output (if any)
- Whether `ydotoold` is running
- Relevant environment values (omit secrets)

Do **not** share your `GROQ_API_KEY`.

## Pull request checklist

- [ ] Change is scoped and clear
- [ ] Script behavior tested manually
- [ ] README/docs updated if needed
- [ ] No secrets committed

## Code style expectations

- Preserve existing shell style and structure in `whisper-dictate.sh`.
- Avoid unrelated refactors in the same PR.
- Prefer simple, robust behavior over clever complexity.

## License

By contributing, you agree that your contributions are licensed under the MIT License used by this repository.# Contribution Guide

Thanks for your interest in contributing to Whisper Dictate.

## How to contribute

- Open an issue first for bugs, regressions, or larger feature ideas.
- Keep pull requests focused and small when possible.
- Update docs (`README.md` and/or this file) when behavior changes.
- Test changes locally before submitting.

## Local development

1. Clone the repository.
2. Ensure runtime dependencies are installed (PipeWire, ydotool/ydotoold, wl-clipboard, curl, flac, notify-send).
3. Export required environment variables:

```bash
export GROQ_API_KEY="YOUR_KEY_HERE"
export WHISPER_LANG="en"
export YDOTOOL_SOCKET="/run/ydotoold/socket"
```

4. Run the script directly while iterating:

```bash
./whisper-dictate.sh toggle
```

## Reporting issues

Please include:

- Your distro and desktop/session type (for example: NixOS + GNOME Wayland)
- Exact command used (`start`, `stop`, `toggle`, etc.)
- Error output (if any)
- Whether `ydotoold` is running
- Relevant environment values (omit secrets)

Do **not** share your `GROQ_API_KEY`.

## Pull request checklist

- [ ] Change is scoped and clear
- [ ] Script behavior tested manually
- [ ] README/docs updated if needed
- [ ] No secrets committed

## Code style expectations

- Preserve existing shell style and structure in `whisper-dictate.sh`.
- Avoid unrelated refactors in the same PR.
- Prefer simple, robust behavior over clever complexity.

## License

By contributing, you agree that your contributions are licensed under the MIT License used by this repository.
