#!/usr/bin/env bash
# =============================================================================
# download-model.sh - Download whisper.cpp models
# =============================================================================

set -euo pipefail

MODEL_DIR="$HOME/.local/share/whisper-dictate"
BASE_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main"

mkdir -p "$MODEL_DIR"

echo "Available models (sorted by speed → quality):"
echo ""
echo "  tiny      -  ~75 MB  - Fastest, lowest quality"
echo "  base      - ~142 MB  - Fast, decent quality"
echo "  small     - ~466 MB  - Good balance"
echo "  medium    - ~1.5 GB  - High quality"
echo "  large-v3-turbo - ~1.6 GB  - Best speed/quality ratio (RECOMMENDED)"
echo "  large-v3  - ~3.1 GB  - Best quality, slowest"
echo ""

MODEL="${1:-large-v3-turbo}"

case "$MODEL" in
    tiny)               FILE="ggml-tiny.bin" ;;
    base)               FILE="ggml-base.bin" ;;
    small)              FILE="ggml-small.bin" ;;
    medium)             FILE="ggml-medium.bin" ;;
    large-v3-turbo)     FILE="ggml-large-v3-turbo.bin" ;;
    large-v3)           FILE="ggml-large-v3.bin" ;;
    *)
        echo "Unknown model: $MODEL"
        exit 1
        ;;
esac

DEST="$MODEL_DIR/$FILE"

if [[ -f "$DEST" ]]; then
    echo "Model already exists: $DEST"
    exit 0
fi

echo "Downloading $FILE to $MODEL_DIR ..."
curl -L --progress-bar "$BASE_URL/$FILE" -o "$DEST"

echo ""
echo "✅ Model downloaded: $DEST"
echo ""
echo "Set this in your environment or configuration.nix:"
echo "  WHISPER_MODEL=$DEST"
