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

## The model decision (full matrix 2026-07-10 — re-run before changing defaults)

Two rounds. Round 1 (8 sentences, `desi-cli --translate`): gemma3:4b beat
qwen2.5 1.5b/3b decisively. Round 2 (the re-validation matrix: 12 sentences ×
7 models via the exact production prompt, warm latency measured, harness at
`scratchpad/model_matrix.py` of session bc4d88f6):

| Model | Size | Median warm | Verdict |
|---|---|---|---|
| gemma3:1b | 815 MB | 0.8 s | ✗✗ hallucinates whole sentences ("Aadhaar mail", "Please stop talking to me") |
| qwen2.5:1.5b-instruct | 986 MB | 0.5 s | ✗✗ hallucinates ("trains exist only in your imagination") |
| **qwen3:1.7b** (think:false) | 1.4 GB | 0.6 s | ✗→△ homographs OK; numbers/negation fail — **numbers fixed by the digit prepass** → usable small fallback |
| qwen2.5:3b | 1.9 GB | ~1 s | ✗ number + literal-idiom errors |
| llama3.2:3b | 2.0 GB | 0.8 s | ✗ leaks prompt text into output, inverts meanings |
| **gemma3:4b** | 3.3 GB | 2.2 s | ✓ best overall — **default** |
| qwen3.5:4b (think:false) | 3.4 GB | 2.7 s | ✓ close second ("kal"→today, one number slip) |

**The finding that changed the architecture:** every model — including both
4Bs — mangled Hindi number-words ("assi hazaar" → 60k/10k) and date-words
("parso" → "Paris"/"Sunday"). But every model got the same sentences right
when digits were substituted first. So `HindiNumbers.normalize()` (a
deterministic spoken-Hindi number parser, lakh/crore grouping, ~40
false-positive guards tested) now runs BEFORE the LLM in both the translation
and structuring paths, and the prompt pins the date words. Rules fix what
model size cannot — that, not model routing, is the orchestration that works
at this scale. Residual known weakness: contrastive negation ("kal NAHI,
parso") still slips on 4B models — tracked for the spoken-Hinglish eval set.

`LLMServices.defaultModel`:

```
physicalMemory ≥ 12 GB → "gemma3:4b"   (~3.4 GB resident incl. context)
else                   → "qwen3:1.7b"  (1.4 GB; digit prepass covers its worst class)
```

`OllamaLLM` always sends `"think": false` (qwen3-family answers instead of
deliberating; non-thinking models ignore the key — verified on gemma3).

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
