# Model routing — one language, one default model (v0.6.1)

**The complaint this fixes:** "Why do I pick English at the top of the app and
then have to go find a model that supports English? That looks bad."

It was right. 0.6.0 had **one global model pin** and a picker listing every
installed `.bin`, including models that cannot produce the selected script at
all. The user was doing the app's job.

## The rule

**Choosing a language is the user's job. Choosing the model that serves it is
ours.**

1. Every language keeps **its own default** (`SettingsStore.modelPaths`, keyed
   by `LanguageMode.modelKey`). Switching language switches model silently.
2. Every model picker is **scoped to the language above it** — only models that
   serve it are listed (`ModelManager.candidates(for:)`).
3. **Auto names its choice** ("Auto (parakeet-tdt-0.6b-v3-q4_k)") — a default
   you can't see is a default you don't trust.
4. Changing language **preloads** the new model, so the swap never lands inside
   the transcribing phase (PERF_RCA_2026-08.md RC5). Per-app rules do this too.

## Where it lives

| Piece | File |
|---|---|
| Per-language pins + migration | `SettingsStore.modelPaths`, `modelPath(for:)`, `setModelPath(_:for:)` |
| Which models serve which language | `ModelManager.score(_:for:)` → `candidates(for:)`, `autoChoice(for:)` |
| Menu-bar picker (scoped, per language) | `MenuContent.swift` |
| Settings → Models → "Default model per language" | `DefaultModelSettings.swift` |
| Main window picker | `DictationPane.swift` |
| Engine chosen from the model file | `EngineRouter.swift` |

## The scoring rules (why a model is hidden)

- **Hinglish fine-tunes score 0 for हिन्दी** — they can only emit Roman script.
- **Parakeet scores 0 everywhere except English** — v3 covers English + 24
  European languages, has no Hindi, and cannot write Devanagari or
  Roman-Hinglish (MODEL_RESEARCH.md §E).
- `anyToEnglish` shares the **Hinglish** pin: it transcribes as Hinglish and
  gets its English from the LLM stage, so a separate default would be a second
  thing to keep in sync.
- Quantized variants beat f16/f32 (`+5`), so a q5_0 file wins ties.

Ordering inside a language is a plain integer score, all in one `switch` — if a
model should be preferred, that is the only place to say so.

## Migration (0.6.0 → 0.6.1)

The old single `modelPath` can only have been meant for the language the user
was last dictating in, so on first launch it moves into **that** language's slot
and nowhere else. Everything else starts on Auto. Covered by
`DesiTests/ModelRoutingTests.swift`.

## Two engines, one protocol

`EngineRouter` conforms to `TranscriptionEngine` and picks the concrete engine
from the model **filename** (`parakeet` → `ParakeetEngine`, otherwise
`WhisperCppEngine`). It keeps **exactly one model resident** — two ~500 MB
models in RAM on an 8 GB Air is not a trade we make — so switching language
unloads the outgoing model before loading the incoming one.

`desi-cli` uses the router too, so the eval harness and the latency gate
exercise the same path the app does.
