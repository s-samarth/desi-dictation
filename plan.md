# Desi Dictation — Build Plan

> A MacWhisper-class, local-first dictation app for macOS, tuned for **Hinglish /
> code-mixed Indian speech** ("kal meeting hai, please deck ready rakhna"), sold on
> Gumroad. Free tier + one-time Pro license. Everything runs on-device on a MacBook Air.

**Status:** Plan v1 — 2026-07-07. Research verified against Hugging Face model cards,
whisper.cpp / WhisperKit docs, and inspection of MacWhisper v13.23.1's architecture.

---

## 1. Product definition

### The gap
- Whisper (and therefore MacWhisper) treats language as a single token (`hi` OR `en`).
  Code-mixed speech gets forced into one script: Hindi mode → everything in Devanagari,
  English mode → Hindi words get mangled or hallucinated into English words.
- What Indians actually type on WhatsApp/Slack/X is **Roman-script Hinglish** —
  Hindi phonetics written in Latin letters, English words kept as-is.
- No dictation app targets this. That's the product.

### The product (v1 scope — dictation only)
A menu bar app. Hold a hotkey → speak (Hinglish/Hindi/English) → release → text is
typed into whatever app you were in. Press Esc to discard. A small floating indicator
shows recording/transcribing state — no live text preview (same as MacWhisper).
Pauses mid-recording are fine; recording continues until you release/toggle.

**Explicitly out of scope for v1** (MacWhisper features we do NOT copy yet):
file/YouTube/batch transcription, meeting recording, speaker diarization, watched
folders, translations, transcript editor. Dictation is the wedge; the rest is roadmap.

### Language modes (user-selectable, one hotkey)
| Mode | Output | Model |
|---|---|---|
| **Hinglish** (default) | Roman-script Hinglish ("aaj scene kya hai") | Oriserve Hindi2Hinglish |
| **English (Indian accent)** | English | Same model (it handles Indian English) or stock large-v3-turbo |
| **Hindi** | Devanagari | Stock Whisper, `language=hi` |
| **Mixed script** (later) | "मेरा favourite festival Diwali है" | shunyalabs / Srota (Phase 5) |

---

## 2. Model research summary (the core bet)

### Primary: Oriserve Whisper-Hindi2Hinglish family — this is exactly our use case
Fine-tuned Whisper models that transcribe Hindi/Hinglish/Indian-English audio into
**Roman-script Hinglish**. Trained on ~700–1000 hrs of noisy, Indian-accented,
conversational audio (call-center data). **Apache 2.0 — safe for a commercial app.**

| Model | Base | Params | WER (CommonVoice/FLEURS/IndicVoices) | Role in our app |
|---|---|---|---|---|
| [Hindi2Hinglish-Apex](https://huggingface.co/Oriserve/Whisper-Hindi2Hinglish-Apex) | whisper-large-v3 lineage | **0.8B** (≈ turbo-class) | 35.96 / 29.79 / 47.64 | **Pro / quality mode** |
| [Hindi2Hinglish-Prime](https://huggingface.co/Oriserve/Whisper-Hindi2Hinglish-Prime) | large-v3-turbo | ~0.8B | between Apex & Swift | Alternative Pro model |
| [Hindi2Hinglish-Swift](https://huggingface.co/Oriserve/Whisper-Hindi2Hinglish-Swift) | whisper-base | **72.6M** | 38.65 / 35.09 / 65.21 | **Free tier / low-power mode** |

Notes:
- Apex is ranked #1 on Speech-To-Text Arena for Hinglish preference; ~42–57% improvement
  over pretrained Whisper on Indian benchmarks. Trained specifically for noise robustness
  and hallucination mitigation (both are Whisper's weak spots).
- Quirk: these models are invoked with `language="en", task="transcribe"` — the Roman
  Hinglish output is baked into the fine-tune.
- WER numbers look high vs English benchmarks — that's expected: Hinglish has no
  canonical spelling ("kya"/"kyaa", "nahi"/"nahin"), so raw WER over-penalizes. Our own
  eval must use normalized WER + human preference (see Phase 0).

### Backups / future models
- [Trelis/whisper-hinglish](https://huggingface.co/Trelis/whisper-hinglish-preview) —
  large-v3 fine-tune, claims best open-weights code-switch performance. Evaluate in Phase 0.
- [shunyalabs/zero-stt-hinglish](https://huggingface.co/shunyalabs/zero-stt-hinglish) —
  Whisper-Medium fine-tune (0.8B), outputs **mixed script**. OpenRAIL license (usable
  commercially with use-restrictions — re-read before bundling).
- **Srota** (Qwen3-ASR-0.6B fine-tune, 15.85% WER conversational Hinglish, mixed script) —
  strong but **not Whisper architecture** → can't use whisper.cpp/WhisperKit; would need
  MLX. Park for Phase 5.
- Because everything primary is a **Whisper fine-tune**, the entire MacWhisper-style
  toolchain (GGML conversion, CoreML conversion, streaming) applies unchanged. This is
  why we stay in the Whisper family for v1. (Parakeet is English/European-only — not
  useful to us despite its speed.)

---

## 3. Inference engine decision

Two viable Apple-Silicon runtimes (MacWhisper ships BOTH, behind a runner abstraction —
we copy that pattern):

| | **whisper.cpp** (GGML) | **WhisperKit** (Argmax, CoreML) |
|---|---|---|
| Custom fine-tune support | `convert-h5-to-ggml.py` — well-trodden, minutes | `whisperkittools` — supported, more pipeline steps |
| Hardware | CPU + Metal GPU (+ optional CoreML encoder) | Neural Engine + GPU — best for fanless Air (battery, thermals) |
| Quantization | q5_0 ≈ 574MB, q8_0 ≈ 874MB for a 0.8B model | float16 / palettized |
| Swift integration | SPM package / XCFramework, C API | Native Swift API, streaming built in |
| Risk | Very low | Medium (conversion of a custom fine-tune can surface op issues) |

**Decision: whisper.cpp first, behind a `TranscriptionEngine` protocol; WhisperKit as a
second backend in Phase 4.**
Trade-off: whisper.cpp gets us to a working product fastest with near-zero conversion
risk; WhisperKit's ANE execution is the better *end state* on a fanless MacBook Air
(cooler, better battery), so the protocol seam keeps that door open — exactly how
MacWhisper evolved (its bundle contains both `WhisperCPP_Runner` and WhisperKit runners).

```swift
protocol TranscriptionEngine {          // mirror of MacWhisper's "runner" bundles
    func load(model: ModelDescriptor) async throws
    func transcribe(_ audio: AudioBuffer, mode: LanguageMode) async throws -> Transcript
    func unload()
}
// v1: WhisperCppEngine. Later: WhisperKitEngine, MLXEngine (Srota), CloudEngine.
```

---

## 4. System architecture

```
┌─ Menu bar app (SwiftUI MenuBarExtra) ─────────────────────────┐
│                                                               │
│  HotkeyManager ──► DictationController ──► TextInserter       │
│  (CGEventTap:        │        ▲             (pasteboard swap  │
│   keyDown/keyUp,     ▼        │              + ⌘V CGEvent;    │
│   Esc-to-cancel)  AudioCapture│              AX fallback)     │
│                   (AVAudioEngine tap,                         │
│                    16kHz mono f32 ring buffer)                │
│                       │                                       │
│                       ▼                                       │
│              TranscriptionEngine (protocol)                   │
│                └─ WhisperCppEngine (Metal)                    │
│                       │                                       │
│                       ▼                                       │
│              PostProcessor (optional: punctuation fixes,      │
│               user dictionary, LLM cleanup via Ollama/API)    │
│                                                               │
│  OverlayPanel (non-activating NSPanel — must NOT steal focus) │
│  ModelManager (HF downloads, checksums, disk cache)           │
│  SettingsStore │ Licensing (Gumroad verify) │ Sparkle updates │
└───────────────────────────────────────────────────────────────┘
```

Key architectural notes (learned from MacWhisper's internals):
- **The overlay must be a non-activating `NSPanel`** (`.nonactivatingPanel` style,
  `canBecomeKey = false`). If it takes focus, the target text field loses focus and
  insertion breaks. This is the #1 subtle bug in this app category.
- **Text insertion strategy** (in order): (1) save pasteboard → set transcript →
  synthesize ⌘V via `CGEvent` → restore pasteboard after ~200ms; (2) AX API
  (`AXUIElementSetAttributeValue` on the focused element) for apps where paste is
  unreliable; (3) per-character `CGEvent` typing as last resort. MacWhisper ships an
  `AccessibilityHelpers` bundle plus app-specific fallbacks — same idea.
- **Permissions**: Microphone (`NSMicrophoneUsageDescription`) + Accessibility
  (`AXIsProcessTrustedWithOptions`) + Input Monitoring (for the event tap). Onboarding
  flow must walk the user through all three — this is where most support tickets come from.
- **Push-to-talk mechanics**: `CGEventTap` watching keyDown/keyUp of the chosen key
  (Fn/Globe requires watching `flagsChanged`). Hold = record; release = transcribe+insert;
  Esc during session = cancel (play `dictation-error`-style sound). Also ship **Toggle
  mode** (tap to start/stop) like MacWhisper.
- **Audio**: `AVAudioEngine` input tap → resample to 16kHz mono Float32 (Whisper's input
  format) → grow-able buffer. Engine pre-warmed when dictation is enabled so keypress→
  recording start is <50ms. Play start/stop/error sounds (MacWhisper ships mp3 cues).
- **Model residency**: keep the model loaded while dictation is enabled (RAM cost below),
  with optional "unload after N min idle" for 8GB Airs.

### Performance budget (MacBook Air M1/M2, 8GB base model)
| Metric | Target | Basis |
|---|---|---|
| RAM with Apex q5_0 loaded | ≤ 1.2 GB | 574MB weights + KV/scratch |
| RAM with Swift (72M) loaded | ≤ 250 MB | free tier default |
| Keypress → recording starts | < 50 ms | pre-warmed AVAudioEngine |
| Release → text inserted (15s utterance, Apex) | ≤ 1.5–2.5 s | turbo-class ≈ 10–30× realtime on M-series Metal |
| Release → text inserted (Swift model) | ≤ 0.5 s | base-class is ~100× realtime |
| Long dictation (2–3 min) | no worse than MacWhisper | chunked background pre-transcription (Phase 3) |

---

## 5. Phases

### Phase 0 — Model validation spike (Python; ~3–5 days) ← DO THIS FIRST
Kills or confirms the core bet before any Swift is written. Plays to your strengths.

1. `uv init` a `spike/` dir; deps: `transformers`, `torch`, `jiwer`, `soundfile` (ask-first rule: these are the only installs, all standard).
2. **Build a personal eval set**: record 40–60 clips of YOUR real dictation (MacBook mic,
   natural pace, pauses, tech vocabulary): ~20 Hinglish, ~10 pure Hindi, ~10 Indian
   English, ~10 hard cases (code terms, names, numbers). Hand-write reference transcripts
   the way YOU would type them on WhatsApp. This eval set is a durable asset.
3. Transcribe every clip with: Apex, Prime, Swift, Trelis-hinglish, stock large-v3-turbo
   (= the MacWhisper baseline), zero-stt-hinglish.
4. Score: (a) normalized WER (lowercase, strip punctuation, collapse spelling variants
   via a small Hinglish normalization map), (b) blind A/B preference ranking by you —
   for Hinglish, preference matters more than WER.
5. Measure single-utterance latency for Apex-class model via whisper.cpp on your machine:
   convert with `models/convert-h5-to-ggml.py`, quantize q5_0/q8_0, run `whisper-cli`
   on the eval clips; log realtime factors.
6. **Gate**: Apex (or Trelis) must beat stock large-v3-turbo on Hinglish preference
   decisively AND run ≥5× realtime quantized on your Air-class target. If yes → build.
   If no → fallback plan: LLM post-processing pipeline (stock Whisper `hi` output →
   local LLM transliteration to Hinglish) — slower, evaluate before committing.

**Deliverable:** `spike/RESULTS.md` with tables + the chosen default model.

### Phase 1 — Core dictation MVP (Swift; ~2–3 weeks)
Goal: hold hotkey → speak Hinglish → release → text lands in any app. Ugly is fine.

1. Xcode project: SwiftUI app, `MenuBarExtra`, no dock icon (`LSUIElement`).
   *(Frontend note: `MenuBarExtra` is SwiftUI's declarative wrapper for a status-bar
   item — think "component that renders into the menu bar instead of a window".)*
2. Integrate whisper.cpp via SPM/XCFramework; implement `WhisperCppEngine` conforming
   to `TranscriptionEngine`; hardcode the Phase-0-winning GGML model bundled or
   side-loaded from disk.
3. `AudioCapture`: AVAudioEngine tap → 16kHz mono conversion → buffer. Mic permission flow.
4. `HotkeyManager`: CGEventTap push-to-talk on a fixed key first (e.g. right-⌥);
   Esc-to-cancel. Input Monitoring + Accessibility permission flow.
5. `TextInserter`: pasteboard-swap + ⌘V synthesis, pasteboard restore.
6. Minimal overlay: tiny non-activating NSPanel with a red dot (recording) / spinner
   (transcribing). Start/stop/cancel sounds.
7. **Acceptance test**: dictate a Hinglish WhatsApp-length message into Notes, Slack,
   Chrome, VS Code, and a terminal. Dogfood daily from here on — replace MacWhisper
   for yourself. That daily irritation list is the real backlog.

### Phase 2 — Language modes + model manager (~2 weeks)
1. `ModelManager`: download models from HF (URLSession, resume, SHA256 verify) into
   `~/Library/Application Support/DesiDictation/models/`; model picker UI with size/
   speed labels ("Swift — fast, 150MB" / "Apex — best, 850MB").
2. Language mode switcher (menu bar + per-mode hotkey option): Hinglish / English /
   Hindi. Under the hood: model + language-token routing per §1 table.
3. Settings window (SwiftUI `Form` + `KeyboardShortcuts` package by sindresorhus for
   recordable hotkeys — the standard, battle-tested choice): hotkey, push-to-talk vs
   toggle, sounds on/off, launch at login (`SMAppService`).
4. **User dictionary / replacements**: user-defined text rules applied post-transcription
   ("nahin→nahi", proper nouns, company names). Cheap to build, disproportionately
   valuable for Hinglish spelling consistency — this is a differentiator MacWhisper
   only approximates with AI prompts.

### Phase 3 — UX parity & polish (~2–3 weeks)
1. Long-dictation handling: chunk audio at silence boundaries (simple energy-based VAD)
   and pre-transcribe completed chunks in the background while the user keeps talking →
   on release, only the tail is pending. Matches MacWhisper's "keep talking, take
   breaks" behavior with near-instant insert.
2. Optional **AI cleanup** (off by default): pipe transcript through a prompt before
   insertion — punctuation, filler removal, tone. Providers: **Ollama (local, free)**
   first-class; OpenAI/Anthropic/Gemini bring-your-own-key later. Hinglish-aware
   default prompt ("preserve Roman-script Hindi words; do not translate").
3. App-specific behavior (MacWhisper's app-specific prompts, our version): per-app
   mode/prompt overrides via `NSWorkspace.frontmostApplication` bundle ID.
4. Onboarding flow: permissions walkthrough + model download + hotkey pick + a guided
   first dictation. (MacWhisper ships an explainer video; we should too.)
5. Menu bar niceties: last-transcript re-copy, history of last N dictations (local
   SQLite/GRDB, optional & purgeable — privacy is a selling point).

### Phase 4 — Ship it (~2 weeks)
1. **Licensing**: Gumroad License API (`POST api.gumroad.com/v2/licenses/verify`,
   `product_id` + `license_key`), activate once, cache locally, offline grace period,
   seat-count check via `uses`. Free tier = Swift model + core dictation. Pro (one-time)
   = Apex/Prime models, AI cleanup, app-specific overrides, user dictionary sync.
2. **Distribution**: Apple Developer ID ($99/yr — the one unavoidable cost), hardened
   runtime, `codesign` + `notarytool` notarization, DMG via `create-dmg`, **Sparkle**
   for auto-updates (appcast on GitHub Pages).
3. Crash/analytics: none, or privacy-safe TelemetryDeck (what MacWhisper uses) —
   "no data leaves your Mac" must stay literally true for audio.
4. Landing page + Gumroad listing: demo GIF of Hinglish dictation into WhatsApp Web —
   that one GIF is the entire pitch. Pricing: free tier + Pro at **₹999–₹1,499 / ~$15–19**
   one-time (undercut MacWhisper's €59; Indian purchasing-power pricing via Gumroad PPP).
5. Legal hygiene: clean-room feature parity is fine; do NOT reuse MacWhisper assets,
   strings, sounds, or name ("Whisper" in the app name is also risky — OpenAI trademark;
   pick a distinct brand, e.g. something desi).

### Phase 5 — Post-launch roadmap (demand-driven)
WhisperKit/ANE backend (battery) → mixed-script mode (zero-stt-hinglish / Srota via MLX)
→ file transcription → other Indic languages (Tamil/Telugu/Bengali fine-tunes exist on
HF) → meeting recording. Each is a separate MacWhisper feature we consciously deferred.

---

## 6. Risks & mitigations
| Risk | Likelihood | Mitigation |
|---|---|---|
| Apex quality disappoints on YOUR voice/use-case | Medium | Phase 0 gate before any app code; Trelis + LLM-post-processing fallbacks |
| Hinglish spelling inconsistency annoys users | High | User dictionary (P2), normalization map, AI cleanup |
| GGML conversion hiccup on fine-tune | Low | Well-trodden path; test in Phase 0 step 5 |
| 8GB Air thermals/RAM with 0.8B model | Medium | q5_0 quant, Swift model default for free tier, idle unload |
| Text insertion breaks in specific apps (Electron, terminals) | High (long tail) | Layered fallbacks (paste → AX → keystrokes); dogfooding; per-app overrides |
| Swift/macOS learning curve (you're Python-first) | Medium | Phase 0 in Python; Swift surface is small & well-documented; whisper.cpp does the heavy lifting in C |
| MacWhisper adds Hinglish support | Low-Medium | Speed + focus: Indian languages roadmap, INR pricing, community |
| Oriserve model updates/removal | Low | Apache 2.0 → mirror weights to your own HF repo on day 1 |

## 7. Cost summary
- Apple Developer Program: **$99/yr** (only hard cost)
- Models: free (Apache 2.0) · Inference: free (whisper.cpp MIT)
- Gumroad: 10% + payment fees per sale · Landing page: GitHub Pages, free
- Total to launch: **≈ $99 + your time (~7–10 weeks part-time)**

## 8. Immediate next actions
1. [ ] Phase 0 spike: eval set + model shootout (`spike/`)
2. [ ] Convert Apex → GGML q5_0, benchmark on this Mac
3. [ ] Decision gate: RESULTS.md review → go/no-go on Swift build
4. [ ] Mirror chosen model weights to own HF repo
5. [ ] Pick a brand name (trademark-safe, desi, memorable)
