# Feature: Speak Desi, Write English (Transcribe → Translate)

## 1 · Explainer

A new dictation mode: the user speaks naturally — Hindi, Hinglish, broken English, all mixed — and what gets pasted is **polished, complete English**. No intermediate step, no user interference: hold key → speak → release → English appears.

This is different from Translate-on-Demand (TRANSLATION.md): there the user *asks* for a translation of existing text; here translation is part of the dictation pipeline itself. One is a tool, this is a *mode* — sitting next to Hinglish/English/हिन्दी in the language picker as **"English (from any language) ✨"** or similar.

The pasted English is normal text — the user can edit it after pasting like anything else.

## 2 · The user

The core insight (Samarth, 2026-07-08): **Indians understand English far better than they produce it.** A user prompting ChatGPT, writing a work email, or filling a form needs *complete, fluent English* — but their natural speech is Hinglish or broken English. Today they either type slowly and self-consciously, or dictate Hinglish and manually rewrite it.

The killer use case is **giving context to AI**: LLMs work best with rich, detailed prompts, and rich detail flows out of people in their mother tongue. Speak two minutes of Hinglish about your problem → get two paragraphs of clean English context to paste into ChatGPT/Claude. The user can verify it (they *read* English fine) — they just couldn't have written it that fast.

Secondary: work emails, LinkedIn posts, complaint letters, visa/government forms — anywhere "proper English" is socially expected.

## 3 · User flow

1. Menu bar mic → Language → **English (from any language)**. One-time: if the translation model isn't installed, the menu item triggers the download inline (progress in the overlay).
2. User clicks into the ChatGPT input box.
3. Holds Right ⌥, speaks: *"mujhe ek aisa script chahiye jo mere saare invoices ko padhe aur ek excel mein daal de, invoices PDF mein hain aur unka format har vendor ke liye alag hai"*
4. Releases. Overlay shows "Transcribing…" then "Translating…" (two stages visible, so slower total time is understood, not mysterious).
5. Pasted: *"I need a script that reads all my invoices and puts them into an Excel sheet. The invoices are PDFs, and each vendor uses a different format."*
6. Clipboard holds the English (house rule). **History stores both** the raw transcript and the English — so if the translation mangled something, the user can see what was heard vs. what was written, and use *Report Last Transcription* on either.

Failure handling (house rules apply):
- Translation stage fails → paste the raw transcript instead, overlay says "Translation failed — pasted the original". Never lose the user's words.
- Too-long input (>~2 min) → translate in chunks; worst case, same fallback.

## 4 · Technical plan

Reuses everything from TRANSLATION.md §4 — same `TranslationEngine`, same llama.cpp vendoring, same model download. Build order is therefore: engine + Translate-on-Demand first (easier to debug, user can see intermediate text), then this mode is mostly pipeline wiring:

- `LanguageMode` gains `.anyToEnglish` case. `resolveModel(for:)` maps it to **Apex** for the transcription stage (it handles the Hindi/Hinglish/English mix best); `catalogEntry(for:)` maps its "required models" to Apex + translation model.
- `DictationController`: after `transcribe()` returns, if mode == `.anyToEnglish`, run `translationEngine.translate(text, to: .english)` on the same serial workQueue before `TextInserter.insert`. New phase `.translating` for the overlay.
- **Chunked-transcription interaction**: today we transcribe ~12 s chunks while the user speaks. Keep that; run translation **once on the full assembled transcript** at release (translation needs whole-message context — sentence-by-sentence translation of code-mixed speech reads disjointed). Latency budget: transcription is already mostly done at release; a 1.5B Q4 model on Metal does ~40–80 tok/s, so a 60-word message ≈ 1.5–3 s of translation. Show the "Translating…" stage honestly.
- Prompt template (v1): system prompt fixing the task ("You translate mixed Hindi/English speech transcripts into natural written English. Output only the translation."), few-shot with 3 real examples. Keep templates in a resource file so they're tunable without rebuilds.
- **Memory (8 GB Air)**: Apex q5_0 ≈ 550 MB + 1.5B Q4 LLM ≈ 1 GB — coexists fine. Document the ceiling: if we ever offer a bigger LLM, gate it on RAM check.
- Whisper's own `translate: true` flag (built-in X→English) is the tempting shortcut — **test it in the spike**, but expect it to fail on Hinglish: Apex is fine-tuned for transcription output and Whisper's translate path produces stilted English from Hindi. If it's surprisingly good, we ship v0 with zero new dependencies. Cheap to check first.

### Eval before ship
Extend `evals/` with a small translation suite: 30 held-out Hinglish clips → pipeline → human-rated 1–5 adequacy/fluency (self-rated by us + 2 beta friends). No standard metric needed at this scale; a rubric doc in evals/ suffices. Gate: median ≥4 adequacy.

## 5 · Rollout & feedback

- **Spike (same spike as TRANSLATION.md)** answers: whisper's translate flag vs. LLM stage, model choice, latency on M1.
- **Beta as a visible mode with a ✨/(beta) suffix** in the picker — sets expectations that it's newer/rougher than the core modes.
- Beta guide gets a "Speak desi, write English" section pitching the ChatGPT-context use case explicitly — that's the demo that sells it in the WhatsApp group. Ask friends to try exactly that once and reply with a screenshot.
- Feedback: history keeps raw + translated side by side → *Report Last Transcription* email includes both automatically. The single question to ask testers: **"did you have to fix the English before using it?"**
- Ambient signal (no telemetry): translation-model download count on HF is a direct proxy for interest in both translation features.

## 6 · What makes it good

- **The two-minute-context test**: a user speaks freely for 2 minutes and pastes the result into an LLM *unedited*. If beta testers do this twice, they're retained — this becomes their default way of talking to AI.
- English is **natural written English**, not translationese: "I need to postpone" not "It is required by me to postpone".
- Total wait after release ≤ ~3 s for a normal message; the two-stage overlay makes longer waits legible.
- Meaning is never inverted or dropped — fallback-to-transcript on any doubt beats confident hallucination.
- It strengthens the brand line: *the only tool where your broken English becomes fluent English without your voice leaving your laptop.* Cloud tools (Wispr Flow etc.) can do this server-side; nobody else does it on-device for Indian speech. If quality hits the bar, this is arguably the headline feature, not an add-on.
