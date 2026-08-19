# Desi Dictation — rules for AI-assisted changes

On-device Hinglish dictation for macOS (menu-bar app) + a zero-install web
demo. Local-first forever, no telemetry ever, Apple Silicon only.

## Read BEFORE changing anything

The documentation is the source of truth for *why* things are the way they
are. Match your change to the row below and read that doc first — do not
skip this even for "small" edits.

| You are about to touch… | Read first |
|---|---|
| Any code, any file (the edit→ship flow itself) | [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) |
| `app/Sources/**` (Swift app) | [docs/SYSTEM_DESIGN.md](docs/SYSTEM_DESIGN.md) + the matching doc in [docs/features/implementation/](docs/features/implementation/) |
| `web/**` (browser demo) | [web/README.md](web/README.md) — and note the parity rule below |
| Prompts, number handling, LLM behavior | [docs/features/implementation/LLM_ENGINE.md](docs/features/implementation/LLM_ENGINE.md) — model matrix + why rules beat bigger models |
| `scripts/**`, `.github/workflows/**` | [docs/CICD.md](docs/CICD.md) |
| Models, ASR quality, engine choice | [docs/MODEL_RESEARCH.md](docs/MODEL_RESEARCH.md) + [docs/features/implementation/MODEL_ROUTING.md](docs/features/implementation/MODEL_ROUTING.md) |
| Anything about speed/latency | [docs/PERFORMANCE.md](docs/PERFORMANCE.md) + [docs/PERF_RCA_2026-08.md](docs/PERF_RCA_2026-08.md) — measure, don't assume RTF |
| Deploy targets, servers, domain | [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) |
| Anything user-facing (flows, menus, UI) | [docs/features/implementation/USER_WALKTHROUGH.md](docs/features/implementation/USER_WALKTHROUGH.md) + [docs/features/PERSONAS.md](docs/features/PERSONAS.md) |

Full index: [docs/README.md](docs/README.md). When a change teaches you a new
failure mode, log it in [docs/BUILD_LOG.md](docs/BUILD_LOG.md) — that file is
why the same bug never bites twice.

## Hard rules (non-negotiable)

1. **Every `swift` command on this Mac needs**
   `export SWIFTPM_CUSTOM_LIBS_DIR=$HOME/.swiftpm-fixed-libs` first
   (CLT 6.3.3 manifest bug — BUILD_LOG FM#17). Builds fail confusingly without it.
2. **`./scripts/preflight.sh` before every push.** Green preflight = green CI;
   it runs build · 119 tests · app↔web parity · web tests · **latency gate**
   (the last one is local-only — CI has no models).
3. **Parity pairs change together:** `HindiNumbers.swift ↔ web/hindi_numbers.py`
   and `PromptTemplates.swift ↔ web/prompts.py` are deliberate ports.
   `scripts/check_parity.sh` fails the build if they drift. Same for
   `DesiTests/NumberTests.swift ↔ web/test_web.py`.
4. **`app/` and `web/` stay separate.** No shared runtime, no imports across
   the boundary. They share only model files on disk and the parity-checked ports.
5. **`swift build` never updates the installed app.** To see a change live:
   `./scripts/build_app.sh && ditto "app/dist/Desi Dictation.app" "/Applications/Desi Dictation.app"`, then relaunch.
6. **No telemetry, no audio upload, no cloud default — ever.** Any feature that
   sends data must be opt-in and justified against [docs/SECURITY_AUDIT.md](docs/SECURITY_AUDIT.md).
7. **Files ≤ 200 lines** — split proactively. Check for existing utilities
   before writing new ones.
8. **Don't run the full evals** (too slow); single clips from `evals/` as
   one-off checks are fine. `desi-tests` + `check_parity.sh` are the gate.
9. **Ask before adding dependencies**, and explain why.
10. **No subagent/workflow fan-outs** — work sequentially; token budget is a
    real constraint here.

## Quick commands

```bash
export SWIFTPM_CUSTOM_LIBS_DIR=$HOME/.swiftpm-fixed-libs   # always, first
(cd app && swift build)                # compile
app/.build/debug/desi-tests            # 119 assertions, exit 0 = green
./scripts/latency_gate.sh              # short-dictation latency per language
./scripts/preflight.sh                 # the full pre-push gate
./scripts/build_app.sh                 # rebuild the .app bundle (v in this file)
./scripts/release.sh v0.6.2            # signed DMG + GitHub Release (one command)
./web/run_demo.sh                      # web demo → http://localhost:8080
```

Commit style: conventional commits (`feat:`, `fix:`, `docs:`, `ci:`…), ending
with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

## Update the docs with the code

A change isn't done until: the matching `docs/features/implementation/` doc
reflects it, [docs/PRODUCT.md](docs/PRODUCT.md) feature table is current, and
anything a user would notice is in
[docs/features/implementation/USER_WALKTHROUGH.md](docs/features/implementation/USER_WALKTHROUGH.md).
