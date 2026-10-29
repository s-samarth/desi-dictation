# "When it fits" — context checker (implementation)

**Status:** written 2026-10-28 in a Linux container, then built and measured
on a Mac (M3) the same day: see **Measured** below. Live dictation in the app
is still to be checked by hand: [handoff/MAC_HANDOFF_CONTEXT_FIT.md](../../handoff/MAC_HANDOFF_CONTEXT_FIT.md).
Plan and decisions: [VOCABULARY_NEXT.md](../VOCABULARY_NEXT.md) §1.

**Problem.** A dictionary pair is a hard rule. *cloud → Claude* is right in
"I asked cloud to refactor this" and wrong in "our data is in the cloud".
**Answer.** The pair can be **When it fits**: a small local model reads the
sentence both ways and keeps the likelier one. It **scores, never writes**,
so it can only pick between "cloud" and "Claude".

**Also used by Review before paste** (2026-10-29): the same model, through
`desi_lm_token_scores`, marks words that are odd in their sentence so the
review panel can underline them (English and हिन्दी). It still never
writes: [REVIEW_BEFORE_PASTE.md](REVIEW_BEFORE_PASTE.md) "Strictness".

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
   - swap when Δ + cues > `margin` (−1.0). No model or a failed score: swap
     only on a cue. A rejected pair (History → "Don't change…") is skipped.
5. Fixes carry source `.context` ("fits the sentence") into History and the
   overlay. Kept words are logged in "What it's been doing" with the reason.
6. **Undo** of a context fix is *not* a permanent rejection (unlike other
   fixes): it depends on the sentence. The log says how to switch the word
   to Always or remove it.

**The prompt** (`ContextFit.prompt`) is a neutral `Message:\n`. Listing the
user's words first (`Words I use: Claude, Kavya.\n`, `ContextFit.prefix`)
was the original plan; measured, it made the Base model swap "The cloud bill
went up" (Δ +3.8), so the app doesn't use it. `desi-cli --fit --word-list`
keeps it testable for the next model.

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
| Eval | `desi-cli --fit <model.gguf> evals/context_fit/cases.tsv [--word-list] [--cpu]` |
| Tests (fake scorer) | `DesiTests/ContextFitTests.swift` |

## Decisions

- **llama.cpp, not MLX or Ollama.** Ollama can't score a given sentence. MLX
  needs full Xcode to compile Metal shaders (BUILD_LOG line ~30); this repo
  builds with CLT. llama.cpp embeds its shaders and follows the
  transcribe.cpp bundle pattern (FM#34).
- **Always linked.** `libllama-bundle.a` is committed, like the whisper and
  transcribe archives, and `Package.swift` links it and defines `DESI_LLAMA`
  unconditionally. A file-exists check in the manifest never worked: SwiftPM
  caches the manifest's answer (BUILD_LOG FM#39). It adds 10.8 MB to the
  app binary (14.3 → 25.1 MB).
- **Freed before exit.** `shutdown()` resets the checker, and `--fit`
  frees its scorer before `exit`: ggml-metal asserts otherwise (FM#40).
- **Gated in the UI** on `ContextChecker.isReady` (runtime + model file). An
  entry already set to When it fits keeps its picker even if the model is
  removed, and then swaps only on cues.
- **English only.** Small models are weak on Roman Hinglish; revisit with a
  Hinglish set.
- **Model:** Qwen3-0.6B **Base** Q4_K_M (396.7 MB) from
  `mradermacher/Qwen3-0.6B-Base-GGUF`, pinned to commit `b8b11a6d…`,
  sha256 `1c728e4f…`. Base beat instruct on the eval (below).
- **Not built yet:** per-word ASR confidence. Its job here is to pick *which*
  words to check beyond dictionary pairs; it's the next step.

## Measured (2026-10-28, M3, `desi-cli --fit`, 42 cases: 21 swap, 21 keep)

| Model · prompt | Wrong swaps at shipped margin | Closest keep Δ | Accuracy at 0 / −1 / −2 | Median · max ms |
|---|---|---|---|---|
| **Base · neutral (shipped)** | **0 / 21** | **−5.22** | 90.5 / **92.9** / 97.6 % | **47 · 79** |
| Base · word list | 1 / 21 ("The cloud bill…", +3.79) | +3.79 | 90.5 / 95.2 / 92.9 % | 56 · 111 |
| Instruct · word list | 0 / 21 | −2.31 | 85.7 / 88.1 / 92.9 % | 55 · 107 |
| Instruct · neutral | 0 / 21 | −5.85 | 81.0 / 81.0 / 88.1 % | 46 · 162 |

Both Q4_K_M, Metal, model load 140–400 ms. **Margin −1.0**: all keep cases
sit at −5.2 or below, so −1 leaves 4 nats of room before a wrong swap while
catching one more swap than 0 would. At −1 the Base model still misses
"cloud code just opened a pull request" (−3.94), "Create a linear ticket"
(−1.75) and "Open the repo in cursor" (−1.38): a missed swap leaves the word
as heard, the cheap error. Cue bonuses (+3 on screen, +3 app name) come on
top. Re-run the table before changing model, prompt or margin.

The eval is small (42 sentences, 7 words), so these numbers pick between
settings; they don't promise 93 % on real dictation. Add every wrongly
judged real sentence to `cases.tsv`.

## Changing it

- `margin`, `screenBonus`, `appBonus`, `windowWords`: constants at the top
  of `ContextFit`. Re-run `desi-cli --fit` and keep **wrong swaps at 0**
  before loosening (a wrong swap is worse than a missed one).
- Add eval sentences to `evals/context_fit/cases.tsv` whenever a real
  dictation is judged wrong.
