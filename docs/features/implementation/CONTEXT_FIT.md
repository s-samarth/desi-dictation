# "When it fits" — context checker (implementation)

**Status:** code built 2026-10-28 (branch `claude/pensive-darwin-73oprx`),
**not yet run on a Mac**. Linux container: no Swift, Hugging Face blocked.
What's verified and what isn't: [handoff/MAC_HANDOFF_CONTEXT_FIT.md](../../handoff/MAC_HANDOFF_CONTEXT_FIT.md).
Plan and decisions: [VOCABULARY_NEXT.md](../VOCABULARY_NEXT.md) §1.

**Problem.** A dictionary pair is a hard rule. *cloud → Claude* is right in
"I asked cloud to refactor this" and wrong in "our data is in the cloud".
**Answer.** The pair can be **When it fits**: a small local model reads the
sentence both ways and keeps the likelier one. It **scores, never writes**,
so it can only pick between "cloud" and "Claude".

## How a dictation flows (English only)

1. **Key down** (`beginVocabulary`): if any English entry is When it fits,
   `ContextChecker.warmUp()` loads the model off-main (once; it stays warm).
2. **Exact pairs** (`PersonalDictionary.apply`) skip When it fits entries.
3. **Near-miss corrector** runs as before.
4. **`ContextFit.apply`** (pure, `Vocabulary/ContextFit.swift`), per
   whole-word match of `heard`, right to left so ranges stay valid:
   - window: up to 12 words either side;
   - Δ = log P(window with `written`) − log P(window with `heard`), each
     scored after the prompt;
   - cues: +3 if `written` is on screen (needs "Use names on screen"),
     +3 if the app's name contains it ("Claude");
   - swap when Δ + cues > `margin` (0). No model or a failed score: swap
     only on a cue. A rejected pair (History → "Don't change…") is skipped.
5. Fixes carry source `.context` ("fits the sentence") into History and the
   overlay. Kept words are logged in "What it's been doing" with the reason.
6. **Undo** of a context fix is *not* a permanent rejection (unlike other
   fixes): it depends on the sentence. The log says how to switch the word
   to Always or remove it.

**The prompt** (`ContextFit.prefix`) is one line, ≤ 10 words:
`Words I use: Claude, Kavya, Tazapay.\n` — When it fits words first, then
the newest dictionary words. Empty dictionary: `Message:\n`. Accepting a
fix adds its word to this line, which is how the model "learns" the user.

## Pieces

| Piece | File |
|---|---|
| `EntryMode` (Always / When it fits), `ContextScorer` protocol, `ContextFit` | `DesiDictationKit/Vocabulary/ContextFit.swift` |
| `LlamaContextScorer`, `ContextChecker` (model path, warm-up, keep loaded) | `DesiDictationKit/Vocabulary/ContextChecker.swift` |
| Third button logic (`canOfferWhenItFits`, `acceptWhenItFits`) | `Vocabulary/AutoVocabularyStore+Fit.swift` |
| Pipeline hook + logging | `DictationController+Vocabulary.swift`, `VocabularySession.Plan` |
| C scorer over llama.cpp (tokenize, one decode, log-softmax) | `native/desi_lm/desi_lm.cpp`, header `app/Sources/CLlamaScore/include/desi_lm.h` |
| Build: llama.cpp `b11900` + desi_lm, ggml hidden | `scripts/setup_llama.sh` → `app/Libraries/libllama-bundle.a` |
| UI: popup "Only when it fits", row "When it fits", per-word Always/When it fits picker, download row | `VocabularyPromptPanel.swift`, `SmartVocabularyView.swift`, `DictionaryView.swift`, `ContextCheckerView.swift` |
| Model download entry (outside the ASR catalog) | `ModelCatalog.swift` `contextCheckerEntry` |
| Eval | `desi-cli --fit <model.gguf> evals/context_fit/cases.tsv [--no-prefix] [--cpu]` |
| Tests (fake scorer) | `DesiTests/ContextFitTests.swift` |

## Decisions

- **llama.cpp, not MLX or Ollama.** Ollama can't score a given sentence. MLX
  needs full Xcode to compile Metal shaders (BUILD_LOG line ~30); this repo
  builds with CLT. llama.cpp embeds its shaders and follows the
  transcribe.cpp bundle pattern (FM#34).
- **Optional at build time.** `Package.swift` links the bundle and defines
  `DESI_LLAMA` only if the `.a` exists. CI stays green before the first Mac
  run; without it `LlamaContextScorer.isAvailable` is false and every When it
  fits control is hidden.
- **Gated in the UI** on `ContextChecker.isReady` (runtime + model file). An
  entry already set to When it fits keeps its picker even if the model is
  removed, and then swaps only on cues.
- **English only.** Small models are weak on Roman Hinglish; revisit with a
  Hinglish set.
- **Model:** Qwen3-0.6B Q4_K_M (~400 MB) from `unsloth/Qwen3-0.6B-GGUF`. URL
  and sha256 must be pinned on the Mac (download refuses an empty sha256).
  Whether the base model scores better than the instruct one is an eval
  question for the handoff.
- **Not built yet:** per-word ASR confidence. Its job here is to pick *which*
  words to check beyond dictionary pairs; it's the next step.

## Changing it

- `margin`, `screenBonus`, `appBonus`, `windowWords`: constants at the top
  of `ContextFit`. Re-run `desi-cli --fit` and keep **wrong swaps at 0**
  before loosening (a wrong swap is worse than a missed one).
- Add eval sentences to `evals/context_fit/cases.tsv` whenever a real
  dictation is judged wrong.
