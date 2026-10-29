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

## 0a · Installing as a new user (2026-09-23) — one command

```bash
curl -fsSL https://raw.githubusercontent.com/s-samarth/desi-dictation/main/install.sh | bash
```

- **What happens:** Apple-Silicon + macOS 14 check → downloads
  `releases/latest/download/DesiDictation.dmg` → verifies its `.sha256` →
  quits a running copy → replaces `/Applications/Desi Dictation.app` →
  opens it. Asks for the admin password only if `/Applications` isn't
  writable for this user.
- **Why no Gatekeeper dialog:** curl doesn't set `com.apple.quarantine`, and
  Gatekeeper only assesses quarantined apps. The DMG route still needs the
  one-time Open Anyway until the build is notarized (Developer ID, $99/yr).
- **Updating:** run it again. Grants survive because every release is signed
  with the same identity and lands at the same path.

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

## 0c · Switching apps mid-dictation, and when it doesn't work (v0.6.2)

- **Flow:** start dictating in one app, switch apps or Spaces while you talk,
  click into any text box (the same one or another), tap Right ⌥ to stop.
  The words paste into the box you're in **when you stop**.
- **What changed:** before v0.6.2 this sometimes put the words on the
  clipboard without pasting, so you had to press ⌘V. The paste could fire
  while Right ⌥ was still held, and apps saw ⌥⌘V (BUILD_LOG FM#31). The app
  now waits for you to let go first. You won't notice the wait.
- **Menu left open (fixed after v0.6.2):** if you open the Desi menu-bar menu
  and then dictate, the open menu used to swallow the paste (FM#32). The app
  now closes its own menu before pasting. Another app's open menu (Spotlight,
  another menu-bar icon) still swallows it. Close it, then stop.
- **No more silent failures:** when a dictation doesn't end in a paste, the
  overlay stays up for a few seconds and says why, with the error sound:
  - ⚠️ *"Didn't catch that — nothing pasted. Try again."*: no speech was
    heard. Your clipboard was left alone.
  - 📋 *"Copied — press ⌘V to paste"*: the words are on the clipboard but
    weren't pasted (a modifier key was still held after 1.5 s).
  - 📋 *"… Grant Accessibility to auto-paste"*: macOS is blocking the paste;
    re-grant Accessibility (section 0).
  - ⚠️ any other error (too short, no model, engine failure) shows its own text.
- **Friction:** a text field that quietly ignores pasted text can't be
  detected. The words are still on the clipboard and in History.

## 0d · The menu and the window (2026-10-28)

The menu bar mic holds what you change daily, nothing else: status,
**Open Desi Dictation… (⌘,)** right under it, **Enable Dictation**, **Language**, **Model** (when the language has more than one installed: English → Parakeet (fastest) / Qwen (most accurate)), "For <app>", **Copy Last**, **History**
(last 10, plus **Show All…**), **Send Feedback…**, **Quit**.

**Open Desi Dictation…** opens the app's one window. Opening the app from
Spotlight (⌘Space), Applications or Launchpad starts it quietly in the menu
bar, like at login, and never pops the window (2026-10-29; only an
unfinished first-run setup comes back). Its sidebar has five pages, each
with its own colored icon, and the sidebar never goes away:

- **Guide** (first, until you've opened it once): every feature in plain
  words, numbered in the order you meet them. Each optional feature says
  what it does, how it plays out step by step, **Turn on if / Leave off
  if**, and has its switch right there. Learn-from-corrections is drawn as
  "Call Rowan at 5" → you fix it to "Rohan" → *Always write Rowan as
  Rohan?*. Vocabulary's "How does this work?" link opens it.
- **Dictation**: on/off with a status dot ("Ready, hold ⌥ and speak"), the
  key and mode, language (the footer names the model it uses), three
  everyday options. VAD, quick restart, flash attention and per-app rules
  sit under **Advanced**. Permissions shrink to one green line once all
  three are granted.
- **Vocabulary**: suggestions waiting for a yes (only when there are any),
  your words, the four "Learn automatically" switches, and Replacements
  under **Advanced**.
- **History**: search, copy, right-click to fix; language tags are colored
  (Hinglish saffron, English blue, हिन्दी green).
- **Models**: the model for each language, then one Downloads list where
  each row says whether you have it, with **Show in Finder** / **Refresh**.

Before this, the same pages lived twice (a sidebar window *and* a Settings
window with different tab names), and the Vocabulary, Models and Text pages
could outgrow the window and hide the sidebar, leaving no way back
(BUILD_LOG FM#35). AI features are built but not released, so their page,
menu items and right-click services are hidden (§3–§8).

## 1 · Personal dictionary — zero setup, works today

> **Two lists, right-click anywhere (2026-10-28).** Your words are split by
> the language you dictate in: Hinglish dictations use the Hinglish list,
> English dictations the English list, हिन्दी neither. Words learned from a
> fix go to the list of the language you were dictating in; the popup says
> which ("…as Rohan in English?"). To teach a word without History: select it
> in any app → right-click → **Services → Always write as… (Desi
> Dictation)** → type the right spelling → Save.

- **Discovery:** you notice a wrong spelling in a paste; you open menu bar
  mic → History and right-click the entry → **"Always write a word as…"**.
  Also listed in Settings → **Vocabulary → Your words** with "Add word…".
- **Flow:** type `Saraswath → Saraswat` once. Done forever, all apps.
- **Why:** names/brands/jargon are the #1 repeated annoyance; no model fixes
  YOUR words.
- **Friction:** the sheet doesn't pre-fill the word you right-clicked from.
  Smart vocabulary (§1b) removes most of the manual step.

## 1b · Smart vocabulary — it learns from your edits (opt-in)

- **Discovery:** onboarding step 4, or menu bar → Open Desi Dictation… → **Vocabulary →
  Learn automatically**. Four switches, all off, each with a one-line note.
- **Learn from corrections:** dictate, then fix a word in the field
  ("Rowan" → "Rohan") within **2 minutes** (30 s until 2026-10-29: too
  short to read and edit). About 2 s after you stop typing, a small popup
  above the overlay asks **"Always write Rowan as Rohan?"** with **Add** /
  **When it fits** (English words) / **Not now**, for 25 s. The popup is as
  wide as its words, so no button is cut off.
  It never steals the caret. Ignore it and the proposal waits under
  Vocabulary → **Waiting for you**. "Add" puts the pair in your Personal dictionary.
  **Not now** only snoozes it: make the same fix a few more times and it
  asks again. Only **Never** stops it for good.
- **When it fits (English):** the popup always offers **When it fits** for
  English words. To have each sentence decide, get the context checker
  (Models or Vocabulary page, 397 MB); choosing it without the checker
  says so, and only on-screen / app-name cues decide until then. Each
  English word in Your words has an *Always / When it fits* picker. Set
  *cloud → Claude* to When it fits: "I asked cloud to fix this" becomes
  "I asked Claude to fix this", "our data is in the cloud" stays. Fixes say
  "fits the sentence" in History; kept words say why under **What it's been
  doing**. Undoing one of these fixes doesn't ban it: the next sentence
  decides again.
- **Fillers and corrections (2026-10-29):** Dictation → **Clean-up**.
  **Remove um and uh** is on: um, uh, hmm, er just go. Sometimes-fillers
  (like, you know, I mean…) are underlined in review as **Filler?** (1
  removes, 0 keeps); **Remove fillers when sure** (off) takes out the ones
  the context checker is sure of. Spoken corrections ("meet at 2, no, make
  it 3", also "two. No, make it three"; "Rohan, sorry, Rahul") are
  underlined as **You probably meant:**; "scratch that" offers **Remove
  this text**. Never applied on their own.
- **Review before paste:** Dictation → **Review**: **Review before paste**
  Off (default), **Only when unsure**, or **Always**, and **Underline
  words** Conservative / **Moderate** (default) / Liberal: how readily
  words get underlined (about 1 in 7, 1 in 12, 1 in 25). Onboarding offers
  both as step 5. When it opens, a panel sized to the text (6 to 20 lines
  without scrolling; it can be dragged bigger) shows the dictation before
  it's pasted. Words the speech
  model wasn't sure of are underlined in orange ("Hard to hear. Maybe:");
  with the context checker installed, English and हिन्दी words that are
  clear but odd in their sentence ("watch one **PC** Luffy", unusual names)
  are underlined in purple ("Odd here."). Everyday words said casually
  ("I would want you to…") are left alone unless they're very odd, and
  never underlined just for sounding like a word on screen. Nothing is
  changed for you.
  **Tab** jumps to the next one and shows suggestions; **1–5** picks one,
  **0** says it looks right (the underline goes, the word stays), or just
  type. The "N unsure words" count drops as you fix, delete or clear them.
  **Enter** pastes into the app you were in, **Esc** copies instead,
  **✕** or **⌘W** just closes it (no paste, clipboard untouched; still in
  History). Under
  "Remember your fixes?" each word you changed is used **Just this once**
  by default, or pick **When it fits** (English) / **Always** to remember
  it. Purple underlines and When it fits judging need the
  optional context checker: its row, with a Get button, sits under the
  Review settings and on the Vocabulary page. Starting a
  new dictation while the panel is open copies the waiting text. With
  Qwen3-ASR (Accurate English), which reports no per-word confidence, only
  odd-in-context words (checker installed) and sound-alikes of your words
  are underlined.
- **Your edit wins:** if it auto-fixed a word and you change it back, the
  popup says "Got it" and that fix is never made again.
- **Near-miss suggestions, never fixes (2026-10-29):** "Saraswath" when the
  dictionary has Saraswat, or "Rowan" when Rohan is on screen, is
  **underlined in the review panel** with the likely word as choice 1. It's
  never changed for you: only words you told it to write (Your words,
  Always; or When it fits) are written automatically. Before this, "plus"
  became "PRs" because "PRs" was on screen. Without Review before paste,
  near-misses are simply left alone.
- **Hinglish:** fix *nahin* → *nahi* once and it proposes the style rule.
  With "suggest my spelling in the field" on, the field's own spelling is
  suggested in the review panel for that dictation.
- **Never touched:** everyday words (the, there, hai, kya), anything inside
  an email or URL, हिन्दी mode.
- **Seeing it work (2026-10-28):** Vocabulary → **What it's been doing**
  lists, per dictation, what it watched, the swaps it saw, what it suggested
  or learned, and why it skipped something ("not a sound-alike", "couldn't
  read the text in …"). Memory only. Learned words land in **Your words**.
- **Electron apps (Claude, Slack, VS Code, Notion):** they hide their text
  fields until asked, so before 2026-10-28 nothing was ever learned there.
  The app now switches their accessibility on when they come to the front
  (it costs those apps a little memory). The very first dictation in a
  freshly opened Electron app can still miss; the activity list says so.
  Chrome and other browsers aren't switched on yet.
- **Chat boxes:** fix the word and press Enter right away and it still
  learns: it reads the box every 0.3 s and judges the last text before the
  box emptied.

## 2 · Per-app language — one click per app, then invisible

- **Discovery:** menu bar mic → the **"For <current app>"** submenu sits
  under Language (only visible while you're "in" another app).
- **Flow:** in WhatsApp: For WhatsApp → Hinglish. In Mail: For Mail →
  English — from any language. Dictation now switches by target app.
- **Why:** kills the 5×/day manual language toggle.
- **Seeing it (v0.6.2):** the overlay shows the language beside "Listening" /
  "Transcribing". When a rule overrides your global language the badge turns
  orange and names the app, e.g. **"English · Claude rule"**. Before this the
  switch was silent: a forgotten Claude → English rule made हिन्दी dictation
  in Claude come out as English or nothing, with no hint why.
- **Review/remove:** Open Desi Dictation… → Dictation → **Advanced** lists every rule.

## 3 · "English — from any language ✨" — the flagship (needs AI setup)

> **Not released (2026-10-28).** §3–§8 describe AI features that are built but
> hidden: `SettingsStore.aiFeaturesReleased = false` hides the AI page, these
> menu items and the language mode, and `scripts/build_app.sh` drops the
> right-click services unless built with `DESI_AI_FEATURES=1`.

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
decision — the model for that language loads itself. To switch model without
opening the window, the menu's **Model** item lists the installed ones for
the current language (English: **Parakeet (fastest)** or **Qwen (most
accurate)**). The Dictation page names it ("Uses Hinglish Prime").

Want a specific model for one language and a different one for another?
**Open Desi Dictation… → Models → Model for each language**. "Auto" names what it
picked, e.g. *Auto (Parakeet)*, and only models that can write that
language's script are listed. Each language remembers its
own choice; switching language switches model silently.

**English is now much faster.** English mode runs NVIDIA's Parakeet model
instead of Whisper — about **0.2 s** for a short dictation on an M3 Air (it was
~1.9 s), with equal-or-better accuracy in our English tests. Download it
from **Models** (416 MB) or take it during onboarding.

**Hinglish runs on Prime (since 2026-10-28).** Onboarding and **Models →
Downloads** offer *Hinglish Prime* (about 1 GB). It replaced Apex: about 30 %
fewer mistakes on long, conversational Hinglish (a joke, a voice-note-style
rant). It's a little slower: 1.8 s instead of 1.4 s on a short dictation,
and roughly twice as long on long ones. Apex is no longer offered. If you
already have it and pinned it, it keeps working until you pick Prime under
**Open Desi Dictation… → Models → Model for each language → Hinglish**.
**Want the most accurate English? Qwen3-ASR (v0.6.3).** It replaced Whisper
Turbo under **Open Desi Dictation… → Models** (2.08 GB). On Indian-accented
English it makes about 11 % fewer errors than Parakeet in quiet rooms and 9 %
fewer in noise. The cost is speed: about 0.4 s for a short dictation instead
of 0.1 s. Parakeet stays the default. Pick Qwen for English under **Model for each
language** when accuracy matters more than speed.

**How fast was that?** The Dictation screen shows the last dictation's real
cost — *"Last: 4.2s speech · 0.31s to paste · 1 call"*. If dictation ever feels
slow, that line is what to quote in a bug report.

**Long हिन्दी dictations are fixed (v0.6.2).** Before this, a हिन्दी dictation
longer than ~15 s could take a minute and lose its last few words. It now
comes back in a few seconds, complete. You'll see one call per ~8–12 s of
speech in the timings line; that's expected for हिन्दी. Quitting the app also no
longer triggers a "quit unexpectedly" crash report.
