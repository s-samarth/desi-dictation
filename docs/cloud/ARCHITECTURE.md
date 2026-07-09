# Cloud Architecture — the endpoint, explained from zero

You said *"I think it's going to be an endpoint but I don't know how"* — so this doc
starts at the bottom and builds up. (You've called endpoints a thousand times from
LangGraph agents; now you're on the other side of the counter.)

## What "an endpoint" means here

An **endpoint** is just a URL your app can send data to and get an answer back —
a function call over the internet. Ours:

```
POST https://api.desidictation.com/v1/transcribe
```

The app POSTs an audio file; a server we run receives it, runs the model on a GPU,
and replies with JSON containing the text. That's the whole idea. Everything else
in this folder is about making that one round-trip fast, cheap, private, and
alive when 10,000 people use it at once.

## The request/response contract (API design)

```
POST /v1/transcribe
Headers:
  Authorization: Bearer <license-key>        ← Gumroad license = the auth token
  Content-Type: audio/ogg                    ← Opus-compressed (see "why Opus")
Body: the audio bytes (max 60s / 2 MB)

200 OK
{
  "text": "kal meeting hai, please deck ready rakhna",
  "duration_s": 7.4,
  "model": "apex-fp16-v1",
  "processing_ms": 610
}

Errors (all JSON): 401 bad/expired license · 402 quota exhausted (body says
remaining=0, resets_at) · 413 too long · 429 slow down (Retry-After) · 503 warming
up, retry in N seconds (serverless cold start, see INFRA)
```

Design rules:
- **Stateless.** Every request carries everything needed. No sessions, no server
  memory of the user → any server can answer any request → scaling is trivial.
- **One utterance = one request.** Matches hold-to-talk exactly; no chunk-stitching
  protocol, no websockets in v1.
- **Version prefix (`/v1/`)** so we can change the contract later without breaking
  shipped apps.
- **Why Opus, not WAV:** 10s of 16 kHz WAV ≈ 320 KB; Opus ≈ 40 KB. On Indian mobile
  data, 8× smaller upload is most of the perceived latency. Every platform has an
  Opus encoder (macOS/iOS: `AVAudioConverter`; Android: `MediaCodec`).

## The full journey of one utterance

```
[App] hold hotkey → record 16kHz → release
  → encode Opus (~50ms)
  → POST over TLS ────────────────► [Load balancer / API gateway]
                                       → auth check (license key, quota counter)
                                       → [GPU worker] decode Opus → mel →
                                         faster-whisper (Apex, fp16) → text
                                       → audio buffer dropped (RAM only, never disk)
  ◄──────────────────────────────── JSON { text }
  → replacement dictionary (STAYS CLIENT-SIDE — personal data never uploads)
  → paste into focused app
```

Latency budget (Mumbai region, Indian user): upload 40 KB ~150–400 ms + inference
~300–800 ms (turbo-class at 30× realtime) + return ~50 ms ≈ **0.5–1.3 s** — on par
with or faster than local Apex on a mid Mac, dramatically faster than a 4 GB phone.

## Server stack (what actually runs on the GPU box)

One container image, used in every phase (serverless AND own-instance):

```
┌─ Docker image ──────────────────────────────┐
│ FastAPI (Python) — /v1/transcribe, /healthz │  ← your home turf
│ faster-whisper (CTranslate2 backend)        │  ← Apex converted to CT2 fp16/int8
│   batching: groups concurrent requests      │
│ Silero VAD — trim silence before decode     │
└─────────────────────────────────────────────┘
```

- **faster-whisper, not whisper.cpp, on the server:** CTranslate2 is the standard
  GPU-serving path for Whisper fine-tunes (HF → CT2 conversion is one command:
  `ct2-transformers-converter --model Oriserve/Whisper-Hindi2Hinglish-Apex ...`),
  and it does dynamic batching — many users share one GPU efficiently. whisper.cpp
  stays the *client* engine; the model weights are the shared asset.
- Decode params must mirror the app's (same language/task/temperature settings as
  `WhisperEngine`) so cloud and local output the same conventions — one eval suite
  ([evals/](../../evals/)) runs against both.

## Auth + quota (how "providing it to people" works)

1. User buys Pro → gets a Gumroad license key → pastes it in the app (already built
   for Pro gating).
2. App sends the key as the Bearer token. The gateway checks it two ways:
   - **Validity:** verify with Gumroad's API once, then cache (key → valid-until) in
     Redis/SQLite so we don't call Gumroad per request.
   - **Quota:** a counter per key (minutes used this month). Free taste = 30 min/mo,
     Pro = fair-use cap (e.g. 600 min/mo) to stop abuse/resale of our GPU time.
3. No accounts, no passwords, no email database — the license key IS the identity.
   This keeps us out of the personal-data business on the server too.

## Privacy engineering (the part we must be able to prove)

- TLS 1.3 only; HSTS.
- Audio handled as an in-memory buffer end-to-end; the worker has **no disk writes**
  in the request path (enforce: read-only container filesystem except /tmp-less).
- Access logs: timestamp, key-hash, audio seconds, latency, status. **Never the
  audio, never the text.** Log config is public in the repo.
- No third-party analytics on the API host. Uptime monitoring pings /healthz only.
- Publish a plain-language "Cloud mode privacy" page + this doc. Auditable claims
  beat adjectives (same philosophy as [SECURITY_AUDIT.md](../SECURITY_AUDIT.md)).

## App-side changes (small, deliberately)

- `TranscriptionEngine` protocol already abstracts the engine; add a
  `CloudEngine` implementation (POST + retry + 503-warmup handling) next to
  `WhisperEngine`. Model picker gets the "Desi Cloud ⚡" row with the consent
  sheet on first selection.
- Offline fallback: if the request fails, auto-fall-back to the best installed
  local model and toast "No internet — used local model."
- Timeout discipline: 10 s hard timeout; hold-to-talk UX must never hang.

## Later (explicitly v2+, don't build now)

- **Streaming** (text appears while speaking): websocket + chunked decode — real
  engineering, 3–5× the GPU cost per minute. Only if users demand it.
- **Developer API**: same endpoint + API-key issuance + docs page + billing. The
  contract above is already shaped for it.
- **LLM post-processing in cloud** (structure/translate for low-end devices): same
  pattern, second endpoint, small LLM on the same GPU.
