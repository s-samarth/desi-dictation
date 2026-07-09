# Sarvam AI

> **Layer:** Indian model / platform (STT + LLM + API) · **Verdict:** the best-funded, most capable Indian voice-AI company — a model-layer giant whose code-mixed ASR is our closest *technical* rival, and whose only reason not to fear directly is that they build platforms/APIs, not consumer dictation apps (yet).

## Snapshot

| | |
|---|---|
| **Company** | Sarvam AI — "India's full-stack sovereign AI platform" |
| **Funding** | **$1.5B valuation** unicorn (June 2026 Series B, $234M; HCLTech led $150M) |
| **Category** | Foundational Indian-language models: STT, TTS, translation, LLMs — sold as APIs/platform |
| **Key STT** | **Saarika** (ASR), **Saaras V3** (speech translation + ASR); real-time + batch; **code-mixing, diarization, auto language detection**; ~19% WER on IndicVoices |
| **LLMs** | Open-sourced **Sarvam 30B** and **Sarvam 105B** (MoE), trained from scratch on Indic data |
| **Pricing** | Pay-per-use API: **STT ₹30/hour** (~$0.35); ₹1,000 free credits; startup program (6–12 mo credits) |
| **Confidence** | High — Wikipedia, official docs, MediaNama coverage |

## What it is

The flagship of India's "sovereign AI" push: a well-capitalized company building foundational models for Indian languages and selling them as infrastructure. Its speech stack (Saarika/Saaras) explicitly targets **code-mixed** speech — the same phenomenon we specialize in — with diarization, timestamps, and auto language detection, at ~19% WER on IndicVoices. It also open-sourced large LLMs. Backed by HCLTech and the government-adjacent sovereign-AI agenda, it has resources and political tailwind no indie can match.

## Where it competes with us — and where it doesn't

- **Model layer (direct overlap):** Saaras/Saarika do code-mixed Hindi-English ASR. If we ever want a *better model than Oriserve's*, Sarvam is both a potential supplier (via API) and a benchmark to beat. Their code-mix quality is a real yardstick for our P1 work.
- **Product layer (no overlap today):** Sarvam sells APIs and platforms to *developers and enterprises*, not a consumer menu-bar dictation app. They are the "picks and shovels" layer; we're the application. A developer could build a Desi-Dictation-like app on Sarvam's API — but it'd be cloud (their API is server-side), losing our on-device privacy story.
- **Architecture difference:** Sarvam is cloud API-first. Our entire pitch is on-device. So even where the *models* overlap, the *product values* diverge sharply.

## Strengths

Deep funding; sovereign-AI political and enterprise tailwind (HCLTech distribution); genuine code-mixed ASR; full stack (STT+TTS+translation+LLM) enabling end-to-end Indian-language products; open-sourced LLMs build developer goodwill; startup-credit program seeds an ecosystem.

## Weaknesses (relative to our niche)

- **Cloud/API-first** — not a privacy-on-device consumer product; audio goes to their servers.
- **Not a consumer app** — no dictation UX, no Mac/Android end-user product competing for Rohan/Rekha directly.
- **Devanagari/enterprise orientation** — their code-mix output and use cases skew toward call-center/enterprise transcription and Devanagari, not the Roman-script "text like you text" consumer need.
- Enterprise/B2B focus means the *consumer* Hinglish-dictation space is unoccupied by them.

## Threat to us & how we differentiate

**Threat: medium, mostly indirect.** Sarvam is unlikely to ship a consumer Mac/Android dictation app soon — it's not their model. The real threats are: (1) they could *power* a competitor's cloud dictation app with a better-than-ours model; (2) their models could become so good and cheap that "on-device quality" stops being worth the tradeoff for users; (3) if they ever did launch a consumer product, their brand + funding would be formidable.

**We differentiate on:** on-device privacy (their structural opposite), consumer product craft (they're infrastructure), Roman-script consumer Hinglish (they're enterprise/Devanagari), and cost model (one-time/free vs. their per-hour API).

**Opportunity, not just threat:** Sarvam is a potential *supplier*. If our own fine-tune (P1-S4) stalls, licensing/serving a Sarvam model — or benchmarking against Saaras to know how far behind we are — is a legitimate path. And their existence *validates the market*: a $1.5B company betting on Indian code-mixed speech means the problem we picked is real and big. The strategic question their scale forces: our defensible space is the **on-device consumer application**, because the *model* layer will eventually be commoditized by giants like Sarvam and Google — we must not bet the company on owning the best model forever (feeds A4).

Sources: [Sarvam AI (Wikipedia)](https://en.wikipedia.org/wiki/Sarvam_AI), [Saaras model docs](https://docs.sarvam.ai/api-reference-docs/models/saaras), [Sarvam models](https://www.sarvam.ai/models), [Sarvam at India AI Summit (MediaNama)](https://www.medianama.com/2026/02/223-sarvam-ai-india-ai-impact-summit-2026/), [Sarvam API pricing](https://www.sarvam.ai/api-pricing).
