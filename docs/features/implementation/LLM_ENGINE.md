# LLM Engine — the shared foundation (how it's built)

Every AI feature (translate ×2, structure, tone) rides ONE engine and ONE
downloaded model — the shared-spike design from TRANSLATION.md §4. This doc is
the map of that layer.

## The pieces (all in `app/Sources/DesiDictationKit/`)

| File | What it is |
|---|---|
| `LocalLLM.swift` | The protocol (`model`, `status()`, `generate(system:user:)`) + shared enums: `TargetLanguage`, `OutputStyle`, `LLMError`, `LLMStatus`. Mirrors how `TranscriptionEngine` abstracts whisper. |
| `OllamaLLM.swift` | The only backend today: HTTP to `127.0.0.1:11434` (`/api/chat`, temperature 0.2, non-streaming). Also `pull(progress:)` — streams `/api/pull` JSONL so the app can download models inline with a progress bar, and `stripReasoning` which removes `<think>…</think>` blocks so reasoning models never leak deliberation to users. |
| `PromptTemplates.swift` | Every system prompt, in code, each overridable **without rebuild** via `~/Library/Application Support/DesiDictation/prompts.json` (keys like `translate.english`, `structure.notes`, `tone.respectful`). Also defines `ToneMode`. |
| `TranslationEngine.swift` | `TranslationEngine` protocol + `LLMTranslationEngine`: paragraph-aware chunking for >4,000-char inputs (`chunks(of:budget:)` is public+pure for tests). |
| `ThoughtStructurer.swift` | `structure(transcript, style) → StructuredThoughts{raw, structured, style}`. Inputs >12k chars (~15 min speech) are capped at a word boundary and the tail is appended verbatim under "Beyond the 15-minute mark" — words are never silently dropped. |
| `LLMServices.swift` | The singleton wiring: owns the backend, rebuilds it on model change, exposes `translator`/`structurer`/`applyTone`, publishes `status` + `pullProgress`, and computes the RAM-gated default model. |

## The model decision (spike, 2026-07-10 — re-run it before changing defaults)

Method: 8 real Hinglish sentences through `desi-cli --translate` (which
exercises the exact app code path). Verdict per model:

| Model | Size | Result |
|---|---|---|
| qwen2.5:1.5b-instruct | ~1.0 GB | ✗ dropped "kal", inverted "thoda adjust kar lena" (wrong subject), nonsense on "scene kya hai", broke "do lakh pachaas hazaar" |
| qwen2.5:3b | ~1.9 GB | ✗ "tomorrow"→"today", "2,50,000"→"25,000 units", literal "What scene is there" |
| **gemma3:4b** | ~3.3 GB | ✓ all 8 faithful and natural, incl. lakh-numbers, idiom ("What's your plan for this evening?"), and correct subject in requests |

This matches TRANSCRIBE_TRANSLATE.md §7's research (Gemma-3-4B-class = COMET
parity for code-mix). Hence `LLMServices.defaultModel`:

```
physicalMemory ≥ 12 GB → "gemma3:4b"        (needs ~3.5 GB resident)
else                   → "qwen2.5:1.5b-instruct"  (honest fallback, simple sentences only)
```

Users can override in **AI tab → Model (advanced)** (stored as `llmModel` in
UserDefaults, applied via `LLMServices.modelChanged()`).

## How a request flows

```
caller → LLMServices.shared.translator/structurer/applyTone
       → LLMTranslationEngine / ThoughtStructurer (chunking, capping, templates)
       → LocalLLM.generate(system:, user:)          ← protocol boundary
       → OllamaLLM: POST /api/chat {model, messages, temperature 0.2}
       → stripReasoning → trimmed text, or a typed LLMError
```

Failure philosophy: **the transcript is sacred**. `applyTone` swallows errors
and returns the original; the anyToEnglish pipeline catches errors and pastes
the raw words with an explanation; Translate-on-Demand shows the error while
the source stays in the editor. No LLM failure can lose or block dictation.

## Setup UX (why users never see a terminal)

`LLMStatus` drives inline guidance everywhere an AI feature surfaces:
`.serverDown` → "install/open the free Ollama app", `.modelMissing` → a
one-click **Get AI model** button that calls `OllamaLLM.pull` with a progress
bar (same pattern as ASR model downloads in ModelManager). Copy is
plain-language by design (Rekha test, PERSONAS.md).

## How to change things

- **Tweak a prompt without rebuilding**: drop the key into
  `~/Library/Application Support/DesiDictation/prompts.json`; ship the change
  later by editing `PromptTemplates.swift`.
- **Swap in vendored llama.cpp later**: implement `LlamaCppLLM: LocalLLM`,
  construct it in `LLMServices` instead of `OllamaLLM`. Callers don't change.
  (Watch out: llama.cpp bundles ggml, and so do our whisper static libs —
  resolve the duplicate-symbol question in a spike first.)
- **Add an LLM feature**: template in `PromptTemplates`, thin method on
  `LLMServices`, call it from wherever. Tone (`applyTone`) is the 30-line
  reference example.
- **Change timeouts/temperature**: `OllamaLLM.init(timeout:)` and the
  `options` dict in `generate`.
