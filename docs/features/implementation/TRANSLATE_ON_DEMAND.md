# Translate on Demand (Flow A) — implementation

**Spec:** features/TRANSLATION.md §3 Flow A. **The pitch:** open your last
dictation, *fix the mishears first*, then Translate → English / हिन्दी. The
translation lands on the clipboard and is saved next to the original.

## What it's made of

- **`DesiDictationApp/LastDictationWindow.swift`** (`LastDictationView`) — the
  whole feature UI: source editor (prefilled with the newest history entry, a
  picker switches among the last 20), two translate buttons, an editable
  result editor, Copy / Copy-&-close. Window is AppKit-managed via
  `AppWindows.showLastDictation()` (same pattern as main/onboarding — callable
  from the menu, survives SwiftUI scene limitations).
- **Menu entry** — "Last dictation — edit / translate…" in `MenuContent`
  (disabled until history has an entry).
- **Storage** — `HistoryEntry.translation: String?` +
  `HistoryStore.attachTranslation(_:to:)`: the translation is attached to the
  entry it came from (same 24 h retention), and HistoryView shows it as a
  secondary "translation:" line. Old history JSON decodes fine (regression-
  tested); old app versions ignore the new key.

## Why edit-then-translate is the flow (not a button on raw output)

Hinglish ASR has spelling variance; translating a mishear compounds it
(live example in implementation/README.md: *diye→die* became "told us about").
The window makes the correction step the *default* posture: the user is
looking at editable source text before any translate button. Garbage in,
garbage out — we hand them the "in".

## Engine path

Buttons call `LLMServices.shared.translator.translate(source, to:)` — the same
`LLMTranslationEngine` the dictation pipeline uses, so quality/behavior are
identical everywhere and one eval covers both. Errors surface as an inline
orange line (plain words from `LLMError`); the source text is untouched, so
nothing is ever lost. `llm.statusGuidance` renders setup guidance inside the
window when Ollama/model are missing.

## Changing it

- **Flow B** (Services menu / hotkey on any selection — v2): add an
  `NSServices` entry in the app bundle's Info.plist + `NSApp.servicesProvider`;
  the translate call is the same one-liner into `LLMServices`.
- Auto-paste after translate (currently copy-only by design — the previous
  app's focus is gone once you're in this window): would need the
  frontmost-app tracking `AppModeStore` already does.
- More target languages: add a `TargetLanguage` case + a template in
  `PromptTemplates.translate(to:)` + a button.
