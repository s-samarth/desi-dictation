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

## 2026-07-07 — Session 1 (continued): first-user friction

### ❌ Failure mode #6: "app won't open" = stale pre-permission process
User reported the app "won't open / buggy". Reality: the process launched during
the build (before ANY permission grants) was still running — macOS applies
Accessibility/Input Monitoring only at process start, so inside that process the
hotkey tap and mic were dead, making the app feel broken. No crash, no logs.
**Fixes applied:**
1. `pkill` stale instance; **install to `/Applications`** via `ditto` (stable
   location + identity for TCC; Input Monitoring in particular is unreliable for
   apps running from arbitrary build dirs).
2. Relaunch fresh → permission prompts fire correctly.
3. Product lesson recorded: onboarding must detect "permissions granted but app
   not restarted since" and offer a one-click relaunch (roadmap item).

## 2026-07-07 — Session 2: v0.2 after first real-user feedback

User feedback on v0.1: Hinglish accuracy weak (was running the 72M model!), only
one model, "no model selected" errors, settings undiscoverable ("just an icon"),
wanted toggle mode + 24h history + a real app window (MacWhisper-style).

### ❌ Failure mode #7: BF16 checkpoints crash convert-h5-to-ggml.py
Apex ships BFloat16 weights; upstream converter calls `.numpy()` directly →
`TypeError: Got unsupported ScalarType BFloat16`. Fix: `convert_model.sh` now
sed-patches the converter to `.float().numpy()` (idempotent, vendor is re-cloneable).

### Shipped in v0.2
- **Models installed (4)**: hinglish-apex-q5_0 (547M — the SOTA), hinglish-swift
  (141M), large-v3-turbo-q5_0 (547M, English/Hindi), small (465M).
- **Auto model selection**: per-mode ranking (Hinglish→Apex, English→turbo,
  Hindi→turbo, quantized preferred; Hinglish models excluded from Devanagari
  mode). "Auto (recommended)" is the default — "no model selected" class of
  errors eliminated. Mode switches preload the new model in the background.
- **Main app window**: sidebar (Dictation / History / Models / Text & AI /
  License), opened via menu bar → "Open Desi Dictation…". Dictation pane =
  MacWhisper-parity controls: hotkey picker, hold-vs-toggle, language+model with
  live "Using: <model>" line, sounds, copy-only, history toggle, permission
  status with fix buttons.
- **History v2**: rolling 24 h window (cap 200), search, per-row copy,
  on/off toggle, clear-all.

### Verified (CLI, release, M3)
| Test | Result |
|---|---|
| Hindi clip → Apex q5_0 (hinglish) | **word-perfect** incl. "Kal" the 72M model dropped; ~3× realtime |
| English clip → turbo q5_0 | verbatim; ~4× realtime |
| Hindi clip → small (hindi mode) | Devanagari output confirmed (turbo is the auto-pick anyway) |

### Model research note (for the English roadmap)
2026 on-device English leaderboard: **NVIDIA Parakeet V3** (~6.3% WER, ~10×
faster than Whisper, zero silence-hallucination) > large-v3-turbo > Moonshine
(245M, streaming-first). whisper.cpp has grown native Parakeet support
(`parakeet-quantize` target exists in our build) → adding Parakeet as the
English-mode engine is the highest-value next model upgrade. Hinglish: Apex
remains SOTA; Srota (Qwen3-ASR) would need an MLX path — Phase 5.

## 2026-07-07 — Session 2 (continued): the stale-permission saga

### ❌ Failure mode #8: TCC grants silently die on every ad-hoc rebuild
User granted Accessibility + Input Monitoring, toggles showed **ON**, app still
reported "Hotkey needs Input Monitoring". Cause: TCC records a grant against the
binary's code requirement; ad-hoc signatures change **every build**, so the
System Settings toggle points at the *previous* binary — shown ON, actually
denied. Brutal because nothing looks wrong.
**Fixes (all three shipped):**
1. **Stable self-signed identity** "Desi Dictation Dev" (`make_dev_cert.sh`;
   `build_app.sh` auto-uses it) → grants now survive rebuilds. Launch builds
   replace this with a Developer ID.
2. **Listen-only tap fallback** in HotkeyManager — if macOS denies the active
   tap, dictation still works (only key-swallowing is lost, which the default
   Right ⌥ hotkey never needed anyway).
3. **Precise error surface**: enable() now distinguishes "never granted" from
   "granted-but-stale" and says exactly what to do. `tccutil reset ... 
   com.desi.dictation` clears stale entries for a clean re-prompt.

### ❌ Failure mode #9: PKCS12 import — "MAC verification failed"
OpenSSL 3.x emits AES/SHA2-MAC PKCS12 that macOS `security import` rejects.
Fix: use system LibreSSL (`/usr/bin/openssl`) or `-legacy` (script does both).

### ❌ Failure mode #10: `security find-identity -v` hides self-signed identities
`-v` lists only *trusted* identities; the dev cert is untrusted-but-functional
(codesign + TCC don't need chain trust). build_app.sh silently fell back to
ad-hoc — drop `-v` when checking.

### ❌ Failure mode #11: error states were terminal (user-reported)
A quick accidental tap → "No audio was captured" → **app unusable until
relaunch**: `startRecording()` demanded `phase == .idle`, and nothing ever left
`.error`. Same root cause made the hold↔toggle switch *look* broken in realtime
(it applied fine — the app was just already bricked).
**Fixes (v0.2.1):**
- All runtime errors are **transient**: message + beep, auto-reset to idle in
  4 s, and recording may start straight from an error state.
- Sub-0.5 s captures get a gentle "Too short — ready again" instead of an error.
- Explicit no-output messaging: "nothing inserted or copied" (user's spec).
- Transcript is never lost: stays on the **clipboard after paste** (restore
  removed — user-requested default), plus History + "Copy Last".
- First proof of real-voice Hinglish in the wild: user's menu showed
  *"Bhai, ab na solid model use ka…"* ✅

<!-- Append new entries below as the build progresses. -->
