# Desi Dictation — Setup Guide (for users)

> This is the guide you link from GitHub/Gumroad/your site. Written for someone
> who has never seen the project. 5 minutes, one time.

## 1. Install

1. Download `DesiDictation-x.y.z.dmg` and open it.
2. Drag **Desi Dictation** into **Applications**.
3. Open it (Spotlight → "Desi Dictation"). A **mic icon** appears in your menu
   bar — there's no Dock icon, that's by design.

### ⚠️ Beta builds only: "Apple could not verify…" dialog

Early builds aren't notarized with Apple yet (that costs the developer $99/yr —
coming before the public launch). macOS will block the first open. This is
expected, not malware:

1. Double-click the app → macOS shows the block dialog → click **Done** (not Move to Trash!)
2. **System Settings → Privacy & Security** → scroll down → next to
   "Desi Dictation was blocked" click **Open Anyway** → confirm.
3. This is needed **once**; afterwards it opens normally.

Terminal-comfortable? This skips the dance entirely:
```bash
xattr -dr com.apple.quarantine "/Applications/Desi Dictation.app"
```

## 2. Grant the 3 permissions (one time)

Desi Dictation types your words into other apps, which needs macOS's blessing.
When prompted (or via **System Settings → Privacy & Security**):

| Permission | Why | Where |
|---|---|---|
| **Microphone** | hear you | prompt appears on first launch → Allow |
| **Accessibility** | paste the text into the app you're using | Privacy & Security → Accessibility → enable Desi Dictation |
| **Input Monitoring** | detect your dictation hotkey anywhere | Privacy & Security → Input Monitoring → enable Desi Dictation |

Then **quit the app (menu bar → Quit) and reopen it** — macOS applies these
only at startup. The app's Dictation screen shows live ✅/❌ for each.

**Your voice never leaves your Mac.** Everything runs locally — that's the
whole point of this app. No account, no cloud, no telemetry.

## 3. Download models (one time, the important step)

The app is tiny; the AI models are not, so you download just the ones you need:
menu bar → **Open Desi Dictation… → Models**.

**Get one ⭐ per language you speak, plus the VAD add-on:**

All models are **free** during the beta:

| Download | When you want | Size |
|---|---|---|
| ⭐ **Hinglish Apex** | Hinglish — "kal meeting hai, deck ready rakhna" | 547 MB |
| Hinglish Swift | Hinglish on older/8GB Macs (faster, lighter) | 141 MB |
| ⭐ **Whisper Large v3 Turbo** | English and/or शुद्ध हिन्दी (Devanagari) | 574 MB |
| Whisper Base | light English/Hindi fallback | 148 MB |
| ⭐ **Silero VAD** | everyone — massively better pauses & long dictations | 1 MB |

Downloads are SHA256-verified — a corrupted or tampered file is refused automatically.

Leave **Model: Auto** — the app picks the best installed model for whichever
language mode you're in.

## 4. Dictate

1. **Enable Dictation** (menu bar or the app window). First time takes ~8 s
   while the model loads.
2. Click into any text field anywhere — WhatsApp Web, Slack, Notes, your IDE.
3. **Hold Right ⌥ (Option)**, speak naturally — pauses are fine — release.
4. Your words appear at the cursor, and are also on your clipboard (⌘V pastes
   them again anywhere).
- Prefer tap-to-start/tap-to-stop? → app window → Activation mode → **Toggle**.
- Pressed it by accident? **Esc** discards.
- Different key (Right ⌘, F13, F16–F19)? → Dictation screen.

## 5. Make it yours

- **Text & AI → Replacements**: enforce your spellings (`nahin=nahi`), fix
  names it gets wrong (`dezi=desi`) — one `find=replace` per line.
- **History**: last 24 h of dictations, searchable, local-only, can be turned off.
- **AI cleanup**: pipe transcripts through a local Ollama model (Text & AI tab) —
  optional, and like everything else, fully on-device.

## Something broken?

The in-app Dictation screen diagnoses permissions live. Beyond that, see
[TROUBLESHOOTING.md](TROUBLESHOOTING.md) — the #1 gotcha is granting
permissions and forgetting to relaunch the app.
