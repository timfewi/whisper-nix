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
umask 077

# --- Configuration -----------------------------------------------------------
# Language for transcription (ISO 639-1 code, e.g. en, de, fr).
LANGUAGE="${WHISPER_LANG:-en}"

# Groq API configuration
GROQ_API_URL="${GROQ_API_URL:-https://api.groq.com/openai/v1/audio/transcriptions}"
GROQ_MODEL="${GROQ_MODEL:-whisper-large-v3-turbo}"
GROQ_TEMPERATURE="${GROQ_TEMPERATURE:-0}"
GROQ_PROMPT="${GROQ_PROMPT:-}"

# Error notification behavior (normal flow stays silent)
ERROR_NOTIFY_ENABLED="${WHISPER_NOTIFY_ON_ERROR:-1}"
ERROR_NOTIFY_TIMEOUT="${WHISPER_ERROR_NOTIFY_TIMEOUT:-2200}"

# Paste pacing (helps when target app focus is not ready immediately)
PASTE_INITIAL_DELAY="${WHISPER_PASTE_INITIAL_DELAY:-0.45}"
PASTE_RETRY_DELAY="${WHISPER_PASTE_RETRY_DELAY:-0.12}"
PASTE_ATTEMPTS="${WHISPER_PASTE_ATTEMPTS:-2}"

# --- Internal paths (don't change) -------------------------------------------
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
PID_FILE="$RUNTIME_DIR/whisper-dictate.pid"
AUDIO_FILE="$RUNTIME_DIR/whisper-dictate.wav"
FLAC_FILE="$RUNTIME_DIR/whisper-dictate.flac"
LOCK_FILE="$RUNTIME_DIR/whisper-dictate.lock"
STATE_FILE="${WHISPER_STATE_FILE:-$RUNTIME_DIR/whisper-dictate.state}"
MIN_WAV_BYTES=128

# Curl timeout/retry settings
CURL_CONNECT_TIMEOUT=5
CURL_MAX_TIME=30
CURL_RETRIES=2

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

set_state() {
    printf '%s\n' "$1" > "$STATE_FILE"
}

notify_error() {
    local message="$1"

    echo "$message" >&2

    if [[ "$ERROR_NOTIFY_ENABLED" != "1" ]]; then
        return 0
    fi

    if ! command -v notify-send >/dev/null 2>&1; then
        return 0
    fi

    notify-send \
        --app-name="Whisper Dictate" \
        --urgency="critical" \
        --expire-time="$ERROR_NOTIFY_TIMEOUT" \
        --icon=dialog-error \
        "Whisper Dictate" "$message" 2>/dev/null || true
}

is_recording() {
    if [[ ! -f "$PID_FILE" ]]; then
        return 1
    fi

    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null || echo "")

    if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$PID_FILE"
        set_state "idle"
        return 1
    fi

    local args
    args=$(ps -p "$pid" -o args= 2>/dev/null || true)
    if [[ "$args" != *"pw-record"* ]]; then
        rm -f "$PID_FILE"
        set_state "idle"
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
        notify_error "GROQ_API_KEY is not set."
        return 1
    fi

    # Compress WAV → FLAC for faster upload (5-15x smaller)
    local upload_file="$AUDIO_FILE"
    if command -v flac >/dev/null 2>&1; then
        if flac --silent --force "$AUDIO_FILE" -o "$FLAC_FILE" 2>/dev/null; then
            upload_file="$FLAC_FILE"
        fi
    fi

    local -a form_args
    form_args=(
        -F "file=@$upload_file"
        -F "model=$GROQ_MODEL"
        -F "response_format=text"
        -F "temperature=$GROQ_TEMPERATURE"
    )

    # Omit language param when set to "auto" so Whisper auto-detects
    if [[ "$LANGUAGE" != "auto" ]]; then
        form_args+=( -F "language=$LANGUAGE" )
    fi

    if [[ -n "$GROQ_PROMPT" ]]; then
        form_args+=( -F "prompt=$GROQ_PROMPT" )
    fi

    local response
    if ! response=$(curl --silent --show-error --fail \
        --connect-timeout "$CURL_CONNECT_TIMEOUT" \
        --max-time "$CURL_MAX_TIME" \
        --retry "$CURL_RETRIES" \
        --retry-delay 1 \
        -X POST "$GROQ_API_URL" \
        -H "Authorization: Bearer $GROQ_API_KEY" \
        "${form_args[@]}" 2>&1); then
        if [[ "$response" == *"timed out"* || "$response" == *"timeout"* ]]; then
            notify_error "Groq API timed out. Check your connection."
        elif [[ "$response" == *"401"* || "$response" == *"Unauthorized"* ]]; then
            notify_error "Groq API auth failed. Check GROQ_API_KEY."
        elif [[ "$response" == *"429"* ]]; then
            notify_error "Groq API rate limited. Try again shortly."
        else
            notify_error "Groq transcription request failed."
        fi
        rm -f "$FLAC_FILE"
        return 1
    fi

    rm -f "$FLAC_FILE"

    printf '%s\n' "$response" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}

paste_shortcuts_once() {
    ydotool key 29:1 42:1 47:1 47:0 42:0 29:0 2>/dev/null && return 0
    ydotool key 29:1 47:1 47:0 29:0 2>/dev/null && return 0
    ydotool key 42:1 110:1 110:0 42:0 2>/dev/null && return 0

    if command -v wtype >/dev/null 2>&1; then
        wtype -M ctrl v -m ctrl 2>/dev/null && return 0
        wtype -M shift Insert -m shift 2>/dev/null && return 0
    fi

    return 1
}

paste_clipboard_with_fallback() {
    local attempts="$PASTE_ATTEMPTS"

    for ((i = 1; i <= attempts; i++)); do
        if paste_shortcuts_once; then
            return 0
        fi
        sleep "$PASTE_RETRY_DELAY"
    done

    return 1
}

type_text_fallback() {
    local text="$1"

    if command -v wtype >/dev/null 2>&1; then
        if wtype "$text" 2>/dev/null; then
            return 0
        fi
    fi

    if command -v ydotool >/dev/null 2>&1; then
        if ydotool type -- "$text" 2>/dev/null; then
            return 0
        fi
    fi

    return 1
}

is_gnome_text_editor_focused() {
    [[ "${XDG_CURRENT_DESKTOP:-}" == *"GNOME"* ]] || return 1
    command -v gdbus >/dev/null 2>&1 || return 1

    local out
    if ! out=$(gdbus call --session \
        --dest org.gnome.Shell \
        --object-path /org/gnome/Shell \
        --method org.gnome.Shell.Eval \
        '(() => { const w = global.display.get_focus_window(); return w ? w.get_wm_class() : ""; })()' \
        2>/dev/null); then
        return 1
    fi

    [[ "$out" == *"org.gnome.TextEditor"* ]]
}

insert_text() {
    local text="$1"

    echo -n "$text" | wl-copy 200>&-
    sleep "$PASTE_INITIAL_DELAY"

    if is_gnome_text_editor_focused; then
        if type_text_fallback "$text"; then
            return 0
        fi
    fi

    if paste_clipboard_with_fallback; then
        return 0
    fi

    if type_text_fallback "$text"; then
        return 0
    fi

    notify_error "Auto-insert failed. Text was copied to clipboard. Press Ctrl+V to paste."
    return 1
}

start_recording() {
    if is_recording; then
        echo "Already recording..." >&2
        set_state "recording"
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
        notify_error "Failed to start recording."
        set_state "idle"
        return 1
    fi

    set_state "recording"
    echo "Recording started (PID: $(cat "$PID_FILE"))"
}

stop_recording() {
    if ! is_recording; then
        notify_error "Not currently recording."
        set_state "idle"
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
        notify_error "No audio recorded."
        set_state "idle"
        return 1
    fi

    set_state "transcribing"

    # Transcribe with Groq API
    local text
    if ! text=$(transcribe_audio); then
        rm -f "$AUDIO_FILE"
        set_state "idle"
        return 1
    fi

    # Clean up audio file
    rm -f "$AUDIO_FILE"

    if [[ -z "$text" ]]; then
        notify_error "No speech detected."
        set_state "idle"
        return 1
    fi

    echo "Transcribed: $text"
    insert_text "$text" || true
    set_state "idle"
}

toggle() {
    if is_recording; then
        stop_recording
    else
        start_recording
    fi
}

with_lock() {
    exec 200>"$LOCK_FILE"
    flock -n 200 || {
        echo "Previous dictation action is still finishing." >&2
        echo "Another instance is running" >&2
        exit 1
    }

    "$@"
}

show_status() {
    if is_recording; then
        echo "Recording (PID: $(cat "$PID_FILE"))"
        return 0
    fi

    if [[ ! -f "$STATE_FILE" ]]; then
        set_state "idle"
        echo "Idle"
        return 0
    fi

    if [[ "$(cat "$STATE_FILE" 2>/dev/null || echo "idle")" == "transcribing" ]]; then
        echo "Transcribing"
        return 0
    fi

    echo "Idle"
}

# --- Main ---------------------------------------------------------------------

case "${1:-toggle}" in
    start)          with_lock start_recording ;;
    stop)           with_lock stop_recording ;;
    toggle)         with_lock toggle ;;
    status)         show_status ;;
    *)
        echo "Usage: $(basename "$0") {toggle|start|stop|status}"
        echo ""
        echo "Environment variables:"
        echo "  WHISPER_NOTIFY_ON_ERROR=1|0"
        echo "  WHISPER_ERROR_NOTIFY_TIMEOUT=<milliseconds>"
        echo "  WHISPER_PASTE_INITIAL_DELAY=<seconds>"
        echo "  WHISPER_PASTE_RETRY_DELAY=<seconds>"
        echo "  WHISPER_PASTE_ATTEMPTS=<count>"
        echo "  WHISPER_STATE_FILE=<path>"
        echo ""
        echo "  toggle          Start or stop recording (default, bind to hotkey)"
        echo "  start           Start recording"
        echo "  stop            Stop and transcribe"
        echo "  status          Show current state"
        exit 1
        ;;
esac
