# Per-App Language Modes — implementation

**Spec:** IDEAS.md #4; competitors/PATTERNS.md §1 (all four majors have it).
**The pitch:** WhatsApp → Hinglish, Mail → English-from-any, set once — five
manual mode-switches a day become zero.

## What it's made of

- **`DesiDictationKit/AppModeStore.swift`** — `AppModeRule{bundleID, appName,
  mode}` persisted to `appmodes.json` (injectable `fileURL` for tests). Also
  tracks **`currentTarget`**: the frontmost *non-self* app, via
  `NSWorkspace.didActivateApplicationNotification`. Tracking is continuous
  because at menu-click time the frontmost app may already be us — the tracked
  value is "the app the user was working in", i.e. where a paste would land.
- **Menu (`MenuContent.swift`)** — a "**For <AppName>**" submenu under the
  Language picker: inline radio list of *Follow global setting* + the four
  languages. Writes/removes a rule for `currentTarget` and preloads the model.
- **Settings (`PerAppModesView.swift`)** — General tab section: the
  `perAppModes` master toggle + every learned rule as *AppName [mode picker]
  (–)* for review/edit/removal.

## How a dictation picks its language

`DictationController.effectiveMode()`:

```
perAppModes on AND rule exists for currentTarget → rule's mode
otherwise                                        → settings.languageMode
```

Called at `startRecording`; the result is stored in `sessionMode` so a rule
can't flip mid-session if the user switches apps while speaking. `sessionMode`
drives the chunk ticker, the final transcription, model resolution, and the
history entry. Model preload (`modelChanged`/`preloadModelIfNeeded`) also uses
`effectiveMode()` so the *next* dictation's model is the warm one.

## Design decision worth knowing

Rules are **explicit** (user sets them from the menu), not auto-learned from
usage. Auto-learning would lock in whatever mode someone happened to try once
in an app, and silently — the predictability cost outweighs the setup cost of
one menu click per app. (If someone pins a model manually via the Model picker,
the pin still wins over per-app auto-selection — existing semantics kept.)

## Changing it

- Remember more than language per app (tone? copy-only?): widen `AppModeRule`,
  bump nothing else — it's Codable JSON; absent fields decode as nil.
- The Rekha flow ("Mail always gives me polished English") is just a rule with
  `mode: .anyToEnglish` — covered in combination tests.
- Tests: `DesiTests/StoreTests.swift` + the combination suite.
