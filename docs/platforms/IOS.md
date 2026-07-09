# iOS — best hardware, worst rules (do it third)

**TL;DR:** Your instinct is correct — iOS is the hardest, but not for the reason you
heard. "App Store bans vibe-coded apps" is a myth (see below). The real wall:
**keyboard extensions have been kernel-blocked from the microphone since iOS 8** —
Apple's position is that a third-party keyboard that can listen is spyware. So *every*
iOS dictation app (Wispr Flow, superwhisper) records in the **main app**, and the
keyboard is just a trigger. The flow you experienced — switch keyboard, hop to app —
is not their laziness; it's the ceiling Apple sets. Our job is to hit that ceiling
more gracefully, with on-device as the differentiator (Wispr is cloud-only — audio
leaves the phone; we're the privacy answer).

## The two myths, killed

1. **"App Store doesn't allow vibe-coded apps."** No such rule. The June-2026
   tightening of guideline 4.3(b) targets *low-effort spam* — template clones and
   minimum-functionality wrappers ([MacRumors](https://www.macrumors.com/2026/06/09/app-store-guidelines-low-quality-apps/)).
   Nothing in review asks how the code was authored. What actually gets apps
   rejected: crashes (2.1), privacy-label gaps (5.1.1), spammy sameness (4.3). A
   native, genuinely functional, on-device dictation app sails past all three.
   Real costs of iOS: **$99/yr developer account** (the kanjoos tax finally comes
   due), review latency (days), and App Store-only distribution (India isn't in the
   EU alt-marketplace regime).
2. **"Someone must have a slicker flow we haven't found."** No. Keyboard extensions
   can't record ([Apple's own docs](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html)); Wispr's flow is keyboard-button → **hop to
   main app** → start a timed "Flow Session" → hop back ([their docs](https://docs.wisprflow.ai/articles/7453988911-set-up-the-flow-keyboard-on-iphone)).
   That's the state of the art. Apple reserves zero-friction dictation for its own
   mic key.

## Flow design — squeeze the ceiling

Ship **several entry points**, because on iOS no single one is good:

1. **Keyboard extension (the Wispr pattern, done politely):** our keyboard is
   *minimal* — one big mic key + "back to your keyboard" key. Tap mic → app-hop →
   recording starts instantly (pre-warmed session) → auto-hop back → keyboard
   inserts the text via the shared App Group container. Total added friction vs
   Wispr: none; and our transcription happens on-device.
2. **Action Button + Shortcuts (App Intents):** iPhone 15 Pro+ users map the Action
   button to "Dictate" — press, speak, result lands in clipboard + a paste banner.
   No keyboard involvement at all. This is the *lowest-friction* iOS path that
   exists; make it first-class, not an afterthought.
3. **Control Center control + Lock Screen widget** (iOS 18 ControlCenter API):
   one-tap dictation from anywhere → clipboard + share sheet.
4. **Share extension:** select text anywhere → "Desi Dictation: reply by voice" (v2,
   pairs with the translate/structure features).

Positioning note: on iOS we're arguably a **capture** app first (voice → clean
Hinglish text in clipboard/notes) and an input method second. Fighting for "type in
every field" on iOS is fighting Apple; capturing thoughts fast is uncontested.

## Technical plan

1. **Engine:** whisper.cpp already builds for iOS. Add the **Core ML encoder** path
   (ANE gives ~3–6× encoder speedup, [upstream #548](https://github.com/ggml-org/whisper.cpp/discussions/548));
   evaluate [WhisperKit](https://github.com/argmaxinc/WhisperKit) (Swift-native,
   ANE-optimized, supports fine-tunes converted to their format) as an alternative
   backend — likely the better iOS citizen for battery.
2. **Reuse the Mac code.** This is the payoff platform for our Swift codebase:
   `DesiDictationKit`'s engine wrapper, model manager, catalog, replacement
   dictionary, history — large parts compile for iOS with minor `#if os()` work.
   New: the keyboard extension target, App Intents, audio-session handling.
3. **Memory:** keyboard extensions get ~60–80 MB — another reason the model *must*
   live in the main app (it does anyway, per the mic rule). Main app has headroom
   for Apex q5_0 on 4 GB+ iPhones; Core ML compile on first run needs a "one-time
   optimization" progress screen.
4. **Model delivery:** on-demand download as on Mac; App Store binary stays small.

## Minimum specs

- **Floor:** iPhone 12 (A14, 4 GB RAM), iOS 17 — Apex q5_0 works; first-run Core ML
  compile ~1 min.
- **Recommended:** iPhone 14+ — comfortably instant.
- iPads: same binary, free bonus market (students, note-takers).
- No Android-style tiering needed — even 4-year-old iPhones outrun mid-range Androids.

## Distribution reality

- $99/yr Apple Developer Program — unavoidable. Budget it; direct install
  (AltStore etc.) is not a real consumer channel in India.
- **TestFlight is the beta channel** (10k testers, no review for internal builds,
  light review for external) — actually *better* than our Mac xattr story.
- Privacy nutrition label: "Data not collected" — we're one of very few dictation
  apps that can truthfully select it. That label is marketing.

## Risks

1. **Review roulette on keyboard extensions** — extra scrutiny category. Mitigation:
   the keyboard requests NO Full Access (we don't need network in the extension —
   text passes via App Group), which removes the scariest review question entirely.
2. **App-hop jank** — the hop must feel < 1s round-trip; pre-warm audio session,
   skip animations, return via the stored return-URL scheme.
3. **WhisperKit vs whisper.cpp divergence** — two engine backends to maintain.
   Decide with a 1-day spike (prompt 1 below) before committing.
4. **Apple Sherlocking** — iOS 26 on-device Apple Intelligence dictation keeps
   improving for *English/Hindi*; Hinglish code-mix + convention control remains our
   gap, same thesis as macOS.

## The Claude prompts (2 prompts + a human day)

**Human pre-flight:** Apple Developer account ($99), Xcode on this Mac, an iPhone in
developer mode, App Group + bundle IDs created in the portal. (Provisioning clicks
are human work; agents suffer here — get certificates working with a hello-world
first, *then* prompt.)

### Prompt 1 — engine spike: whisper.cpp/Core ML vs WhisperKit (one shot)

```text
GOAL — loop until done: In a new `ios/` folder, build an iOS app (SwiftUI,
iOS 17+) with one screen and two buttons: "Transcribe fixture (whisper.cpp)"
and "Transcribe fixture (WhisperKit)". Both run the same bundled 10s Hinglish
WAV fully on-device with our Apex q5_0-equivalent model and print: text,
wall-time, realtime factor, peak memory.
CONTEXT: reuse DesiDictationKit sources where they compile for iOS (engine
wrapper, decode params — replicate exactly); whisper.cpp vendored at
vendor/whisper.cpp (enable the Core ML encoder build per its README);
WhisperKit via SPM (convert/load our model per Argmax docs — if our fine-tune
cannot be converted losslessly, document why and benchmark their large-v3-turbo
as proxy, clearly labeled).
DEFINITION OF DONE: builds clean via xcodebuild for the connected device;
XCTest asserts non-empty Roman-script output on both paths (or a documented,
reproduced failure for one path); ios/SPIKE.md contains the numbers table and
a one-paragraph engine recommendation with reasoning.
NON-GOALS: keyboard extension, UI design, App Intents, model downloads.
Loop rule: never ask to continue; stop when done or hard-blocked (say what).
```

### Prompt 2 — the product (one shot, after engine decision)

```text
GOAL — loop until done: Build "Desi Dictation" for iPhone v0.1 in ios/:
1. Main app: record screen (tap-to-talk, 60s cap, pre-warmed AVAudioSession),
   on-device transcription with [chosen engine], result view with Copy/Share,
   model download with progress + SHA256, settings (model picker, replacement
   dictionary — port format from DesiDictationKit), local 24h history.
2. Keyboard extension "Desi Mic": one large mic key + globe key + paste-last
   key. Mic key opens the main app via URL scheme with a return-URL; after
   transcription the app auto-returns; the keyboard inserts the finished text
   from the App Group container. The extension requests NO Full Access and
   contains NO model code.
3. App Intents: "Dictate" intent (record → transcribe → put text in clipboard,
   return it to Shortcuts) usable from the Action button; a Control Center
   control (iOS 18) that launches it.
DEFINITION OF DONE (loop until all pass):
A. xcodebuild test green: engine fixture test, dictionary tests, App Group
   round-trip test, URL-scheme parse tests.
B. UI test: full app-hop cycle in simulator with a stubbed engine — keyboard
   button → app → fake result → back → text inserted into the host test app.
C. On-device smoke checklist auto-generated to ios/SMOKE.md with each step's
   expected result, plus screenshots from the UI test run.
D. Extension memory: assert via test that the keyboard target links neither
   whisper nor models (binary size < 5 MB).
E. ios/NOTES.md updated (decisions, failures fixed, review-risk checklist:
   privacy labels = data-not-collected, mic usage string, no Full Access).
NON-GOALS: monetization, TestFlight submission (human does that), Watch app,
iPad-specific layout, streaming.
```

**Then the human day:** screenshots, privacy labels, TestFlight external review,
App Store listing (the "your voice never leaves your iPhone" line is the ad).
