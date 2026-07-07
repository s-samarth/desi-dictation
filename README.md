# Desi Dictation 🎙️🇮🇳

**Local-first Hinglish dictation for macOS.** Hold a hotkey, speak the way you
actually talk — *"kal meeting hai, please deck ready rakhna"* — release, and
Roman-script Hinglish lands in whatever app you're typing in. No cloud, no
subscription, runs on a MacBook Air.

Built as a MacWhisper-class product tuned for Indian code-mixed speech, powered by
[Oriserve's Whisper-Hindi2Hinglish](https://huggingface.co/Oriserve/Whisper-Hindi2Hinglish-Apex)
models (Apache 2.0) on [whisper.cpp](https://github.com/ggml-org/whisper.cpp).

**Verified on this machine:** Hindi speech → `"Meeting hai please presentation
taiyaar rakhana. Bahut zaroori kaam hai time par aana."` at **39× realtime** (M3).

## Quickstart

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
├── plan.md                  # the master build plan (phases, decisions, risks)
├── MacWhisper.md            # competitive research on MacWhisper
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
└── docs/
    ├── PRODUCT_VISION.md    # vision, strategy, positioning
    ├── GTM.md               # go-to-market plan
    ├── SYSTEM_DESIGN.md     # architecture deep-dive
    ├── BUILD_LOG.md         # chronological build steps + all failure modes
    ├── USAGE.md             # how to use it locally (precise steps)
    ├── LAUNCH.md            # how to launch on Gumroad
    └── TROUBLESHOOTING.md   # when things break
```

## The stack, in one breath

macOS `CGEventTap` global hotkey → `AVAudioEngine` 16 kHz capture →
**whisper.cpp** (Metal, static-linked) running a **Hinglish fine-tuned Whisper**
→ user-dictionary post-processing (optional local-LLM cleanup via Ollama) →
pasteboard-swap ⌘V insertion → non-activating overlay for state. SwiftUI
`MenuBarExtra` shell. Free/Pro gating via Gumroad license API.

## Status

v0.1.0 — feature-complete for the dictation wedge, **not yet launched**.
See [docs/LAUNCH.md](docs/LAUNCH.md) for the launch runway and
[plan.md](plan.md) §Phase 5 for the roadmap (WhisperKit/ANE backend,
mixed-script models, more Indic languages, file transcription).

## License note

App code: yours. Models: Oriserve (Apache 2.0), stock Whisper GGML (MIT
conversion of OpenAI weights). whisper.cpp: MIT. Do not ship MacWhisper assets
or use "Whisper" in the product name (OpenAI trademark risk).
