# Product & Features — living document

What exists, how well it works, and where it's going. Update this every release.
(Vision/strategy: [PRODUCT_VISION.md](PRODUCT_VISION.md) · GTM: [GTM.md](GTM.md))

## Current state — v0.3.0 (2026-07-07)

### Features
| Feature | Status | Notes |
|---|---|---|
| Push-to-talk dictation (hold Right ⌥) | ✅ shipped | any app, any text field |
| Toggle mode (tap start/stop) | ✅ shipped | live-switchable |
| Esc to cancel | ✅ shipped | |
| Hinglish (Roman) output | ✅ shipped | Apex model — the differentiator |
| English / हिन्दी modes | ✅ shipped | Large-v3-Turbo |
| Auto model-per-language | ✅ shipped | manual pin optional |
| In-app model downloads + ⭐ recommendations | ✅ shipped | models not bundled (size) |
| Silence/pause robustness (VAD) | ✅ shipped | Silero VAD, 1 MB add-on |
| Long-dictation quality | ✅ fixed v0.3 | `no_context` + VAD |
| Error recovery without relaunch | ✅ fixed v0.2.1 | all errors transient |
| Transcript always recoverable | ✅ shipped | clipboard + 24 h history + Copy Last |
| Replacement dictionary | ✅ shipped | user-enforced Hinglish spellings |
| Main window (sidebar UI) | ✅ shipped | Dictation/History/Models/Text/License |
| AI cleanup via local Ollama | ✅ shipped (Pro) | off by default, fails safe |
| Gumroad licensing | 🔨 code ready | needs product ID at launch |
| App icon | ✅ shipped | generated, tricolor mic |

### Measured quality (M3, release build)
- Hinglish (Apex q5): word-perfect on eval clips; ~3× realtime; **15× realtime
  with VAD** on pause-heavy audio; long-form degradation eliminated.
- English (Turbo q5): verbatim on eval clips.
- Known limits: Hinglish spelling variance (mitigate: replacements); very noisy
  environments untested; proper-noun bias toward common words.

## Direction — ranked backlog

**Next (v0.4):**
1. **Parakeet V3 for English mode** — 2026's best local English model (~6.3% WER,
   ~10× faster, silence-proof); whisper.cpp already ships support in our build.
2. **Personal eval harness round 2** — user-voice eval set to CI-gate model changes.
3. First-run onboarding flow (permissions → model download → first dictation, guided).
4. Menu bar quick language switcher improvements (per-mode hotkeys?).

**Later:**
- Mixed-script mode ("मेरा favourite festival Diwali है") — shunyalabs/Srota, needs MLX runner
- Tanglish / Manglish / Benglish — same app, new fine-tunes
- WhisperKit/ANE backend — battery on fanless Airs
- App-specific profiles (per-app language/prompt)
- File transcription (drag a voice note onto the menu bar icon)
- Sparkle auto-updates (pre-1.0 requirement)

**Explicit non-goals:** meeting bots, cloud transcription, subscriptions,
anything that uploads audio.

## Quality bar for "world-class" (check before each release)
1. Zero states that require quit/relaunch to recover. 
2. A dictation, once spoken, is never lost.
3. Cold install → first successful dictation < 5 minutes (SETUP_GUIDE path).
4. Hinglish preference win-rate vs MacWhisper turbo ≥ 80% on the eval set.
5. Every failure mode discovered lands in BUILD_LOG.md + TROUBLESHOOTING.md.
