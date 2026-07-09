# Superwhisper

> **Layer:** Application (on-device dictation, cross-platform) · **Verdict:** our closest *business-model* twin — on-device, freemium + subscription + lifetime, with the most complete "modes" system in the category.

## Snapshot

| | |
|---|---|
| **Category** | On-device voice-to-text with LLM post-processing and per-context "modes" |
| **Platforms** | macOS (Intel + Apple Silicon), **Windows**, **iOS** |
| **Engine** | Whisper family (incl. Large) on-device + a menu of LLMs (GPT-5, Claude Haiku 4.5, Llama 4, Grok 4.1, Gemini 3.0 Flash, Ministral) for post-processing |
| **Pricing** | Free (limited) · **$8.49/mo** · **$84.99/yr** · **$249.99 lifetime** — all three offered |
| **Privacy** | Works fully offline for transcription; cloud LLMs optional (user-selected) |
| **Confidence** | High — vendor feature pages |

## What it is

A closed-source, on-device-first dictation app that mirrors our architecture (local Whisper + optional LLM layer) and our likely monetization (free + pass/sub + lifetime). Its defining idea is **modes**: a mode bundles a transcription model, an LLM prompt, formatting rules, and behavior, and can be auto-selected per app. It is the product whose *shape* our own tone-dial and app-aware-modes roadmap should study most closely.

## Platforms & the India angle

macOS + Windows + iOS — notably **already on Windows** (our first expansion target) and iOS, but **not Android** (India's must-win). No Indian-language specialization; its "translate any language → English" is generic Whisper, weak on Hinglish. So on *our* market it's absent, but on *platforms* it's ahead of us.

## Features (exhaustive)

- Push-to-talk with configurable shortcut (⌥+Space default; hold-speak-release).
- **Offline transcription** ("no Wi-Fi, no problem") — genuine on-device.
- **Predefined modes**: Formal, Casual, Legal, Chat.
- **Custom modes**: your own prompt + formatting rules + model choice, saved as a reusable mode.
- **Per-app settings**: modes auto-selected by application.
- **Custom vocabulary**: "enter names, abbreviations, specialized terms once; remembered forever" (their P4 — but declare-in-advance, not learned).
- **Multiple LLM backends** for post-processing (the model buffet above).
- **100+ languages**; translation of any language → English.
- **File transcription** (upload audio/video); **Meeting Assistant** (record + auto-digest notes).
- **Agentic-coding integrations**: Claude Code, OpenCode, Cursor — dictating *to AI tools*, an exploding niche.
- 30+ app integrations (Slack, Gmail, Notion…); clipboard auto-paste.
- History (free tier limited to ~15 minutes).

## Strengths

The most complete modes/custom-prompt system in the market; genuinely offline; the triple pricing option lets users self-select (and validates that a chunk of the market refuses subscriptions — hence the lifetime tier); agentic-coding bet is forward-looking; broad LLM choice for power users.

## Weaknesses

- **Choice overload**: a buffet of LLMs and manual modes is power-user-friendly but a burden for a Rekha (our Auto philosophy is the counter-bet).
- **15-minute free history cap** — a usage-cap variant we consider hostile.
- **No Hinglish**; generic translation.
- Closed source (vs. VoiceInk's trust play).
- Custom vocabulary is declare-in-advance (our learn-from-corrections goes further).

## Threat to us & how we differentiate

**Threat: medium.** It's the competitor most likely to be cross-shopped against us by a *technical* Indian user (Rohan) who wants on-device + modes. If it added an Indian model it would be a real rival — but its whole design philosophy (manual modes, model menus) targets tinkerers, not the Rekha/Aman mainstream we center.

**We differentiate on:** Hinglish depth, Auto-over-configuration (one great local model, sensible defaults, no menu), learn-from-corrections personalization (vs. their declare-upfront), full free history, and India pricing. **We validate our own roadmap against them**: modes-as-bundles, per-app auto-selection, and agentic-coding dictation are all directions they've proven demand for.

**What to copy:** the modes-as-bundles UX shape (build our tone dial this way), the triple-pricing acknowledgment that lifetime must exist alongside recurring, and the agentic-coding preset (near-free for us, and dead-center of our transcribe→translate-to-English use case).

Sources: [superwhisper.com](https://superwhisper.com), [Superwhisper pricing (Voibe)](https://www.getvoibe.com/resources/superwhisper-pricing/), [Superwhisper vs Raycast](https://superwhisper.com/vs/raycast).
