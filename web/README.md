# Desi Dictation — web demo

A shareable, zero-install demo: open a link, tap the mic, speak Hinglish —
the transcript **types out into an editable text box** (repeat dictations
append; edits flow into the AI actions → English ✨ / → हिन्दी / 🧠 Organize).
**Fully separate from the Mac app** (`app/` is untouched); it reuses only the
model files on disk and the vendored whisper.cpp.

## Architecture (three boring processes)

```
browser mic (MediaRecorder, webm/opus or mp4)
   └► FastAPI :8080  (server.py — static site + gateway, rate-limited)
        ├► ffmpeg → 16 kHz wav → whisper-server :8081 (Apex — English/Hinglish)
        │                        whisper-server :8082 (Vaani — हिन्दी, optional)
        └► Ollama :11434 (gemma3:4b — same prompts + Hindi-number prepass
                          as the app, ported in prompts.py / hindi_numbers.py)
```

Audio lives in a temp dir for one request and is deleted. No accounts, no
storage, 30 requests / 5 min / IP, 60 s / 12 MB per clip.

## Run it on this laptop

```bash
./web/setup_demo.sh     # one-time: builds whisper-server, uv env, checks deps
./web/run_demo.sh       # starts everything → http://localhost:8080
```

## Share a public link (today, free)

Browsers only allow microphone access over **HTTPS** (localhost is exempt) —
so a plain `http://<your-ip>` link will never work for others. The zero-setup
answer is a Cloudflare quick tunnel:

```bash
brew install cloudflared
cloudflared tunnel --url http://localhost:8080
# → prints https://<random>.trycloudflare.com — send that link to anyone.
```

Laptop must stay awake (`caffeinate -s`) while the link is live. For a stable
URL tied to your own domain, create a named tunnel in the Cloudflare dashboard
(free) instead of the quick tunnel.

## Moving to AWS (when the laptop isn't enough)

**When:** you want 24/7 uptime, or >~5 concurrent users (one M3 handles a demo
crowd fine — ASR is 3–15× realtime — but the LLM serializes).

> Never used AWS? [docs/DEPLOYMENT.md](../docs/DEPLOYMENT.md) walks the whole
> thing from account creation (MFA, billing alarm, the GPU-quota trap, key
> pair, security group, Elastic IP, DNS on your domain) to systemd + Caddy.
> The steps below are the condensed on-server version.

| Instance | Specs | ~$/mo on-demand | Fit |
|---|---|---|---|
| c7g.xlarge | 4 vCPU Graviton, 8 GB | ~$105 | ASR-only demo (drop AI chips) |
| c7g.2xlarge | 8 vCPU Graviton, 16 GB | ~$210 | Everything on CPU; AI actions take 10–20 s |
| **g4dn.xlarge** | 4 vCPU, 16 GB, T4 16 GB | ~$385 (spot ~$115) | **Recommended**: ASR + LLM both fast |
| g6.xlarge | 4 vCPU, 16 GB, L4 24 GB | ~$565 | Overkill for a demo; right for the real cloud product (docs/cloud/) |

Steps (Ubuntu 24.04 on g4dn.xlarge, ap-south-1 Mumbai for Indian visitors):

```bash
# 1. deps
sudo apt update && sudo apt install -y build-essential cmake ffmpeg git python3-venv
curl -fsSL https://ollama.com/install.sh | sh          # installs GPU-aware Ollama
ollama pull gemma3:4b
# 2. whisper.cpp with CUDA
git clone https://github.com/ggml-org/whisper.cpp && cd whisper.cpp
cmake -B build -DGGML_CUDA=1 && cmake --build build --target whisper-server -j
# 3. this demo + models (scp from your Mac; HF once models are published)
scp -r you@laptop:~/Codebases/desi-dictation/web .
scp "you@laptop:~/Library/Application Support/DesiDictation/models/*.bin" ./models/
# 4. edit web/run_demo.sh paths (MODELS=…/models, SERVER=…/whisper.cpp/build/bin)
# 5. HTTPS without certificates: same cloudflared tunnel, or Caddy + a domain:
sudo apt install -y caddy   # Caddyfile: "demo.yourdomain.in { reverse_proxy :8080 }"
# 6. keep it alive
sudo systemctl enable --now ollama
# wrap run_demo.sh in a systemd unit (After=network.target ollama.service)
```

Cost control for a demo: stop the instance when idle (`aws ec2 stop-instances`),
or use spot + a start/stop schedule. Don't leave a $385/mo box idling for a
demo nobody's clicking at 3 am — the laptop + tunnel covers launch week.
The production-grade path (serverless GPU, our own endpoint, quotas) is a
different beast and already designed in [docs/cloud/](../docs/cloud/README.md).

## What was verified (2026-07-14, this machine)

- `/api/health`, `/api/transcribe` (wav AND browser webm/opus — accurate
  Roman-Hinglish vs. eval reference, 1.6–2.3 s for a short clip),
  `/api/refine` (₹2,50,000 prepass ✓)
- Full UI flow in a real browser: pills → blob through the exact `onstop`
  code path → transcript types into the editable box → "→ English ✨" chip →
  correct translation card. Mic *capture* itself needs a human + mic
  permission — untested headlessly.
- Known past failures worth reading before touching this code:
  BUILD_LOG FM#18 (the stuck-"transcribing…" recorder-null bug) and FM#19
  (duplicate whisper-servers from repeated run_demo.sh launches).
