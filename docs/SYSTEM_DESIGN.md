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
                   │AVAudioEngine│ │(serial)  │ │+ MenuBarExtra│  NSPanel)
                   │→16kHz mono │ └────┬─────┘ └─────────────┘
                   └────────────┘      ▼
                              ┌────────────────┐
                              │TranscriptionEngine (protocol)
                              │ └ WhisperCppEngine (Metal)   │
                              └────────┬───────┘
                                       ▼
                              ┌────────────────┐
                              │ PostProcessor  │ dictionary rules → (opt) Ollama
                              └────────┬───────┘
                                       ▼
                              ┌────────────────┐
                              │  TextInserter  │ pasteboard swap + ⌘V CGEvent
                              └────────────────┘
```

Support singletons: `SettingsStore` (UserDefaults), `ModelManager` (scan +
download), `HistoryStore` (last 50, JSON), `LicenseManager` (Gumroad),
`Permissions`, `Sounds`.

## 3. Key decisions & trade-offs

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

### Record-then-transcribe, no streaming (v1)
At 39× realtime, even a 60 s dictation transcribes in ~1.5 s after key-release.
Streaming/chunked pre-transcription adds state-management complexity (whisper
context reuse, chunk-boundary word merging) for marginal perceived gain at these
speeds. Revisit only if users dictate multi-minute monologues (genesis/plan.md P3.1).

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
| Transcription speed (hinglish-swift, 72 M) | **39× realtime** |
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
