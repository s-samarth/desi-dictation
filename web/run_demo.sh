#!/usr/bin/env bash
# run_demo.sh — start the whole demo on this machine.
#   whisper-server :8081 (Apex — English + Hinglish, model stays resident)
#   whisper-server :8082 (Vaani — हिन्दी, only if the model exists)
#   FastAPI        :8080 (the site + API gateway)
#
# Local use:   http://localhost:8080
# Share a link (public HTTPS — browsers require HTTPS for mic access):
#   brew install cloudflared
#   cloudflared tunnel --url http://localhost:8080
#   → gives you a https://….trycloudflare.com URL to send to anyone.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEB="$ROOT/web"
SERVER="$ROOT/vendor/whisper.cpp/build/bin/whisper-server"
MODELS="$HOME/Library/Application Support/DesiDictation/models"
VAD="$MODELS/ggml-silero-vad.bin"

PIDS=()
cleanup() { echo; echo "==> stopping"; kill "${PIDS[@]}" 2>/dev/null || true; }
trap cleanup EXIT

# A previous run that wasn't cleanly stopped leaves whisper-servers holding the
# ports; duplicates then pile up (each loads the model, all fight for CPU) and
# transcription crawls. Clear the ports before starting.
for port in 8080 8081 8082; do
  lsof -ti tcp:"$port" 2>/dev/null | xargs kill 2>/dev/null || true
done
sleep 1

VAD_FLAGS=()
[ -f "$VAD" ] && VAD_FLAGS=(--vad --vad-model "$VAD")

echo "==> ASR :8081 (Apex — English/Hinglish)"
"$SERVER" -m "$MODELS/ggml-hinglish-apex-q5_0.bin" --port 8081 --host 127.0.0.1 \
  -t 6 "${VAD_FLAGS[@]}" >/tmp/desi-asr-en.log 2>&1 &
PIDS+=($!)

if [ -f "$MODELS/ggml-vaani-hindi-q5_0.bin" ]; then
  echo "==> ASR :8082 (Vaani — हिन्दी)"
  "$SERVER" -m "$MODELS/ggml-vaani-hindi-q5_0.bin" --port 8082 --host 127.0.0.1 \
    -t 4 "${VAD_FLAGS[@]}" >/tmp/desi-asr-hi.log 2>&1 &
  PIDS+=($!)
else
  echo "==> हिन्दी model not installed — Hindi pill will be disabled"
fi

sleep 2
echo "==> Web :8080"
echo
echo "   Local:   http://localhost:8080"
echo "   Public:  cloudflared tunnel --url http://localhost:8080"
echo
cd "$WEB" && exec .venv/bin/uvicorn server:app --host 0.0.0.0 --port 8080
