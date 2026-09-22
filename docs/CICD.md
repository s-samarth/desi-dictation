# CI/CD — how a change travels from your editor to users

Three delivery surfaces, one gate. Written 2026-07-10; first live run green
2026-07-14 (`macos-26` runner label confirmed). Developer-facing walkthrough
of the same flow: [CONTRIBUTING.md](CONTRIBUTING.md). Hosting the web demo:
[DEPLOYMENT.md](DEPLOYMENT.md).

```
                 you edit code
                      │
            ./scripts/preflight.sh          ← run before EVERY push
      (build · 119 tests · app↔web parity · web tests)
                      │  git push
                      ▼
   GitHub Actions: ci.yml  (mirrors preflight exactly)
      ├─ app job (macOS): swift build → desi-tests → check_parity
      └─ web job (ubuntu): test_web.py → server compiles
                      │
        ┌─────────────┼──────────────────┐
        ▼             ▼                  ▼
   Mac app (.app)   Web demo          DMG release
   build_app.sh →   deploy_web.sh →   git tag v0.6.2 →
   ditto to         rsync+restart     release.yml →
   /Applications    (auto once        DMG on GitHub
   (dev loop)       server exists)    Releases
```

## The rule that keeps app and server in sync

The Mac app (Swift) and web demo (Python) deliberately carry **ported copies**
of the shared brains — `HindiNumbers.swift ↔ web/hindi_numbers.py` and
`PromptTemplates.swift ↔ web/prompts.py` (two languages, no shared runtime).
Sync is **enforced, not remembered**: `scripts/check_parity.sh` runs identical
sentences through BOTH normalizer implementations and diffs the output, and
`web/test_web.py` greps the load-bearing prompt lines. Change one side without
the other → preflight and CI go red with a message naming the file to update.
The same applies to test intent: `DesiTests/NumberTests.swift` and
`web/test_web.py` mirror each other's cases.

## Day-to-day (the whole ritual)

```bash
./scripts/preflight.sh        # green = CI will be green
git commit … && git push      # ci.yml runs automatically
```

App on YOUR Mac: `./scripts/build_app.sh && ditto "app/dist/Desi Dictation.app" \
"/Applications/Desi Dictation.app"` — `swift build` alone never updates the
launched app (learned the hard way; see implementation/USER_WALKTHROUGH.md §0).

## Shipping a DMG

1. Bump `CFBundleShortVersionString` in `scripts/build_app.sh`.
2. `./scripts/release.sh v0.6.2` — preflight → build → **verify the bundle is
   signed, not ad-hoc** → DMG → tag + push → GitHub Release with install and
   update notes. It refuses a dirty tree or a tag that disagrees with the
   bundle version, so there are no mismatched releases.

The tag push also starts `release.yml`, which rebuilds from clean (fresh
whisper.cpp libs, preflight gate) as a check on the tag — see **Releases**
below for why it will not touch the uploaded DMG.

## Web demo deploys

- **Today (laptop hosting):** nothing to deploy — the laptop runs the working
  tree. Restart `./web/run_demo.sh` after pulling changes.
- **Server (when it exists):** one-time setup per web/README.md, then
  `./scripts/deploy_web.sh ubuntu@host` on every change (rsync + dep refresh +
  unit tests on the host + service restart).
- **Automatic:** ci.yml has a dormant `deploy-web` job — set repo variable
  `DEPLOY_ENABLED=true` + secrets `DEPLOY_HOST`/`DEPLOY_KEY` and every green
  push to main deploys itself.

## Runner note

Workflows target `runs-on: macos-26` because the manifest needs Swift ≥ 6.2.
Verified live 2026-07-14: the first ci.yml run completed green on GitHub's
runners (app ✓ · web ✓ · deploy-web correctly skipped while dormant).
Everything the workflows execute is byte-identical to the local preflight.


## Releases (updated 2026-08-19)

Two paths, both gated by preflight:

| Path | Command | Signing |
|---|---|---|
| **From this Mac** (use today) | `./scripts/release.sh v0.6.2` | "Desi Dictation Dev" — stable identity, permission grants survive updates |
| From a tag push | `git tag v0.6.2 && git push --tags` → `release.yml` | signs only if `MACOS_CERT_P12_BASE64` + `MACOS_CERT_PASSWORD` secrets exist; otherwise ad-hoc, and the release notes say so |

`release.yml` had a latent bug until 2026-08-19: the signing and notarization
steps were gated on `env.CERT`/`env.NID` defined in the step's *own* `env:`
block, which their `if:` could not see — so both steps never ran, no matter
what secrets were set. The variables now live at job level. The identity
matcher also used `find-identity -v`, which lists only Apple-trusted
identities and can never see a self-signed cert.

A tag push runs `release.yml` too, but it **will not replace a DMG that is
already attached** to that release — otherwise the ad-hoc-signed CI build would
overwrite the properly-signed one from `release.sh` and silently reset every
user's permission grants. When that happens the job still builds and verifies
the tag, and logs a notice saying it skipped the upload.

Setup for CI signing (exporting the .p12 into secrets): docs/LAUNCH.md §0.5.

## SDK auto-pick (added 2026-09-22)

`scripts/sdk_env.sh` is sourced by `preflight.sh` and `build_app.sh`. On a
Mac with Command Line Tools only (no Xcode), it type-checks one SwiftUI
`@State` line against the default SDK; if that fails, it exports `SDKROOT` to
the newest installed macOS 26 SDK. Why: CLT 27 ships the macOS 27 SDK, where
`@State` is a macro, but not the SwiftUIMacros compiler plugin (BUILD_LOG
FM#23). It's a no-op when `SDKROOT` is already set or Xcode is the active
developer dir, so CI (macos-26 runners with Xcode) is untouched. The
deployment target stays macOS 14, so the SDK choice doesn't change which
Macs the app runs on.

## Latency gate (added 2026-08-19)

`preflight.sh` step 5 runs `scripts/latency_gate.sh`: a short clip per language
(the manifest's `s`-bucket clip closest to 4 s — BUILD_LOG FM#29) through
`desi-cli` with the model resident, against a per-language
release→paste budget (docs/PERFORMANCE.md). It **skips silently in CI** — the
runner has neither the models nor the eval clips — so it is a local gate by
design. The RCA that motivated it: docs/PERF_RCA_2026-08.md.
