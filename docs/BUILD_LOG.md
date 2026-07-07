# Build Log — Desi Dictation

> Chronological record of every build step, decision, and **failure mode** encountered
> while building the product. Newest entries at the bottom. Companion to
> [SYSTEM_DESIGN.md](SYSTEM_DESIGN.md) (the "what") — this is the "how and what went wrong".

---

## 2026-07-07 — Session 1: environment + scaffold

### Environment discovered
| Component | Found | Implication |
|---|---|---|
| Swift | 6.3.3 (Command Line Tools only) | ✅ can build SwiftPM projects |
| Xcode | **NOT installed** (CLT at `/Library/Developer/CommandLineTools`) | ❌ no `xcodebuild`, no Xcode project builds, no build-time Metal shader compiler |
| cmake | **not installed** → installed via `brew install cmake` | needed to build whisper.cpp |
| Python | 3.14.6 + uv 0.7.14 | spike env pins 3.12 for torch compatibility |
| Hardware | Apple M3, 16 GB RAM, 61 GB free disk | comfortably above MacBook Air target |
| Git | repo existed with **zero commits** | initial commit made this session |

### ❌ Failure mode #1: whisper.cpp no longer ships a Swift package
**Expected:** add `ggml-org/whisper.cpp` as an SPM dependency (older tutorials show this).
**Reality:** cloned HEAD — **no `Package.swift`** in the repo root. The Swift package was
removed upstream.
**Fix:** build whisper.cpp as **static libraries via cmake**, then link them into our
SwiftPM target with `linkerSettings` (header search path + `-l` flags). See
`scripts/setup_whisper.sh`.

### ⚠️ Constraint: Metal shaders without Xcode
`GGML_METAL=ON` normally compiles `ggml-metal.metal` at build time with `xcrun metal`,
which **requires full Xcode** (CLT doesn't ship the Metal compiler).
**Fix:** build with `-DGGML_METAL_EMBED_LIBRARY=ON` — embeds the Metal source in the
binary and JIT-compiles it at first launch. GPU acceleration without Xcode.

### Decisions this session
- `vendor/` (gitignored) holds the whisper.cpp clone; reproducible via script.
- Models live in `models/` (gitignored) + `~/Library/Application Support/DesiDictation/`.
- Docs-first: every failure mode lands here as it happens.

### Phase 0 executed: model pipeline works end-to-end ✅
1. `spike/` uv env synced (Python 3.12, torch, **transformers 5.13** — note: major
   version 5; pipeline API verified working).
2. Downloaded `Oriserve/Whisper-Hindi2Hinglish-Swift` (72M, whisper-base arch).
3. Converted → `models/ggml-hinglish-swift.bin` (141 MB f32) via
   `vendor/whisper.cpp/models/convert-h5-to-ggml.py` + openai/whisper assets clone.
4. **Smoke test (synthetic audio via macOS `say`):**
   - English clip → transcribed verbatim. ✅
   - **Hindi clip (Lekha voice)** → `"Meeting hai please presentation taiyaar
     rakhana. Bahut zaroori kaam hai time par aana."` → **Roman Hinglish, exactly
     the product hypothesis.** ✅ (dropped one word, "kal" — 72M model; Apex/Prime
     expected to fix)
   - Speed: 242 ms total for ~8 s audio ≈ **33× realtime** on M3 (smallest model).

### ❌ Failure mode #2: cmake target `quantize` doesn't exist
Upstream renamed it. Correct target: **`whisper-quantize`**. (Also discovered
`parakeet-quantize` — whisper.cpp now has native Parakeet support; roadmap note.)

### Real-voice eval still pending (needs the human)
Synthetic TTS audio validates the *pipeline*, not accent robustness. The
`spike/README.md` flow (record 40–60 personal clips → `eval.py`) remains the
decision gate for which model ships as default. Harness is ready.

## 2026-07-07 — Session 1 (continued): the Swift app

### ❌ Failure mode #3: SwiftPM manifest fails to link with tools-version 5.10
`swift build` died compiling **Package.swift itself** — undefined
`PackageDescription.Package.__allocating_init(...)`. The CLT 6.3 ManifestAPI no
longer ships the older manifest ABI. Fix: `swift-tools-version: 6.0` +
`-swift-version 5` per-target (keeps pre-strict-concurrency semantics).

### ❌ Failure mode #4: the CLT's SwiftPM is broken system-wide
Even a hello-world manifest at tools-version 6.0/6.2 failed with the same
undefined symbol → the CLT 26.6 install has a **mismatched
libPackageDescription.dylib vs .swiftmodule**. No CLT update available via
`softwareupdate`.
**Fix:** `brew install swift` (OSS toolchain 6.3.2, keg-only at
`/opt/homebrew/Cellar/swift/6.3.2/Swift-6.3.xctoolchain/usr/bin/swift`) — its
SwiftPM is self-consistent and it compiles AppKit/SwiftUI via the CLT SDK's
textual interfaces. `build_app.sh` honors `DESI_SWIFT` to override.

### ❌ Failure mode #5: Swift concurrency isolation errors
`OverlayCoordinator` touched `@MainActor` state from a nonisolated context, and
the engine property was accessed from the worker queue. Fixes: `@MainActor` on
OverlayCoordinator/AppDelegate; `nonisolated(unsafe) let engine` (safe because
all engine access is serialized on one DispatchQueue by design).

### ✅ Results
- Full package builds: `DesiDictationKit` (15 files) + menu bar app + `desi-cli`.
- **CLI verification (debug):** Hindi audio → Roman Hinglish, 10× realtime.
- **Release:** same clip **39× realtime** (0.14 s for 5.6 s audio, M3).
- Model load = **7.7 s** (one-time Metal shader JIT at startup — this is why the
  app preloads and keeps the model resident; per-dictation latency is unaffected).
- `build_app.sh` → `Desi Dictation.app` (2.6 MB, ad-hoc signed, LSUIElement).
- `make_dmg.sh` → `DesiDictation-0.1.0.dmg` (1.3 MB, models not bundled).
- Launch smoke test: app runs, menu bar icon present, permission prompts fire.

### Deliberate scope decisions (v0.1)
- **No chunked pre-transcription while speaking** — at 39× realtime, a 60 s
  dictation transcribes in ~1.5 s post-release; chunking is a Phase-5 optimization.
- **No Fn/Globe hotkey** — macOS reserves it; Right ⌥ default instead.
- **System sounds** (Tink/Pop/Basso) instead of custom audio assets.
- **Pasteboard-swap insertion only** — AX-API and keystroke fallbacks are
  designed (see SYSTEM_DESIGN.md) but not yet needed in tested apps.

<!-- Append new entries below as the build progresses. -->
