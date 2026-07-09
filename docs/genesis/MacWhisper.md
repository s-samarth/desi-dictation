# MacWhisper — Complete Reference

> A local-first speech-to-text app for macOS built around OpenAI's Whisper (and now
> NVIDIA's Parakeet) models. Transcribes audio/video files, records meetings, and
> — most relevantly for your workflow — provides **system-wide push-to-talk dictation**
> into any text field on your Mac.

**Document compiled:** 2026-07-07
**Verified against:** locally installed build **v13.23.1** (`/Applications/MacWhisper.app`), the
official docs at `docs.macwhisper.com`, the Gumroad listing, and third-party reviews.

---

## 1. What it is (at a glance)

| | |
|---|---|
| **Category** | Local speech-to-text / transcription / dictation utility |
| **Platform** | macOS (Apple Silicon + Intel); companion iOS app; App Store variant called *Whisper Transcription* |
| **Developer** | Jordi Bruin — solo indie developer, studio **Good Snooze** (`goodsnooze`) |
| **Core engine** | OpenAI **Whisper** family + NVIDIA **Parakeet** (via WhisperKit / whisper.cpp) |
| **Distribution** | Direct download via **Gumroad** (`goodsnooze.gumroad.com/l/macwhisper`) and the Mac App Store |
| **Privacy model** | Runs **100% locally / on-device** by default — audio never leaves your Mac unless you opt into a cloud provider. "Never phones home." |
| **Business model** | Generous **free tier** + one-time **Pro** lifetime license (no subscription on the Gumroad version) |
| **Scale** | ~300,000 copies distributed |

The name is a play on "Mac" + "Whisper" (the OpenAI model). It is essentially a polished,
native macOS front-end that makes Whisper usable without touching a terminal, plus a large
layer of workflow features (dictation, meeting capture, AI post-processing) built on top.

---

## 2. Two products, one family (important distinction)

There are **two** apps from the same developer. This trips people up constantly:

### MacWhisper (Gumroad / `www.macwhisper.com` direct download) — *this is what you have*
- One-time **Pro** license, no subscription.
- Has the **full feature set**, including **system-wide Dictation** and **automatic meeting recording** — features Apple's sandbox rules forbid in the App Store version.
- Supports **all AI providers** (OpenAI, Anthropic/Claude, Gemini, Ollama, Groq, etc.).
- Supports **MDM** (managed deployment for businesses).

### Whisper Transcription (Mac App Store + iOS)
- **Subscription** pricing (or a lifetime IAP).
- **No Dictation, no meeting auto-recording** — blocked by App Store sandbox restrictions.
- Fewer AI provider options.
- iOS version: all local models free; optional "Assistant" subscription for cloud transcription/summaries/chat.

> **Rule of thumb:** if you want the hotkey dictation you've been using, you must be on the
> **Gumroad build** (which you are — v13.23.1). That feature literally cannot exist in the
> App Store version.

Source: [MacWhisper & Whisper Transcription Difference](https://docs.macwhisper.com/article/40-macwhisper-whisper-transcription-difference)

---

## 3. The Dictation feature (your primary use case)

This is the "hold a hotkey, speak, release, and it types for you" workflow you described.
It replaces Apple's built-in macOS dictation with something far more accurate and private.

### How it works
- Press and hold a customizable **dictation hotkey** → start speaking → release → the transcribed text is **typed directly into whatever text field is focused** (any app).
- The app advertises typing "at up to **250 words per minute**" (i.e. as fast as you can talk).
- **Escape** cancels/discards the current dictation without inserting anything (matches your description of "press escape to ignore your inputs").

### Two activation modes (confirmed in v13.23.1)
| Mode | Behaviour |
|---|---|
| **Push to Talk** (default) | *"Press and hold the dictation key to dictate and release when you're done."* Hold = recording; release = transcribe + insert. |
| **Toggle** | Tap once to start, tap again to stop. Set via **Settings → Dictation** ("change the button behaviour to toggle instead of push to talk"). |

### Setup
1. On the home screen click **Dictation**, or go to **Settings → Dictation**.
2. Toggle on **Enable Dictation**.
3. Set the **Dictation Keyboard Button** (a Function key like `fn` is recommended so it doesn't clash with other shortcuts).
4. Choose **Push to Talk** or **Toggle**.

Audio cues ship with the app (`dictation-start.mp3`, `dictation-finish.mp3`, `dictation-error.mp3`) to signal start/stop/failure.

### AI enhancement of dictation
Dictated text can be piped through an LLM before it's inserted, using **dictation prompts**:
- Built-in transforms: clean up filler/rambling, fix grammar/spelling, make it professional, translate.
- Turns "rambling speech into structured emails and lists."
- Requires an API key (OpenAI, or now Anthropic/Claude, Gemini, Groq, or local Ollama).

### App-specific dictation prompts
You can bind **different prompts to different apps** (the target app must be running to appear in the picker). **Settings → Dictation → App Specific Prompts.** Examples from the docs:
- **A chat app** → auto-translate your dictation into Spanish.
- **A code editor** → auto-generate code in your preferred language/style.
- **Mail** → always make the text read professionally and spell-correctly.

Sources: [How to use the Dictation feature](https://docs.macwhisper.com/article/14-how-to-use-the-dictation-feature) · [App Specific Dictation Prompts](https://docs.macwhisper.com/article/31-app-specific-dictation-prompts)

### Related: the "Global" overlay
A sibling to Dictation. A floating overlay (bound to its own hotkey) that records from the mic and transcribes, so you can grab text into your clipboard from anywhere. Options:
- **Auto Start** — begins recording the moment the overlay opens.
- **Auto Copy** — copies the finished transcript to the clipboard automatically.
- **Always on Top** — floats over every app (can be disabled).

Source: [How to use the Global feature](https://docs.macwhisper.com/article/16-global)

---

## 4. Models & transcription engines

MacWhisper is not tied to a single model — it's a multi-engine host. Confirmed engine
"runners" bundled in v13.23.1:

- **whisper.cpp** (`WhisperCPP_Runner`) — the C/C++ Whisper implementation, CPU/GPU local.
- **WhisperKit / WhisperKit Pro** (Argmax) — Apple-Silicon-optimized Core ML Whisper, used for live/streaming transcription. Pro features gate `WhisperKitPro`.
- **NativeSpeechTranscriber** — Apple's on-device speech framework.
- Cloud runners: **OpenAI**, **OpenAI-compatible**, **Groq**, **Deepgram**, **ElevenLabs**.
- **MLXAudio** runner (Apple MLX).

### Whisper model tiers
Whisper comes in multiple sizes — larger = more accurate but slower and heavier to download:

| Model | Tier | Notes |
|---|---|---|
| **Tiny** | Free | Fastest, least accurate |
| **Base** | Free | Light |
| **Small** | Free | Good balance for the free tier |
| **Medium** | **Pro** | More accurate |
| **Large-v2** | **Pro** | High accuracy |
| **Large-v3** | **Pro** | Highest accuracy, 100+ languages |
| **Large-v3 Turbo** | **Pro** | Near-Large-v3 accuracy, much faster — the modern default for on-device |

You download models locally and pick which to use; everything then runs offline.

### Parakeet (NVIDIA) — added in v13 (June 2025)
- **Parakeet v2 / v3** run via WhisperKit on **Apple Silicon (M-series)** Macs.
- Extremely fast — cited at up to **hundreds of ×-realtime** on M-series chips, and generally faster than Whisper.
- **Parakeet v3** supports **multilingual transcription across ~25 languages** in a single session.
- **Pro feature.** On **Intel Macs**, Parakeet isn't available locally — you'd use cloud providers (Deepgram/ElevenLabs) instead.

Sources: [MacWhisper now supports NVIDIA's Parakeet (9to5Mac)](https://9to5mac.com/2025/06/27/macwhisper-13-supports-nvidia-parakeet-transcription-model/) · [Release notes](https://macwhisper-site.vercel.app/release_notes.html)

### Languages
- **100+ languages** supported for transcription (inherited from Whisper).
- Multilingual single-session transcription with Parakeet v3 (~25 languages).

---

## 5. Free vs. Pro — feature breakdown

### Free (Gumroad)
- Local Whisper transcription with **Tiny / Base / Small** models.
- Drag-and-drop file transcription (mp3, wav, m4a, mp4, and more: m4b, flac, ogg, opus, aac).
- Microphone recording + transcription.
- 100+ languages.
- Full-text **search & highlight** across a transcript.
- **Audio playback synced** to the transcript (click a line to jump).
- **Reader mode**, **compact mode**.
- **Star/favorite** segments; edit/delete/split segments.
- Copy whole transcript or individual sections.
- Basic exports: **.txt / .srt / .vtt**.
- YouTube URL transcription and basic batch transcription are available in free per some reviews (gated features vary by version).

### Pro (one-time license) — adds
- **All large models**: Medium, Large-v2, Large-v3, **Large-v3 Turbo**, plus **Parakeet v2/v3**.
- **System-wide Dictation** (push-to-talk / toggle) + the **Global** overlay.
- **Automatic meeting recording** (see §6).
- **System audio recording** (capture what's playing, not just the mic).
- **Real-time / live transcription** from mic or system audio; **Live Captions**.
- **Batch / folder transcription** (hundreds of files at once).
- **Watch/Watched Folders** — auto-transcribe any new file dropped in a folder.
- **Speaker diarization / Automatic Speaker Recognition** (identify & label speakers; local models; speaker photos & per-speaker customization).
- **AI features**: summaries, chat-with-transcript, custom prompts (OpenAI, Claude, Gemini, Groq, local Ollama).
- **Translation**: via Whisper, **Apple Translation**, or **DeepL API**.
- **Advanced export formats**: SRT, VTT, PDF, HTML, JSON, CSV, Markdown, and more; simultaneous multi-format export.
- **Automation / integrations**: Make.com, n8n, Zapier, Obsidian, Notion; CLI access.
- **MDM support** for managed/business deployment.
- Unlimited use, no per-minute charges.

Sources: [daveswift review](https://daveswift.com/macwhisper/) · [getvoibe pricing](https://www.getvoibe.com/resources/macwhisper-pricing/) · [Gumroad listing](https://goodsnooze.gumroad.com/l/macwhisper)

---

## 6. Meeting recording

- **Automatic meeting detection & recording** — detects when you join **Zoom, Teams, Webex**, etc. and can auto-start recording.
- Captures **system audio + mic** so both sides of the call are transcribed.
- Feeds straight into transcription + AI summaries (action items, bullet points, key takeaways).
- **Gumroad-only** (App Store sandbox forbids it).

Source: [Automatic Meetings Recordings with MacWhisper](https://docs.macwhisper.com) (Meeting Recording category)

---

## 7. AI / LLM features

MacWhisper layers an AI post-processing stack on top of raw transcripts. Bundled prompt
runners in v13.23.1: **OpenAI**, **Anthropic (Claude)**, **Gemini**, **Ollama** (fully local
LLM). Assistant runners: **ElevenLabs**, **Groq**.

- **Transcript Chat** — ask questions about a transcript; AI answers from its content.
- **Summaries** — one-click summarization, bullet points, key takeaways, action items; custom prompts.
- **Dictation prompts** — transform dictated speech before insertion (see §3).
- **Translation** — Whisper-based, **Apple Translation** (on-device, limited language set), or **DeepL** (broader coverage, needs DeepL API key).
- **Bring-your-own-key** — you supply API keys; the app is a client. Local models (Ollama) need no key and keep everything private.

> Note: AI features that use cloud providers send that text to the provider — the *only* part
> of MacWhisper that isn't purely local. Transcription itself stays on-device unless you pick
> a cloud transcription runner.

---

## 8. Transcript editing & UI

- Segment-based editor: edit text, split lines (`⇧⏎` while editing), delete/merge, favorite (`f`).
- Assign speakers to rows by pressing number keys (`1`, `2`, `3`, …).
- Inline **video player with subtitle overlay** for video files.
- Playback synced to transcript; adjustable playback speed.
- Full transcription **history** with search and speaker filtering.
- Find & Replace across the transcript.

### Keyboard shortcuts (in-app)
| Action | Shortcut |
|---|---|
| Search / Filter | `⌘F` |
| Find & Replace | `⌘⇧F` |
| Increase / decrease font size | `⌘+` / `⌘-` |
| Toggle playback | `Space` |
| Increase / decrease playback speed | `⇧>` / `⇧<` |
| Transcript / AI / Translations / Info / Export tabs | `⌘1` … `⌘5` |
| Split line (while editing) | `⇧⏎` |
| Assign speaker to row | `1`, `2`, `3`, … |
| Favorite row | `f` |
| Copy selected row | `⌘C` |

(The **dictation** and **Global** hotkeys are separate, user-defined global shortcuts.)

Source: [Keyboard Shortcuts](https://docs.macwhisper.com/article/28-keyboard-shortcuts)

---

## 9. Export & automation

- **Export formats**: TXT, SRT, VTT, PDF, HTML, JSON, CSV, Markdown; export multiple at once.
- **Batch transcription** of folders / many files.
- **Watched Folders** with configurable recursion depth — drop files in, get transcripts out automatically.
- **CLI access** for scripting.
- Integrations: **Make.com, n8n, Zapier, Obsidian, Notion**.

---

## 10. Pricing (as of 2026)

### Gumroad / direct (`goodsnooze.gumroad.com/l/macwhisper`) — *your version*
| Tier | Price | Billing |
|---|---|---|
| **Free** | $0 | Forever |
| **Pro** | **€59 (~$69 USD)** one-time | Lifetime license, no subscription |
| **Bulk packs** | 5 / 10 / 20 / 50 seats | One-time, per-seat discount |
| **Student / journalist / nonprofit** | **25% off** Pro | One-time |

> Prices reported by third parties vary a bit (€59–€64 / $69–$79) depending on region, promos,
> and when the review was written. Treat the Gumroad page as authoritative.

Activation is via a **license key** you paste into the app. A **20% upgrade discount** is mentioned for moving from free to Pro to unlock AI features.

### Mac App Store — *Whisper Transcription* (different app, for reference)
| Tier | Price |
|---|---|
| Free | $0 |
| Pro Monthly | $6.99/mo |
| Pro Yearly | $29.99/yr |
| Pro Lifetime (IAP) | $99.99 |
| Assistant add-on (cloud AI) | $5.99/wk, $9.99/mo, or $89.99/yr |

Source: [getvoibe pricing](https://www.getvoibe.com/resources/macwhisper-pricing/)

---

## 11. Privacy & system notes

- **Local by default.** Audio and transcription stay on your Mac. Reviewers specifically praise that it "never phones home." The only outbound traffic is (a) telemetry (TelemetryDeck — anonymous usage) and (b) any cloud AI/transcription provider *you* explicitly enable with your own key.
- **Apple Silicon** gets the fast path (WhisperKit + Parakeet + MLX). **Intel** Macs can still run Whisper locally but lose local Parakeet — cloud providers (Deepgram/ElevenLabs) fill that gap.
- Uses **GRDB / SQLite** for its transcript database (with undo support). The DB is versioned; opening it in an older app version than it was last written by is blocked.
- Localized (English, German confirmed; more likely).

---

## 12. Pros / cons summary

**Pros**
- Genuinely useful free tier.
- One-time Pro price — no subscription (Gumroad).
- Strong privacy — local processing.
- Multi-engine: Whisper + Parakeet + cloud fallbacks.
- Deep workflow features: dictation, meetings, watched folders, AI, automation.
- Fast on Apple Silicon.

**Cons**
- **Mac-only** (no Windows/Linux; iOS is a separate lighter app).
- Speaker diarization is still **beta**.
- Cloud AI features incur **separate API costs** (bring your own key).
- Advanced features have a learning curve.
- Intel Macs miss local Parakeet.

---

## 13. Sources

- [MacWhisper on Gumroad](https://goodsnooze.gumroad.com/l/macwhisper)
- [MacWhisper Support Docs](https://docs.macwhisper.com/)
- [How to use the Dictation feature](https://docs.macwhisper.com/article/14-how-to-use-the-dictation-feature)
- [App Specific Dictation Prompts](https://docs.macwhisper.com/article/31-app-specific-dictation-prompts)
- [How to use the Global feature](https://docs.macwhisper.com/article/16-global)
- [Keyboard Shortcuts](https://docs.macwhisper.com/article/28-keyboard-shortcuts)
- [MacWhisper vs Whisper Transcription](https://docs.macwhisper.com/article/40-macwhisper-whisper-transcription-difference)
- [daveswift.com — MacWhisper Review 2026](https://daveswift.com/macwhisper/)
- [getvoibe — MacWhisper Pricing 2026](https://www.getvoibe.com/resources/macwhisper-pricing/)
- [9to5Mac — MacWhisper adds NVIDIA Parakeet](https://9to5mac.com/2025/06/27/macwhisper-13-supports-nvidia-parakeet-transcription-model/)
- [MacWhisper Release Notes](https://macwhisper-site.vercel.app/release_notes.html)
- [Whisper Transcription on the App Store](https://apps.apple.com/us/app/whisper-transcription/id1668083311)
- Local inspection of installed build **v13.23.1** (`/Applications/MacWhisper.app`)
