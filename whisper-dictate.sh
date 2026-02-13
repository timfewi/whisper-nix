#!/usr/bin/env bash
# =============================================================================
# whisper-dictate.sh - Voice-to-text dictation for GNOME/Wayland on NixOS
#
# Uses: Groq Speech-to-Text API, pipewire (audio capture), ydotool (typing)
#
# Usage:
#   whisper-dictate.sh toggle   # Start/stop recording (bind this to a hotkey)
#   whisper-dictate.sh start    # Start recording
#   whisper-dictate.sh stop     # Stop recording and transcribe
#   whisper-dictate.sh status   # Check if currently recording
# =============================================================================

set -euo pipefail

# --- Configuration -----------------------------------------------------------
# Language for transcription (de = German, en = English, auto = auto-detect)
LANGUAGE="${WHISPER_LANG:-de}"

# Groq API configuration
GROQ_API_URL="${GROQ_API_URL:-https://api.groq.com/openai/v1/audio/transcriptions}"
GROQ_MODEL="${GROQ_MODEL:-whisper-large-v3-turbo}"
GROQ_RESPONSE_FORMAT="${GROQ_RESPONSE_FORMAT:-json}"
GROQ_TEMPERATURE="${GROQ_TEMPERATURE:-0}"
GROQ_PROMPT="${GROQ_PROMPT:-}"

# Notification timeout in milliseconds
NOTIFY_TIMEOUT=2000

# --- Internal paths (don't change) -------------------------------------------
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
PID_FILE="$RUNTIME_DIR/whisper-dictate.pid"
AUDIO_FILE="$RUNTIME_DIR/whisper-dictate.wav"
LOCK_FILE="$RUNTIME_DIR/whisper-dictate.lock"
MIN_WAV_BYTES=128

if [[ -n "${YDOTOOL_SOCKET:-}" ]] && [[ -S "$YDOTOOL_SOCKET" ]]; then
    export YDOTOOL_SOCKET
elif [[ -S "/run/ydotoold/socket" ]]; then
    export YDOTOOL_SOCKET="/run/ydotoold/socket"
elif [[ -S "/run/.ydotoold/socket" ]]; then
    export YDOTOOL_SOCKET="/run/.ydotoold/socket"
else
    export YDOTOOL_SOCKET="${YDOTOOL_SOCKET:-/run/ydotoold/socket}"
fi

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
    if [[ ! -f "$PID_FILE" ]]; then
        return 1
    fi

    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null || echo "")

    if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$PID_FILE"
        return 1
    fi

    local args
    args=$(ps -p "$pid" -o args= 2>/dev/null || true)
    if [[ "$args" != *"pw-record"* ]]; then
        rm -f "$PID_FILE"
        return 1
    fi

    return 0
}

stop_capture_process() {
    local pid="$1"

    kill -INT "$pid" 2>/dev/null || true

    for _ in {1..30}; do
        if ! kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
        sleep 0.1
    done

    kill -TERM "$pid" 2>/dev/null || true
    sleep 0.2
    kill -KILL "$pid" 2>/dev/null || true
}

has_valid_audio() {
    [[ -f "$AUDIO_FILE" ]] && [[ $(stat -c%s "$AUDIO_FILE" 2>/dev/null || echo 0) -ge "$MIN_WAV_BYTES" ]]
}

transcribe_audio() {
    if [[ -z "${GROQ_API_KEY:-}" ]]; then
        notify "❌ GROQ_API_KEY is not set." "critical"
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        notify "❌ jq is required for cloud transcription parsing." "critical"
        return 1
    fi

    local -a form_args
    form_args=(
        -F "file=@$AUDIO_FILE"
        -F "model=$GROQ_MODEL"
        -F "language=$LANGUAGE"
        -F "response_format=$GROQ_RESPONSE_FORMAT"
        -F "temperature=$GROQ_TEMPERATURE"
    )

    if [[ -n "$GROQ_PROMPT" ]]; then
        form_args+=( -F "prompt=$GROQ_PROMPT" )
    fi

    local response
    if ! response=$(curl --silent --show-error --fail \
        -X POST "$GROQ_API_URL" \
        -H "Authorization: Bearer $GROQ_API_KEY" \
        "${form_args[@]}" 2>&1); then
        notify "❌ Groq transcription request failed." "critical"
        return 1
    fi

    if [[ "$GROQ_RESPONSE_FORMAT" == "text" ]]; then
        printf '%s\n' "$response" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
        return 0
    fi

    printf '%s\n' "$response" | jq -r '.text // empty'
}

paste_clipboard_with_fallback() {
    local pasted=1

    if ydotool key 29:1 47:1 47:0 29:0 2>/dev/null; then
        pasted=0
    else
        # Fallback for apps that prefer Shift+Insert
        if ydotool key 42:1 110:1 110:0 42:0 2>/dev/null; then
            pasted=0
        fi
    fi

    if [[ "$pasted" -ne 0 ]]; then
        notify "📋 Copied to clipboard. Press Ctrl+V to paste." "low"
        return 1
    fi

    return 0
}

start_recording() {
    if is_recording; then
        notify "Already recording..." "low"
        return 1
    fi

    # Clean up any leftover audio file
    rm -f "$AUDIO_FILE"

    # Start recording with pipewire
    # --rate 16000: optimal for speech-to-text
    # --channels 1: mono audio
    # --format s16: 16-bit signed integer
    pw-record \
        --rate 16000 \
        --channels 1 \
        --format s16 \
        "$AUDIO_FILE" 200>&- &

    echo $! > "$PID_FILE"

    # Ensure recorder process actually started
    sleep 0.15
    if ! is_recording; then
        rm -f "$PID_FILE"
        notify "❌ Failed to start recording." "critical"
        return 1
    fi

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
    stop_capture_process "$pid"
    wait "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"

    # Check if audio file exists and has content
    if ! has_valid_audio; then
        notify "⚠️ No audio recorded." "critical"
        return 1
    fi

    notify "⏳ Transcribing..."

    # Transcribe with Groq API
    local text
    text=$(transcribe_audio)

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
    flock -n 200 || {
        notify "⏳ Previous dictation action is still finishing." "low"
        echo "Another instance is running"
        exit 1
    }

    if is_recording; then
        stop_recording
    else
        start_recording
    fi
}

toggle_clipboard() {
    exec 200>"$LOCK_FILE"
    flock -n 200 || {
        notify "⏳ Previous dictation action is still finishing." "low"
        echo "Another instance is running"
        exit 1
    }

    if is_recording; then
        stop_recording_clipboard
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

    stop_capture_process "$pid"
    wait "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"

    if ! has_valid_audio; then
        notify "⚠️ No audio recorded." "critical"
        return 1
    fi

    notify "⏳ Transcribing..."

    local text
    text=$(transcribe_audio)

    rm -f "$AUDIO_FILE"

    if [[ -z "$text" ]]; then
        notify "⚠️ No speech detected." "low"
        return 1
    fi

    # Copy to clipboard and paste
    echo -n "$text" | wl-copy 200>&-
    sleep 0.1
    paste_clipboard_with_fallback || true

    notify "✅ Done: ${text:0:50}..."
}

# --- Push-to-talk mode -------------------------------------------------------
# ptt-start: begin recording on key press
# ptt-stop: stop recording + paste on key release

ptt_start() {
    start_recording
}

ptt_stop() {
    stop_recording_clipboard
}

# --- Main ---------------------------------------------------------------------

case "${1:-toggle}" in
    start)          start_recording ;;
    stop)           stop_recording ;;
    stop-clipboard) stop_recording_clipboard ;;
    ptt-start)      ptt_start ;;
    ptt-stop)       ptt_stop ;;
    toggle)         toggle ;;
    toggle-clipboard) toggle_clipboard ;;
    status)         show_status ;;
    *)
        echo "Usage: $(basename "$0") {toggle|toggle-clipboard|start|stop|stop-clipboard|ptt-start|ptt-stop|status}"
        echo ""
        echo "  toggle          Start or stop recording (default, bind to hotkey)"
        echo "  toggle-clipboard Start/stop and paste via clipboard (more robust)"
        echo "  start           Start recording"
        echo "  stop            Stop and transcribe (types via ydotool)"
        echo "  stop-clipboard  Stop and transcribe (pastes via clipboard)"
        echo "  ptt-start       Push-to-talk start (bind to key press)"
        echo "  ptt-stop        Push-to-talk stop + paste (bind to key release)"
        echo "  status          Show current state"
        exit 1
        ;;
esac
