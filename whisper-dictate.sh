#!/usr/bin/env bash
# =============================================================================
# whisper-dictate.sh - Voice-to-text dictation for GNOME/Wayland on NixOS
#
# Uses: whisper-cpp (offline STT), pipewire (audio capture), ydotool (typing)
#
# Usage:
#   whisper-dictate.sh toggle   # Start/stop recording (bind this to a hotkey)
#   whisper-dictate.sh start    # Start recording
#   whisper-dictate.sh stop     # Stop recording and transcribe
#   whisper-dictate.sh status   # Check if currently recording
# =============================================================================

set -euo pipefail

# --- Configuration -----------------------------------------------------------
# Path to whisper.cpp model (download instructions in README)
MODEL="${WHISPER_MODEL:-$HOME/.local/share/whisper-dictate/ggml-large-v3-turbo.bin}"

# Language for transcription (de = German, en = English, auto = auto-detect)
LANGUAGE="${WHISPER_LANG:-de}"

# Number of processing threads
THREADS="${WHISPER_THREADS:-4}"

# Notification timeout in milliseconds
NOTIFY_TIMEOUT=2000

# --- Internal paths (don't change) -------------------------------------------
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
PID_FILE="$RUNTIME_DIR/whisper-dictate.pid"
AUDIO_FILE="$RUNTIME_DIR/whisper-dictate.wav"
LOCK_FILE="$RUNTIME_DIR/whisper-dictate.lock"

# --- Helper functions ---------------------------------------------------------

notify() {
    local urgency="${2:-normal}"
    notify-send \
        --app-name="Whisper Dictate" \
        --urgency="$urgency" \
        --expire-time="$NOTIFY_TIMEOUT" \
        --icon=audio-input-microphone \
        "Whisper Dictate" "$1" 2>/dev/null || true
}

is_recording() {
    [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

start_recording() {
    if is_recording; then
        notify "Already recording..." "low"
        return 1
    fi

    # Clean up any leftover audio file
    rm -f "$AUDIO_FILE"

    # Start recording with pipewire
    # --rate 16000: whisper.cpp expects 16kHz audio
    # --channels 1: mono audio
    # --format s16: 16-bit signed integer
    pw-record \
        --rate 16000 \
        --channels 1 \
        --format s16 \
        "$AUDIO_FILE" &

    echo $! > "$PID_FILE"

    notify "🎙️ Recording started... Press hotkey again to stop."
    echo "Recording started (PID: $(cat "$PID_FILE"))"
}

stop_recording() {
    if ! is_recording; then
        notify "Not currently recording." "low"
        return 1
    fi

    local pid
    pid=$(cat "$PID_FILE")

    # Stop recording gracefully
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"

    # Check if audio file exists and has content
    if [[ ! -f "$AUDIO_FILE" ]] || [[ ! -s "$AUDIO_FILE" ]]; then
        notify "⚠️ No audio recorded." "critical"
        return 1
    fi

    notify "⏳ Transcribing..."

    # Transcribe with whisper.cpp
    local text
    text=$(whisper-cpp \
        --model "$MODEL" \
        --language "$LANGUAGE" \
        --threads "$THREADS" \
        --no-timestamps \
        --file "$AUDIO_FILE" 2>/dev/null \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
        | grep -v '^\[' \
        | tr '\n' ' ' \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Clean up audio file
    rm -f "$AUDIO_FILE"

    if [[ -z "$text" ]]; then
        notify "⚠️ No speech detected." "low"
        return 1
    fi

    echo "Transcribed: $text"

    # Type the text into the focused window using ydotool
    # Small delay to ensure focus is correct
    sleep 0.1
    ydotool type --key-delay 2 -- "$text"

    notify "✅ Done: ${text:0:50}..."
}

toggle() {
    # Use a lock file to prevent race conditions with rapid key presses
    exec 200>"$LOCK_FILE"
    flock -n 200 || { echo "Another instance is running"; exit 1; }

    if is_recording; then
        stop_recording
    else
        start_recording
    fi
}

show_status() {
    if is_recording; then
        echo "Recording (PID: $(cat "$PID_FILE"))"
    else
        echo "Idle"
    fi
}

# --- Clipboard fallback mode --------------------------------------------------
# If ydotool doesn't work well, you can use this instead.
# It copies text to clipboard and pastes with Ctrl+V.

stop_recording_clipboard() {
    if ! is_recording; then
        notify "Not currently recording." "low"
        return 1
    fi

    local pid
    pid=$(cat "$PID_FILE")

    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"

    if [[ ! -f "$AUDIO_FILE" ]] || [[ ! -s "$AUDIO_FILE" ]]; then
        notify "⚠️ No audio recorded." "critical"
        return 1
    fi

    notify "⏳ Transcribing..."

    local text
    text=$(whisper-cpp \
        --model "$MODEL" \
        --language "$LANGUAGE" \
        --threads "$THREADS" \
        --no-timestamps \
        --file "$AUDIO_FILE" 2>/dev/null \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
        | grep -v '^\[' \
        | tr '\n' ' ' \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    rm -f "$AUDIO_FILE"

    if [[ -z "$text" ]]; then
        notify "⚠️ No speech detected." "low"
        return 1
    fi

    # Copy to clipboard and paste
    echo -n "$text" | wl-copy
    sleep 0.1
    ydotool key 29:1 47:1 47:0 29:0  # Ctrl+V

    notify "✅ Done: ${text:0:50}..."
}

# --- Main ---------------------------------------------------------------------

case "${1:-toggle}" in
    start)          start_recording ;;
    stop)           stop_recording ;;
    stop-clipboard) stop_recording_clipboard ;;
    toggle)         toggle ;;
    status)         show_status ;;
    *)
        echo "Usage: $(basename "$0") {toggle|start|stop|stop-clipboard|status}"
        echo ""
        echo "  toggle          Start or stop recording (default, bind to hotkey)"
        echo "  start           Start recording"
        echo "  stop            Stop and transcribe (types via ydotool)"
        echo "  stop-clipboard  Stop and transcribe (pastes via clipboard)"
        echo "  status          Show current state"
        exit 1
        ;;
esac
