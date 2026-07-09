# Using Desi Dictation Locally — Precise Steps

Everything below was executed and verified on this machine (M3, macOS 26,
2026-07-07) unless marked *manual*. Commands run from the repo root.

## A. One-time setup (already done on this machine)

```bash
# 1. Build whisper.cpp static libs + CLI tools (~2 min)
./scripts/setup_whisper.sh

# 2. Download + convert the free Hinglish model (~141 MB result)
./scripts/convert_model.sh swift

# 3. Put it where the app looks
mkdir -p ~/Library/Application\ Support/DesiDictation/models
cp models/ggml-hinglish-swift.bin ~/Library/Application\ Support/DesiDictation/models/

# 4. Build the app bundle
./scripts/build_app.sh          # → app/dist/Desi Dictation.app
```

Optional, better accuracy (Pro-tier model, ~1.6 GB download, ~570 MB after quant):
```bash
./scripts/convert_model.sh apex
cp models/ggml-hinglish-apex-q5_0.bin ~/Library/Application\ Support/DesiDictation/models/
```

## B. First launch (manual — needs your clicks)

```bash
# Install to /Applications — REQUIRED for reliable permission grants (TCC
# identifies apps by location/signature; build-dir apps get flaky grants)
ditto "app/dist/Desi Dictation.app" "/Applications/Desi Dictation.app"
open "/Applications/Desi Dictation.app"
```

1. A **mic icon** appears in the menu bar (no Dock icon — it's an accessory app).
2. macOS will prompt for **Microphone** → Allow.
3. Grant the other two in **System Settings → Privacy & Security**:
   - **Accessibility** → add/enable *Desi Dictation* (needed to paste text)
   - **Input Monitoring** → add/enable *Desi Dictation* (needed for the global hotkey)
   The app's *Settings → General → Permissions* section has "Open Settings"
   buttons and a live status for each.
4. **Quit and relaunch the app after granting** (macOS only applies these to
   new processes).

> Ad-hoc-signed builds lose TCC grants when rebuilt — see TROUBLESHOOTING §1.

## C. Dictate

1. Menu bar mic → **Enable Dictation** (first enable preloads the model; ~8 s
   one-time — the icon settles once ready).
2. Model defaults to **Auto** — it picks the best installed model per language
   (Hinglish→Apex, English/Hindi→Large-v3-Turbo). Override via the Model picker
   only if you want to trade accuracy for speed (e.g. hinglish-swift).
   The full control panel lives at menu bar → **Open Desi Dictation…**
   (sidebar: Dictation / History / Models / Text & AI / License).
3. Click into any text field (Notes, WhatsApp Web, Slack, VS Code…).
4. **Hold Right ⌥ (Option)** — overlay shows *"Listening…"*, start sound plays.
5. Speak naturally. Pauses are fine; it records until you release.
6. **Release** — *"Transcribing…"* flashes, then the text is pasted at your cursor.
7. **Esc** while recording = discard everything (error sound confirms).

**Toggle mode** (tap to start, tap to stop): Settings → General → Activation.
**Different hotkey** (Right ⌘, F13, F16–F19): Settings → General.
**Clipboard-only mode** (never auto-paste): Settings → General.

## D. Language modes

| Mode | Output | Use with model |
|---|---|---|
| **Hinglish (Roman)** | `kal meeting hai please deck ready rakhna` | hinglish-swift / -prime / -apex |
| **English** | plain English (handles Indian accents) | any |
| **हिन्दी (Devanagari)** | `कल मीटिंग है` | stock model (Base/Small/Turbo from Settings → Models) |

## E. Power features

- **Replacements** (Settings → Text): one rule per line, `find=replace`.
  E.g. `nahin=nahi`, `dezi=desi`, your company/product names. Applied to every
  transcript — this is how you enforce YOUR Hinglish spellings.
- **AI cleanup via Ollama** (Settings → Text, Pro): pipes the transcript through
  a local LLM (default prompt preserves Hinglish words). Needs
  [Ollama](https://ollama.com) running (`ollama serve`) with the configured model
  pulled. Fails safe: raw transcript is used if Ollama is unreachable.
- **History**: menu bar → History → click any entry to re-copy it. Local file,
  clearable.
- **Dev unlock** (pre-launch builds — licensing isn't wired to a product yet):
  ```bash
  defaults write com.desi.dictation devUnlock -bool true
  ```

## F. Headless verification (no permissions needed)

```bash
# transcribe any audio file through any model — great for model comparisons
app/.build/release/desi-cli models/ggml-hinglish-swift.bin spike/audio/test-hi.wav hinglish
```

## G. Model evaluation (recommended before daily-driving)

Record your own eval clips and compare models on YOUR voice — the whole flow is
scripted: see [spike/README.md](../spike/README.md). Decision gate + how to read
the numbers are in [plan.md](genesis/plan.md) Phase 0.

## H. Rebuild after code changes

```bash
./scripts/build_app.sh && open "app/dist/Desi Dictation.app"
# ⚠️ re-grant Accessibility + Input Monitoring after each rebuild (ad-hoc signing)
```
