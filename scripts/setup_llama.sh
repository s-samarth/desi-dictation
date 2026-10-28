#!/usr/bin/env bash
# setup_llama.sh — build llama.cpp + our tiny scorer (native/desi_lm) as ONE
# static archive for the "When it fits" context checker (CONTEXT_FIT.md).
#
# Same shape as setup_transcribe.sh, for the same reason: llama.cpp vendors
# its own ggml, newer than whisper.cpp's. We pre-link libllama + its ggml +
# desi_lm.o into one relocatable object with `ld -r -exported_symbols_list`,
# so only `desi_lm_*` stays global and every llama/ggml symbol is private.
# The ggml-metal ObjC class is renamed (whisper.cpp and transcribe.cpp each
# define their own). Metal shaders are embedded (no Xcode needed).
#
# Package.swift links the result only if it exists, so CI stays green until
# this has been run once on a Mac and app/Libraries/libllama-bundle.a is
# committed (as the whisper and transcribe archives are).
#
# Usage: ./scripts/setup_llama.sh
# Produces:
#   app/Libraries/libllama-bundle.a   (merged, llama + ggml hidden)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor/llama.cpp"
# Pinned: the tag desi_lm.cpp was written and syntax-checked against.
TAG="b11900"

if [ ! -d "$VENDOR" ]; then
  echo "==> Cloning llama.cpp @ $TAG"
  git clone --depth 1 --branch "$TAG" https://github.com/ggml-org/llama.cpp "$VENDOR"
fi
git -C "$VENDOR" fetch -q --depth 1 origin tag "$TAG" 2>/dev/null || true
git -C "$VENDOR" -c advice.detachedHead=false checkout -q "$TAG"

echo "==> Configuring (static, Metal embedded, no BLAS, renamed ObjC class)"
cmake -S "$VENDOR" -B "$VENDOR/build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DBUILD_SHARED_LIBS=OFF \
  -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_TOOLS=OFF \
  -DLLAMA_BUILD_SERVER=OFF -DLLAMA_BUILD_COMMON=OFF -DLLAMA_CURL=OFF \
  -DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON -DGGML_BLAS=OFF \
  -DCMAKE_C_FLAGS="-fno-common" \
  -DCMAKE_OBJC_FLAGS="-DGGMLMetalClass=LlamaGGMLMetalClass"

echo "==> Building libllama"
cmake --build "$VENDOR/build" --config Release -j "$(sysctl -n hw.ncpu)" --target llama

echo "==> Compiling desi_lm.cpp"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
clang++ -std=c++17 -O2 -arch arm64 -mmacosx-version-min=14.0 -fno-common \
  -I "$ROOT/app/Sources/CLlamaScore/include" -I "$VENDOR/include" -I "$VENDOR/ggml/include" \
  -c "$ROOT/native/desi_lm/desi_lm.cpp" -o "$WORK/desi_lm.o"

echo "==> Pre-linking into one object (only desi_lm_* stays global)"
FORCE=()
for a in src/libllama.a ggml/src/libggml.a ggml/src/libggml-base.a \
         ggml/src/libggml-cpu.a ggml/src/ggml-metal/libggml-metal.a; do
  if [ ! -f "$VENDOR/build/$a" ]; then
    echo "missing $VENDOR/build/$a (llama.cpp layout changed?)" >&2
    exit 1
  fi
  FORCE+=(-force_load "$VENDOR/build/$a")
done
echo "_desi_lm_*" > "$WORK/exports.txt"
ld -r -arch arm64 -platform_version macos 14.0 14.0 \
  -exported_symbols_list "$WORK/exports.txt" \
  -o "$WORK/llama-merged.o" "$WORK/desi_lm.o" "${FORCE[@]}"

APP="$ROOT/app"
mkdir -p "$APP/Libraries"
rm -f "$APP/Libraries/libllama-bundle.a"
ar rcs "$APP/Libraries/libllama-bundle.a" "$WORK/llama-merged.o"

echo "==> Leaked llama/ggml symbols (must be empty):"
nm -gU "$APP/Libraries/libllama-bundle.a" | grep -E " _llama_| _ggml_| _gguf_" || echo "   none"
echo "==> Exported:"
nm -gU "$APP/Libraries/libllama-bundle.a" | grep " _desi_lm_"
ls -la "$APP/Libraries/libllama-bundle.a"
echo "Next: (cd app && swift build) — Package.swift now links it and defines DESI_LLAMA."
