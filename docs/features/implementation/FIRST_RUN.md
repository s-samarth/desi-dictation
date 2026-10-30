# First run: showing where the app lives

**Built:** 2026-10-30, after the launch film. Desi Dictation is a menu-bar-only
app: no Dock icon and no window on launch (user decision 2026-10-29). That's
by design, so it stays out of the way, but a first-time user couldn't tell
where it went. "I opened it and nothing happened."

This doc covers what each launch now shows, how the pointer finds the
menu-bar mic, and where to change it.

## What the user sees

| Launch | Shows | Why |
|---|---|---|
| Never set up | The setup window (onboarding) | Unchanged since v0.5.1 |
| Setup's **Finish** relaunch | **The tour:** a big callout under the mic ("Desi Dictation lives up here"), a pulsing saffron ring around it, and buttons **Show me the menu** and **Got it**. It stays until dismissed or the menu opens. | The moment the window disappears is when people lose it |
| Opened by hand (Spotlight, Finder, the installer) | **The reminder:** a small callout under the mic for 7 s, with an **Open Desi Dictation** link | Opening it again usually means "where is it?" |
| Opened again while running | The reminder (unfinished setup reopens setup instead) | Same |
| At login | Nothing | The user didn't ask for it |

Also in setup:

- **Permissions, one at a time.** Before, launch fired the microphone,
  Accessibility and Input Monitoring prompts all at once, and the three
  system dialogs buried the setup window. Now setup's step 3 has an **Allow**
  button per permission. The first press shows macOS's prompt; after that, a
  press opens the right System Settings pane. The ticks update every second
  by themselves.
  - An already set-up app whose permission was lost still asks at launch, as
    before.
  - Input Monitoring may only show its tick after Finish's restart; the step
    says so once you've pressed it.
- **"After setup, it lives in your menu bar"** in big letters above Finish,
  with why: no Dock icon, no window to keep open, works in every app.

## When there's no icon to point at

`MenuBarPlacement.visibility` checks the icon's frame:

- **Behind the notch.** On a notched MacBook with a full menu bar, macOS
  hides overflowing icons under the notch. The icon counts as visible only if
  it sits wholly inside `NSScreen.auxiliaryTopLeftArea` or
  `auxiliaryTopRightArea`, the strips beside the notch.
  - Shows a centred notice: "Your menu bar is full… Hold ⌘ and drag a few
    other icons out", plus **Open Desi Dictation**.
  - A reminder (opened by hand) also opens the main window, since the user
    can't reach the menu.
- **Off screen.** No frame, or its centre isn't on the screen (another
  display, or an auto-hiding menu bar). Shows the same notice, worded for
  that case.

## How it finds the icon

`MenuBarExtra` keeps its `NSStatusItem` private, but the item draws in its
own window, of class `NSStatusBarWindow`, and that window's frame is the
icon's. `MenuBarPointer.iconWindow()` takes the visible one with a non-empty
frame.

- **Just after launch the frame is empty** (0 high). `show` retries every
  0.25 s for about 3 s before falling back to the notice.
- **It pokes above the screen.** The window measured 2 pt above a 1080p
  screen's top edge (y 1049, height 33). So visibility tests the icon's
  centre, not its whole frame; a desi-tests case covers those numbers.
- **"Show me the menu"** clicks the icon's `NSStatusBarButton`. On macOS 26
  that button is nested: `NSStatusBarContentView › NSView › NSStatusBarButton`.
  It's searched for, not assumed.
- **Hiding when the menu opens** listens for
  `NSMenu.didBeginTrackingNotification` with `queue: nil`, so it runs at once.
  A queued handler would wait until the menu closed: menu tracking blocks the
  main queue.

## The panels

- **Two borderless `NSPanel`s** at `.popUpMenu` level (above the menu bar),
  non-activating, so the user's app keeps focus.
- **The ring ignores clicks**, so a click on the icon goes through to it.
- **The callout can become key**, so its buttons work on the first click.
- **Buttons use their own saffron style** (`PointerButton`). macOS greys a
  `.borderedProminent` button in a window that isn't key, and these panels
  never take focus.
- **The callout hangs 4 pt under the icon**, kept 10 pt inside the screen.
  Its arrow moves to stay over the icon when the callout is pushed in from
  the edge (`MenuBarPlacement.callout`).

## How a launch is classified

`LaunchKind.of(onboarded:tourPending:loginItem:uptime:)`:

- **`tourPending`** (`menuBarTourPending` in UserDefaults) is set by
  **Finish** and cleared when the tour shows.
- **`loginItem`** comes from the launch Apple event
  (`keyAELaunchedAsLogInItem`), read in `applicationWillFinishLaunching`
  while that event is still current. A launch in the first 120 s after boot
  counts as login too, in case the event isn't set.

## Files

| File | What |
|---|---|
| `DesiDictationKit/MenuBarPlacement.swift` | Visibility, callout placement, `LaunchKind`. Pure, tested in `DesiTests/MenuBarTests.swift` |
| `DesiDictationApp/MenuBarPointer.swift` | Finds the icon, shows and hides the panels, clicks the icon |
| `DesiDictationApp/PointerViews.swift` | The callout, notice, ring and button style |
| `DesiDictationApp/OnboardingParts.swift` | The permission step and the "lives in your menu bar" note |
| `DesiDictationApp/DesiDictationApp.swift` | Classifies the launch; reopen shows the reminder |

## Trying it

```bash
DESI_POINTER=tour app/.build/debug/desi-dictation       # or =reminder (debug builds only)
DESI_UI_SCALE=2 DESI_UI_SNAPSHOTS=/tmp/shots app/.build/debug/desi-dictation  # pointer-*.png, onboarding-parts.png
```

Debug builds log the icon frame, its visibility and the callout frame
(`[pointer]` lines).

A bare `desi-dictation` binary keeps its settings under the `desi-dictation`
defaults domain, not `com.desi.dictation`. So
`defaults write desi-dictation onboarded -bool true` (and
`menuBarTourPending`) tries each launch kind without touching the installed
app.
