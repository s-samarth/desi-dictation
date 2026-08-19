#!/usr/bin/env bash
# setup_whisper.sh — clone + build whisper.cpp as static libs for Desi Dictation.
#
# Why this exists: whisper.cpp removed its Swift package, and this machine has no
# full Xcode (Command Line Tools only), so:
#   - we build static libs with cmake and link them into SwiftPM manually
#   - GGML_METAL_EMBED_LIBRARY=ON JIT-compiles Metal shaders at runtime,
#     avoiding the Xcode-only build-time `xcrun metal` compiler.
#
# Usage: ./scripts/setup_whisper.sh
# Produces:
#   vendor/whisper.cpp/build/src/libwhisper.a (+ ggml static libs)
#   vendor/whisper.cpp/build/bin/whisper-cli  (for benchmarking/spike)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor/whisper.cpp"

if [ ! -d "$VENDOR" ]; then
  echo "==> Cloning whisper.cpp (shallow)"
  git clone --depth 1 https://github.com/ggml-org/whisper.cpp "$VENDOR"
fi

echo "==> Configuring (static, Metal embedded, Accelerate)"
cmake -S "$VENDOR" -B "$VENDOR/build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DGGML_METAL=ON \
  -DGGML_METAL_EMBED_LIBRARY=ON \
  -DGGML_ACCELERATE=ON \
  -DWHISPER_BUILD_TESTS=OFF \
  -DWHISPER_BUILD_EXAMPLES=ON

echo "==> Building libwhisper + whisper-cli"
cmake --build "$VENDOR/build" --config Release -j "$(sysctl -n hw.ncpu)" \
  --target whisper whisper-cli

# Parakeet (NVIDIA FastConformer-TDT) is a SEPARATE ggml model runtime that
# ships inside whisper.cpp — its own static lib over the same ggml backends, so
# there is no duplicate-symbol problem. English mode runs on it (measured 5x
# faster than large-v3-turbo at equal accuracy: docs/MODEL_RESEARCH.md).
echo "==> Building libparakeet + parakeet-cli"
cmake --build "$VENDOR/build" --config Release -j "$(sysctl -n hw.ncpu)" \
  --target parakeet parakeet-cli

echo "==> Building whisper-quantize (for 0.8B model q5_0 quants)"
cmake --build "$VENDOR/build" --config Release -j "$(sysctl -n hw.ncpu)" \
  --target whisper-quantize

echo "==> Staging headers + static libs into the Swift package"
APP="$ROOT/app"
mkdir -p "$APP/Libraries" "$APP/Sources/CWhisper/include"
cp "$VENDOR/include/whisper.h" "$APP/Sources/CWhisper/include/"
cp "$VENDOR/include/parakeet.h" "$APP/Sources/CWhisper/include/"
cp "$VENDOR"/ggml/include/*.h "$APP/Sources/CWhisper/include/"
find "$VENDOR/build" -name "*.a" -not -name "libcommon.a" \
  -exec cp {} "$APP/Libraries/" \;

echo "==> Artifacts:"
ls "$APP/Libraries"
find "$VENDOR/build/bin" -type f | sed "s|$ROOT/||"
