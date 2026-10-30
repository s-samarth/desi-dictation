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

## Setup: one question per page (redesigned 2026-10-30)

The first fresh-install review found the single scrolling setup page
cluttered and cut off: tiny text, the user's own name in examples, Review
explained in one dense paragraph, and an Accessibility tick that never turned
green. Setup is now seven pages with Back and Continue and a progress bar
(`OnboardingView`). `OnboardingModel` holds every choice, so going Back
loses nothing.

| Page | What it asks | Notes |
|---|---|---|
| Welcome | nothing | What it does: private, every app, one key |
| Language | main language, "I also speak" | **English preselected** (user decision 2026-10-30) |
| Models | English: Parakeet and/or Qwen | Parakeet "fastest, default" (0.14–0.21 s), Qwen "most accurate": ~1 in 6 fewer errors on clear Indian English, ~0.5 s slower (ENGLISH_ASR_AB_2026-10.md). With both, Auto uses Parakeet. **Download and continue** starts the downloads; the footer shows progress on later pages |
| Permissions | Microphone, Accessibility, Input Monitoring | One **Allow** each. Ticks come from `PermissionProbe` (below). After the first press, a drawing shows the row to switch on. The list isn't named: macOS 27 files Accessibility under "Device Control and Data Access" |
| Your words | the vocabulary switches | Each card: what it does, a generic example (Kartick → Kartik), who should turn it on |
| Review | when it opens, how much it underlines | A drawing of the panel; "Feel it's poking you too often? Switch to Liberal"; the context checker card shows whether or not Review is on |
| Done | nothing | The menu bar with the mic ringed; the three everyday steps; **Finish** unlocks when models are in |

### Why the ticks needed a probe (FM#44)

`AXIsProcessTrusted()` answers once per process. Setup used to poll it every
second, but macOS's log showed only two real checks: at launch and on Allow.
`PermissionProbe.ask()` starts this app's own binary with
`--permission-probe`; that copy asks macOS, exits with the answer as its
exit code (40 + 1 Accessibility + 2 Input Monitoring), and is judged by
macOS as this app, since it's a child process. ~25 ms warm.

- `Launch.main` handles the flag before any of the app starts.
- `PermissionWatcher` probes every second until all three are granted, and
  once more when the app becomes active again (back from System Settings).
- The paste gate (`Permissions.accessibilityGranted()`) probes only when the
  cached answer is "no", so an Accessibility grant made while the app runs
  works without a restart.
- An already set-up app whose permission was lost still asks at launch, as
  before.

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
| `DesiDictationApp/Onboarding*.swift` | Setup: the flow (`OnboardingView`, `OnboardingModel`), shared cards (`OnboardingKit`), and one file per group of pages |
| `DesiDictationKit/PermissionProbe.swift` | Fresh permission answers from a short-lived copy of the app |
| `DesiDictationApp/DesiDictationApp.swift` | Classifies the launch; reopen shows the reminder |

## Trying it

```bash
DESI_POINTER=tour app/.build/debug/desi-dictation       # or =reminder (debug builds only)
DESI_UI_SCALE=2 DESI_UI_SNAPSHOTS=/tmp/shots app/.build/debug/desi-dictation  # pointer-*.png, onboarding-<n>-<page>.png
```

Debug builds log the icon frame, its visibility and the callout frame
(`[pointer]` lines).

A bare `desi-dictation` binary keeps its settings under the `desi-dictation`
defaults domain, not `com.desi.dictation`. So
`defaults write desi-dictation onboarded -bool true` (and
`menuBarTourPending`) tries each launch kind without touching the installed
app.
