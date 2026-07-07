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

<!-- Append new entries below as the build progresses. -->
