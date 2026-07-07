#!/usr/bin/env bash
# publish_models.sh — upload converted Hinglish GGML models to your Hugging Face
# repo so the app's in-app downloads work for users (LAUNCH.md step 3).
#
# One-time prereqs:
#   cd spike && uv run hf auth login     # paste a WRITE token from hf.co/settings/tokens
#
# Usage: ./scripts/publish_models.sh [hf-repo]   (default: samarthsaraswat/desi-dictation-models)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${1:-samarthsaraswat/desi-dictation-models}"

cd "$ROOT/spike"
uv run hf repo create "$REPO" --type model -y 2>/dev/null || true

# Explicit publish list — quantized/production files only (no f16/f32 originals)
FILES=(
  "ggml-hinglish-swift.bin"
  "ggml-hinglish-apex-q5_0.bin"
  "ggml-vaani-hindi-q5_0.bin"
)
for name in "${FILES[@]}"; do
  file="$ROOT/models/$name"
  [ -f "$file" ] || { echo "skip (not converted): $name"; continue; }
  echo "==> Uploading $name to $REPO"
  uv run hf upload "$REPO" "$file" "$name"
done

echo "==> Done. Update the README of https://huggingface.co/$REPO to credit:"
echo "    Oriserve/Whisper-Hindi2Hinglish (Apache 2.0) — converted to GGML for whisper.cpp"
echo "    If your HF username differs, keep ModelManager.hinglishRepoBase in sync."
