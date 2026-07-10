# "English — from any language ✨" — implementation

**Spec:** features/TRANSCRIBE_TRANSLATE.md. **The pitch:** speak Hindi /
Hinglish / broken English; what pastes is polished written English. Not a tool
— a *mode*, sitting in the Language picker beside Hinglish/English/हिन्दी.

## What it's made of (mostly pipeline wiring — the plan doc called it)

- **`LanguageMode.anyToEnglish`** (TranscriptionEngine.swift) — new case.
  `whisperLanguage == "en"`, `needsLLM == true`, display name
  "English — from any language ✨". Appears automatically in every Language
  picker (menu, Dictation pane, per-app rules) because they iterate `allCases`.
- **Model routing** (ModelManager.swift) — scores exactly like `.hinglish`
  (Apex wins: it hears the mixed speech best; the *English* comes from the LLM
  stage, not the ASR). `catalogEntry(for:)` maps onboarding/downloads to Apex.
- **Pipeline** (DictationController.swift) — `finishPipeline` runs after
  transcription + replacements + dictionary: for `needsLLM` modes it sets the
  new **`.translating`** phase and calls
  `LLMServices.shared.translator.translate(text, to: .english)`.
  - Success → `deliver(text: english, raw: hinglish)` — history stores BOTH
    (the HistoryView "heard:" line; Report-email includes both).
  - Any failure → `deliver(text: raw)` + transient "Translation failed —
    pasted your original words." **The user's words are never lost.**
- **Two-stage overlay** (OverlayPanel.swift) — "Transcribing" then
  "Translating ✨" as distinct stages, so the longer wait is legible
  (spec §3.4). Menu bar icon shows `sparkles` during the stage.
- **Setup guidance** — if the mode is selected but the LLM isn't ready:
  menu shows "⚠️ Finish AI setup (one-time)…" (deep-links to the AI pane via
  `MainNav`), and the Dictation pane shows an inline caption. Until set up,
  dictations paste as heard — the mode degrades to Hinglish, never to nothing.

## Latency & memory reality (M3, 16 GB, gemma3:4b)

- Translation stage: ~2–5 s warm for 1–3 sentences (first call after idle can
  hit ~8 s while Ollama loads the model). Chunked transcription means the ASR
  work is mostly done at key-release, exactly as before.
- Memory: Apex q5_0 (~570 MB, in-process) + gemma3:4b (~3.5 GB, in Ollama's
  process). On 8 GB Macs the RAM-gated default drops to qwen2.5:1.5b — quality
  is honestly worse on code-mix (spike table in LLM_ENGINE.md).

## What Whisper's own `translate:true` flag would have given us

The plan doc said "test it in the spike; expect it to fail on Hinglish." We
route around it entirely: Apex is a transcription fine-tune (its translate path
is untrained), and the LLM stage measurably handles idiom/lakh-numbers that
X→en Whisper decoding does not. Revisit only if a translate-tuned Indic ASR
model ships.

## Changing it

- Different target register: it's one template (`translate.english` in
  PromptTemplates — overridable via prompts.json without rebuild).
- Speak-X-write-हिन्दी as a mode: add a `LanguageMode` case with
  `needsLLM`-style routing to `.hindi` target — the stage is target-agnostic.
- Tone × translation composition: deliberately NOT composed in v1 (translation
  already produces professional English; stacking two rewrites doubles latency
  and drift risk). If wanted: chain `applyTone` after translate in
  `finishPipeline`.
