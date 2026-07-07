#!/usr/bin/env bash
# convert_model.sh — HF Hinglish Whisper fine-tune -> GGML for whisper.cpp.
#
# Usage: ./scripts/convert_model.sh <swift|prime|apex>
# Steps: download via spike env -> convert-h5-to-ggml.py -> models/ggml-hinglish-<name>.bin
#        (0.8B models also get a q5_0 quant: ~570MB, near-lossless for dictation)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="${1:?usage: convert_model.sh <swift|prime|apex>}"
MODELS_DIR="$ROOT/models"
mkdir -p "$MODELS_DIR"

echo "==> Ensuring model '$NAME' is downloaded"
HF_DIR="$(cd "$ROOT/spike" && uv run python -c "
from download_models import download
print(download('$NAME'))
" | tail -1)"
echo "==> HF snapshot: $HF_DIR"

echo "==> Converting to GGML (f16)"
OUT_TMP="$MODELS_DIR/.convert-$NAME"
mkdir -p "$OUT_TMP"
(cd "$ROOT/spike" && uv run python \
  "$ROOT/vendor/whisper.cpp/models/convert-h5-to-ggml.py" \
  "$HF_DIR" "$ROOT/vendor/openai-whisper" "$OUT_TMP")

FINAL="$MODELS_DIR/ggml-hinglish-$NAME.bin"
mv "$OUT_TMP"/ggml-model.bin "$FINAL"
rm -rf "$OUT_TMP"
echo "==> Wrote $FINAL ($(du -h "$FINAL" | cut -f1))"

# Quantize the large models so they fit 8GB MacBook Airs comfortably
if [ "$NAME" != "swift" ]; then
  QUANT="$MODELS_DIR/ggml-hinglish-$NAME-q5_0.bin"
  "$ROOT/vendor/whisper.cpp/build/bin/whisper-quantize" "$FINAL" "$QUANT" q5_0
  echo "==> Wrote $QUANT ($(du -h "$QUANT" | cut -f1))"
fi
