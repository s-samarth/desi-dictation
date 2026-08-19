# Launch Runway — from this repo to Gumroad

Ordered checklist to take v0.1.0 from "works on my Mac" to "strangers pay for
it". Strategy/why lives in [GTM.md](GTM.md); this is the how. Estimated total:
2–3 weeks part-time.

## 0. Pre-flight quality gate (do first)

- [ ] Run the personal eval (spike/README.md): 40–60 of YOUR clips, decide the
      default model (swift vs apex-q5_0), record verdict in `spike/results/RESULTS.md`.
- [ ] Dogfood daily for 2 weeks — replace MacWhisper for yourself.
- [ ] Test insertion in: Notes, Safari, Chrome (WhatsApp Web), Slack, VS Code,
      Terminal, iTerm, Mail, Notion. Log breakages → fix or document.
- [ ] Pick the final name. "Desi Dictation" is a working title — check
      trademark + .com/.in + App-Store-collision before printing it anywhere.

## 0.5 Signing beta builds (before you pay Apple anything)

Betas ship signed with the project's **own self-signed identity**, "Desi
Dictation Dev" (`./scripts/make_dev_cert.sh`, one time). It does *not* clear
Gatekeeper — testers still do the "Open Anyway" dance once — but it fixes the
thing that actually annoys them on every update:

| | ad-hoc | self-signed "Desi Dictation Dev" | Developer ID + notarized |
|---|---|---|---|
| "Apple could not verify…" on first open | yes | yes (once per machine) | **no** |
| Accessibility / Input Monitoring survive an update | **no** | **yes** | yes |
| Cost | — | — | $99/yr |

macOS ties permission grants to the code signature. Ad-hoc signatures are
regenerated per build, so every update looks like a different app and testers
must remove (−) and re-add the app in Privacy & Security
(TROUBLESHOOTING.md §1). A stable identity ends that.

**Cut a signed release from this Mac** (the identity lives in your login
keychain — this is the path to use today):

```bash
./scripts/release.sh v0.6.1        # preflight → build → sign → DMG → GitHub Release
```

It refuses to publish a dirty tree, a tag that disagrees with the bundle
version, or an ad-hoc-signed bundle.

**To let CI sign instead** (optional — needed only if you want tag-pushes to
produce signed DMGs without your laptop):

```bash
# Export the identity — macOS will prompt for your login password.
security export -k ~/Library/Keychains/login.keychain-db -t identities \
  -f pkcs12 -P "choose-a-password" -o /tmp/desi-dev.p12
base64 -i /tmp/desi-dev.p12 | pbcopy       # now in your clipboard
```
Then in the repo: **Settings → Secrets and variables → Actions → New secret**
- `MACOS_CERT_P12_BASE64` — paste the clipboard
- `MACOS_CERT_PASSWORD` — the password you chose

Delete `/tmp/desi-dev.p12` afterwards. `release.yml` imports it and signs
automatically; without the secrets it falls back to ad-hoc and says so in the
release notes. Same two secrets later hold the Developer ID cert — the workflow
prefers a Developer ID identity when one is present and adds the hardened
runtime for notarization.

## 1. Apple Developer setup ($99/yr — the only mandatory cost)

1. Enroll: https://developer.apple.com/programs/enroll/
2. Create a **Developer ID Application** certificate (Certificates → +) and
   install it in Keychain.
3. Find identity: `security find-identity -v -p codesigning`
4. `build_app.sh` already prefers the best identity it finds; for a Developer ID
   build make sure it signs with the hardened runtime:
   ```bash
   codesign --force --deep --options runtime \
     --sign "Developer ID Application: YOUR NAME (TEAMID)" "$BUNDLE"
   ```
   (`--options runtime` = hardened runtime, required for notarization.)

## 2. Notarization (required — unsigned apps are near-uninstallable now)

```bash
xcrun notarytool store-credentials desi-notary \
  --apple-id you@email --team-id TEAMID --password <app-specific-password>

./scripts/build_app.sh && ./scripts/make_dmg.sh
xcrun notarytool submit app/dist/DesiDictation-0.1.0.dmg \
  --keychain-profile desi-notary --wait
xcrun stapler staple app/dist/DesiDictation-0.1.0.dmg
```

Verify on a different Mac (or new user account): download → open → no Gatekeeper block.

## 3. Model distribution (scripted)

Users can't run `convert_model.sh`, so models ship via your Hugging Face repo
and the app's in-app downloader (already wired to
`samarthsaraswat/desi-dictation-models`):

```bash
cd spike && uv run hf auth login      # one-time, WRITE token from hf.co/settings/tokens
./scripts/publish_models.sh           # uploads ggml-hinglish-*.bin
```
- [ ] Add a README to the HF repo crediting Oriserve (Apache 2.0) + whisper.cpp.
- [ ] Test: fresh Mac (or `rm` the models dir) → Models tab → download each ⭐.
- [ ] If your HF username differs, update `ModelManager.hinglishRepoBase`.

## 4. Gumroad product

1. Product type: **Digital product** → "Desi Dictation Pro — Lifetime License".
2. Price ₹999 (or $19); **enable "Generate a unique license key per sale"**.
3. Settings → Advanced → note the **product ID** → paste into
   `LicenseManager.productID` → rebuild. Verify a real key end-to-end via
   Settings → License.
4. Enable PPP; create `DESILAUNCH` (-20%) discount code.
5. Upload the notarized DMG as the product file (free tier: same DMG, license
   just unlocks Pro — one binary, honest gating).
6. Product page: the hero GIF (see GTM.md), 3 bullets, privacy headline, FAQ
   from GTM objections.

## 5. Minimal web presence

- [ ] Landing page (GitHub Pages is fine): GIF, one paragraph, Gumroad button,
      comparison table, FAQ.
- [ ] Support email + a `docs/` copy of USAGE + TROUBLESHOOTING as the user manual.
- [ ] Privacy policy page (one honest paragraph — local processing, no audio
      collection, Gumroad handles payments).

## 6. Auto-updates (strongly recommended before v1.0)

Integrate [Sparkle](https://sparkle-project.org) (SPM package), generate EdDSA
keys, host an appcast.xml on the landing page repo. Without this, every bugfix
requires users to re-download manually. (~1 day of work.)

## 6.5 Knowing you have users — without taking their data

Privacy is the headline promise, so measurement happens **outside the app**:

| Signal | Source | Effort |
|---|---|---|
| Paying users | Gumroad dashboard (sales, license activations, refunds) | free |
| Free downloads | Gumroad "$0+" product analytics + GitHub Release download counts (`gh api repos/<you>/<repo>/releases`) | free |
| Site traffic → conversion | Plausible or GoatCounter on the landing page (cookieless, GDPR-clean) | ~$0–9/mo |
| Qualitative | support email volume, Twitter/Reddit mentions, HF model download stats | free |

**In-app telemetry: none.** If you ever add it, make it opt-in TelemetryDeck
(anonymous counts only — what MacWhisper uses) and say so loudly. Never audio,
never transcripts — that line is the brand.

## 6.6 CI releases (already configured)

`.github/workflows/release.yml`: push a tag → macOS runner builds whisper.cpp +
app → DMG → GitHub Release. Add the signing/notarization secrets from steps 1–2
(`MACOS_CERT_P12_BASE64`, `MACOS_CERT_PASSWORD`, `NOTARY_APPLE_ID`,
`NOTARY_TEAM_ID`, `NOTARY_PASSWORD`) and releases come out fully notarized:

```bash
git tag v0.3.0 && git push origin v0.3.0
```

## 7. Launch week

Follow GTM.md Phase 2 sequence (X thread → Product Hunt → Reddit → Show HN →
LinkedIn). Have 3 beta testimonials ready. Watch the Gumroad license API
dashboard for activation failures.

## What "do not launch yet" means for this build

Current build is **deliberately pre-launch**: ad-hoc signed (no $99 spent),
`LicenseManager.productID` empty (dev-unlock flag instead), models are
locally-converted only. Steps 1–4 above are exactly the delta between this
build and a sellable one.
