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
   build_app.sh →   deploy_web.sh →   git tag v0.6.1 →
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
2. `git tag v0.6.1 && git push --tags`.
3. `release.yml`: fresh whisper.cpp libs → preflight gate → .app → DMG →
   GitHub Release. Signing/notarization activate automatically once the
   Developer ID secrets exist (workflow header lists them; LAUNCH.md steps 1–2);
   until then CI DMGs are ad-hoc (testers right-click → Open) and the
   properly-signed build is the local one (make_dev_cert.sh identity).
   The workflow fails if the bundle version ≠ tag — no mismatched releases.

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


## Latency gate (added 2026-08-19)

`preflight.sh` step 5 runs `scripts/latency_gate.sh`: a short clip per language
through `desi-cli` with the model resident, against a per-language
release→paste budget (docs/PERFORMANCE.md). It **skips silently in CI** — the
runner has neither the models nor the eval clips — so it is a local gate by
design. The RCA that motivated it: docs/PERF_RCA_2026-08.md.
