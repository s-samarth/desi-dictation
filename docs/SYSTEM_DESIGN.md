# System Design — Desi Dictation

The "what and why" of the architecture. The "what went wrong while building it"
lives in [BUILD_LOG.md](BUILD_LOG.md).

## 1. Design goals

1. **Latency**: release-of-key → text-inserted must feel instant (< 1 s typical).
2. **MacBook Air-class hardware**: fanless, possibly 8 GB RAM.
3. **Local-first**: audio never leaves the machine; the only optional network
   calls are model downloads, Gumroad license verify, and user-opted Ollama
   (which is also local).
4. **Never lose a dictation**: any post-processing failure degrades gracefully
   to the raw transcript.
5. **Swappable engines/models**: MacWhisper's "runner" pattern — the engine is a
   protocol, the model is a file.

## 2. Component map

```
                        ┌──────────────────────────────┐
   Right⌥ down/up ──►   │  HotkeyManager (CGEventTap)  │──► Esc? cancel
                        └───────────┬──────────────────┘
                                    ▼
                        ┌──────────────────────────────┐
                        │ DictationController @MainActor│  phase: idle/recording/
                        │  (the only orchestrator)      │  transcribing/error
                        └───┬───────────┬───────────┬──┘
              start/stop    │           │           │ publishes phase
                            ▼           ▼           ▼
                   ┌────────────┐ ┌──────────┐ ┌─────────────┐
                   │AudioCapture│ │ worker Q  │ │OverlayPanel │ (non-activating
                   │ input-only │ │(serial)  │ │+ MenuBarExtra│  NSPanel)
                   │AUHAL (mic's│ │          │ │             │
                   │native rate)│ │          │ │             │
                   │→16kHz mono │ └────┬─────┘ └─────────────┘
                   └────────────┘      ▼
                              ┌────────────────┐
                              │TranscriptionEngine (protocol)
                              │ └ WhisperCppEngine (Metal)   │
                              └────────┬───────┘
                                       ▼
                              ┌────────────────┐
                              │ PostProcessor  │ legacy rules → PersonalDictionary
                              └────────┬───────┘ → (opt) Ollama cleanup
                                       ▼
                              ┌─────────────────────────────┐
                              │ finishPipeline (post stages) │ anyToEnglish →
                              │  LLMServices (LocalLLM proto │ .translating;
                              │  └ OllamaLLM, 127.0.0.1)     │ tone → .polishing;
                              │  translate / tone / structure│ thinking session →
                              └────────┬────────────────────┘ ThoughtsWindow
                                       ▼         (every failure → raw words win)
                              ┌────────────────┐
                              │  TextInserter  │ pasteboard swap + ⌘V CGEvent
                              └────────────────┘
```

Support singletons: `SettingsStore` (UserDefaults), `ModelManager` (scan +
download), `HistoryStore` (last 50, JSON, now with raw/translation fields),
`PersonalDictionary` (lexicon JSON), `AppModeStore` (per-app language rules +
frontmost-app tracking), `LLMServices` (LLM feature wiring),
`LicenseManager` (Gumroad), `Permissions`, `Sounds`.
LLM feature internals: [features/implementation/](features/implementation/README.md).

## 3. Key decisions & trade-offs

### Two engines behind one protocol (v0.6.1)
`EngineRouter` picks the runtime from the model **file**: Parakeet TDT
(`libparakeet`, English) or whisper.cpp (Hinglish, हिन्दी, everything else), and
keeps exactly one model resident. Parakeet encodes only the audio it was given,
which is why English dictation is ~9× faster per call than the whisper path it
replaced (MODEL_RESEARCH.md §E, features/implementation/MODEL_ROUTING.md).

### whisper.cpp static libs, not WhisperKit (v1)
- whisper.cpp conversion of a HF fine-tune is a one-script, low-risk path;
  WhisperKit CoreML conversion is a longer pipeline with op-coverage risk.
- Cost: CPU+GPU instead of Neural Engine → slightly worse battery on fanless
  Airs. The `TranscriptionEngine` protocol is the seam where a
  `WhisperKitEngine` lands in Phase 5.
- Built with `GGML_METAL_EMBED_LIBRARY=ON`: Metal shaders are JIT-compiled at
  model load (≈7 s once per process) because the CLT has no Metal compiler.
  Mitigation: the model is **preloaded when dictation is enabled** and kept
  resident, so users never feel it per-dictation.

### Record-then-transcribe; chunk only long sessions (v0.4, corrected v0.6.1)
Whisper's cost is **per call, not per second** — it encodes a padded 30 s window
every time — so chunking a short dictation buys nothing and costs a second full
call (BUILD_LOG FM#20). Dictations under 30 s of speech are therefore one call;
longer ones cut every ≥25 s while the user keeps talking. Streaming *partial
text* into the overlay remains deferred (PERFORMANCE.md).

### Input-only mic unit, not AVAudioEngine (v0.6.2)

On macOS, AVAudioEngine runs input and output as **one** device, so the mic is
clocked to the default *speaker*. Measured 2026-09-22: a 48 kHz USB mic arrived
at 44.1 kHz because output was a Bluetooth Echo Dot, through a conversion macOS
27 runs without drift correction. Capture now uses `MicrophoneUnit`, a HAL unit
with output disabled, bound to the default input and opened at the mic's own
rate and channel count. The only resampling is ours: native → 16 kHz mono,
stereo downmixed rather than dropping a channel. The speaker can no longer
touch the words (BUILD_LOG FM#22).

### Pasteboard-swap insertion
1. Save current clipboard string → 2. set transcript → 3. synthesize ⌘V via
`CGEvent` at the HID tap → 4. restore old clipboard after 400 ms.
- Works in native apps, Electron, browsers, terminals — the widest single
  strategy. Known gaps (apps that block programmatic paste, non-string
  clipboard content is not restored) get the AX-API fallback in a later rev.
- The **overlay must never take focus** (`.nonactivatingPanel`, no key window,
  `ignoresMouseEvents`) — if it did, the paste would land in the overlay.

### Hotkey via CGEventTap, not Carbon RegisterEventHotKey
PTT semantics need **keyUp** and **flagsChanged** (for Right ⌥), which Carbon
hotkeys don't deliver. The tap also lets us swallow Esc only *while recording*.
Cost: requires Input Monitoring + Accessibility permissions; the tap re-enables
itself on `tapDisabledByTimeout` (macOS punishes slow callbacks — ours only
dispatch async and return).

### Concurrency model
`DictationController` is `@MainActor`; the engine lives behind a **single serial
DispatchQueue** (`nonisolated(unsafe)` — safety by serialization, documented at
the property). Whisper contexts are not thread-safe; one queue = no locks.

### Free/Pro gating
`LicenseManager.isPro` gates: >base-size model downloads, Ollama cleanup.
Gumroad verify (`/v2/licenses/verify`) is called once, cached in UserDefaults,
so the app is fully offline after activation. Pre-launch builds use
`defaults write com.desi.dictation devUnlock -bool true`.

## 4. Data & privacy

| Data | Where | Leaves the Mac? |
|---|---|---|
| Audio | RAM only (Float array), discarded after transcription | Never |
| Transcripts | RAM + optional `history.json` (last 50, clearable) | Never |
| Models | `~/Library/Application Support/DesiDictation/models/` | Downloaded from HF once |
| Settings | UserDefaults `com.desi.dictation` | Never |
| License key | UserDefaults + one POST to Gumroad on activation | Only to Gumroad |

## 5. Performance (measured, M3, release build)

| Metric | Value |
|---|---|
| Transcription speed (hinglish-swift, 72 M) | **39× realtime** — a *throughput* number; short-dictation latency is what users feel, see PERFORMANCE.md |
| Post-release latency, 15 s utterance | **~0.4 s** |
| Model load (one-time, incl. Metal JIT) | 7.7 s |
| App bundle size | 2.6 MB (+ model files) |
| RAM with swift model resident | ~350 MB |

Apex (0.8 B q5_0, ~570 MB) projections: ~8–15× realtime on M1 Air → 15 s
utterance ≈ 1–2 s. Validate in the personal eval (spike/README.md).

## 6. Failure-mode handling (runtime)

| Failure | Behavior |
|---|---|
| No model selected | phase → error, menu shows message; nothing crashes |
| Mic permission denied | `audio.start()` throws → error phase + Basso sound |
| Event tap creation fails | phase → error "needs Input Monitoring"; menu links to System Settings |
| Ollama down/slow/garbage | 30 s timeout, raw transcript inserted unchanged |
| Empty/too-short audio | error sound, back to idle, nothing inserted |
| Esc mid-recording | audio discarded, error sound, idle |
| macOS disables the tap | auto re-enable inside the callback |
