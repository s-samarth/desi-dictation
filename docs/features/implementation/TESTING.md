# How the 0.6 features are tested

Constraint: the machine builds with Command Line Tools only — **no XCTest**.
So tests are a plain executable target with a micro assert-harness:

```bash
cd app
export SWIFTPM_CUSTOM_LIBS_DIR=~/.swiftpm-fixed-libs   # see BUILD_LOG FM#17
swift run desi-tests          # exit 0 = green; prints ✓/✗ per assertion
```

119 assertions as of 2026-08-19, all green. Files in `app/Sources/DesiTests/`:

| File | Covers |
|---|---|
| `TestHarness.swift` | `T.expect/equal/begin/finish`, temp-file factory (stores under test never touch real Application Support data) |
| `DictionaryTests.swift` | word-boundary matching, casing preservation (Meating/MEATING/gpt-4), latest-wins editing, persistence round-trip, legacy `replacementRules` regression |
| `ModelRoutingTests.swift` | v0.6.1: per-language model pins + migration from the old global pin; catalog lookup by id; language-scoped candidates (**Parakeet hidden outside English**, Hinglish models hidden for हिन्दी); engine routing by filename; chunk-threshold floors that keep a short dictation to one engine call |
| `StoreTests.swift` | AppModeStore rules+persistence; `anyToEnglish` contract (whisper token, `needsLLM`, **pinned raw values** — they live in UserDefaults/history JSON, renaming = data migration); model routing incl. "Hindi never gets a Hinglish model" regression; HistoryEntry decode of **pre-0.6 JSON** (backward compat) |
| `EngineTests.swift` | translation chunking invariants (budget respected, zero word loss), `MockLLM`-driven translate incl. failure propagation, structurer capping/overflow/zero-loss, `stripReasoning`, prompt-template sanity (every style forbids invention; faithful tone = nil) |
| `CombinationTests.swift` | the real pipeline order: legacy rules → dictionary → LLM stage; anyToEnglish failure→raw fallback; tone rides corrected text; structure carries exact raw; per-app rule × anyToEnglish (the Rekha flow) |

`MockLLM` makes every pipeline path deterministic — no server needed, and
failure paths are as testable as success paths.

## Live validation (real models — run when engine/prompts/models change)

Not part of `desi-tests` (network + model-dependent + slow); done via desi-cli
against the running Ollama:

```bash
.build/debug/desi-cli --translate "thoda adjust kar lena yaar, main paanch minute late ho jaunga" english
.build/debug/desi-cli --structure "<rambly hinglish>" notes|actionList|emailDraft|outline
# model override for comparisons:  defaults write desi-cli llmModel "qwen2.5:3b"
```

2026-07-10 results: gemma3:4b 8/8 spike sentences faithful; Hindi target
produces clean Devanagari; known limits recorded in implementation/README.md.

## ASR regression (the "don't run the whole eval suite" check)

One fixture through the real engine — verifies the whisper path end-to-end
after kit changes without the multi-minute eval run:

```bash
.build/debug/desi-cli ~/Library/Application\ Support/DesiDictation/models/ggml-hinglish-apex-q5_0.bin \
    evals/data/hinglish/clips/0000.wav hinglish
# 2026-07-10: exact Roman-Hinglish match vs manifest ref, 3× realtime — unchanged
```

The full `evals/` suite stays the pre-release gate; it was deliberately NOT run
in this build session (long runtime) per the goal's instruction.

## What is NOT covered by automated tests

- `DictationController` session states (hotkey/audio/phases) — needs mic +
  Input Monitoring; covered by the manual smoke checklist in USAGE.md §C.
- SwiftUI views — compile-checked only.
- `OllamaLLM` HTTP layer — exercised by the live CLI checks above, not mocked.
