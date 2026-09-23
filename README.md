# Desi Dictation 🎙️🇮🇳

**Local-first Hinglish dictation for macOS.** Hold a hotkey, speak the way you
actually talk — *"kal meeting hai, please deck ready rakhna"* — release, and
Roman-script Hinglish lands in whatever app you're typing in. No cloud, no
subscription, runs on a MacBook Air.

Built as a MacWhisper-class product tuned for Indian code-mixed speech, powered by
[Oriserve's Whisper-Hindi2Hinglish](https://huggingface.co/Oriserve/Whisper-Hindi2Hinglish-Apex)
models (Apache 2.0) on [whisper.cpp](https://github.com/ggml-org/whisper.cpp).

**Verified on this machine:** Hindi speech → `"Meeting hai please presentation
taiyaar rakhana. Bahut zaroori kaam hai time par aana."` — Hinglish lands in
~1.5 s, English in ~0.2 s (M3 Air, short dictation, model resident; the numbers
users feel are in [docs/PERFORMANCE.md](docs/PERFORMANCE.md)).

## Install (Apple Silicon, macOS 14+)

Paste this into Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/s-samarth/desi-dictation/main/install.sh | bash
```

It downloads the **latest release**, checks its SHA-256, installs
`Desi Dictation.app` into `/Applications` and opens it — no "Apple could not
verify…" dialog, no Open Anyway step. Run the same command again to update;
settings, history, dictionary and models are kept. Prefer clicking? Grab
[the latest DMG](https://github.com/s-samarth/desi-dictation/releases/latest/download/DesiDictation.dmg)
and follow [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md).

## Build from source

```bash
# 1. One-time setup: build whisper.cpp static libs (needs cmake, git)
./scripts/setup_whisper.sh

# 2. Get a Hinglish model (downloads from HF + converts to GGML)
./scripts/convert_model.sh swift        # 141 MB, fast — free tier
cp models/ggml-hinglish-swift.bin ~/Library/Application\ Support/DesiDictation/models/

# 3. Build + launch the app
./scripts/build_app.sh
open "app/dist/Desi Dictation.app"
```

Then: grant the 3 permissions it asks for → menu bar mic icon → **Enable
Dictation** → pick the model → hold **Right ⌥** and speak. Full instructions:
[docs/USAGE.md](docs/USAGE.md).

## Folder structure

```
desi-dictation/
├── app/                     # Swift package (no Xcode needed)
│   ├── Package.swift        #   links whisper.cpp static libs
│   ├── Sources/
│   │   ├── CWhisper/        #   C shim (headers staged by setup script)
│   │   ├── DesiDictationKit/#   engine, audio, hotkeys, insertion, licensing
│   │   ├── DesiDictationApp/#   SwiftUI menu bar app + overlay + settings
│   │   └── DesiCLI/         #   headless verification CLI
│   ├── Libraries/           #   staged .a files (gitignored)
│   └── dist/                #   built .app + .dmg (gitignored)
├── spike/                   # Phase 0: Python model eval harness (uv)
├── scripts/                 # setup_whisper / convert_model / build_app / make_dmg
├── models/                  # converted GGML models (gitignored)
├── vendor/                  # whisper.cpp + openai/whisper clones (gitignored)
└── docs/                    # ALL documentation — see docs/README.md for the index
    ├── README.md            #   the documentation index (start here)
    ├── SYSTEM_DESIGN.md     #   architecture · PERFORMANCE · BUILD_LOG · SECURITY_AUDIT
    ├── SETUP_GUIDE.md       #   end-user install · USAGE · TROUBLESHOOTING
    ├── genesis/             #   founding docs: MacWhisper teardown + original plan.md
    ├── features/            #   planned features + personas
    ├── problems/            #   the problems that decide the product (P1–P4 + more)
    ├── competitors/         #   per-competitor deep-dives + PATTERNS synthesis
    └── *.md                 #   strategy/GTM/market/monetization/ICP/PMF/outcomes
```
Full index: **[docs/README.md](docs/README.md)**. This repo is private, so product,
strategy, and business docs all live in `docs/` (they used to be gitignored).

## The stack, in one breath

macOS `CGEventTap` global hotkey → `AVAudioEngine` 16 kHz capture →
**whisper.cpp** (Metal, static-linked) running a **Hinglish fine-tuned Whisper**
→ user-dictionary post-processing (optional local-LLM cleanup via Ollama) →
pasteboard-swap ⌘V insertion → non-activating overlay for state. SwiftUI
`MenuBarExtra` shell. Free/Pro gating via Gumroad license API.

## Status

**v0.6.2 — free beta.** Feature-complete for the dictation wedge: first-launch
onboarding, 5 curated models (Apex/Parakeet/Turbo/Vaani + VAD) with per-language
defaults,
VAD pause handling, chunked transcription while you speak, 24h local history,
replacement dictionary, in-app feedback, launch-at-login. Install with the one-liner
above (or the DMG from [Releases](../../releases)) and follow [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md).
Roadmap highlights: on-device LLM layer (translate-to-English, structuring),
own fine-tuned Hinglish model, more Indic languages, Windows/Android.

## License note

App code: yours. Models: Oriserve (Apache 2.0), stock Whisper GGML (MIT
conversion of OpenAI weights). whisper.cpp: MIT. Do not ship MacWhisper assets
or use "Whisper" in the product name (OpenAI trademark risk).
