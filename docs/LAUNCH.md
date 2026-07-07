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

## 1. Apple Developer setup ($99/yr — the only mandatory cost)

1. Enroll: https://developer.apple.com/programs/enroll/
2. Create a **Developer ID Application** certificate (Certificates → +) and
   install it in Keychain.
3. Find identity: `security find-identity -v -p codesigning`
4. In `scripts/build_app.sh`, replace ad-hoc signing:
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

## 3. Model distribution

Users can't run `convert_model.sh`. Before launch:
- [ ] Create your own HF repo (e.g. `<you>/desi-dictation-models`), upload
      `ggml-hinglish-swift.bin` + `ggml-hinglish-apex-q5_0.bin` (Apache 2.0
      permits redistribution; credit Oriserve in the README).
- [ ] Add both to `ModelManager.catalog` (swift: `pro: false`; apex: `pro: true`)
      so in-app download covers everything.
- [ ] Bump app version; rebuild.

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

## 7. Launch week

Follow GTM.md Phase 2 sequence (X thread → Product Hunt → Reddit → Show HN →
LinkedIn). Have 3 beta testimonials ready. Watch the Gumroad license API
dashboard for activation failures.

## What "do not launch yet" means for this build

Current build is **deliberately pre-launch**: ad-hoc signed (no $99 spent),
`LicenseManager.productID` empty (dev-unlock flag instead), models are
locally-converted only. Steps 1–4 above are exactly the delta between this
build and a sellable one.
