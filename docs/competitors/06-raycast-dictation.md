# Raycast Dictation

> **Layer:** Application (dictation as a feature of a launcher) · **Verdict:** not a great dictation product, but a **distribution threat** — it can put "good enough" dictation in front of millions of developers at zero install cost.

## Snapshot

| | |
|---|---|
| **Company** | Raycast (macOS launcher / productivity platform; also iOS, Windows in progress) |
| **Category** | Dictation bundled inside a launcher people already run all day |
| **Platforms** | macOS (within Raycast); iOS via Raycast Keyboard |
| **Engine** | Two flavors: a **local whisper.cpp** community extension (manage Whisper models in-app), and Raycast's own cloud dictation (audio to Raycast servers, not retained; refinement needs **Raycast Pro**) |
| **Pricing** | Dictation feature free/beta; AI refinement requires Raycast Pro (~$8–16/mo bundled with all Raycast AI) |
| **Privacy** | Mixed: local extension is on-device; native Raycast dictation is cloud-processed (not retained) |
| **Confidence** | Medium — vendor store + comparisons |

## What it is

Raycast is a beloved macOS launcher/command-palette with a huge developer userbase. Dictation is one of many features inside it — both as an official cloud feature (with AI refinement gated behind Raycast Pro) and as a popular community whisper.cpp extension. The product quality is secondary; the danger is **channel**: for a developer who already lives in Raycast, dictation is one hotkey away with nothing to install.

## Features

- Hotkey-triggered dictation inside the Raycast palette.
- Local whisper.cpp transcription (community extension) with in-app model management; or cloud dictation (official).
- AI refinement: punctuation/formatting cleanup, custom instructions, via Raycast AI (Pro) or any OpenAI-compatible API / local Ollama.
- Custom vocabulary; app-context awareness; local dictation history with timestamps (browse/copy/paste).

## Strengths

Zero-install distribution into a captive, high-value developer audience; integrates with the tools those users already orchestrate through Raycast; local option for the privacy-minded; bundled into an existing Pro subscription (no separate purchase decision).

## Weaknesses

- Dictation is a side feature, not a focus — less polished than dedicated apps.
- macOS/dev-centric; not a mainstream-India product (Rekha/Aman don't run Raycast).
- Official path is cloud + Pro-gated; fragmented (official vs. community extension).
- No Indian-language depth.

## Threat to us & how we differentiate

**Threat: low on our core market, real on one persona.** Raycast contests exactly one of our personas — **Rohan, the developer** — via distribution we can't match. A dev who wants quick English dictation may never leave Raycast to try us. But it does nothing for Hinglish, nothing for non-technical users, and nothing for Android/India at large.

**We differentiate on:** Hinglish (irrelevant to Raycast), a focused dictation UX, and reach beyond the developer niche. For Rohan specifically, our wedge is that his *Hinglish* WhatsApp/Slack messages are where Raycast's English dictation fails — we win the code-mixed half of his typing, which Raycast can't touch.

**Watch-list item (see A4 in ADDITIONAL_PROBLEMS):** if Raycast ever adds Indian-language dictation or ships broadly on Android/Windows, the developer persona becomes genuinely contested. Low probability, high-value segment — monitor Raycast release notes quarterly.

Sources: [Raycast Whisper Dictation store](https://www.raycast.com/finjo/whisper-dictation), [Superwhisper vs Raycast](https://superwhisper.com/vs/raycast), [Spokenly vs Raycast](https://spokenly.app/comparison/raycast).
