# Making a change — the full flow

The one document that walks an edit from idea to every delivery surface.
Written 2026-07-14. Companion pieces: [CICD.md](CICD.md) (the pipeline
itself) and [DEPLOYMENT.md](DEPLOYMENT.md) (getting the web demo hosted).

## 0. One-time shell setup (this Mac)

```bash
# CLT 6.3.3 ships a broken SwiftPM manifest lib (BUILD_LOG.md FM#17).
# Every swift command fails without this — put it in ~/.zshrc:
export SWIFTPM_CUSTOM_LIBS_DIR=$HOME/.swiftpm-fixed-libs
```

## 1. Before you edit: read the right doc

The repo-root [CLAUDE.md](../CLAUDE.md) has the routing table (what to read
before touching which directory). The short version: every built feature has
a design doc in [features/implementation/](features/implementation/) that
explains how it works and *why* — read it, or you'll re-fight a decided fight
(e.g. "use a bigger LLM" was tested and lost to deterministic rules;
LLM_ENGINE.md has the matrix).

## 2. The edit loop

```
edit code
  │
  ▼
(cd app && swift build)                     # compiles?
  │
  ▼
app/.build/debug/desi-tests                 # 95 assertions green?
  │            (add a test for your change — DesiTests/*.swift)
  ▼
try it for real  ──────────────┬─ app change: build_app.sh + ditto + relaunch (§3)
  │                            └─ web change: ./web/run_demo.sh → localhost:8080
  ▼
./scripts/preflight.sh                      # the full gate: build · tests ·
  │                                         # app↔web parity · web tests
  ▼
update the docs (§5) → conventional commit → push
  │
  ▼
GitHub Actions ci.yml runs preflight's exact steps → green
```

**If you touched the shared brains** — number normalization
(`HindiNumbers.swift`) or prompts (`PromptTemplates.swift`) — the Python
ports (`web/hindi_numbers.py`, `web/prompts.py`) must change in the same
commit. You don't have to remember: `check_parity.sh` (inside preflight and
CI) diffs both implementations on shared sentences and fails with the
filename to fix. Mirror test intent too: `NumberTests.swift ↔ web/test_web.py`.

## 3. Seeing an app change live (the trap)

`swift build` builds a **binary**, not the **.app bundle** you launch. The
app in /Applications does not update until you:

```bash
./scripts/build_app.sh
ditto "app/dist/Desi Dictation.app" "/Applications/Desi Dictation.app"
# quit the app (menu bar → Quit) and relaunch it
open "/Applications/Desi Dictation.app"
```

The dev certificate (`make_dev_cert.sh`, one-time) keeps mic/Accessibility/
Input-Monitoring grants across rebuilds. Ad-hoc builds lose them every time
(TROUBLESHOOTING.md §1).

## 4. How the change reaches each surface

| Surface | How it updates | Trigger |
|---|---|---|
| **Your Mac** (dev loop) | §3 above | manual, each iteration |
| **Web demo — laptop** | laptop runs the working tree; Ctrl-C + `./web/run_demo.sh` | manual, after pull/edit |
| **Web demo — server** | `./scripts/deploy_web.sh ubuntu@host` (rsync + deps + host tests + service restart) | manual — or **automatic** on every green push to main once repo variable `DEPLOY_ENABLED=true` + secrets `DEPLOY_HOST`/`DEPLOY_KEY` are set ([CICD.md](CICD.md)) |
| **DMG for users** | bump `CFBundleShortVersionString` in `scripts/build_app.sh`, then `./scripts/release.sh v0.6.2` — preflight, build, **sign with the stable identity**, DMG, GitHub Release. (A bare `git push --tags` also works but CI can only ad-hoc sign until the cert is in secrets — LAUNCH.md §0.5.) | one command |

One commit, all surfaces: CI re-verifies it, the server redeploys itself (once
enabled), and the next tag ships it in the DMG. Nothing is deployed that
didn't pass the same 95-test + parity gate.

## 5. Docs are part of the change

Before the commit, walk this checklist:

- [ ] Feature behavior changed → its [features/implementation/](features/implementation/) doc
- [ ] User-visible change → [USER_WALKTHROUGH.md](features/implementation/USER_WALKTHROUGH.md) (+ [USAGE.md](USAGE.md) if steps changed)
- [ ] Feature added/removed → [PRODUCT.md](PRODUCT.md) table + [README.md](README.md) index if a new doc exists
- [ ] New failure mode discovered → [BUILD_LOG.md](BUILD_LOG.md) (numbered FM entry) + [TROUBLESHOOTING.md](TROUBLESHOOTING.md) if users can hit it
- [ ] Pipeline/scripts changed → [CICD.md](CICD.md)

## 6. Commit and push

```bash
git add -A
git commit -m "feat(scope): what and why"   # conventional commits
./scripts/preflight.sh                       # if you haven't already
git push                                     # ci.yml takes it from here
```

Watch the run with `gh run watch` if you want; a red CI on a green preflight
means environment drift — read the failing job's log, it names the step.
