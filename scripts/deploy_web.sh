#!/usr/bin/env bash
# deploy_web.sh — push the web demo to a server and restart it.
#
#   ./scripts/deploy_web.sh ubuntu@your-ec2-host
#
# Assumes the host was set up once per web/README.md ("Moving to AWS"):
# whisper.cpp built, models copied, Ollama running, and a `desi-web` systemd
# unit wrapping run_demo.sh. Idempotent — run it on every change (CI runs it
# automatically once DEPLOY_ENABLED/secrets are configured).
set -euo pipefail
HOST="${1:?usage: deploy_web.sh user@host}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> rsync web/ → $HOST"
rsync -az --delete \
  --exclude ".venv" --exclude "__pycache__" \
  "$ROOT/web/" "$HOST:~/desi-dictation/web/"

echo "==> refresh deps + restart"
ssh "$HOST" '
  cd ~/desi-dictation/web
  command -v uv >/dev/null || pip install --user uv
  uv venv --quiet 2>/dev/null || true
  uv pip install --quiet fastapi "uvicorn[standard]" httpx python-multipart
  python3 test_web.py
  sudo systemctl restart desi-web 2>/dev/null || echo "note: no desi-web unit — start manually (web/README.md)"
'
echo "==> deployed."
