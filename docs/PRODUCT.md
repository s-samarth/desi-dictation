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
| Hinglish (Roman) output | ✅ shipped | **Prime** model — the differentiator; replaced Apex as the default 2026-10-28 (more accurate on long takes, ~1.3–2x slower — [research §F](MODEL_RESEARCH.md)); Apex is no longer offered |
| English / हिन्दी modes | ✅ shipped | **English runs on Parakeet TDT** (0.21 s/call, 4.3 % nWER on Indian English — [research §E](MODEL_RESEARCH.md)); हिन्दी on Vaani, split into ≤ 12 s calls so long dictations neither stall nor truncate (v0.6.2, [FM#26](BUILD_LOG.md)) |
| **Default model per language** | ✅ built 2026-08-19 | pick a language, the right model loads itself; pickers hide models that can't serve it ([impl](features/implementation/MODEL_ROUTING.md)) |
| In-app model downloads + ⭐ recommendations | ✅ shipped | models not bundled (size) |
| Silence/pause robustness (VAD) | ✅ shipped | Silero VAD, 1 MB add-on |
| **Per-dictation timings** | ✅ built 2026-08-19 | "Last: 1.2 s speech · 0.30 s to paste · 1 call" in the Dictation pane + system log ([RCA](PERF_RCA_2026-08.md)) |
| Long-dictation quality | ✅ fixed v0.3 | `no_context` + VAD |
| Error recovery without relaunch | ✅ fixed v0.2.1 | all errors transient |
| **Mic capture independent of speakers** | ✅ fixed v0.6.2 | mic's native rate, reopens on device change mid-dictation, logs which mic ([FM#22](BUILD_LOG.md)) |
| Transcript always recoverable | ✅ shipped | clipboard + 24 h history + Copy Last |
| **Paste after switching apps + no silent failures** | ✅ fixed v0.6.2 | ⌘V lands in the field focused at stop; the overlay says "Didn't catch that" / "Copied — press ⌘V" instead of failing silently ([impl](features/implementation/PASTE_AND_FEEDBACK.md), [FM#31](BUILD_LOG.md)) |
| Replacement dictionary | ✅ shipped | user-enforced Hinglish spellings |
| **Personal dictionary ("always write it as…")** | ✅ built 2026-07-10 | word-boundary + casing-aware; add from History right-click ([impl](features/implementation/PERSONAL_DICTIONARY.md)) |
| **Auto vocabulary (smart vocabulary)** | ✅ built 2026-10-28 | opt-in: retype a word → "Always write X as Y?" popup; undo an auto-fix → never made again; near-miss names from your dictionary + the window you're in (memory only) and your field's Hinglish spelling are **suggested in Review before paste, never applied** (2026-10-29); Qwen3-ASR hotword seam ([impl](features/implementation/AUTO_VOCABULARY.md)) |
| **"When it fits" words (context checker)** | 🟡 measured on a Mac 2026-10-28 (0 wrong swaps, 92.9 %); live dictation check pending | English: a word like cloud → Claude is written only when the sentence is about Claude; a 397 MB local model scores both versions, never writes; third button "Only when it fits" appears once it's downloaded ([impl](features/implementation/CONTEXT_FIT.md)) |
| **Review before paste** | 🟡 built 2026-10-28; live focus/paste check pending | opt-in (Off / Only when unsure / Always) with strictness Conservative / Moderate (default) / Liberal: a panel sized to the text (6–20 lines) underlines unsure words (low engine confidence; odd in its sentence per the context checker, English + हिन्दी; or a sound-alike of your words; everyday words need much more), never changes them, Tab to jump, 1–5 to pick, Enter pastes, Esc copies; fixes are used Just this once by default, or kept When it fits / Always. Confidence: whisper + Parakeet; Qwen3-ASR gives none ([impl](features/implementation/REVIEW_BEFORE_PASTE.md)) |
| **Fillers and spoken corrections** | 🟡 built 2026-10-29; live check pending | um/uh/hmm/er removed (switch, on); "like / you know / I mean…" offered in review when the context checker judges them filler (auto-remove only with "Remove fillers when sure", off); "2, no, make it 3" / "sorry, Rahul" / "scratch that" offered in review, never applied ([impl](features/implementation/FILLERS_AND_CORRECTIONS.md)) |
| **Send Feedback window** | 🟡 built 2026-10-30; live send pending (EmailJS setting) | message + optional reply address, "Include app info" (shown as sent, on) and "Include my last dictation" (off); posted to samarthsaraswat.com/api/feedback only on Send, forwarded by email, not stored; Copy and Email instead as fallbacks ([impl](features/implementation/FEEDBACK.md)) |
| **Download counts per route** | ✅ 2026-10-30 | no tracking: the website, the installer and the releases page each fetch their own copy of the DMG, so GitHub counts them apart; `scripts/download_counts.sh` sums releases ([impl](features/implementation/FEEDBACK.md)) |
| **Per-app language modes** | ✅ built 2026-07-10 | WhatsApp→Hinglish, Mail→English, zero switching; the overlay names the rule when one overrides (v0.6.2) ([impl](features/implementation/PER_APP_MODES.md)) |
| **"English — from any language ✨" mode** | 🔒 built 2026-07-10, hidden until AI ships | speak Hinglish → paste polished English; falls back to raw words ([impl](features/implementation/SPEAK_DESI_WRITE_ENGLISH.md)) |
| **Translate on Demand (edit → translate)** | 🔒 built 2026-07-10, hidden | last-dictation window, → English / हिन्दी ([impl](features/implementation/TRANSLATE_ON_DEMAND.md)) |
| **Structure my thoughts (beta)** | 🔒 built 2026-07-10, hidden | ramble → Notes/Actions/Email/Outline review window ([impl](features/implementation/STRUCTURE_THOUGHTS_IMPL.md)) |
| **Tone modes (Faithful/Casual/Professional/Respectful)** | 🔒 built 2026-07-10, hidden | Faithful default = zero rewrite ([impl](features/implementation/TONE_MODES.md)) |
| First run: where the app lives | ✅ built 2026-10-30 | setup asks for each permission separately; after Finish, and on every manual open, a callout and pulsing ring point at the menu-bar mic; a notice if the notch hides it ([FIRST_RUN.md](features/implementation/FIRST_RUN.md)) |
| Main window (sidebar UI) | ✅ shipped, decluttered 2026-10-28 | one window (menu → Open Desi Dictation…, ⌘,): Guide / Dictation / Vocabulary / History / Models; the Guide explains every feature with its switch beside it and opens first until seen, colored icons; tuning knobs under Advanced ([walkthrough §0d](features/implementation/USER_WALKTHROUGH.md)) |
| AI cleanup via local Ollama | 🔒 built, hidden | unreleased with the rest of the AI layer (`aiFeaturesReleased`) |
| Gumroad licensing | 🔨 code ready | needs product ID at launch |
| App icon | ✅ shipped | generated, tricolor mic |
| **Web demo (zero-install)** | ✅ built 2026-07-10 | browser mic → transcript + AI chips; share via tunnel ([web/](../web/README.md)) |
| **Right-click Services translation** | 🔒 built 2026-07-10, hidden (`DESI_AI_FEATURES=1` to build in) | select text anywhere → Services → English/हिन्दी |
| **One-line installer** | ✅ built 2026-09-23 | `curl … install.sh \| bash` → latest release, SHA-256 checked, no Gatekeeper prompt ([SETUP_GUIDE](SETUP_GUIDE.md)) |
| **CI/CD** | ✅ built 2026-07-10 | preflight = CI gate, tag→DMG release, app↔web parity enforced ([CICD.md](CICD.md)) |

**LLM features need one-time setup** (free Ollama app + a model download from
the AI tab; default gemma3:4b on ≥12 GB Macs). Test coverage: `desi-tests`
(119 assertions) + live spike results — see
[implementation/TESTING.md](features/implementation/TESTING.md).

### Measured quality (M3, release build)
- Hinglish (Apex q5): word-perfect on eval clips; ~3× realtime; **15× realtime
  with VAD** on pause-heavy audio; long-form degradation eliminated.
- English (Parakeet TDT v3 q4_k): 4.3 % nWER on the English eval suite (US English — see FM#24), 0.21 s/call — better and ~9× faster than the Turbo q5 it replaced ([research §E](MODEL_RESEARCH.md)).
- Accurate English (Qwen3-ASR-1.7B q8_0, opt-in, v0.6.3): on 278 Indian-English clips, 12.6 % / 17.7 % nWER clean / noisy vs Parakeet's 14.3 % / 19.5 %, at ~0.4 s per short dictation. It replaced Turbo in the catalog ([A/B](ENGLISH_ASR_AB_2026-10.md)).
- Known limits: Hinglish spelling variance (mitigate: replacements); very noisy
  environments untested; proper-noun bias toward common words.

## Direction — ranked backlog

**Next:**
1. **CoreML/ANE encoder** — the remaining big speed lever, and now the only one
   that helps हिन्दी (Vaani is 3.55 s/call, the slowest path we ship).
   ~1–2 days ([PERFORMANCE.md](PERFORMANCE.md) deferred #1).
2. **Personal eval harness round 2** — user-voice eval set to CI-gate model changes.
3. Menu bar quick language switcher improvements (per-mode hotkeys?).
4. Developer ID + notarization — kills the "Apple could not verify…" dialog for
   every tester ([LAUNCH.md](LAUNCH.md) §1).

**Done:**
- ~~Parakeet V3 for English mode~~ — shipped v0.6.1: 4.3 % nWER, 0.21 s/call
  ([MODEL_RESEARCH.md](MODEL_RESEARCH.md) §E).
- ~~First-run onboarding flow~~ — shipped v0.5.1.
- ~~Show new users where the menu-bar app lives~~: setup asks for permissions one at a time, then the app points at the mic after setup and whenever it's opened by hand, and catches an icon hidden behind the notch ([FIRST_RUN.md](features/implementation/FIRST_RUN.md)).

**Later:**
- Mixed-script mode ("मेरा favourite festival Diwali है") — shunyalabs/Srota, needs MLX runner
- Tanglish / Manglish / Benglish — same app, new fine-tunes
- WhisperKit/ANE backend — battery on fanless Airs
- ~~App-specific profiles (per-app language/prompt)~~ ✅ built 2026-07-10 (per-app modes)
- Vendored llama.cpp LLM backend (drop the Ollama prerequisite — needs the ggml
  duplicate-symbol spike, see implementation/README.md)
- Translate any selection (Services menu — Flow B, after Flow A proves demand)
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
