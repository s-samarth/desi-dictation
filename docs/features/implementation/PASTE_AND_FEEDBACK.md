# Paste-back and end-of-dictation feedback (v0.6.2, 2026-10-28)

How a finished transcript reaches the text field, and what the user is told
when it doesn't. Root cause and history: [BUILD_LOG FM#31](../../BUILD_LOG.md).

## Where the paste goes

`TextInserter.insert` puts the transcript on the clipboard, then posts ⌘V at
the HID tap. Nothing about the target is captured when recording starts: ⌘V
goes to **whatever field is focused when the user stops**. Switching apps or
Spaces mid-dictation, then clicking into any text box and stopping, pastes
there. The words stay on the clipboard afterwards (no restore), so a rejected
paste is one ⌘V away.

## The modifier wait (the FM#31 fix)

Before posting ⌘V, `insert` polls `CGEventSource.flagsState(.hidSystemState)`
every 20 ms until ⌥, ⇧ and ⌃ are physically up. The decision is the pure
function `PasteGate.step(copyOnly:trusted:held:waited:)`:

| Condition | Step |
|---|---|
| copy-only setting on | `.copyOnly`: clipboard only, no notice |
| `AXIsProcessTrusted()` false | `.skip(.noAccessibility)`: macOS would drop the keystroke silently |
| one of our menus is open (`MenuTracker`) | `.closeMenu`: `cancelTracking()` it, wait for it to end, +80 ms, then continue (FM#32) |
| still open at 1.5 s | `.skip(.menuOpen)` |
| no ⌥ ⇧ ⌃ held (⌘, Caps Lock and fn don't count) | `.paste` |
| held, under `PasteGate.maxWait` (1.5 s) | `.wait` |
| still held at 1.5 s | `.skip(.modifiersHeld)`: never send ⌥⌘V, which moves files in Finder |

The wait almost always costs 0 ms. It only matters when the tail transcribes
faster than the user lets go of the toggle key: toggle mode stops on Right ⌥
*keyDown*, and a silent tail (common after a long, chunked session where the
user went quiet while switching apps) returns from VAD in ~10 ms.

## Our own menu steals the keystroke (FM#32)

An open menu holds keyboard focus as the window server's "key thief". The
frontmost app doesn't change, but every keystroke, our ⌘V included, goes to
the menu. So opening the menu-bar menu, dictating, and stopping with the
menu still open used to drop the paste. `MenuTracker` (started from
`DictationController.init`) follows `NSMenu.didBegin/EndTrackingNotification`
for every menu in our process. `TextInserter` closes those menus before the
paste. Menus of *other* apps (another menu-bar item, Spotlight) can't be seen
from here and still swallow ⌘V.

## Feedback: `DictationController.notice`

`notice: DictationNotice?` is published next to `phase`. The overlay
(`OverlayCoordinator`) shows while the phase is active **or** a notice is set;
`OverlayNoticeRow` renders it in the same capsule. Notices clear after
`DictationNotice.displaySeconds` (4 s) or as soon as a new dictation starts.

| Ending | Notice | Sound |
|---|---|---|
| Pasted | none | Pop |
| Copy-only setting | none | Pop |
| Empty transcript (silence, noise, a filtered label) | ⚠️ "Didn't catch that — nothing pasted. Try again." | Basso |
| Paste skipped, key held or menu wouldn't close | 📋 "Copied — press ⌘V to paste" | Basso |
| Paste skipped, no Accessibility | 📋 "Copied — press ⌘V. Grant Accessibility to auto-paste" | Basso |
| Any other transient error (too short, no model, engine failure, translation fallback) | ⚠️ the error text | Basso |

Every `transientError` also sets a notice, so a new error message is visible
without extra work. Errors set by `enable()` (missing or stale permissions)
are persistent states, not notices; they stay in the menu and the Dictation
pane and never pin the overlay on screen.

`delivered(_:)` only moves the phase to idle from the pipeline's own phases
(transcribing / translating / polishing). A fallback error ("Translation
failed — pasted your original words.") or a dictation the user already
started again survives the paste finishing.

## Limits

- Another app's open menu takes the ⌘V; we can't detect it (FM#32).
- A paste the target app accepts but ignores (a field that blocks
  programmatic paste) can't be detected; the words are on the clipboard.
- With a stale Accessibility grant (`AXIsProcessTrusted` true but events
  denied, the listen-only tap mode), the drop is invisible to us too.

## Tests

`DesiTests/PasteTests.swift`: every `PasteGate` branch (held ⌥ waits, ⌘ and
Caps Lock don't, timeout skips, no Accessibility skips, copy-only wins, an
open menu is closed first and skipped if it won't close) and
the outcome → notice mapping.
