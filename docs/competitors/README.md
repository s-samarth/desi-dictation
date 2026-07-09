# Competitor Intelligence (private)

> Built 2026-07-09 from a multi-wave web research pass plus our own hands-on MacWhisper work. This directory replaces the old `features/COMPETITOR_FEATURES.md` (deleted): each competitor now has a **standalone, comprehensive** file — read any one on its own. Repetition across files is intentional so each stands alone. Cross-layer patterns live in [PATTERNS.md](PATTERNS.md).

## Why this exists

We compete on more layers than "other Mac dictation apps." Our stack is: an **application** (menu-bar dictation UX) wrapping an **engine** (whisper.cpp) running **models** (Oriserve fine-tunes) for a **market** (Indian code-mixed speech) on a **platform** (Apple Silicon macOS — today). Every one of those layers has its own competitors, and a threat at any layer can hollow us out. This folder maps all of them.

## The layers we're actually contesting

| Layer | Who lives here | Our position |
|---|---|---|
| **App / UX** | MacWhisper, Wispr Flow, Superwhisper, VoiceInk, Willow, Raycast | Where we play directly. |
| **Platform-native (free defaults)** | Apple Dictation, Google Gboard, Windows Voice Typing | The "good enough & free" gravity we must visibly beat. |
| **Indian model / platform** | Sarvam, AI4Bharat, Krutrim, Bhashini, Oriserve, Reverie/Gnani | Our language moat's real contest — and our supply chain. |
| **Global model / infra** | OpenAI Whisper, NVIDIA Parakeet/Canary, cloud STT APIs | What we're built on and what could replace what we're built on. |
| **Adjacent (voice notes)** | AudioPen, Voicenotes | Where our Structure-Your-Thoughts feature competes. |

## Roster

| # | File | Layer | One-line threat |
|---|---|---|---|
| 01 | [macwhisper.md](01-macwhisper.md) | App | Category king; could add an Indian model any day. |
| 02 | [wispr-flow.md](02-wispr-flow.md) | App | The UX/marketing benchmark and the privacy cautionary tale. |
| 03 | [superwhisper.md](03-superwhisper.md) | App | Closest business-model twin; on-device, tiered. |
| 04 | [voiceink.md](04-voiceink.md) | App | Structural twin: indie, whisper.cpp, open-source, one-time. |
| 05 | [willow-voice.md](05-willow-voice.md) | App | YC-backed, cross-platform (incl. Android), fast-growing. |
| 06 | [raycast-dictation.md](06-raycast-dictation.md) | App | Zero-install distribution into millions of devs. |
| 07 | [apple-dictation.md](07-apple-dictation.md) | Platform | Free, on-device, OS-level — the default we must beat. |
| 08 | [google-gboard.md](08-google-gboard.md) | Platform | **The biggest threat**: Gemini "Rambler" + Hinglish on Android. |
| 09 | [windows-voice-typing.md](09-windows-voice-typing.md) | Platform | The default on our must-win expansion platform. |
| 10 | [audiopen-voicenotes.md](10-audiopen-voicenotes.md) | Adjacent | Standalone businesses proving Structure-Your-Thoughts. |
| 11 | [sarvam-ai.md](11-sarvam-ai.md) | Indian model | $1.5B unicorn; code-mixed ASR; could ship a consumer app. |
| 12 | [ai4bharat.md](12-ai4bharat.md) | Indian model | Open-source Indic ASR — a model-supply alternative to Oriserve. |
| 13 | [krutrim.md](13-krutrim.md) | Indian model | Ola-backed; Hinglish-strong LLM; consumer distribution muscle. |
| 14 | [bhashini.md](14-bhashini.md) | Indian model | Govt DPI; free APIs; sets the "free floor" politically. |
| 15 | [oriserve.md](15-oriserve.md) | Indian model | **Our own supplier** — makes the model we ship. |
| 16 | [indian-enterprise-voice.md](16-indian-enterprise-voice.md) | Indian model | Reverie, Gnani, BharatGen — the enterprise-voice field. |
| 17 | [openai-whisper.md](17-openai-whisper.md) | Infra | Our foundation; whisper.cpp/WhisperKit runtimes. |
| 18 | [nvidia-parakeet-canary.md](18-nvidia-parakeet-canary.md) | Infra | 10× faster than Whisper; our English-engine upgrade path. |
| 19 | [cloud-stt-apis.md](19-cloud-stt-apis.md) | Infra | Deepgram/AssemblyAI/ElevenLabs/Speechmatics — code-switch APIs. |

## Methodology & confidence

- **Verified** = official site/docs, our installed build, or multiple independent reviews agreeing.
- **(guess)** = my inference, labelled inline. Almost nothing here is a pure guess; vendors document heavily.
- MacWhisper is the only one I have *hands-on* (installed v13.23.1) plus fresh 2026 reviews.
- Research date 2026-07-09; the voice-AI space moves monthly (see Gboard/Rambler) — re-verify before betting on any single claim.

## The one-paragraph takeaway (full version in PATTERNS.md)

Every app competitor has converged on the same feature set (personal dictionary, per-app modes, LLM post-processing) — and **not one of them, at any layer, does Roman-script code-mixed Indian speech well as a polished consumer product.** The platform players (Google especially) are the real medium-term danger, because Gboard's Gemini "Rambler" targets exactly our use case on exactly the platform (Android) we don't yet support. Our moat is real but time-boxed: win Hinglish quality and get onto Android before Google's default gets good enough.
