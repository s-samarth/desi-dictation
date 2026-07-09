# Feature: Translate on Demand

## 1 · Explainer

Any text the user has — most importantly their **last dictation** — can be translated into a language of their choice (English or Hindi to start). Two entry points:

- **In the app**: open the last dictation (or any history entry), **edit it first** if the transcription needs fixing, then hit *Translate → English / हिन्दी*. The result replaces the clipboard (and optionally pastes).
- **Anywhere on the Mac** (later phase): select text in any app → right-click → *Translate with Desi Dictation* (macOS Services menu), or a hotkey that translates the current selection.

Translation runs **fully on-device**, same promise as transcription. Nothing leaves the Mac.

The key design decision: **edit-then-translate is a first-class flow**, not an afterthought. Hinglish transcription will have errors; letting the user fix "meating" → "meeting" *before* translating means the translation is built on what they actually meant. Garbage in, garbage out — we give them the "in" to fix.

## 2 · The user

Primary: **the confident-understander, hesitant-writer** (see PERSONAS.md — Rekha, Aman). They understand English perfectly well — menus, movies, work email — but *producing* correct, formal English is slow and stressful. They speak in Hindi/Hinglish because that's where they're fluent; they need output in English because that's what the recipient (boss, client, government portal, ChatGPT) expects. The reverse also exists: someone drafts in English but wants to send शुद्ध हिन्दी to a parent or a community group.

Pain today: they type Hinglish into Google Translate in a browser tab, fight with its romanization guessing, copy-paste back. Three apps, four steps, and their text just went to Google's servers.

## 3 · User flow

### Flow A — fix and translate the last dictation (v1)
1. User dictates: *"kal ka presentation postpone karna padega kyunki client ne naya data bheja hai"*
2. Menu bar mic → **"Last dictation…"** → a small editor window opens with the transcript.
3. User fixes any transcription mistakes inline (plain TextEditor, nothing fancy).
4. Clicks **Translate → English**. Below the original, the translation appears: *"We'll have to postpone tomorrow's presentation because the client has sent new data."*
5. The translation can itself be edited. **Copy** puts it on the clipboard; **Paste** inserts it at the cursor of the previous app.
6. Original stays in History; the translation is attached to that history entry (local only, same 24 h rule).

### Flow B — translate any selection (v2, after v1 proves demand)
1. User selects text in Mail/WhatsApp Web/anywhere.
2. Right-click → Services → **Translate to English (Desi Dictation)** — or presses a configurable hotkey.
3. Translation appears in the overlay capsule + on the clipboard. Cmd+V to use it.

Failure states follow the house rule (never require quit/reopen):
- Translation model not downloaded → button shows "Get translation model (X MB)" inline, downloads with progress, then translates.
- Model produces garbage/empty → show "Translation failed — original is still on your clipboard", auto-reset.

## 4 · Technical plan

### Model choice (the decision that gates everything)
We need on-device Hinglish/Hindi ↔ English translation. Candidates, in preference order:

1. **Small instruction LLM via llama.cpp** — Qwen2.5-1.5B/3B-Instruct or Gemma-2-2B, Q4_K_M GGUF (~1–2 GB). Handles *Hinglish* (Roman-script code-mixed) far better than dedicated MT models, which expect clean Devanagari Hindi. Prompted: "Translate to natural English. Preserve meaning, fix nothing else." Also reusable for Structure-Your-Thoughts — **one model, two features** — which is why this is the recommended path.
2. **IndicTrans2** (AI4Bharat, 200M–1B) — best-in-class hi↔en quality, but expects Devanagari input, so Hinglish would need a transliteration pre-pass (error-prone); ONNX/CT2 runtimes, new dependency.
3. **Apple's Translation framework (macOS 15+)** — zero download, but Hindi support and Hinglish handling are weak, and it raises our OS floor. Rejected for now.

Spike first (like the original model spike): 20 real Hinglish sentences → each candidate → eyeball quality. The spike decides; don't commit in this doc.

### Architecture
- New `DesiDictationKit/TranslationEngine.swift` protocol mirroring `TranscriptionEngine`: `translate(_ text: String, to: TargetLanguage) async throws -> String`.
- `LlamaCppEngine` implementation: vendor llama.cpp the same way whisper.cpp is vendored (`scripts/setup_whisper.sh` pattern → `setup_llama.sh`), static libs, Metal embedded. Load lazily on first translate; unload after idle timeout (memory: Air with 8 GB is the constraint — never hold Whisper large + LLM simultaneously; translate happens *after* transcription completes, so we can borrow that headroom, but add an explicit "unload whisper if RAM-tight" path if needed).
- `ModelManager`: add a `translation` catalog entry (SHA-pinned, HF `SamarthBuilds/desi-dictation-models`, same Downloader).
- UI: new `LastDictationWindow` (AppKit-managed via `AppWindows`, like main/onboarding) with editor + translate buttons; `MenuContent` gets "Last dictation…" item; `HistoryStore.Entry` gains optional `translation` field.
- Services menu (v2): `NSServices` entry in Info.plist + `NSApp.servicesProvider` — well-trodden macOS API, no new permissions.

### What both translation features share
This engine, the model download, and the prompt templates are shared with TRANSCRIBE_TRANSLATE.md — build the engine once, both features are thin UI on top.

## 5 · Rollout & feedback

- **Phase 0 (spike, ~2 days)**: CLI-only — `desi-cli --translate` over 20 saved Hinglish transcripts. Decide the model. Share before/after samples in the beta WhatsApp group: "would you use this?"
- **Phase 1 (beta)**: Flow A only, behind a Models-tab download (opt-in by nature — no model, no feature; nobody's app gets heavier without consent). Ship in a `beta-0.6.x` release; beta guide gets a section.
- **Phase 2**: right-click Services + hotkey, once Flow A quality is confirmed.
- **Feedback under no-telemetry**: extend *Report Last Transcription* to *Report Last Translation* (pre-filled mailto with source + output, user sees everything before sending). Ask the WhatsApp group two concrete questions: "did you edit before translating?" and "did you send the English somewhere real?" — the second is the adoption signal.

## 6 · What makes it good

- **Trustworthy output**: a user sends the translation to their boss *without rewriting it*. That's the bar — measured by beta testers self-reporting "I sent it as-is".
- **Faster than the Google Translate tab**: select/edit → translated on clipboard in under ~3 s for a 2–3 sentence message.
- **Handles real Hinglish**, not textbook Hindi: *"thoda adjust kar lena yaar"* must not become nonsense.
- **Privacy story intact**: we can still say, truthfully, "nothing ever leaves your Mac" — this is the differentiator vs. every cloud translator.
- Kill criteria: if the spike shows no local model translates Hinglish acceptably on an M1 Air, park the feature rather than ship a bad one — a wrong translation sent to a boss is worse than no feature.
