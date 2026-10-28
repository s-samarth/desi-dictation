# Mac handoff — "Not now" fix + "When it fits" context checker

**PR:** https://github.com/s-samarth/desi-dictation/pull/14 · branch
`claude/pensive-darwin-73oprx`. Written 2026-10-28 by a cloud session on
Linux: **no Swift toolchain, Hugging Face blocked**. Delete this file once
every box below is ticked.

## What was and wasn't verified in the cloud

| Thing | Status |
|---|---|
| `native/desi_lm/desi_lm.cpp` compiles against llama.cpp `b11900` headers | ✓ `g++ -std=c++17 -fsyntax-only -Wall -Wextra`, no warnings |
| `scripts/setup_llama.sh` | `bash -n` only; never run (macOS-only `ld -r`, Metal) |
| Every Swift change, `desi-tests`, parity, preflight | ✗ never compiled. CI on the PR compiles with the llama code **compiled out** |
| `#if DESI_LLAMA` Swift code (`ContextChecker.swift`) | ✗ first compiled on your Mac, after step 3 |
| The model: URL, sha256, accuracy, latency | ✗ nothing run; the catalog sha256 is empty on purpose (download refuses) |

## Steps (in order; stop and fix at the first red)

```bash
export SWIFTPM_CUSTOM_LIBS_DIR=$HOME/.swiftpm-fixed-libs
source scripts/sdk_env.sh
git fetch && git switch claude/pensive-darwin-73oprx && git pull
```

1. **Baseline build (llama compiled out).** Check CI on the PR first.
   `(cd app && swift build) && app/.build/debug/desi-tests && ./scripts/check_parity.sh`.
   Expect new groups "Vocabulary — old 'two Not nows'…" and "Context fit —…".
2. **Pin the model.** Download `Qwen3-0.6B-Q4_K_M.gguf` from
   `unsloth/Qwen3-0.6B-GGUF` (or the closest ≤ 400 MB Qwen3-0.6B GGUF).
   Pin the URL to a commit (`/resolve/<sha>/…`, like the Qwen3-ASR entry),
   `shasum -a 256` it, and fill `ModelCatalog.swift` → `contextCheckerEntry`
   (`sha256`, real `approxMB`). Also fetch a **Qwen3-0.6B-Base** GGUF if one
   exists, for step 5.
3. **Build the runtime.** `./scripts/setup_llama.sh`. It must print
   "Leaked … none" and list `_desi_lm_load/_free/_score`. If llama.cpp's
   build layout differs, fix the script (paths of the `.a` files).
4. **Rebuild with llama.** `(cd app && swift build)` now defines `DESI_LLAMA`
   (Package.swift checks for `app/Libraries/libllama-bundle.a`). Fix
   compile errors in `Vocabulary/ContextChecker.swift`. Then `desi-tests`
   and **`./scripts/preflight.sh`** (latency gate unchanged: everything is
   off by default).
5. **Evaluate** (minutes, not the full evals):
   ```bash
   M=~/Downloads/Qwen3-0.6B-Q4_K_M.gguf
   app/.build/debug/desi-cli --fit $M evals/context_fit/cases.tsv
   app/.build/debug/desi-cli --fit $M evals/context_fit/cases.tsv --no-prefix
   # repeat both with the Base model if you have it
   ```
   Targets: **wrong swaps 0** on the 21 keep cases (a wrong swap is worse
   than a miss), accuracy ≥ 85 %, median ≤ 60 ms per sentence. Pick model +
   prefix-or-not + margin from the sweep; update `ContextFit.margin` (and the
   prefix if it hurts keep cases). If no setting reaches the targets, say so
   in the PR and keep the feature hidden: don't ship a guesser.
   Record the numbers in a "Measured" section of
   `docs/features/implementation/CONTEXT_FIT.md`.
6. **Live app.** `./scripts/build_app.sh && ditto "app/dist/Desi Dictation.app" "/Applications/Desi Dictation.app"`, relaunch.
   - Vocabulary → **When it fits** → Get. Installs, shows Installed.
   - Remove any exact *cloud → Claude* entry. Dictate "I asked cloud to fix
     this", retype cloud → Claude: popup shows **Only when it fits**; click it.
     Your words shows the row with a *When it fits* picker.
   - In Claude's chat box: "I asked cloud to refactor this function" → Claude;
     "our data is stored in the cloud" → cloud. History says "fits the
     sentence"; Vocabulary → What it's been doing explains kept words.
   - Undo a context fix in the field: log says it still decides per sentence,
     and the next dictation is judged again (not banned).
   - Hinglish mode: no third button, no context checks.
   - First dictation after launch: note the extra wait while the model
     loads. Activity Monitor: memory added (~0.4 GB expected).
7. **"Not now" fix (first commit).** Not now on a proposal → make the same
   fix again: the log says "asks again after 2 more fixes"; the 3rd time, the
   popup is back. Your own old `autovocab.json`: pairs two Not nows had
   banned are proposed again; Never-ed pairs stay banned.
8. **Commit** `app/Libraries/libllama-bundle.a`, the pinned catalog entry,
   any fixes, and the measured numbers; push to the same branch; get CI
   green; update the PR description; log new failure modes in BUILD_LOG.

## Known risks to watch

- The `Package.swift` file-exists check runs inside SwiftPM's manifest
  sandbox. If reading is blocked, `hasLlama` is always false: see whether
  `DESI_LLAMA` is defined after step 3 (`ContextChecker.isReady`).
- Three ggml copies in one process (whisper.cpp, transcribe bundle, llama
  bundle), each with its own Metal device: check the app and `desi-cli`
  both exit cleanly (FM#27, Metal teardown at exit).
- `desi_lm_score` uses `add_special = true`; Qwen3 adds no BOS, so a
  non-empty prompt is required (ContextFit always sends one).
- The first dictation after launch blocks on model load if the warm-up
  hasn't finished (`ContextChecker.loaded()` holds a lock while loading).
- Popup width went 460 → 580 for the third button; check it on a 13" screen.

## Next, once this is green (separate PR)

Per-word ASR confidence: expose min token `p` per word (`transcribe_token.p`
for Parakeet/Qwen3-ASR, `whisper_full_get_token_data().p` for whisper), add
`desi-cli … --words` to print it, and measure on the quick tier whether
flagging the lowest 5 % of words catches ≥ 40 % of errors. Then run the
context checker on low-confidence words that have a sound-alike candidate.
That decides Review before paste's highlighting (VOCABULARY_NEXT.md §2).
