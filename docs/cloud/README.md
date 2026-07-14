# Cloud Transcription — strategy (opt-in, never default)

**Status: plan only, nothing built. Written 2026-07-09.**

| Doc | What |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | What "an endpoint" actually is, the API design, app integration, no-retention design |
| [INFRA_AND_SCALING.md](INFRA_AND_SCALING.md) | Phase-wise infra: API-proxy → serverless GPU → own instances; scaling math |
| [COSTS.md](COSTS.md) | Unit economics — cost per user per month, scenarios at 100 / 1k / 10k users |
| [SERVING_STACK.md](SERVING_STACK.md) | Production serving decisions — faster-whisper vs whisper.cpp, when vLLM earns its place, what's overkill |

## Why cloud at all

1. **The device floor is real.** India's entry phones ship 3–4 GB RAM, old office
   laptops can't run Apex comfortably, and RAM prices are inflating budget-phone
   specs *downward*. Cloud mode turns "sorry, your phone can't" into "your phone
   streams it" — it makes the [platforms/](../platforms/README.md) floor tier a
   first-class citizen instead of a degraded one.
2. **Quality ceiling.** A server can run the *full-precision* Apex (or our future
   fine-tune) — better output than q5_0, no thermal limits.
3. **It's a choice users expect.** superwhisper offers both; Wispr is cloud-only.
   Offering both makes "local" a *feature you chose*, not a limitation you're stuck with.

## The one non-negotiable: our privacy brand survives this

- **Local stays the default, forever.** Cloud is opt-in with a plain-words consent
  screen: *"This sends your voice to our server over an encrypted connection, we
  transcribe it, send text back, and delete the audio immediately. We keep nothing.
  Prefer nothing leaves your device? Stay on local — it's the default."*
- **No retention, by architecture:** audio processed in memory, never written to
  disk, no transcript logging, request logs keep only timing/size metadata.
  This must be *true* and *documented publicly* — it's also our DPDP Act (India)
  posture: we are not a data fiduciary for voice content if we never store it.
- Marketing framing: "**Private by default. Cloud when *you* choose.**" — this is a
  strength (user agency), not a contradiction, as long as the default never moves.

## The strategic catch that decides the build

Cheap hosted STT APIs (Groq at ~$0.04/audio-hour, Fireworks ~$0.001/min) only serve
**stock Whisper** — which produces exactly the Hinglish mess our product exists to fix.
**A cloud mode worth shipping must run OUR model** (Apex today, our fine-tune tomorrow).
So the real options are:

| Option | What | Hinglish quality | Ops burden | Verdict |
|---|---|---|---|---|
| **A. Resell a hosted API** (Groq/Fireworks/Deepgram) | Proxy to their stock Whisper | ❌ Worse than our local app | ~zero | Prototype/fallback only |
| **B. Serverless GPU, our model** (RunPod/Modal) | Apex on faster-whisper, pay-per-second, scale-to-zero | ✅ Full-precision Apex | Low | **Start here** |
| **C. Own instances** (AWS/Azure Mumbai, autoscaled) | Same server, reserved/spot GPUs | ✅ | Medium | Move here when volume justifies (and burn the [YC credits](../YC_CREDITS_PLAN.md)) |

**Recommendation: A for a 1-week internal prototype of the app plumbing → B for launch
→ C at scale.** B and C run the *same container image*, so C is a redeploy, not a rewrite.

## How users get it (product shape)

- In the model picker, cloud appears as just another "model":
  **"Desi Cloud ⚡ — fastest & most accurate, needs internet"** next to the local ones.
  Same hotkey, same insertion — the engine choice is invisible after setup.
- **Pro-tier feature** (per [MONETIZATION.md](../MONETIZATION.md)): cloud costs us real
  money per minute, so it's gated by license key = our auth token. Free tier gets a
  taste (e.g. 30 min/month) so low-end-device users can experience the product at all —
  that taste *is* the conversion funnel for exactly the users who can't run Apex locally.
- Later (separate decision): the same endpoint, productized as a **developer API** —
  the platform play in [ICP.md](../ICP.md) O-cases. Design the endpoint as if external
  developers will use it someday (clean REST, API keys), because they might.

## What this is NOT

- Not a pivot to cloud-first. The moat thesis (on-device, privacy) stands.
- Not real-time streaming ASR (v1 is batch per-utterance, same as local hold-to-talk;
  streaming is a later, harder, more expensive project).
- Not training-data collection. Cloud audio is deleted; the P3 donation program stays
  separate, explicit, and per-item opt-in. **Never quietly merge these.**

## Sources (key ones)

- API pricing landscape: [Groq ~$0.04/hr audio](https://tokenmix.ai/blog/whisper-api-pricing), [comparison table](https://awesomeagents.ai/pricing/transcription-api-pricing/), [Deepgram $0.0036/min batch](https://www.opentypeless.com/en/blog/deepgram-vs-whisper)
- Serverless GPU: [RunPod pricing (L4 ~$0.84/hr, per-second, FlashBoot cold starts)](https://www.runpod.io/pricing), [Modal comparison](https://www.buildmvpfast.com/blog/scale-to-zero-serverless-gpu-modal-runpod-ai-hosting-2026)
- Throughput: [faster-whisper turbo on L4 — dozens of concurrent streams, 30–40× realtime batch](https://gigagpu.com/whisper-vs-faster-whisper-for-api-serving/), [INT8 turbo ≈1.6 GB VRAM](https://gigagpu.com/whisper-vram-requirements/)
- Instance prices: [g6.xlarge (L4) ≈$0.80/hr](https://instances.vantage.sh/aws/ec2/g6.xlarge), [g4dn.xlarge (T4) ≈$0.53/hr](https://instances.vantage.sh/aws/ec2/g4dn.xlarge)
