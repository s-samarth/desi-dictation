# Platform Expansion — getting Desi Dictation on every device

**Status: research + plan only. Nothing here is being executed yet.** (Written 2026-07-09.)

This folder answers: which devices do we go to, in what order, what does each one
minimally need, what does the dictation *flow* look like on each (and how do we cut
friction), and — since we build with Claude — the precise one-shot prompt per platform.

| Doc | Platform | Difficulty | Verdict |
|---|---|---|---|
| [WINDOWS.md](WINDOWS.md) | Windows 10/11 x64 (+ARM later) | ★★☆☆☆ **Easiest** | Do first. Same product shape as the Mac app. |
| [ANDROID.md](ANDROID.md) | Android 10+ arm64 | ★★★☆☆ Medium | Do second. **The must-have for India.** Voice-IME, not a full keyboard. |
| [IOS.md](IOS.md) | iPhone (iOS 17+) | ★★★★☆ **Hardest** | Do third. Keyboard extensions can't touch the mic — flow is structurally worse. |

## Why this order (and not Android first, despite India)

1. **Windows** reuses ~everything you know: tray app (≈ menu bar), global hotkey,
   whisper.cpp (already has Windows/Vulkan builds), paste-style insertion, direct
   `.exe`/`.msi` download — no store, no reviewer, no $99. Wispr Flow and superwhisper
   both shipped Windows *before* Android for exactly this reason. Fastest second
   platform → fastest learning about non-Mac users.
2. **Android** is the strategic prize (India is an Android country — the sub-$200
   segment is ~40% of shipments) but adds a new language (Kotlin), JNI, IME
   plumbing, device fragmentation, and battery/thermal discipline. Worth it — as
   platform #2-in-parallel or #3, not the first port.
3. **iOS** has the best hardware (Neural Engine) and the worst rules: **keyboard
   extensions have been kernel-blocked from the microphone since iOS 8** — every
   competitor (Wispr Flow, superwhisper) lives with an app-hop flow. Also App
   Store-only distribution + the $99/yr account. Do it once Android proves the
   mobile UX.

**"App Store doesn't allow vibe-coded apps" is a myth.** Apple's 4.3(b) rule (tightened
June 2026) targets *low-effort spam* — template clones, thin wrappers, minimum-functionality
apps. It does not ask how code was written. A real, native, functional dictation app with
on-device models is the opposite of what 4.3(b) exists to block. What *will* get you
rejected: crashes (2.1), missing privacy disclosures (5.1.1), or looking like the 500th
"AI keyboard" wrapper. Ship something real and polished and this is a non-issue.

## The architecture that makes 4 platforms sane: one C++ core, native shells

whisper.cpp is C/C++ and already runs on macOS, Windows, Android (JNI example in-repo),
and iOS. **The same GGML `.bin` files we already host serve every platform.** So:

```
        ┌───────────────────────────────────────────────┐
        │  SHARED CORE (C/C++, one repo folder)         │
        │  whisper.cpp + VAD + our decode params +      │
        │  post-processing rules + model catalog JSON   │
        └───────┬──────────┬──────────┬──────────┬──────┘
             Swift       C#/C++     Kotlin      Swift
            (macOS ✅)  (Windows)  (Android)    (iOS)
            menu bar     tray       voice-IME    keyboard ext
            Right-⌥      Ctrl+Win   mic-button    + app-hop
```

- **Native shells, not Flutter/React Native.** An IME, a tray app, and a keyboard
  extension are exactly the surfaces cross-platform frameworks are worst at
  (deep OS hooks, tiny memory budgets). The shell code per platform is small; the
  hard part (engine, models, decode tuning) is shared C++.
- **Shared "brain" spec:** hotkey semantics, model catalog + SHA256s, replacement-
  dictionary format, history schema — write once as a spec doc, implement per shell.
  This is also what makes the Claude one-shot prompts work: the spec is the prompt's
  backbone.

## Minimum specs per device (and the GPU question)

**We do not need a GPU anywhere.** Unified memory matters for 7B+ LLMs, not for a
0.5–1 GB ASR model. Whisper-class inference at our sizes is CPU-feasible on anything
modern; GPU (Metal/Vulkan) and NPU (ANE) are accelerators, not requirements. The
Apex q5_0 model is 547 MB on disk, ~1–1.5 GB working set with mel + KV + runtime.

| Device | Minimum | Recommended | Model tier | Engine backend |
|---|---|---|---|---|
| **macOS** (shipping) | Apple Silicon, 8 GB | M-anything, 16 GB | Apex q5_0 | Metal ✅ |
| **Windows** | x64 CPU with AVX2 (~2015+, 4 cores), 8 GB RAM, Win 10 64-bit | 8-core 2020+ CPU or any Vulkan-capable GPU (incl. Intel/AMD iGPU), 16 GB | Apex q5_0 (CPU ok); Swift 141 MB fallback for old laptops | CPU + optional Vulkan (skip CUDA installer hell at first) |
| **Android** | arm64-v8a, Android 10+, **6 GB RAM**, 1.5 GB free storage | 8 GB RAM, Snapdragon 7-series+ / Dimensity 8000+ | **Swift 141 MB default**, Apex q5_0 opt-in on 8 GB+ | CPU (NEON) first; Vulkan/NNAPI later |
| **iPhone** | iPhone 12 / A14, 4 GB RAM, iOS 17 | iPhone 14+, 6 GB | Apex via Core ML-encoder or WhisperKit | CPU+ANE (Core ML encoder ≈ 3–6× speedup) |

India reality check: entry phones (<₹10k) still ship 3–4 GB RAM — they get the Swift
model + batch mode, not Apex. Don't chase 3 GB devices at launch; the ₹15k+ tier
(6–8 GB) is the beachhead. Details per platform file.

**Battery/thermal (mobile only):** batch-on-release transcription (record → release →
transcribe once), *not* continuous streaming — whisper.cpp streaming on Android is
~5× slower than realtime and drains battery. Our Mac app's hold-to-talk model already
matches the right mobile pattern.

## The friction problem on mobile (summary — details in each file)

You're right that "switch keyboard → dictate → switch back" is a terrible flow. The fixes:

- **Android — don't be a keyboard, be the *voice input method*.** Android lets a voice
  IME register so that **the mic button on the user's existing keyboard** (Gboard etc.)
  invokes *us* — our panel slides up over the keyboard, transcribes on-device, commits
  text, returns. User keeps Gboard, swipe typing, everything. This is the FUTO Voice
  Input model and it's the single most important design decision in this folder.
- **iOS — friction is structural; minimize, don't eliminate.** Keyboard extension with a
  big mic button that hops to the app for the recording session and auto-returns
  (Wispr's model), **plus** Action-button/Shortcut entry (record without any keyboard
  switching) and a Control Center control. Nobody — including $30M-funded Wispr — has
  a friction-free iOS flow, because Apple reserves true dictation integration for itself.
- **Windows — zero friction available:** global hotkey works everywhere, exactly like the Mac.

## Building it with Claude — how to use the prompts

Each platform file ends with a **one-shot prompt**. The prompts follow one recipe
(this is the "loop engineering" part):

1. **Human pre-flight first** (10 min, listed per platform): install SDK, plug in a
   device, create signing key. An agent can't click "Trust this computer."
2. **Precise goal + explicit non-goals** — one-shots die from scope creep, so the
   prompt pins v0.1 scope and forbids everything else.
3. **Machine-checkable Definition of Done** — every acceptance criterion is something
   the agent itself can verify (build passes, `adb` smoke test emits expected text,
   CLI transcribes a fixture WAV). "Works well" is not a criterion; "exit code 0 and
   output contains ≥1 Devanagari-free Hinglish token" is.
4. **A verification loop, stated as a loop:** "build → run → read logs → fix → repeat
   until all DoD checks pass; do not report done before." Run it with dynamic
   workflows/loop mode on and a generous budget; check in at milestone gates, not
   every step.
5. **Reference implementations named in the prompt** (whisper.cpp's own
   `examples/whisper.android`, FUTO Voice Input source, our Mac repo) — one-shots
   succeed when the model ports proven code instead of inventing.

Realistic expectations: **Windows v0.1 is genuinely one-shot-able** (one long session).
**Android is a 3-prompt arc** (engine JNI → voice-IME → polish), each one-shot-able.
**iOS is 2 prompts + a human day** for provisioning/App Store submission, which no
agent can do for you.

## Not doing (and why)

- **Full keyboard app (Android/iOS):** swipe, autocorrect, emoji, 40 languages — a
  multi-year product on its own. We are the *voice* layer that plugs into any keyboard.
- **Web/WASM:** whisper-in-browser is slow, tab-bound, and can't insert text into other
  apps — breaks the whole product promise.
- **Linux:** dear to hackers, ~0 revenue, and the desktop input landscape (X11/Wayland)
  is fragmented. Revisit if the community asks loudly; the C++ core makes it cheap later.
- **Intel Macs:** already decided — never.

## Sources (key ones)

- iOS keyboard-mic block: [Apple's Custom Keyboard guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html), [MacStories on the limitation](https://www.macstories.net/notes/on-the-limitations-of-ios-custom-keyboards/)
- Wispr Flow's iOS app-hop flow: [Wispr help center](https://docs.wisprflow.ai/articles/7453988911-set-up-the-flow-keyboard-on-iphone), [9to5Mac coverage](https://9to5mac.com/2025/06/30/wispr-flow-is-an-ai-that-transcribes-what-you-say-right-from-the-iphone-keyboard/)
- Android voice-IME prior art: [FUTO Voice Input](https://voiceinput.futo.org/), [source](https://gitlab.futo.org/keyboard/voiceinput)
- whisper.cpp platform support + Core ML/ANE speedups: [whisper.cpp repo](https://github.com/ggml-org/whisper.cpp), [ANE discussion #548](https://github.com/ggml-org/whisper.cpp/discussions/548)
- Android streaming-vs-batch perf: [whisper.cpp discussion #3567](https://github.com/ggml-org/whisper.cpp/discussions/3567)
- App Store 4.3(b) tightening (low-effort apps, not AI authorship): [MacRumors](https://www.macrumors.com/2026/06/09/app-store-guidelines-low-quality-apps/), [9to5Mac](https://9to5mac.com/2026/06/09/apple-tightens-app-review-guidelines-against-apps-that-do-not-add-value-to-the-app-store/)
- India RAM/segment data: [Counterpoint via Fonearena](https://www.fonearena.com/blog/474743/india-smartphone-market-2025-counterpoint.html), [Business Standard](https://www.business-standard.com/technology/tech-news/premium-push-or-rising-costs-what-s-shrinking-india-s-budget-phone-market-126031300318_1.html)
