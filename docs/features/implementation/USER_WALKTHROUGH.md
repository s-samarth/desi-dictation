# The 0.6 features, as a user actually meets them

Click-by-click walkthrough + friction audit, feature by feature. The baseline
user habit: **hold Right ⌥ → speak → release → text appears at the cursor.**
Nothing below changes that. Every feature is additive and opt-in by action.

## 0 · Getting the new build (why "I restarted and see nothing" happened)

`swift build` alone does NOT update the app you launch — the .app bundle must
be rebuilt and installed:

```bash
export SWIFTPM_CUSTOM_LIBS_DIR=$HOME/.swiftpm-fixed-libs
./scripts/build_app.sh
osascript -e 'tell application "Desi Dictation" to quit'
ditto "app/dist/Desi Dictation.app" "/Applications/Desi Dictation.app"
open "/Applications/Desi Dictation.app"
```

With the "Desi Dictation Dev" signing cert installed (it is, on this Mac),
permissions survive the swap. If the hotkey ever goes dead after an update:
System Settings → Privacy → Accessibility + Input Monitoring → remove (−)
Desi Dictation, re-add, relaunch.

## 0b · Microphone (v0.6.2) — nothing to set up

- **What you pick:** System Settings → Sound → **Input**. The app always
  records from that device: a USB mic, the built-in mic, or a headset.
- **What changed:** the speaker you have connected (a Bluetooth speaker, a
  monitor, AirPods) no longer affects what the model hears. Before v0.6.2 the
  mic was resampled to the speaker's rate (BUILD_LOG FM#22).
- **Switching mics mid-dictation:** capture continues on the new mic; before
  v0.6.2 the rest of that dictation was silent.
- **Friction:** the built-in mic is silent with the lid closed, and a
  Bluetooth headset mic is call quality (16–24 kHz). Both are macOS/hardware
  limits; TROUBLESHOOTING §6b shows how to check which mic was used.

## 1 · Personal dictionary — zero setup, works today

- **Discovery:** you notice a wrong spelling in a paste; you open menu bar
  mic → History and right-click the entry → **"Always write a word as…"**.
  Also listed in Settings → Text with an "Add word…" button.
- **Flow:** type `Saraswath → Saraswat` once. Done forever, all apps.
- **Why:** names/brands/jargon are the #1 repeated annoyance; no model fixes
  YOUR words.
- **Friction:** you must notice + act once per word (no auto-learn, by trust
  design). The sheet doesn't pre-fill the word you right-clicked from.

## 2 · Per-app language — one click per app, then invisible

- **Discovery:** menu bar mic → the **"For <current app>"** submenu sits
  under Language (only visible while you're "in" another app).
- **Flow:** in WhatsApp: For WhatsApp → Hinglish. In Mail: For Mail →
  English — from any language. Dictation now switches by target app.
- **Why:** kills the 5×/day manual language toggle.
- **Friction:** the auto-switch is silent — the overlay doesn't say which
  language a rule picked; review lives in Settings → General.

## 3 · "English — from any language ✨" — the flagship (needs AI setup)

- **Discovery:** a fourth entry in the same Language picker + one line in
  onboarding. If selected before setup, the menu shows
  **"⚠️ Finish AI setup (one-time)…"** which deep-links to the AI pane.
- **Setup (once):** install the free Ollama app → Desi Dictation → AI →
  "Get AI model" (progress bar; ~3.3 GB on 16 GB Macs, ~1.4 GB on 8 GB).
- **Flow after that:** identical to normal dictation — click into ChatGPT/
  Mail/anywhere, hold key, speak Hinglish, release. Overlay: "Transcribing" →
  "Translating ✨ (esc pastes as heard)" → polished English pastes.
- **Failure:** anything goes wrong → your words paste as heard + a plain
  message. Esc during Translating pastes them immediately.
- **Why:** English production is the deepest pain (PERSONAS.md); this is
  speak-Hinglish-send-English with nothing leaving the Mac.
- **Friction (honest):** Ollama is a second app to install (the wall for
  non-technical users); translation adds 2–8 s per dictation; new dictations
  wait while one is translating.

## 4 · Tone — a dial, defaulting to "exactly what you said"

- **Discovery:** "Tone" picker right under Language in the menu.
- **Flow:** pick Respectful before dictating to the courier company; back to
  Faithful after. Faithful = zero LLM, zero latency, byte-exact behavior.
- **Friction:** a non-Faithful tone adds seconds to EVERY dictation while
  set; easy to forget it's on (History always keeps the original).

## 5 · Right-click translate — select text anywhere (NEW, Flow B)

- **Discovery:** select any text in any app → right-click → **Services →
  "Translate to English (Desi Dictation)"** (or → हिन्दी).
- **Flow:** in editable fields macOS replaces the selection with the
  translation in place. Type your rough English/Hinglish anywhere, select,
  right-click, done — no app-switching at all.
- **Friction:** first appearance in the Services menu can need a logout or
  `pbs -update` after install; the calling app blocks for the 2–8 s
  translation; non-editable text (web pages) needs copy → Last-dictation
  window instead.

## 6 · Last dictation — edit → translate (the careful path)

- **Discovery:** menu bar mic → "Last dictation — edit / translate…".
- **Flow:** the window opens with your newest dictation; **fix mishears
  first** (that's the point — "meating"→"meeting"), then Translate →
  English / हिन्दी; edit the result; Copy. Translation is saved beside the
  original in History.
- **Friction:** copy-only (no paste-back — the target app's focus is gone);
  doesn't auto-refresh if you dictate while it's open.

## 7 · 🧠 Structure my thoughts (beta)

- **Discovery:** menu bar mic → "🧠 Structure my thoughts (beta)…".
- **Flow:** overlay flips to "🧠 Thinking — take your time"; ramble as long
  as you like (pauses fine); tap the hotkey or menu Finish; a review window
  opens: one-line summary + sections + action items, restyle as Notes /
  Action list / Email draft / Outline, raw transcript one click below,
  👍/👎 feedback buttons.
- **Why:** voice-memo graveyard → searchable structured text, on-device.
- **Friction:** starts from the menu (no dedicated hotkey yet); 5–15 s
  structuring wait; backtracking ("nahi wait, wala point…") can still leak
  both versions — hence (beta) + the always-visible raw transcript.

## 8 · Turning it all off

Settings → AI → **"Enable AI features" OFF** = the classic dictation app:
no AI menu items, no LLM modes, no tone picker, nothing extra to download,
right-click services refuse politely. Dictation itself is untouched either way.

## Cost of the full experience (16 GB Mac)

Apex ASR 570 MB (already had) + Ollama app + gemma3:4b 3.3 GB ≈ **~4 GB disk,
~3.5 GB RAM while the AI model is warm**. On 8 GB Macs: qwen3:1.7b ≈ 1.4 GB.
Skip AI entirely → 0 extra.


## Picking a language (v0.6.1)

Menu bar → **Language** → English / Hinglish / हिन्दी. That is the whole
decision — the model for that language loads itself, and the **Model** picker
under it only lists models that can actually produce that language's script.
"Auto" names what it picked, e.g. *Auto (parakeet-tdt-0.6b-v3-q4_k)*.

Want a specific file for one language and a different one for another?
**Settings → Models → Default model per language**. Each language remembers its
own choice; switching language switches model silently.

**English is now much faster.** English mode runs NVIDIA's Parakeet model
instead of Whisper — about **0.2 s** for a short dictation on an M3 Air (it was
~1.9 s), with equal-or-better accuracy in our English tests. Download it
from **Models** (416 MB) or take it during onboarding.

**How fast was that?** The Dictation screen shows the last dictation's real
cost — *"Last: 4.2s speech · 0.31s to paste · 1 call"*. If dictation ever feels
slow, that line is what to quote in a bug report.

**Long हिन्दी dictations are fixed (v0.6.2).** Before this, a हिन्दी dictation
longer than ~15 s could take a minute and lose its last few words. It now
comes back in a few seconds, complete. You'll see one call per ~8–12 s of
speech in the timings line; that's expected for हिन्दी. Quitting the app also no
longer triggers a "quit unexpectedly" crash report.
