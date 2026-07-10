# Feature Implementation Docs — the 0.6 feature wave (built 2026-07-10)

The *plan* docs one level up ([TRANSLATION.md](../TRANSLATION.md),
[TRANSCRIBE_TRANSLATE.md](../TRANSCRIBE_TRANSLATE.md),
[STRUCTURE_THOUGHTS.md](../STRUCTURE_THOUGHTS.md), [IDEAS.md](../IDEAS.md)) say
*what and why*. These docs say **how each feature is actually built, what it
uses, and where to reach in when you want to change it.** One doc per feature,
written to be read two months from now.

## What was built (all tested — `swift run desi-tests`, 76 assertions green)

| Feature | Spec source | Implementation doc |
|---|---|---|
| Local LLM engine (the shared foundation) | TRANSLATION.md §4 | [LLM_ENGINE.md](LLM_ENGINE.md) |
| Personal dictionary | P4-S1, IDEAS #3, PATTERNS §1 | [PERSONAL_DICTIONARY.md](PERSONAL_DICTIONARY.md) |
| Per-app language modes | IDEAS #4, PATTERNS §1 | [PER_APP_MODES.md](PER_APP_MODES.md) |
| Translate on Demand (edit → translate) | TRANSLATION.md Flow A | [TRANSLATE_ON_DEMAND.md](TRANSLATE_ON_DEMAND.md) |
| "English — from any language ✨" mode | TRANSCRIBE_TRANSLATE.md | [SPEAK_DESI_WRITE_ENGLISH.md](SPEAK_DESI_WRITE_ENGLISH.md) |
| Structure my thoughts (beta) | STRUCTURE_THOUGHTS.md | [STRUCTURE_THOUGHTS_IMPL.md](STRUCTURE_THOUGHTS_IMPL.md) |
| Tone modes (Faithful/Casual/Professional/Respectful) | IDEAS #1, PATTERNS §1 | [TONE_MODES.md](TONE_MODES.md) |
| Test harness + how everything is verified | — | [TESTING.md](TESTING.md) |

## What was deliberately NOT built, and why

1. **Vendored llama.cpp engine** (TRANSLATION.md §4's long-term preference).
   The LLM backend is **Ollama** for now. Reasons: (a) llama.cpp and our
   vendored whisper.cpp both bundle ggml — linking two copies of ggml static
   libs into one binary is a duplicate-symbol/version-skew minefield that needs
   its own careful spike (the plan doc itself says "spike first, don't commit");
   (b) Ollama was already integrated (the AI-cleanup feature) and runs fully
   on-device, so the privacy promise holds; (c) new-dependency decisions are
   Samarth-approval-gated by repo convention. The swap stays cheap: everything
   rides the `LocalLLM` protocol — a future `LlamaCppLLM` is one new file plus
   one line in `LLMServices`. **Consequence users feel:** AI features need the
   free Ollama app installed; the AI tab explains it in plain words.
2. **Flow B of Translate on Demand** (right-click any selection → Services
   menu). Plan doc explicitly sequences it *after* Flow A proves demand (v2).
3. **Streaming structured output into the window** (STRUCTURE_THOUGHTS.md
   latency idea). Deferred: needs llama.cpp streaming; Ollama's chat endpoint
   is used non-streaming for simplicity. Restyle latency is seconds, acceptable.
4. **Auto-learning dictionary** ("learns" from corrections automatically).
   v1 is explicit-add only (History right-click / Settings) — silent learning
   without UX for review contradicts the trust posture.

## Re-validation round (2026-07-10, same day — after holistic testing)

A second pass tested the features end-to-end (`desi-cli --e2e`: wav →
whisper → dictionary → translate) and re-validated the model choice against
6 smaller/newer candidates (matrix in LLM_ENGINE.md). It produced fixes:

1. **Homograph-aware prompt** — ASR spells Hindi as English lookalikes
   ("die hain" = diye hain, "ke beach" = beech); the translate prompt now
   teaches this class + date words (parso ≠ Paris). Fixed 2 of 3 failing clips.
2. **`HindiNumbers` deterministic prepass** — every LLM ≤4B mangles
   "assi hazaar"-class figures; digits substituted before the LLM fix it for
   all of them (19 new tests).
3. **Esc during Translating/Polishing** now pastes the words as heard
   immediately (before: a hung LLM call held the pipeline up to 60 s with no
   exit).
4. **No fake "Polishing"** when the AI engine isn't ready — the stage is
   skipped instead of flashing and changing nothing.
5. **"Enable AI features" master switch** (AI tab, default on) — off = the
   classic dictation app: no AI menu items, no LLM modes, nothing to download.
6. **Small-Mac default model** qwen2.5:1.5b → qwen3:1.7b (matrix: the 1.5b
   hallucinates whole sentences; 1.7b + prepass is repairable), and
   `think:false` sent always.
7. Thinking-session overlay is now visibly distinct ("🧠 Thinking — take your
   time"); restyle races guarded in ThoughtsSession.

## Known quality limits (honest, with live repro examples)

- **Small-model translation**: the 2026-07-10 spike (see LLM_ENGINE.md) showed
  qwen2.5:1.5b/3b invert meaning and mangle lakh-numbers on code-mix;
  **gemma3:4b passes all 8 spike sentences** and is the default on ≥12 GB Macs.
- **ASR→LLM error compounding**: Apex wrote *"die hain"* (for *diye hain*) on an
  eval clip; gemma3:4b then read it as English *"die"* → translated "told us
  about" instead of "gave us". Exactly the gap TRANSCRIBE_TRANSLATE.md §7 says
  our own spoken-Hinglish eval set must measure. Mitigations shipped: raw
  transcript stored beside every AI output; edit-then-translate flow.
- **Structuring backtracks**: "hatana hai… nahi wait, rakhna hai" can still
  yield both versions in the output despite prompt rules (repro in
  STRUCTURE_THOUGHTS_IMPL.md). Feature is labeled (beta); raw transcript is
  always one disclosure-click away.

## One build-system note you'll hit

CLT 6.3.3 shipped a stale `*.private.swiftinterface` in its SwiftPM ManifestAPI
— `swift build` fails at the *manifest* link step until you export
`SWIFTPM_CUSTOM_LIBS_DIR` (details + fix script: BUILD_LOG.md FM#17).
