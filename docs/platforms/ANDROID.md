# Android — the strategic must-have (India lives here)

**TL;DR:** Don't build a keyboard. Build a **voice input method (voice IME)** — the
thing that opens when the user taps the mic button on the keyboard they already love.
whisper.cpp already runs on Android (official `examples/whisper.android`); FUTO Voice
Input proves the entire architecture end-to-end and is source-available to learn from.
**A 3-prompt arc with Claude**, each prompt one-shot-able.

## The flow question — answered

Your instinct is right: "install our keyboard → switch keyboards → dictate → switch
back" is a dead-on-arrival flow. Android gives us something iOS doesn't:

### The low-friction path: be the *voice input method*, not the keyboard

Android's IME framework supports a **voice subtype**: when the user taps the **mic
button on their existing keyboard** (Gboard, Samsung Keyboard, etc.), Android opens
the configured *voice* IME — which can be us. Additionally, any app firing the generic
`android.speech.action.RECOGNIZE_SPEECH` intent can route to us.

User experience after one-time setup:
1. User is typing in WhatsApp with Gboard, exactly as always.
2. Taps Gboard's mic button (or our panel's trigger).
3. **Our panel slides up in place of the keyboard** — big mic, waveform, "bol, likh
   denge" — records, transcribes on-device, commits Hinglish text into the field.
4. Tap done / auto-return → Gboard is back. No keyboard switching, ever.

This is exactly [FUTO Voice Input](https://voiceinput.futo.org/)'s architecture
([source](https://gitlab.futo.org/keyboard/voiceinput), whisper.cpp inside). It exists,
it works, it's the pattern to port — with our models, our Hinglish tuning, our polish.

Secondary entry points (cheap to add): home-screen widget + Quick Settings tile that
open a floating dictation card with "Copy"/"Share" results — covers dictating *before*
choosing where the text goes.

### What we deliberately don't do

- **Full keyboard app:** swipe, autocorrect, emoji search, themes — a separate company's
  worth of work, and keyboard-switching is the friction we're avoiding. Never.
- **Accessibility-service text injection** (to type into fields from a floating bubble):
  powerful but a Play-policy minefield (accessibility APIs for non-accessibility use get
  apps rejected/pulled). Not in v1; revisit only with strong counsel.

## Technical plan

1. **Engine layer:** whisper.cpp via JNI — start from the official
   `examples/whisper.android` (Kotlin + JNI, arm64 NEON). Batch mode only
   (hold/tap-to-talk → release → transcribe once). Streaming on Android is ~5×
   slower than realtime and kills battery — [confirmed upstream](https://github.com/ggml-org/whisper.cpp/discussions/3567).
   VAD (Silero, already in our stack) trims silence to cut compute.
2. **IME layer:** `InputMethodService` registered with a voice subtype +
   `RecognitionService` for the RECOGNIZE_SPEECH intent. IMEs can hold
   `RECORD_AUDIO` — mic access happens while our panel is foreground (no
   background-mic foreground-service headaches in the core flow).
3. **Model delivery:** same catalog/HF URLs. **Default = Swift 141 MB** (downloads on
   first run over Wi-Fi prompt), Apex q5_0 547 MB opt-in on 8 GB+ devices. APK stays
   <30 MB; models are never bundled (Play has a 200 MB base limit anyway).
4. **Memory/thermal budget:** target ≤700 MB working set with Swift, ≤1.6 GB with
   Apex; unload model after N minutes idle; single inference thread pool sized to
   big cores only.
5. **Distribution:** Play Store (declare mic use in Data Safety; IME privacy policy
   required) **+ direct APK on the site** (Android's blessing — beta can ship
   *today* without any review, our Gatekeeper story doesn't repeat here).

## Minimum specs

| Tier | Device | Model | Experience |
|---|---|---|---|
| Floor | arm64, Android 10, 4 GB RAM (₹8–12k phones) | Swift 141 MB | 3–8s wait after release; usable, not delightful |
| **Target** | 6–8 GB RAM, SD 7-series/Dimensity 8000 (₹15–30k) | Swift default, Apex opt-in | 1–3s; good |
| Premium | 8–12 GB flagships | Apex q5_0 | ~1s; great |

India context: 4–8 GB is ~42% of the market and entry phones still ship 3–4 GB — the
floor tier exists so the app *installs and works* there, but the ₹15k+ tier is the
beachhead. 32-bit and <4 GB devices: unsupported, politely.

## Risks

1. **Perf variance across SoCs** — mitigate: model tiering by `ActivityManager.MemoryInfo`
   + a first-run 3-second benchmark that picks the tier.
2. **OEM keyboards that hide the voice-IME hook** (some Chinese OEM keyboards hardcode
   their own) — mitigate: widget/tile entry points + setup screen that deep-links to
   the voice-input setting.
3. **Kotlin/JNI is new to us** — mitigate: the two reference codebases named above; the
   Claude prompts pin them.
4. **Play review friction** — IMEs get extra privacy scrutiny; our genuinely-offline
   story is the strongest possible answer (audio never leaves the device, verifiable).

## The Claude prompts (3-prompt arc)

**Human pre-flight:** install Android Studio + NDK; a physical arm64 phone with USB
debugging (`adb devices` shows it); clone repo; test WAV + model file on hand.

### Prompt 1 — engine spike (one shot)

```text
GOAL — loop until done: In a new `android/` folder, build a minimal Android app
(Kotlin, minSdk 29, arm64-v8a only) that transcribes a bundled 10s Hinglish WAV
fully on-device using whisper.cpp via JNI, and ALSO records 5s from the mic and
transcribes that, showing both results on screen.

CONTEXT: Port from the official whisper.cpp example examples/whisper.android
(vendored at vendor/whisper.cpp). Model: load ggml-hinglish-swift.bin from app
files dir; add a debug screen button "fetch model" that downloads it from the
catalog URL in app/Sources/DesiDictationKit/ModelManager.swift and verifies SHA256.
Decode params: mirror the Swift app's (language hi->Hinglish task, our params in
WhisperEngine — replicate them exactly).

DEFINITION OF DONE (verify each via adb, loop until all pass):
A. `./gradlew assembleDebug` exits 0.
B. `adb install` + an instrumented test that runs the WAV fixture through the
   JNI engine and asserts a non-empty Roman-script result — passes on the
   attached device.
C. Logcat shows transcription wall-time; print realtime factor; it must be <1.0
   (faster than realtime) for the fixture on this device.
D. Peak RSS during transcription logged and < 900 MB.
E. Write android/NOTES.md with timings, memory, and every error you fixed.
NON-GOALS: IME, UI polish, streaming, VAD, Apex model, Play packaging.
Never ask to continue; stop only when A–E pass or hard-blocked (say what).
```

### Prompt 2 — the voice IME (one shot)

```text
GOAL — loop until done: Turn android/ into "Desi Dictation" v0.1: an Android
voice input method. When the user taps the mic key on their existing keyboard
(voice IME subtype) or an app fires RECOGNIZE_SPEECH, our panel opens over the
keyboard: tap-to-talk (tap start / tap stop, with 30s cap), on-device
transcription with the engine from Prompt 1, text committed via
InputConnection.commitText, panel dismisses back to their keyboard.

STUDY FIRST: FUTO Voice Input source (gitlab.futo.org/keyboard/voiceinput,
mirrored at github.com/futo-org/voice-input) — replicate its IME wiring
(InputMethodService with voice subtype + RecognitionService), NOT its UI.

ALSO BUILD: onboarding activity (enable IME → set as voice input → mic
permission → model download with progress), settings screen (model picker,
replacement dictionary — port the format from the Swift app), Quick Settings
tile that opens a floating dictation card with Copy/Share.

DEFINITION OF DONE (loop until all pass):
A. assembleDebug exits 0; ktlint clean.
B. Instrumented test: focus an EditText in a test activity, invoke our IME
   programmatically, feed a fixture WAV through the engine path, assert the
   EditText contains the expected Hinglish substring.
C. Manual-equivalent scripted check via adb: enable IME (`adb shell ime enable/set`),
   open the test activity, trigger dictation, screenshot saved to android/screenshots/.
D. Model unloads after 3 min idle (assert via a test hook + memory log).
E. Update android/NOTES.md (what works, what's flaky, on-device timings).
NON-GOALS: Play Store packaging, accessibility service, full keyboard, streaming,
history UI, monetization.
```

### Prompt 3 — hardening + release (one shot)

Device-tier auto-selection (RAM check + first-run benchmark), Apex opt-in for 8 GB+,
battery/thermal guardrails, crash-free error states, direct-APK release build with
signing config, Play data-safety draft, SETUP_GUIDE_ANDROID.md. Same loop rules,
DoD includes: release APK < 30 MB, cold-start-to-ready < 2s (model preloaded),
instrumented suite green.
