# Troubleshooting — Desi Dictation

Symptoms → causes → fixes.

## 0. "The application 'Desi Dictation' can't be opened" (first open)

In order of likelihood:
1. **Gatekeeper block (expected on beta builds)** — click OK → System Settings
   → Privacy & Security → scroll to the bottom → **Open Anyway** → confirm.
   Or in Terminal: `xattr -dr com.apple.quarantine "/Applications/Desi Dictation.app"`
2. **Intel Mac** ( → About This Mac shows "Intel") — not supported; the
   models need Apple Silicon (M1+).
3. **macOS 13 or older** — requires macOS 14+. Build-time failures are also chronicled with full
context in [BUILD_LOG.md](BUILD_LOG.md).

## 1. Hotkey does nothing / permission errors in the menu

- Grant **Input Monitoring** AND **Accessibility** in System Settings →
  Privacy & Security, then **quit and relaunch the app** (grants apply at
  process start).
- **Toggle shows ON but still denied = stale grant** (the #1 trap): the grant
  was recorded for a previous build of the binary. Releases from **v0.6.1
  onward are signed with a stable identity**, so grants now survive updates —
  this should only bite you when moving *from* an older ad-hoc build, or on a
  local rebuild made before `./scripts/make_dev_cert.sh` was run. Fix:
  ```bash
  tccutil reset Accessibility com.desi.dictation
  tccutil reset ListenEvent com.desi.dictation
  ```
  then relaunch and grant the fresh prompts. Prevention: sign with a stable
  identity — run `./scripts/make_dev_cert.sh` once; `build_app.sh` picks it up
  automatically (Developer ID replaces it at launch).
- Even with a partial grant the app degrades gracefully: it falls back to a
  listen-only hotkey tap (dictation works; the hotkey/Esc keys just aren't
  swallowed).
- Still dead? Check the tap was created: menu bar status line will show the
  error phase; also `log stream --predicate 'process == "Desi Dictation"'`.

## 2. Recording works but nothing gets pasted

- **Accessibility** permission missing → the synthesized ⌘V is silently dropped.
- Focus was lost: the target text field must stay focused while you dictate —
  don't click elsewhere mid-dictation (the overlay never steals focus).
- Some apps block programmatic paste (rare; some password fields, some VMs).
  Workaround: Settings → General → "Copy to clipboard instead of pasting",
  then ⌘V manually.
- Secure input mode: password managers/terminals can enable *SecureKeyboardEntry*
  which blocks event taps globally. Quit the offending app (`ioreg -l -w0 |
  grep SecureInput` hints at the culprit).

## 3. "No model is loaded" error

- Menu bar → Model shows "None selected" → pick one. If the list is empty:
  models live in `~/Library/Application Support/DesiDictation/models/*.bin` —
  copy a converted model there and hit **Refresh Models**.
- Model file corrupt (interrupted download/conversion): re-run
  `./scripts/convert_model.sh swift`.

## 3b. Dictation feels slow

The Dictation screen shows what the last one actually cost:
*"Last: 4.2s speech · 0.31s to paste · 1 call"*. Quote that line in any report.

- **Which language?** English (Parakeet) ≈ 0.2 s, Hinglish (Apex) ≈ 1.5 s,
  हिन्दी (Vaani, a 1.06 GB model) ≈ 3.5 s on an M3 Air — roughly double those
  on an M1 Air. हिन्दी is genuinely the slow path today (PERFORMANCE.md).
- **English still slow?** You are probably still on a Whisper model. Download
  **Parakeet** in Models, then set Language → English → Model → **Auto**.
- **"2 calls" or more for a short dictation?** That should not happen under
  30 s of speech — file it with the timings line (PERF_RCA_2026-08.md).
- **First dictation after the Mac woke up** is slower: the model gets paged
  back in. Subsequent ones are not.

## 4. First dictation after enabling is slow

Expected: enabling dictation preloads the model (~8 s on M3 — includes one-time
Metal shader JIT because the build embeds shader source; see SYSTEM_DESIGN §3).
Subsequent dictations are instant. If EVERY dictation is slow, the model is
being reloaded — check nothing else is deleting/touching the model file.

## 5. Hinglish comes out as Devanagari / English mangles Hindi words

- Wrong mode/model pairing. Hinglish output needs BOTH: Language =
  *Hinglish (Roman)* AND a `hinglish-*` model. Stock Whisper models cannot
  produce Roman Hinglish no matter the mode.
- Spelling variants annoying you (`nahin` vs `nahi`)? Settings → Text →
  Replacements — one `find=replace` per line.

## 6. Transcripts cut off / miss the first word

- You started speaking before the start sound. The mic engine spins up on key
  press (~100–200 ms) — begin speaking after the Tink.
- Very short utterances (<0.5 s) are rejected by design (EngineError.emptyAudio).

## 7. Build failures (developer)

| Error | Fix |
|---|---|
| `Undefined symbols: PackageDescription.Package...` on `swift build` | Your CLT SwiftPM is broken (BUILD_LOG #4). Use the Homebrew toolchain: `brew install swift`, then `DESI_SWIFT=/opt/homebrew/Cellar/swift/<ver>/Swift-*.xctoolchain/usr/bin/swift ./scripts/build_app.sh` |
| `no such module 'CWhisper'` / linker can't find `-lwhisper` | Run `./scripts/setup_whisper.sh` (stages headers into `app/Sources/CWhisper/include` and libs into `app/Libraries`) |
| `xcodebuild requires Xcode` | Expected — nothing here uses xcodebuild. Scripts only need CLT + cmake + brew swift |
| cmake `No rule to make target 'quantize'` | Target renamed upstream: `whisper-quantize` (already fixed in setup script) |
| convert_model.sh: torch/transformers import errors | `cd spike && uv sync` first; spike pins Python 3.12 |
| Metal errors at model load | Build must use `-DGGML_METAL_EMBED_LIBRARY=ON` (setup script does); re-run setup if you built vendor manually |

## 8. App doesn't appear in the menu bar

- It's an `LSUIElement` accessory — no Dock icon is normal; look at the top-right.
- Menu bar full? macOS hides overflow icons — remove something or use Bartender.
- Crashed on launch? `Console.app` → Crash Reports, or run the raw binary for
  stderr: `"app/dist/Desi Dictation.app/Contents/MacOS/Desi Dictation"`.

## 9. Ollama cleanup never changes anything

- Is Ollama actually serving? `curl -s localhost:11434/api/tags`.
- Model pulled? `ollama pull llama3.2` (or whatever Settings → Text names).
- Cleanup is Pro-gated: pre-launch, set the dev unlock
  (`defaults write com.desi.dictation devUnlock -bool true`) and relaunch.
- By design, any Ollama failure silently falls back to the raw transcript
  (the transcript is sacred).

## 10. Reset everything

```bash
defaults delete com.desi.dictation                                  # settings
rm -rf ~/Library/Application\ Support/DesiDictation                  # models+history
tccutil reset Microphone com.desi.dictation                          # mic grant
tccutil reset Accessibility com.desi.dictation
tccutil reset ListenEvent com.desi.dictation
```
