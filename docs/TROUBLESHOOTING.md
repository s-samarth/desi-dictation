# Troubleshooting — Desi Dictation

Symptoms → causes → fixes. Build-time failures are also chronicled with full
context in [BUILD_LOG.md](BUILD_LOG.md).

## 1. Hotkey does nothing / "needs Input Monitoring" in the menu

- Grant **Input Monitoring** AND **Accessibility** in System Settings →
  Privacy & Security, then **quit and relaunch the app** (grants apply at
  process start).
- **After every rebuild** of an ad-hoc-signed app, macOS treats it as a new
  binary: remove the stale entry (−) in both panes, re-add the fresh .app, relaunch.
  (Developer-ID-signed builds keep grants across updates — launch build fixes this.)
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
