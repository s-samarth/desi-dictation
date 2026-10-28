#!/usr/bin/env bash
# setup_transcribe.sh — build transcribe.cpp (Qwen3-ASR runtime) as ONE static
# archive that can sit next to whisper.cpp's ggml without clashing.
#
# Why this shape: transcribe.cpp vendors its own, much newer ggml (0.26 vs
# whisper.cpp's 0.15). Linking both archives as-is would give duplicate ggml_*
# symbols with different ABIs. So we pre-link libtranscribe + its ggml into a
# single relocatable object with `ld -r -exported_symbols_list`, which keeps
# only the public `transcribe_*` C API global and makes every ggml symbol
# private to that object. Its ggml-metal ObjC class is renamed at compile time
# (both copies define GGMLMetalClass). Metal shaders are embedded (no Xcode).
#
# Usage: ./scripts/setup_transcribe.sh
# Produces:
#   app/Libraries/libtranscribe-bundle.a        (merged, ggml hidden)
#   app/Sources/CTranscribe/include/*.h          (public C headers)
#   vendor/transcribe.cpp/build/bin/transcribe-cli (for spikes and benchmarks)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor/transcribe.cpp"
# Pinned: the commit the 2026-10-28 English A/B was planned against.
COMMIT="5700f12"

if [ ! -d "$VENDOR" ]; then
  echo "==> Cloning transcribe.cpp @ $COMMIT"
  git clone https://github.com/handy-computer/transcribe.cpp "$VENDOR"
fi
git -C "$VENDOR" -c advice.detachedHead=false checkout -q "$COMMIT"

echo "==> Configuring (static, Metal embedded, Accelerate, renamed ObjC class)"
cmake -S "$VENDOR" -B "$VENDOR/build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
  -DTRANSCRIBE_BUILD_SHARED=OFF \
  -DTRANSCRIBE_BUILD_TESTS=OFF \
  -DTRANSCRIBE_BUILD_EXAMPLES=ON \
  -DTRANSCRIBE_METAL=ON \
  -DGGML_METAL_EMBED_LIBRARY=ON \
  -DCMAKE_C_FLAGS="-fno-common" \
  -DCMAKE_OBJC_FLAGS="-DGGMLMetalClass=TranscribeGGMLMetalClass"

echo "==> Building libtranscribe + transcribe-cli"
cmake --build "$VENDOR/build" --config Release -j "$(sysctl -n hw.ncpu)" \
  --target transcribe transcribe-cli

echo "==> Pre-linking into one object (only transcribe_* stays global)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FORCE=()
for a in src/libtranscribe.a ggml/src/libggml.a ggml/src/libggml-base.a \
         ggml/src/libggml-cpu.a ggml/src/ggml-metal/libggml-metal.a; do
  FORCE+=(-force_load "$VENDOR/build/$a")
done
echo "_transcribe_*" > "$WORK/exports.txt"
# (-fno-common above makes ggml's tentative tables, e.g. ggml_table_f32_f16,
# real definitions — "common" symbols would escape the export list and merge
# with whisper.cpp's copies.)
ld -r -arch arm64 -platform_version macos 14.0 14.0 \
  -exported_symbols_list "$WORK/exports.txt" \
  -o "$WORK/transcribe-merged.o" "${FORCE[@]}"

APP="$ROOT/app"
mkdir -p "$APP/Libraries" "$APP/Sources/CTranscribe/include"
rm -f "$APP/Libraries/libtranscribe-bundle.a"
ar rcs "$APP/Libraries/libtranscribe-bundle.a" "$WORK/transcribe-merged.o"
cp "$VENDOR/include/transcribe.h" "$APP/Sources/CTranscribe/include/"
if [ -d "$VENDOR/include/transcribe" ]; then
  mkdir -p "$APP/Sources/CTranscribe/include/transcribe"
  cp "$VENDOR"/include/transcribe/*.h "$APP/Sources/CTranscribe/include/transcribe/"
fi

echo "==> Leaked ggml symbols (must be empty):"
nm -gU "$APP/Libraries/libtranscribe-bundle.a" | grep -E " _ggml_| _gguf_" || echo "   none"
ls -la "$APP/Libraries/libtranscribe-bundle.a"
