# Windows — the easiest port (do this first)

**TL;DR:** Same product shape as the Mac app: tray icon, global hotkey, hold-to-talk,
whisper.cpp, paste insertion. No store gatekeeper, no $99, no new UX to invent. The
only real news is: C#/.NET instead of Swift, Vulkan instead of Metal, and SmartScreen
instead of Gatekeeper. **One-shot-able in a single long Claude session.**

## Why Windows before Android

- India's *offices* run Windows. The ICP segments that pay (B2B teams, professionals
  writing email/WhatsApp Web/CRM entries) sit at Windows desks all day.
- Every design decision is already made — we're translating [SYSTEM_DESIGN.md](../SYSTEM_DESIGN.md),
  not designing. Wispr Flow and superwhisper both did Mac → Windows as step 2.
- Zero distribution friction: ship an `.exe` from the site/GitHub Releases, same as the DMG.

## Product shape (mirror of the Mac app)

| Mac (shipping) | Windows equivalent |
|---|---|
| `MenuBarExtra` menu bar app | System-tray app (NotifyIcon) |
| Right-⌥ hold-to-talk via `CGEventTap` | Low-level keyboard hook (`WH_KEYBOARD_LL`) — default **Right-Ctrl** or **Win+H-style Ctrl+Win** (configurable; don't steal Win+H itself) |
| `AVAudioEngine` 16 kHz capture | WASAPI capture (NAudio wraps it) |
| whisper.cpp + Metal | whisper.cpp + CPU (AVX2) / optional Vulkan — via [whisper.net](https://github.com/sandrohanea/whisper.net) bindings or direct P/Invoke |
| Pasteboard-swap ⌘V insertion | Clipboard-swap Ctrl+V via `SendInput` (identical trick; save/restore clipboard) |
| Non-activating overlay | Borderless topmost `WS_EX_NOACTIVATE` overlay window |
| `~/Library/Application Support/DesiDictation/models` | `%LOCALAPPDATA%\DesiDictation\models` (same catalog JSON, same HF URLs, same SHA256s) |
| Launch at login | `Run` registry key |

Stack recommendation: **C# / .NET 8 + WPF** (tray + overlay + settings), whisper.net for
bindings. Rationale: fastest path with a memory-safe UI layer; the C++ core stays C++.
(Alternative — pure C++/Win32 — is leaner but triples shell effort. Not worth it for v0.1.)

## Minimum specs (the "no unified memory" answer)

Unified memory is irrelevant at our model sizes — the 547 MB Apex q5_0 loads into
ordinary system RAM and inference is compute-bound, not bandwidth-starved.

- **Minimum:** 64-bit Win 10, 4-core CPU with AVX2 (Intel ≥2015 / Ryzen anything), 8 GB RAM.
  Apex q5_0 runs ~1–3× realtime on such CPUs in batch mode — fine for hold-to-talk.
- **Comfortable:** any 2020+ 6–8-core, 16 GB — instant-feeling.
- **GPU: not required.** If present, **Vulkan** backend (works on NVIDIA, AMD, *and* Intel
  iGPUs, within ~25–30% of CUDA) — one build, every vendor, no CUDA runtime download.
  Skip CUDA/DirectML/NPU until users ask.
- **Old-laptop fallback:** Swift 141 MB model — same tiering we ship on Mac.

## Distribution & the SmartScreen wall

Direct download (`.exe` installer via Inno Setup or MSIX). Unsigned binaries get a
SmartScreen "unrecognized app" scare — Windows' version of our Gatekeeper problem, but
softer: users click "More info → Run anyway" (no Terminal command needed, kanjoos-
compatible). Fixes over time: cheap OV code-signing cert (~$100–200/yr, reputation
builds), or **free** signing via the Microsoft Store route later. Beta ships unsigned
with a guide section, exactly like the Mac beta.

## Risks

1. **Hotkey conflicts** — Windows apps fight over hotkeys; make it configurable day one.
2. **Insertion edge cases** — some apps (admin-elevated windows, secure desktops) block
   `SendInput`; fall back to "copied to clipboard" toast like the Mac app does.
3. **Antivirus false positives** on unsigned keyboard-hook apps — document, sign ASAP.
4. **Hardware zoo** — pin v0.1 to CPU-only inference; add Vulkan behind a toggle.

## The one-shot Claude prompt

**Human pre-flight (do these yourself first):** a Windows 11 machine (or VM) with
.NET 8 SDK + Git + CMake + VS Build Tools installed; clone the repo; copy one model
file into `%LOCALAPPDATA%\DesiDictation\models`; a test WAV in the repo.

Then paste (run with loop/dynamic-workflow mode on, high budget):

```text
GOAL — one shot, loop until done:
Build "Desi Dictation for Windows" v0.1: a C#/.NET 8 WPF system-tray app that
does hold-to-talk Hinglish dictation into any focused Windows app, fully offline,
mirroring our shipping macOS app.

CONTEXT (read all before writing code):
- This repo: docs/SYSTEM_DESIGN.md (pipeline + decisions), docs/genesis/plan.md,
  app/Sources/DesiDictationKit/ (the Swift reference implementation — port its
  behavior: hotkey semantics, clipboard-swap insertion, model catalog with URLs
  and SHA256s in ModelManager.swift, replacement dictionary, 24h history).
- whisper.cpp is vendored per scripts/setup_whisper.sh; use the whisper.net NuGet
  bindings (CPU runtime) instead of hand-rolled P/Invoke.
- Models: same GGML files, catalog URLs unchanged. Default: ggml-hinglish-apex-q5_0.bin.

SCOPE v0.1 (nothing more):
1. Tray icon with menu: Enable/Disable, model picker (installed models only),
   hotkey picker (Right-Ctrl default), Launch at login, Quit.
2. Global hold-to-talk: WH_KEYBOARD_LL hook; press = start WASAPI 16kHz mono
   capture; release = stop, transcribe once (batch, no streaming), insert.
3. Insertion: save clipboard → set text → SendInput Ctrl+V → restore clipboard
   after 300ms. If insertion fails, toast "Copied to clipboard".
4. Minimal always-on-top non-activating overlay showing recording/transcribing state.
5. Model download from the catalog URLs with SHA256 verify + progress, into
   %LOCALAPPDATA%\DesiDictation\models.
6. Settings persisted as JSON in %LOCALAPPDATA%\DesiDictation.

NON-GOALS (do NOT build): streaming transcription, VAD, GPU backends, installer,
signing, auto-update, licensing/Pro gating, onboarding UI, history UI (log to a
JSONL file only), any change to the mac app or shared docs.

DEFINITION OF DONE — verify each yourself, loop until ALL pass:
A. `dotnet build -c Release` exits 0 with zero warnings-as-errors.
B. A headless CLI mode (`DesiDictation.exe --transcribe path.wav`) prints a
   non-empty transcription of the test WAV and exits 0 — prove the engine path.
C. Unit tests (xUnit) for: clipboard save/restore, catalog JSON parse, SHA256
   verify, replacement-dictionary application. All green.
D. App launches, tray icon appears, log file shows hook installed; simulate the
   hotkey path in an integration test using SendInput on a Notepad window and
   assert the text arrives (use UI Automation to read it back).
E. Working set < 300 MB idle (model unloaded) — read it from Process metrics
   and print it in the smoke test.
F. Write BUILD_WINDOWS.md: exact build steps + a failure-modes log of every
   error you hit and fixed (mirror the style of docs/BUILD_LOG.md).

LOOP RULE: after every change, rebuild and rerun the failing check; never ask me
whether to continue; only stop when A–F all pass or you are hard-blocked by
something requiring a human (say exactly what). Work in a new folder `windows/`
at repo root; touch nothing outside it.
```

**Expected outcome:** a working v0.1 in `windows/` in one session; a second short
prompt adds Vulkan toggle, installer, and polish.
