#!/usr/bin/env bash
# setup_demo.sh — one-time setup for the web demo (macOS host).
# Builds whisper-server from the vendored whisper.cpp, creates the Python
# env (uv), and checks every runtime piece, telling you exactly what's missing.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEB="$ROOT/web"
MODELS="$HOME/Library/Application Support/DesiDictation/models"

echo "==> 1/4 whisper-server (vendored whisper.cpp HTTP server)"
if [ ! -x "$ROOT/vendor/whisper.cpp/build/bin/whisper-server" ]; then
  cmake --build "$ROOT/vendor/whisper.cpp/build" --target whisper-server -j 8
fi
echo "    ok: $ROOT/vendor/whisper.cpp/build/bin/whisper-server"

echo "==> 2/4 Python env (uv)"
cd "$WEB"
uv venv --quiet 2>/dev/null || true
uv pip install --quiet fastapi "uvicorn[standard]" httpx python-multipart
echo "    ok: $WEB/.venv"

echo "==> 3/4 Models"
[ -f "$MODELS/ggml-hinglish-apex-q5_0.bin" ] \
  && echo "    ok: Apex (English + Hinglish)" \
  || echo "    MISSING: $MODELS/ggml-hinglish-apex-q5_0.bin — download via the Mac app's Models tab"
[ -f "$MODELS/ggml-vaani-hindi-q5_0.bin" ] \
  && echo "    ok: Vaani (हिन्दी)" \
  || echo "    note: Vaani missing — the हिन्दी pill will be disabled (demo still works)"

echo "==> 4/4 Runtime deps"
command -v ffmpeg >/dev/null && echo "    ok: ffmpeg" || echo "    MISSING: ffmpeg → brew install ffmpeg"
curl -s --max-time 2 http://127.0.0.1:11434/api/tags >/dev/null \
  && echo "    ok: Ollama (AI actions enabled)" \
  || echo "    note: Ollama not running — demo works, AI chips will be disabled"

echo
echo "Setup done. Run:  ./web/run_demo.sh"
