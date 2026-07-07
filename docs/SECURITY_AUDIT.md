# Security & Privacy Audit — v0.3.x (2026-07-07)

Scope: what ships to users, what goes public on GitHub, and how secrets are
handled. Re-run this checklist before every public release.

## 1. Repository — safe to publish? ✅ (with one business caveat)

Verified on 84 tracked files:
- **No secrets**: pattern scan for HF/OpenAI/GitHub tokens, private keys,
  passwords → clean. `.env`, `spike/hf_cache/`, `vendor/`, models, build
  artifacts all gitignored.
- **No personal data**: no email addresses; the only occurrences of the
  author's name are intentional (HF model repo URLs, copyright).
- **`.DS_Store`**: gitignored, none tracked.
- **CI secrets** (`release.yml`): referenced via GitHub encrypted secrets —
  standard, safe; certificate imported into a throwaway CI keychain.

⚠️ **Business caveat, not security**: `docs/GTM.md`, `PRODUCT_VISION.md`,
`LAUNCH.md` contain your pricing strategy and launch plan. Public repo = 
competitors can read them. Options: keep the repo private and attach only the
DMG to a public release repo, or move strategy docs elsewhere. Code and user
docs are fine to publish.

## 2. Hugging Face token hygiene ✅

- `hf auth login` stores the token at `~/.cache/huggingface/token` — **outside
  the repo**, never committed, never referenced by app code.
- The app only ever **downloads** public files (no token needed at runtime).
- Recommendation: create a **fine-grained token** scoped to write only
  `desi-dictation-models`, and revoke it after publishing sessions. If a token
  ever leaks: hf.co/settings/tokens → revoke; nothing in the app breaks.

## 3. App attack surface

| Vector | Status |
|---|---|
| Model downloads (HTTPS) | ✅ + **SHA256 pinned per catalog entry** (v0.3.2) — a hijacked model repo can't feed tampered GGML into whisper.cpp's C parser; mismatches are deleted |
| Network calls | Only 3, all visible in code: model downloads (user-initiated), Gumroad license verify (dormant — gating disabled), Ollama at 127.0.0.1 (opt-in, localhost-only) |
| Telemetry / analytics | **None. Zero.** |
| Keystroke access (Input Monitoring) | Tap inspects keycodes for the hotkey/Esc only; no logging, no buffering of other keys — auditable in `HotkeyManager.swift` (~120 lines) |
| Audio | RAM-only Float buffer, discarded post-transcription; never written to disk, never transmitted |
| Transcripts | Local: clipboard (by design), `history.json` (24 h, toggleable, clearable) |
| License state | UserDefaults flags — trivially editable by the user (accepted: client-side gating is honor-system; real enforcement is the Gumroad key check at activation) |
| Dependencies | whisper.cpp (MIT, pinned by clone; consider pinning a commit hash pre-launch), Oriserve models (Apache 2.0), zero Swift package dependencies |

## 4. Known accepted risks (documented, low severity)

1. **Ad-hoc/self-signed beta signing** — friends see Gatekeeper's "Open Anyway"
   flow (SETUP_GUIDE). Fix at launch: Developer ID + notarization.
2. **Client-side Pro gating** (currently moot — everything free) — a determined
   user can set UserDefaults flags. Cost of "fixing" exceeds the harm.
3. **whisper.cpp clone is unpinned** (`--depth 1` HEAD) — reproducible-build
   gap. Action before v1.0: pin a known-good commit in `setup_whisper.sh`.
4. **Beta = everything free** (`LicenseManager.gatingEnabled = false`) —
   deliberate product decision, one-line revert at launch.

## 5. Privacy posture (the user-facing promise)

Audio never leaves the Mac. No accounts. No telemetry. Transcripts stored
locally only, deletable, optional. The only outbound traffic is model downloads
the user clicks, and (post-launch) a single license verification to Gumroad.
Any future change to this list must be release-noted loudly.
