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
| Which models serve which language | `ModelScoring.swift` (`ModelManager.score(_:for:)`) → `candidates(for:)`, `autoChoice(for:)` |
| What can be downloaded, onboarding picks | `ModelCatalog.swift` (`catalog`, `catalogEntry(for:)`) |
| Verified download (SHA256, progress) | `ModelDownloader.swift` |
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
- **Hinglish: Prime (100) > Apex (90) > Swift (50).** Prime is the more
  accurate model on long, conversational takes (MODEL_RESEARCH.md §F) and
  became the default and onboarding download on 2026-10-28. It costs 1.82 s
  vs Apex's 1.42 s on the latency gate's short clip, inside the 2.0 s budget.
  Apex left the catalog. An Apex file already on disk still serves Hinglish
  if pinned, ranked below Prime.

Ordering inside a language is a plain integer score, all in one `switch` — if a
model should be preferred, that is the only place to say so.

## Migration (0.6.0 → 0.6.1)

The old single `modelPath` can only have been meant for the language the user
was last dictating in, so on first launch it moves into **that** language's slot
and nowhere else. Everything else starts on Auto. Covered by
`DesiTests/ModelRoutingTests.swift`.

## Three engines, one protocol (v0.6.3)

`EngineRouter` conforms to `TranscriptionEngine` and picks the concrete engine
from the model **filename**: `parakeet` → `ParakeetEngine`, `qwen3-asr` →
`QwenASREngine` (transcribe.cpp), otherwise `WhisperCppEngine`. It keeps
**exactly one model resident**, because two ~500 MB models in RAM on an 8 GB
Air is not a trade we make. Switching language unloads the outgoing model
before loading the incoming one.

## English: a fast default and an accurate option (v0.6.3)

| | Parakeet TDT v3 (default, score 120) | Qwen3-ASR-1.7B q8_0 (score 110) |
|---|---|---|
| nWER, Indian English, 278 clips clean / noisy | 14.3 % / 19.5 % | 12.6 % / 17.7 % (MLX run) |
| Short dictation, median | 0.09 s | ~0.35–0.45 s |
| Download | 416 MB | 2.08 GB |

Auto keeps **Parakeet**. Qwen is the pick when you want accuracy over speed:
choose it under the English model picker, or as the English default in
Settings. It replaced Whisper large-v3-turbo in the catalog. Turbo was less
accurate than Parakeet clean and noisy, at 10× its latency
(ENGLISH_ASR_AB_2026-10.md). A leftover turbo file still works and ranks below
Qwen.

**Qwen is English-only here.** `score()` returns 0 for Hinglish, हिन्दी and
any→English. The model can do Hindi, but those modes have their own
fine-tunes.

**Long audio is cut at pauses into pieces of 30 s or less** (`AudioSplitter`).
On the quick tier, one call over 45–110 s scored 40 % vs 32 % nWER in noise.
A decode that starts looping (`OUTPUT_REPETITION`) or hits its budget keeps
its partial text instead of failing the dictation.

`desi-cli` uses the router too, so the eval harness and the latency gate
exercise the same path the app does.
