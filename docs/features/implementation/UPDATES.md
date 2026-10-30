# In-app updates: one click, nothing to set up again

**Built:** 2026-10-30. Before this, updating meant the Terminal one-liner or
a new DMG: quit the app, drag, Replace, and click Open Anyway again. Users
don't go looking for updates, so a "Check for updates" button would be
ignored (user decision 2026-10-30). The app looks by itself and shows one
line when there's something new.

## What the user sees

- **Nothing**, until a newer release exists.
- Then:
  - **a dot on the menu-bar mic**;
  - **"⬆︎ Update to v0.8.0 (click to install)"** just under the menu's status line;
  - **a banner across the window**: "Desi Dictation 0.8.0 is ready. Nothing to set up again." with **Update now**.
- **One click.** The menu shows "Downloading update… 42%", then "Restarting
  to finish the update…". The app quits and the new version opens by
  itself, about ten seconds later.
- **Not mid-sentence.** If a dictation is recording or transcribing, the
  restart waits for it to finish.
- **Same permissions, settings and models.** Nothing to grant again (see
  below). Settings, history and models live outside the app bundle and
  aren't touched.
- **If something fails**, the line says why ("The download was damaged.")
  and becomes **Try again**.

There is no switch to turn the check off, and no setup question about it
(user decision 2026-10-30): it sends nothing about the user (see
[SECURITY_AUDIT.md](../../SECURITY_AUDIT.md)).

## When it checks

- 20 s after launch, every launch, so a pending update shows again after a
  restart.
- Then hourly, but it only asks GitHub when 12 h have passed since the last
  answer (`updateLastCheck` in UserDefaults).
- Offline? The request fails quietly and the next hourly tick tries again.
  That's "whenever they're on the internet", without watching the network.

## How an update installs

`UpdateInstaller` (DesiDictationKit) does what `install.sh` does, in Swift:

1. **Ask.** `GET api.github.com/repos/s-samarth/desi-dictation/releases/latest`:
   ephemeral session, fixed User-Agent, no IDs. `AppRelease.parse` picks the
   DMG:
   - `DesiDictation-update.dmg` (release.sh publishes it from this version on,
     so `download_counts.sh` shows updates apart from new installs);
   - else the versioned DMG.
   A DMG without a `.sha256` beside it is never offered.
2. **Download** to `~/Library/Caches/com.desi.dictation/Update/`. This
   costs nothing until the click, so the counts aren't inflated by people
   who never update.
3. **Check, three ways:**
   - **SHA-256** matches the published checksum;
   - **version**: the unpacked app's `CFBundleShortVersionString` is the one
     advertised and newer than the running one (no downgrades);
   - **signature**: the new app satisfies the running app's *designated
     requirement*, which means the same bundle ID and the same signing
     certificate (`SecStaticCodeCheckValidity`).
4. **Swap after quitting.** A small `/bin/sh` helper waits for the app's PID
   to exit, then:
   - moves the old bundle aside;
   - `ditto`s the new one into the same path (restoring the old app if the
     copy fails);
   - clears quarantine;
   - `open`s it.

Where the app can't write its own folder (a non-admin account, or a
read-only location), the click opens the DMG download instead, as before.

### Why permissions survive

macOS stores the mic, Accessibility and Input Monitoring grants against the
app's designated requirement: bundle ID plus signing certificate, not the
file's hash. `release.sh` already refuses to ship an ad-hoc build for this
reason. The signature check in step 3 is the same test macOS applies, so an
update that passes it keeps every grant, and one that wouldn't is refused.

- A dev build is ad-hoc signed. Its requirement is its own hash, so it never
  accepts an update.
- If the certificate were ever replaced, updates would be refused, and users
  would install once by hand and grant permissions again (user decision:
  acceptable, no certificate backup process).

### Downloads, and the first update

The app doesn't mark files it downloads as quarantined, so the new version
opens without Gatekeeper's "Open Anyway". The update arrives with the first
release that contains it. Users on v0.7.1 or older install that one by hand
(DMG or Terminal), once.

## Testing

| What | How |
|---|---|
| Version order, DMG choice, checksum required, foreign signature refused | `desi-tests` → `runUpdateTests` |
| A real update, end to end | `./scripts/rehearse_update.sh` (~70 s) |
| Banner and dot | `DESI_UI_SNAPSHOTS=…` → `update-banner.png`, `update-downloading.png`, `update-icon.png` |

`rehearse_update.sh` runs three passes and touches nothing of the user's.
It sets up:

- a throwaway keychain with two throwaway certificates;
- a test bundle ID (`com.desi.dictation.updatetest`);
- a local feed (`DESI_UPDATE_FEED`).

The old app is the real debug binary with only its updater running
(`DESI_UPDATE_REHEARSAL=1`, `DESI_UPDATE_INSTALL_NOW=1`). The new one is a
stub that notes it was opened. The passes:

| Pass | Expected |
|---|---|
| Same certificate | Swapped, signature intact, new app opened |
| Other certificate | Refused, old app kept |
| Wrong checksum | Refused, old app kept |

The rehearsal can't cover real grants or the menu click, so both were
checked by hand on the maintainer's Mac (2026-10-30):

- the real app, signed with "Desi Dictation Dev", ran with
  `open --env DESI_UPDATE_FEED=…` against a local feed offering v0.7.1.1
  (the same build, re-signed with a bumped version);
- the mic showed the dot, and the menu line was clicked;
- about 3 s later v0.7.1.1 was running from `/Applications`, signature
  intact;
- a dictation worked straight away, with no permission asked again.

Use a four-part version like that for hand tests, so the next real
release is still newer.

## Files

| File | What |
|---|---|
| `DesiDictationKit/Update/AppRelease.swift` | Release JSON → DMG + checksum; version order; the feed request |
| `DesiDictationKit/Update/UpdateInstaller.swift` | Download, the three checks, the swap helper |
| `DesiDictationApp/Updater.swift` | When to check, the state the UI shows, waiting for idle, quitting |
| `DesiDictationApp/UpdateViews.swift` | Menu line, window banner, the mic with a dot |
| `scripts/release.sh` | Publishes `DesiDictation-update.dmg` + `.sha256` |
| `scripts/download_counts.sh` | An "updates" column, kept out of the new-download total |
| `scripts/rehearse_update.sh` | The end-to-end rehearsal |
