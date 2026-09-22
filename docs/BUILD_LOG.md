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

## 2026-07-07 — Session 3: v0.3.0 — quality crux + launch prep

User dictated the entire session-3 prompt WITH the product (in Hinglish). Reported:
quality degrades on long dictations and around silences — "fundamental for our
success."

### ✅ The long-form fix (the crux)
Root causes and fixes, both verified:
1. **`no_context = true`** — Whisper defaults to conditioning each 30 s window
   on the previous window's output; one bad segment poisons everything after it.
   This is THE classic long-dictation degradation, now off.
2. **Silero VAD** (whisper.cpp built-in, `ggml-silero-vad.bin`, 1 MB) — trims
   silences before decoding; silence is where Whisper hallucinates.
**Verification:** 23 s synthetic clip with three 3–5 s silences → all four
sentences transcribed correctly, zero hallucination in gaps, and **15× realtime**
(VAD skips silence, so it's *faster* than the 3× baseline).

### Launch prep shipped
- **App icon**: CoreGraphics generator (`generate_icon.swift` — charcoal
  squircle, saffron mic, green dot; tricolor nod) → .icns wired into bundle.
- **Model catalog v2**: in-app one-click downloads with ⭐ recommendations and
  category labels (user's requirement: models can't be bundled — DMG stays 1.4 MB);
  Hinglish models served from own HF repo (`publish_models.sh` ready, needs
  `hf auth login` before first run).
- **CI**: `.github/workflows/release.yml` — tag push → build → DMG → GitHub
  Release; signing/notarization activate when secrets are configured.
- **New docs**: SETUP_GUIDE.md (end-user install/permissions/models),
  PRODUCT.md (living feature/roadmap doc), LAUNCH.md gained privacy-first user
  measurement (Gumroad dashboard + GH release counts + Plausible; no in-app
  telemetry) and CI release instructions.
- Version 0.3.0; DMG built.

### Open item requiring the human
`publish_models.sh` needs a Hugging Face write token (`hf auth login`) — until
the HF repo exists, in-app Hinglish downloads 404 (local installs unaffected).

### ❌ Failure mode #12: v0.3 regression — transcriptions return "NaN" (user-reported)
Live-mic dictations decoded to literal "nan" text after the v0.3 engine changes;
CLI tests with clean TTS wavs never reproduced it (mic audio has a different
noise profile). Couldn't single-step the root cause on-device, so all suspects
were fixed defensively (v0.3.1):
1. **`flash_attn = false`** — prime suspect; known NaN-logit source with
   quantized models on Metal for some inputs. Cost: ~3×→ measured 11× realtime
   with VAD anyway — negligible.
2. **Mic sample sanitization** — non-finite samples from the converter zeroed.
3. **Pre-flight buffer check** — silent/corrupt buffers rejected before decode.
4. **"nan" output filter** — never paste garbage; degrade to "no speech" message.
5. **VAD kill-switch** in Dictation → Options ("Smart pause handling") so the
   user can bisect quality issues live without a rebuild.
Verified post-fix: Apex+VAD long-form clip still perfect (11× realtime), turbo
English verbatim. **Lesson: mic audio ≠ TTS test audio — the eval set needs
real mic recordings** (already the spike/README.md plan).

### Overlay redesign (user feedback: "very bad UI")
Truncated "(Esc to c…" at 180 px → 260 px capsule, pulsing red dot, "Listening"
+ quiet "esc to cancel" secondary label, ultra-thin material + 0.92 panel alpha
(user wanted to see through it), hairline border for readability.

## 2026-07-07 — Session 4: v0.4.0 — latency overhaul + download fixes

User reports: model "Get" buttons dead, first 1–2 s of speech lost, short
utterances rejected, transcription "significantly slower than MacWhisper".

### ❌ Failure mode #14: model downloads failed silently (three stacked bugs)
1. Progress delegate declared `URLSessionTaskDelegate` only → `didWriteData`
   (a `URLSessionDownloadDelegate` method) never delivered → no progress UI.
2. Errors swallowed by `try?` in the UI → 404s (unpublished HF repo) invisible.
3. Already-installed models hit a silent early-return → button "did nothing".
**Fixed:** proper delegate-based `Downloader` (progress, 404 → friendly
"repo not published yet" message), `downloadErrors` surfaced in UI, an
"Installed ✓" state, and progress appears instantly on click.

### ❌ Failure mode #15: first words lost (mic spin-up)
Fresh-engine-per-session (the FM #13 fix) meant 200–500 ms of dead air after
keypress. **Fixed with warm-idle capture**: engine runs while dictation is
enabled, 0.3 s pre-roll ring included in each session — words spoken AT the
keypress are captured. Off-switch: Options → "Instant mic". Wedge-immunity
kept via device-change rebuild + dead-session self-heal.

### Perceived-speed overhaul (v0.4)
- **Chunked incremental transcription**: ~12 s chunks (cut at quiet moments,
  forced at 20 s) transcribed while the user is still speaking; on release only
  the tail runs → long dictations insert in ~1–2 s regardless of length.
- Short-utterance floor lowered 0.5 s → 0.2 s.
- **Quantization benched**: q8_0 is *slower* than q5_0 on Metal (10× vs 14×) —
  q5_0 confirmed as the right choice; q8 experiment deleted.
- Full lever inventory (applied + deferred with plans): **docs/PERFORMANCE.md**.
  Top deferred: CoreML/ANE encoder (~3×), Parakeet V3 for English.

## 2026-07-07 — Session 5: model landscape research + lab results

Deep research pass (docs/MODEL_RESEARCH.md): Trelis whisper-hinglish-preview
(June 2026) is the new open mixed-script SOTA; Sarvam's ASR stays API-only;
pure-Roman Hinglish remains Oriserve-only for structural reasons (Devanagari-
labeled data, no standard Roman orthography, no benchmark → no releases).

### ✅ Vaani ships as the हिन्दी-mode default (v0.4.2)
A/B on the Hindi test clip: **Vaani got every word right** (प्रेजेंटेशन, तैयार,
टाइम) where turbo misspelled all three; turbo is ~1.7× faster and adds
punctuation. Accuracy wins for dictation → Auto now prefers Vaani for हिन्दी
(score 110 > turbo 100); catalog entry added (served from our HF repo once
published). Turbo remains the English pick and the fallback.

### ❌ Failure mode #16: added-vocab fine-tunes break whisper.cpp
Trelis adds `<|mixedcode|>` → n_vocab 51,867 (stock 51,866). whisper.cpp infers
the language-token table from vocab size → `whisper_lang_str: unknown language
id 100`, decode unusable. **Lesson: check `vocab_size` in a fine-tune's
config.json BEFORE converting** — must be exactly 51,865/51,866 (v2/v3) for
whisper.cpp. Fix path (roadmap): patch whisper.cpp for extended vocabs +
prompt-token injection; that also unlocks the Mixed-script mode.

## 2026-07-07 — Session 6: evals live + market study

### First eval report (50 clips × 3 suites × 6 models, via shipping engine)
Champions by crWER: english → **turbo 4.2%** · hindi → **vaani 10.8%** (3×
better than turbo's 29.6% — today's A/B now benchmark-confirmed) · hinglish →
**turbo-in-hindi-mode 30.6% vs Apex 44.0%** ⚠️.

That last one is the day's headline finding — with nuance: CS-FLEURS hin-eng is
*read* speech; Apex is tuned for *conversational/noisy* audio and dominates our
informal real-dictation tests. Domain mismatch, not a verdict. Action: do NOT
flip Hinglish auto-selection on one read-speech benchmark; the personal eval
set (real dictation distribution) is the deciding suite. If Apex loses there
too → FINETUNING.md Part 3 trigger fires. Also measured: metric design works
(english raw WER 24.6% vs crWER 4.2% = punctuation noise removed); vaani is
slow (1.1× RT) but accuracy-worth-it; vaani on English = 99% error (correctly
excluded by mode scoring).

### Market study (docs/MARKET_STUDY.md)
Voice AI $18–22B/~35% CAGR; ASR APIs commoditized ($0.15–0.48/hr) — never sell
raw Hinglish API. Category proof: Wispr Flow ~$10M ARR @ $15/mo, 270 F500
bottom-up. Killer structural insight: **on-device = zero marginal cost →
lifetime pricing is sustainable for us and impossible for cloud rivals**
(Superwhisper's $249→$849 lifetime hike = the cautionary tale). India voice AI
is all B2B/Gov (Sarvam/Gnani/CoRover) — consumer shelf empty. Roadmap implications
ranked in §8 (voice commands → team pack → Windows → clinics vertical).

<!-- Append new entries below as the build progresses. -->

## 2026-07-10 — the 0.6 feature wave (LLM layer + parity features)

Built in one loop session: **personal dictionary** (P4-S1), **per-app language
modes** (IDEAS #4), **LocalLLM engine** (Ollama backend), **Translate on
Demand** (Flow A window), **"English — from any language ✨" mode**
(transcribe→translate pipeline with `.translating` overlay stage), **Structure
my thoughts (beta)** (thinking session → review window), **tone modes**
(Faithful default = no LLM pass). Full how-it's-built docs:
[features/implementation/](features/implementation/README.md). Tests: new
`desi-tests` target (no XCTest under CLT), 76 assertions green; ASR regression
one-off vs evals clip 0000 = exact match at 3× realtime.

Model spike (decisive, recorded in implementation/LLM_ENGINE.md): Hinglish→
English needs **gemma3:4b** — qwen2.5:1.5b/3b invert meaning ("thoda adjust
kar lena yaar" → "I will adjust"), mangle lakh-numbers, and literalize idiom
("scene kya hai"). Default is RAM-gated: ≥12 GB → gemma3:4b, else 1.5b.

### Failure mode #17 — CLT 6.3.3 ships a stale private swiftinterface (manifest won't link)

**Symptom:** every `swift build` dies linking the *manifest*: undefined symbol
`PackageDescription.Package.__allocating_init(... swiftLanguageVersions:
[SwiftVersion]? ...)`.
**Cause:** in `/Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI`,
`PackageDescription.swiftmodule`'s `*.private.swiftinterface` is from an older
build (old API: `enum SwiftVersion`, `swiftLanguageVersions:` inits) while
`libPackageDescription.dylib` is newer (only `SwiftLanguageMode`/
`swiftLanguageModes:` symbols). The compiler prefers the private interface →
emits calls to symbols the dylib no longer exports. Root-owned files; can't
patch in place without sudo.
**Fix (user-local, no sudo):** copy ManifestAPI+PluginAPI to
`~/.swiftpm-fixed-libs/`, delete the stale `*.private.swiftinterface` copies
(compiler falls back to the correct public `.swiftinterface`), and export
`SWIFTPM_CUSTOM_LIBS_DIR=$HOME/.swiftpm-fixed-libs` for every build. Also
bumped `swift-tools-version` 6.0 → 6.2 while diagnosing (harmless, kept).
A CLT update/reinstall should obsolete this workaround — retest after updating.

## 2026-07-10 (later) — web demo + CI/CD

**Web demo** (`web/`, fully separate from `app/`): zero-install browser demo —
FastAPI gateway + vendored whisper-server (Apex/Vaani resident) + Ollama with
the app's exact prompts and a Python port of HindiNumbers. Verified end-to-end
incl. browser-format (webm/opus) audio and full UI flow. Share via
`cloudflared tunnel` (mic requires HTTPS off-localhost). AWS path + sizing in
web/README.md.

**CI/CD** (docs/CICD.md): `scripts/preflight.sh` = the local gate (build,
95 tests, app↔web parity, web tests); `ci.yml` mirrors it on every push;
`release.yml` (updated: macos-26, preflight gate, version-tag sanity) turns
`git tag v*` into a DMG release. **Parity is enforced, not remembered**:
`check_parity.sh` diffs the Swift and Python number-normalizers on shared
sentences and greps prompt sentinels — porting drift fails the build. Dormant
auto-deploy job for the web host (enable via DEPLOY_ENABLED + secrets).

## 2026-07-14 — web demo: the stuck-"transcribing…" bug + editor rework

UI reworked around an **editable text box** (transcript types out into it,
repeat dictations append, edits flow into the AI actions); mic button lives in
the box's toolbar; "Get the Mac app" + feedback links removed for now.
Serving-stack decisions (vLLM/SGLang verdict, what's overkill when) recorded
in docs/cloud/SERVING_STACK.md.

### Failure mode #18 — transcription "never completes" (recorder.mimeType read after null)

**Symptom:** every browser recording ends stuck on "transcribing…" forever; no
error, no transcript. The API itself is healthy (curl works).
**Cause:** `stop()` set the global `recorder = null` *before* MediaRecorder's
async `onstop` fired; the `onstop` closure then read `recorder.mimeType` →
TypeError on null → `send()` never ran → the hint never updated. A silent
client-side death that looks exactly like a slow server.
**Fix:** capture `const blobType = recorder.mimeType` at setup time, use it in
`onstop`. **Lesson:** in event closures, never read globals another handler
may have cleared — capture at bind time. And when "the server is slow",
check the browser console *first*.

### Failure mode #19 — duplicate whisper-servers after repeated run_demo.sh

**Symptom:** transcription slow; `ps` shows 3× whisper-server per port, each
with the model loaded, fighting for CPU.
**Cause:** run_demo.sh's EXIT trap only kills PIDs from *its own* run;
crashed/abandoned runs leave holders on :8080–:8082 and re-runs stack up.
**Fix:** run_demo.sh now clears listeners on its ports (`lsof -ti | xargs
kill`) before starting. Also made the gateway's ffmpeg call async — a blocking
`subprocess.run` inside an async route stalls the whole event loop (every
other visitor) for up to 30 s.

## 2026-08-19 — the slowness investigation (v0.6.1)

Users (and the author) reported dictation taking 10 s+ and "getting worse the
longer the app runs". Full root-cause analysis: [PERF_RCA_2026-08.md](PERF_RCA_2026-08.md).
It was neither the AI modules nor a leak (`leaks` on an 18-day-old process: 14 KB,
all system XPC). It was model tier × a fixed per-call cost × the chunker.
Shipped in response: Parakeet TDT for English, corrected chunk thresholds,
flash attention on, per-dictation timings, per-language model defaults, and a
latency gate in preflight.

### Failure mode #20 — the chunker charged short dictations for extra full-price calls

**Symptom:** a 2-second tail took ~2 s to appear on an M3 (worse on an M1 Air),
and "release → text" sometimes took several seconds for an ordinary sentence.
**Cause:** whisper encodes a **padded 30-second window** on every call, so a
call costs ~1.5 s (M3) / ~3 s (M1) *regardless of how much audio it holds*. The
chunker cut every 12 s, so a normal dictation paid 2–4 of those; worse, chunk
jobs and the final tail share one serial queue, so releasing while a chunk was
mid-decode made the user wait for both.
**Fix:** don't chunk below 30 s of speech; chunk every ≥25 s (forced at 35 s)
after that. **Lesson:** an optimization built on "cost scales with length" is
wrong when the cost is fixed per call — measure the constant term before
designing around it. Guarded by `scripts/latency_gate.sh` (short clip, per
language) so RTF-on-a-long-clip can never hide this again.

### Failure mode #21 — `enable()` mid-session orphans the chunk ticker

**Symptom:** none reported yet — found while reading the hot path. Would present
as the app getting progressively slower within a session, with duplicated words.
**Cause:** `reloadHotkey()` calls `enable()`, which reset `phase` without
stopping the chunk ticker. Changing a setting *while recording* left a ticker
polling forever; the next dictation started a second one, and both cut chunks →
every chunk transcribed twice, compounding for the life of the process.
**Fix:** `enable()` now tears the session down (`stopChunkTicker()` +
`audio.cancelSession()`) before restarting the hotkey tap.

### Failure mode #12 (flash attention) — retested and reversed

The v0.3 NaN-logits problem with quantized models on Metal did **not** reproduce
on current whisper.cpp: 18 clips across apex/turbo/vaani q5_0, zero NaN, zero
empty decodes, text identical on 17/18 (one single-token difference), ~11 % less
encode time. Flash attention is now **on** with a kill switch in Options.
**Lesson:** a workaround for an upstream bug is a dated decision, not a
permanent one — re-test it on every dependency bump.

## 2026-09-22 — "quality degrades over days" RCA (v0.6.2)

Investigated first: the models themselves. 300 transcriptions of 3 clips in one
long-lived Parakeet process gave identical text and identical speed; both
engines reset decoder/VAD state every call (`no_context`), and 30 h of the
running app's timing log showed flat engine cost. The model does not decay.

### Failure mode #22 — the mic was clocked to the speaker

**Symptom:** users (and the author) report dictation quality "feels worse after
a few days", with no in-app cause.
**Cause:** AVAudioEngine on macOS drives input + output as one device. With a
Maono DGM20 (48 kHz, 2 ch) as input and a Bluetooth Echo Dot (44.1 kHz) as
output, `inputNode` delivered **44.1 kHz** — coreaudiod logged a sample-rate
converter per session and, on macOS 27, "sample rate conversion no longer
enables drift correction by default". So the words depended on whichever speaker
happened to be connected that day. Pinning the device on `inputNode.audioUnit`
did not help: the hardware side read 48 kHz, the node still vended 44.1 kHz.
Secondary: a device change during a session was ignored (`rebuildIfWarm`
skipped when `inSession`) and never retried.
**Fix:** `MicrophoneUnit` — an AUHAL with output disabled, bound to the default
input, client format = the device's native rate/channels. Prototype measured
~80 ms to first audio on both the DGM20 (48 kHz/2ch) and the built-in mic
(44.1 kHz/1ch). Listeners on default-input / device-alive / nominal-rate reopen
the mic, mid-session included. Each open logs `mic open: <name> <rate>Hz <ch>ch`
at `.notice`, so "which mic was it?" is answerable from `log show` afterwards.
**Lesson:** "the default input" is not a stable thing on a laptop that meets
docks, webcams, phones and Bluetooth speakers — log which device the words came
from, or quality complaints are unfalsifiable. **Side note:** the built-in mic
returns pure silence with the lid closed (clamshell) — expected, not a bug.

### Failure mode #23 — CLT 27 can't compile SwiftUI `@State`

**Symptom:** after Command Line Tools 27.0 installed (2026-09-10), every
`swift build` fails with `external macro implementation type
'SwiftUIMacros.StateMacro' could not be found … plugin for module
'SwiftUIMacros' not found`, on every `@State` in the app target. The Kit and
CLI targets still compile.
**Cause:** CLT 27 points `MacOSX.sdk` at the macOS 27 SDK, where SwiftUI's
`@State` is a macro, but the SwiftUIMacros compiler plugin ships only with
full Xcode. Searching the SDK's swiftinterface for "SwiftUIMacros" does *not*
detect it; only compiling does.
**Fix:** `scripts/sdk_env.sh` (sourced by preflight + build_app) type-checks
one `@State` line against the default SDK and, if it fails, exports `SDKROOT`
to the newest installed macOS 26 SDK. No-op with Xcode (CI) or an explicit
`SDKROOT`. The deployment target is unchanged (macOS 14), so the app still runs
on macOS 14 → 27. **Lesson:** a CLT update can change the default SDK under
you — probe by compiling, don't sniff files.

### Failure mode #24 — the "Indian English" eval suite was US English

**Symptom:** found 2026-09-22 while benchmarking Parakeet Redux: the `english`
suite's first clip is a FLEURS sentence read by a US speaker. Four docs, two
code comments and the English engine decision all cited "Svarah, Indian-accented
English".
**Cause:** Svarah is gated; the HF account was never on its access list (the
cache only ever held its README; data files return 403). `download_data.py`
caught the error, printed a one-line fallback notice, and wrote **FLEURS
en_us** into `data/english/` — the manifest carried no source, so nothing
downstream could tell. The same account is also not approved for Lahaja,
IndicVoices or Kathbath.
**Fix:** the eval set was rebuilt from open sources with real Indian voices
(SD-QA ind_n/ind_s, SVQ, EdAcc Indian English, IndicVoices re-cut —
evals/README.md). Every clip records its `source` (and speaker, region, length
bucket) in the manifest; reports break results down by source, so a fallback is
visible in every table, and a failing source aborts loudly (exit 1) instead of
being substituted. Docs corrected in place. While rebuilding: MUCS 2021
Hinglish and NPTEL were rejected (segment audio misaligned with transcripts —
check a few ref/hyp pairs before trusting any new source), and a naive
pyarrow read over HfFileSystem pulled 2.25 GB to read four text columns —
`hf_parquet.py` reads exact byte ranges instead.
**Follow-up (2026-09-23):** Svarah access approved; it is now the english
suite's core (80 clips across 19 native languages + long stretches).
**Lesson:** a silent fallback in a *measurement* pipeline is a mislabelled
result. Record provenance per sample, and fail loudly instead of substituting.
