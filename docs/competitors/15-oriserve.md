# Oriserve (Whisper-Hindi2Hinglish)

> **Layer:** Indian model (our own supplier) · **Verdict:** not a competitor — our **single most critical supply-chain dependency.** Oriserve makes the exact model our whole product currently runs on. This file exists so we're clear-eyed about how much we depend on one third party.

## Snapshot

| | |
|---|---|
| **Company** | Oriserve (OriServe AI) — Indian conversational-AI company |
| **What they made** | **Whisper-Hindi2Hinglish** family: Apache-2.0 Whisper fine-tunes for Hindi / Hinglish / Indian-accented English, **Roman-script output** |
| **Variants** | **Apex** (~800M params, our Hinglish default), **Prime**, **Swift** (we dropped Swift from our catalog) |
| **Training** | 1,000+ hours of conversational Indian audio incl. call-center recordings and mixed Hindi-English |
| **Claims** | ~42% higher avg performance vs. Whisper baseline; robust on accented/noisy/hybrid audio; "8× faster than larger models" at equivalent accuracy |
| **License** | **Apache 2.0** — public on Hugging Face |
| **Confidence** | High — press coverage + HF + their GitHub |

## Why this file matters

Our product's headline capability — Roman-script Hinglish dictation — is *entirely* provided by Oriserve's Apex model. We didn't train it; we convert it to GGUF, quantize it, and run it in whisper.cpp. Everything we've built (the app, onboarding, personalization plans, GTM) sits on top of a model owned and maintained by someone else. That's the most important strategic fact about our current position, and it belongs in a competitor/supplier map even though Oriserve isn't chasing our users.

## What Oriserve actually is (and isn't)

- **Is:** an enterprise conversational-AI/customer-experience company that fine-tuned Whisper for Indian speech (originally for call-center/CX use) and open-sourced it under Apache 2.0.
- **Isn't:** a consumer dictation app maker. They have no menu-bar app, no Rekha-facing product. They serve businesses.
- So they're a **supplier**, and only a competitor in the abstract sense that they *could* build a consumer product on their own model (no sign they intend to).

## The dependency risks (the real content here)

1. **Single-supplier concentration:** if Oriserve stops updating, changes license posture on future versions, or a model is pulled, our core value is frozen at today's Apex. (Apache 2.0 means we can keep using *current* weights forever — that's a real protection — but we don't get *their* future improvements for free unless they keep publishing.)
2. **We don't control quality:** P1 (Hinglish accuracy) is partly bounded by Apex's ceiling. To break past it we must fine-tune *ourselves* (P1-S4) — at which point we reduce this dependency.
3. **Anyone can use the same model:** Apache 2.0 + public HF means a competitor (or a MacWhisper user) can load Apex too. Our moat was never the model — it's the *stack around it* (convention, personalization, OOD, onboarding, GTM, on-device UX). This file is the reminder that the model is not our moat.
4. **Domain-mismatch caveat:** Apex was trained largely on call-center audio; our eval surprise (turbo beating Apex on read-speech CS-FLEURS) reflects that its strength is *conversational* speech, which happens to match dictation well — but it's not tuned for *our* exact distribution. A personal/dictation eval set is what tells us the truth.

## Strengths (as our supplier)

Genuinely good Roman-script Hinglish (the reason we chose it); permissive license (commercial-safe, can't be rug-pulled on current weights); trained on real conversational Indian audio (accents/noise/code-mix); multiple size variants; active enough to have shipped Apex recently.

## Strategic implications

- **Short term:** Apex is a gift — it's what makes the product possible today, and Apache 2.0 protects our current use permanently.
- **Medium term:** reduce the dependency by (a) benchmarking AI4Bharat's IndicWhisper/IndicConformer as alternatives ([ai4bharat.md](12-ai4bharat.md)), and (b) executing P1-S4 to fine-tune our *own* convention-normalized model (using Apex or an open base as the starting point). Owning a model we trained is what turns "app on someone's model" into "defensible product."
- **Relationship:** worth a friendly outreach — Oriserve open-sourced this for goodwill/ecosystem; a real-world consumer app showcasing their model is good for both. Potential collaboration, data-sharing, or early access to future variants.

Sources: [Oriserve open-sources India speech model (Financial Express)](https://brandwagon.financialexpressb2b.com/news/oriserve-open-sources-india-focused-ai-speech-model-fine-tuned-on-whisper), [Whisper-Hindi2Hinglish (GitHub)](https://github.com/OriserveAI/Whisper-Hindi2Hinglish), [Whisper-Hindi2Hinglish-Apex (HF)](https://huggingface.co/Oriserve/Whisper-Hindi2Hinglish-Apex), [Oriserve Apex launch (CXOToday)](https://cxotoday.com/press-release/oriserve-launches-whisper-hindi-to-english-apex-engine-to-power-next-gen-ai-for-indias-multilingual-business-needs/).
