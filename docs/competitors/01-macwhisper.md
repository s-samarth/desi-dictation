# MacWhisper

> **Layer:** Application (macOS transcription + dictation) · **Verdict:** the category king we cloned our UX from; a broad, mature, sustainable indie product whose one gap is *our entire market*.

## Snapshot

| | |
|---|---|
| **Developer** | Jordi Bruin — solo indie, studio **Good Snooze** |
| **Category** | Local-first speech-to-text: file transcription + system-wide dictation + meeting capture |
| **Platforms** | macOS (Apple Silicon + **Intel**); separate lighter iOS/App-Store app ("Whisper Transcription") |
| **Engine** | Whisper family via whisper.cpp + **WhisperKit** (Argmax, Core ML) + NVIDIA **Parakeet** + Apple native speech + MLX |
| **Pricing** | Generous free tier + **€59 (~$69) one-time lifetime Pro** on Gumroad; App Store variant is subscription ($29.99/yr) or $99.99 lifetime |
| **Privacy** | 100% local by default; only outbound traffic is anonymous **TelemetryDeck** analytics + any cloud AI provider *you* enable with your own key |
| **Scale** | ~300,000 copies distributed; years of sustainable solo-dev revenue |
| **Confidence** | **Highest** — hands-on with installed v13.23.1 + 2026 reviews |

## What it is

A polished native macOS front-end that made Whisper usable without a terminal, then accreted a large workflow layer on top: file/batch transcription, automatic meeting recording, AI post-processing, and — most relevant to us — **system-wide push-to-talk dictation** into any text field. It is the product our own app's UX is most directly modelled on, and the benchmark reviewers measure everyone else against.

**Two-product trap (important):** the full-featured build is the **Gumroad** direct download — it has Dictation and meeting auto-recording. The Mac App Store build ("Whisper Transcription") is sandboxed and *cannot* have system-wide dictation. Anyone comparing "MacWhisper" must know which one; the dictation feature only exists outside the App Store.

## Features (exhaustive)

**Dictation (our overlap):** push-to-talk + toggle modes; customizable hotkey (Fn recommended); Esc to cancel; start/stop/error audio cues; marketing claim "types at up to 250 wpm." **Dictation prompts** pipe the transcript through an LLM before insertion (clean filler, fix grammar, make professional, translate) — needs an API key (OpenAI/Anthropic/Gemini/Groq) or local Ollama. **App-specific prompts**: bind a different LLM prompt per target app (chat → translate to Spanish; editor → generate code; Mail → make professional). A sibling "Global" overlay records from anywhere to clipboard with auto-start/auto-copy/always-on-top.

**Transcription utility (their center of gravity, not ours):** file transcription; batch/folder processing (hundreds of files); watched folders (drop a file, get a transcript); synced audio playback; segment edit/split/star; reader & compact modes.

**Meetings:** automatic detection & recording of Zoom/Teams/Webex; system-audio capture (not just mic); real-time live transcription + Live Captions; speaker diarization with local models, labels and photos. All Gumroad-only (App Store sandbox forbids it).

**AI layer:** transcript chat (ask questions of a transcript), one-click summaries/action items/custom prompts, translation via Whisper / Apple Translation / DeepL. Bring-your-own-key; local Ollama keeps it private.

**Export & automation:** TXT/SRT/VTT/PDF/HTML/JSON/CSV/Markdown, multi-format at once; Zapier/Make/n8n/Obsidian/Notion; CLI; **MDM** for managed business deployment; bulk seat packs (5/10/20/50); 25% student/journalist/nonprofit discount.

## Models

Free tier: tiny/base/small Whisper. Pro unlocks medium, large-v2/v3, **large-v3-turbo**, and **Parakeet v2/v3** (via WhisperKit, Apple Silicon only; Parakeet v3 = ~25 languages in one session). 100+ languages inherited from Whisper. Intel Macs run Whisper locally but lose local Parakeet (fall back to cloud Deepgram/ElevenLabs). Engine abstraction across whisper.cpp/WhisperKit/Apple-native/MLX gives them resilience and a fast Apple-Silicon path.

## Strengths

Maturity and breadth (years of features), native-feeling simplicity, genuinely private local default, strong *file* transcription accuracy (2026 reviews: ~3.1% WER on standard English, competitive with cloud), a trusted solo-dev brand, and a proven one-time-license business at scale.

## Weaknesses (2026 reviews, verified)

- **Live dictation is clunky**: reviewers measured ~2.4 s of silence after you stop before text appears; no real-time streaming; text dumps all at once. It's built for *files*, and dictation is the weaker sibling. **This is our opening even in English** — our chunked-while-speaking pipeline targets exactly this.
- **RAM**: ~1.1 GB for the background process; 8 GB Macs slow down with a browser open.
- **No filler-word removal, no context-aware punctuation, no auto-paragraphing** — raw text needs manual editing (they never built the Wispr-style AI cleanup by default).
- **Hinglish**: none. Its translation paths (Whisper/Apple/DeepL) are generic and weak on Roman-script code-mix. It has no Indian-tuned model.
- Anonymous TelemetryDeck analytics — flagged even in glowing reviews; we out-position on zero-telemetry.

## Threat to us & how we differentiate

**Threat: medium-high, latent.** MacWhisper runs *any* whisper.cpp model — a user can already load our own public Apex into MacWhisper today. If Jordi decided to ship an Indian-tuned model + Roman-script post-processing, he'd have distribution (300k users) and polish we can't match quickly. But it's not his focus, and Hinglish needs the *whole* stack we've built (convention, personalization, OOD handling), not just a model drop.

**We differentiate on:** Hinglish depth (their fatal gap), live-dictation latency (their measured weakness), zero telemetry (out-privacy the privacy king), and India-shaped pricing/onboarding. We should *not* chase their file-transcription/meeting breadth — different product.

**What to copy:** the one-time-license model (works at scale here), app-specific prompts (mature IDEAS #4), student discount, bulk seat packs + MDM for our enterprise plan, and the honest speed claim as marketing.

Sources: local [MacWhisper.md](../genesis/MacWhisper.md) (hands-on v13.23.1 + docs.macwhisper.com), [MacWhisper 30-day review 2026 (LumeVoice)](https://lumevoice.com/blog/macwhisper-review-2026/), [MacWhisper on Gumroad](https://goodsnooze.gumroad.com/l/macwhisper), [MacWhisper pricing (Voibe)](https://www.getvoibe.com/resources/macwhisper-pricing/).
