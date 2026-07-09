# Cloud STT APIs (Deepgram · AssemblyAI · ElevenLabs Scribe · Speechmatics)

> **Layer:** Infra / cloud model API · **Verdict:** the server-side STT market — not our competitors (we're on-device), but the alternative a *cloud* Desi-Dictation-clone would use, and the benchmark for what "state-of-the-art code-switching" looks like.

## Snapshot

| Provider | Notable model | Code-switching | Pricing (approx, 2026) |
|---|---|---|---|
| **Deepgram** | Nova-3 | **Real-time code-switching across 10 languages incl. Hindi** | ~$0.46/hr English streaming |
| **AssemblyAI** | Universal-3 | High-accuracy streaming | ~$0.45/hr |
| **ElevenLabs Scribe** | Scribe v2 Realtime | No native code-switching; 90+ languages, sub-150ms latency | ~$0.22–0.48/hr |
| **Speechmatics** | Ursa 2 | **Code-switching ~35% better than nearest competitor** | enterprise |
| **Sarvam** (Indian) | Saaras V3 | code-mixed 22 Indic langs (see [sarvam-ai.md](11-sarvam-ai.md)) | ₹30/hr |

**Confidence:** medium-high — 2026 benchmark roundups; note published WERs use clean audio and real-world can be 3–4× worse.

## What they are

The cloud speech-to-text infrastructure market: fast, accurate, continuously-updated ASR sold per-hour-of-audio to developers. Several now explicitly support **code-switching** (Deepgram Nova-3 with Hindi; Speechmatics Ursa 2 leading on it) — i.e., the hard problem we specialize in is increasingly a checkbox on cloud APIs. They are how you'd build a Hinglish dictation app *if you didn't care about on-device privacy*.

## Why they're in our map

1. **They define "cloud SOTA" for code-switching** — the quality bar a connected app can hit. Our on-device models must be "close enough" that the privacy/cost tradeoff is worth it. If cloud code-switching gets dramatically better than anything on-device, "good enough locally" gets harder to sell to quality-maximizers.
2. **They're the build-vs-us path for a competitor** — a well-funded team could wrap Deepgram/Speechmatics into a slick Hinglish dictation app in weeks (cloud), skipping all our on-device engineering. Their weakness (and our defense) is the same one that dooms Wispr on privacy: **the audio leaves the device**, with data-cost, latency, offline-failure, and privacy consequences.
3. **They're a fallback/benchmark for us** — like Sarvam, a potential cloud fallback for hard cases (against our brand, so unlikely) and a yardstick to measure our on-device quality gap against.

## Strengths (the category)

Continuously improving; very high accuracy on clean audio; real-time streaming with low latency; growing code-switching support; no on-device compute needed; easy to integrate.

## Weaknesses (vs. our approach)

- **Cloud** — audio uploaded; privacy, data-cost, offline-failure, latency-variability. Fatal for our personas (Rohan/Priya/Suresh) and our brand.
- **Per-hour cost recurs** — a cloud app must charge subscriptions to cover it (why Wispr/Willow are subs); our COGS≈0 lets us undercut.
- **English/global-first** (except Sarvam/Deepgram-Hindi) — most aren't tuned for Indian Roman-script consumer output.
- **Benchmark-vs-reality gap** — 5% WER on clean audio can be 15–20% on real noisy speech; their headline numbers flatter them.

## Threat & strategic implications

**Threat: low direct, medium as an enabler.** These APIs won't compete with us — they enable whoever *does*. The strategic reality they underline (with Sarvam, Google, Parakeet) is the recurring theme of this whole directory: **the model layer is commoditizing.** Code-switching STT is becoming a cloud commodity. That means our long-term defensibility cannot be "we have the best Hinglish model" — it must be **on-device privacy + consumer product craft + personalization + the feature layer + India-native GTM**, i.e. everything *around* the model.

**Our on-device bet is the hedge against exactly this commoditization:** when the model is a commodity anyone can rent for ₹30/hr, the differentiator becomes "and it never leaves your laptop, works offline, costs nothing per use, and is tuned to *your* Hinglish." That's a value proposition a per-hour cloud API structurally cannot offer.

Sources: [Best STT providers 2026 (Coval)](https://www.coval.ai/blog/best-speech-to-text-providers-in-2026-independent-benchmarks-and-how-to-choose/), [STT APIs 2026 benchmarks (FutureAGI)](https://futureagi.com/blog/speech-to-text-apis-in-2026-benchmarks-pricing-developer-s-decision-guide/), [Best STT APIs (Deepgram)](https://deepgram.com/learn/best-speech-to-text-apis-2026), [AssemblyAI vs Deepgram (Gladia)](https://www.gladia.io/blog/assemblyai-vs-deepgram).
