# VoiceInk

> **Layer:** Application (on-device dictation, open source) · **Verdict:** our structural twin — indie dev, whisper.cpp, on-device, one-time price — and living proof that open-source + paid-binary works in this exact niche.

## Snapshot

| | |
|---|---|
| **Developer** | Prakash Joshi — indie |
| **Category** | Open-source on-device Mac dictation with LLM enhancement |
| **Platforms** | macOS (Apple Silicon); iOS mentioned |
| **Engine** | **whisper.cpp** local (same as us) + optional cloud/local LLM enhancement |
| **License / code** | **GPL v3, source on GitHub, 4,400+ stars** |
| **Pricing** | **One-time**: $25 (1 Mac) / $39 (2) / $49 (3) / $159 (10). Build-from-source free. |
| **Privacy** | 100% offline processing by default ("no data leaves your device"); cloud enhancement opt-in |
| **Confidence** | High — vendor site + comparisons + reviews |

## What it is

The competitor that most resembles *us* under the hood: a solo developer wrapping whisper.cpp in a native Mac dictation app, sold as a cheap one-time license — while giving the source away under GPL. Its ~4,400 GitHub stars are simultaneously its marketing engine and its privacy proof. It is the clearest evidence for two of our open strategic questions: (1) one-time pricing is viable in this niche, and (2) open-sourcing the app can be an asset, not a giveaway.

## Features (exhaustive)

- Local whisper.cpp transcription; "99% accuracy" claim (English — nobody claims that for Hinglish, which is our whole gap).
- 100% offline; optional cloud LLM enhancement (Gemini, Groq) or local via Ollama / LM Studio.
- Global push-to-talk shortcut (configurable).
- **Personal dictionary** (custom word training for jargon/proper nouns).
- **Smart Replace** (text replacements + expansion/shortcuts).
- **Enhancement modes**: Polish, Email, Chat, Post presets.
- **App-based automatic mode switching** (Gmail, Slack, Cursor, X).
- **Context awareness from screen + clipboard** to improve enhancement — the *same capability* as Wispr's screenshot scandal, but **processed locally**, which flips it from liability to feature. (Instructive: the objection was never "context," it was "context leaving the machine.")
- **AI Assistant** mode (ask questions / give voice commands).
- Works across all macOS apps; tiered device licensing (1/2/3/10 Macs).

## Strengths

Rock-bottom price with no subscription; radical transparency (auditable privacy is the strongest possible claim for a privacy product — Rohan's Little-Snitch energy converted into advocacy); the star count *is* the marketing; local context-awareness done right; a clean simple product.

## Weaknesses

- English-centric; no Indian-language depth.
- Fewer polish/AI features than the cloud players (by design — it's lean).
- Open source is a double edge: forks could outrun a solo dev; self-builders add support load.
- Smaller platform reach (Mac-centric).

## Threat to us & how we differentiate

**Threat: low-medium, but philosophically important.** It doesn't touch Hinglish, so it's not a market rival — but it's the proof-of-concept a *future* competitor (or a fork) could point at: "indie + whisper.cpp + open source + cheap." If someone forked VoiceInk and dropped in our public Apex model, they'd have a Hinglish-capable app fast. Our defense is the *rest* of the stack (convention, personalization, OOD, onboarding, India GTM) that a model-drop doesn't provide.

**We differentiate on:** Hinglish depth and the full India-specific stack; bundled zero-setup local models (VoiceInk leans on BYO-Ollama for LLM features — too much setup for Rekha); onboarding for non-technical users.

**What VoiceInk teaches our own strategy:** (1) one-time pricing works — it anchors our MONETIZATION.md. (2) Open-sourcing the app is a genuine trust-and-marketing multiplier for a privacy product — it strengthens the case for our open-core deliberation (MONETIZATION.md 2.9). (3) Local screen/clipboard context is *acceptable and valued* when it never leaves the device — a future-accuracy avenue for us that Wispr poisoned by doing it in the cloud.

Sources: [tryvoiceink.com](https://tryvoiceink.com), [VoiceInk review (Voibe)](https://www.getvoibe.com/resources/voiceink-review/), [VoiceInk app comparison](https://tryvoiceink.com/best-dictation-apps), [VoiceInk vs Superwhisper](https://tryvoiceink.com/superwhisper-alternative).
