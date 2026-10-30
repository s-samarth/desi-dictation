# Documentation Index

The public documentation for Desi Dictation — how it's built, run, and shipped. Strategy, business and planning notes are kept in a separate private repo (cloned into a gitignored `private/` folder in the maintainer's checkout); links to them in these docs are marked *(private)*. Grouped by purpose; start wherever your question sits.

## 🛠 Engineering & product (how it's built and run)
| Doc | What |
|---|---|
| [SYSTEM_DESIGN.md](SYSTEM_DESIGN.md) | Architecture deep-dive — the full pipeline, key decisions |
| [PERFORMANCE.md](PERFORMANCE.md) | Latency engineering: applied + deferred levers, and the numbers that are gated |
| [PERF_RCA_2026-08.md](PERF_RCA_2026-08.md) | **Why dictation got slow** — the root-cause analysis behind the v0.6.1 speed work |
| [BUILD_LOG.md](BUILD_LOG.md) | Chronological build steps + every failure mode (FM#1–16) |
| [SECURITY_AUDIT.md](SECURITY_AUDIT.md) | Privacy/security posture, verified |
| [legal/](legal/) | **Privacy Policy** and **Terms of Service** for release (fill the bracketed date, city and website line first) |
| [SETUP_GUIDE.md](SETUP_GUIDE.md) | End-user install guide (start here to *use* it) |
| [USAGE.md](USAGE.md) | Developer usage — precise build/run steps |
| [CONTRIBUTING.md](CONTRIBUTING.md) | **Making a change, end to end** — edit loop, tests, docs checklist, how each surface updates |
| [CICD.md](CICD.md) | Preflight → CI → DMG release → web deploy; the app↔web parity gate |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Hosting the web demo: laptop → your domain (free tunnel) → AWS from zero |
| [../web/README.md](../web/README.md) | **Zero-install browser demo** — run locally, share via tunnel, AWS path |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | When things break (incl. "can't be opened" triage) |

## 🌱 Genesis (where it began)
| Doc | What |
|---|---|
| [genesis/](genesis/) | The founding docs — [MacWhisper.md](genesis/MacWhisper.md) (the teardown that inspired it) + [plan.md](genesis/plan.md) (the original build plan) |

## 🧭 Product and features
| Doc | What |
|---|---|
| [PRODUCT.md](PRODUCT.md) | Product & features reference |
| [features/implementation/](features/implementation/) | **How the built features actually work** — LLM engine, dictionary, per-app modes, translate ×2, structure, tones, [model routing](features/implementation/MODEL_ROUTING.md), [review before paste](features/implementation/REVIEW_BEFORE_PASTE.md), [fillers and spoken corrections](features/implementation/FILLERS_AND_CORRECTIONS.md), [feedback and download counts](features/implementation/FEEDBACK.md), testing |

## 🔬 Model research and launch
| Doc | What |
|---|---|
| [MODEL_RESEARCH.md](MODEL_RESEARCH.md) | Model landscape & selection research |
| [ENGLISH_ASR_SCOUT_2026-10.md](ENGLISH_ASR_SCOUT_2026-10.md) | Can anything beat Parakeet for English? Leaderboard + on-device scout, Oct 2026 |
| [ENGLISH_ASR_AB_2026-10.md](ENGLISH_ASR_AB_2026-10.md) | The measured A/B: Parakeet v3 vs v2, Qwen3-ASR, NVIDIA unified, Turbo — clean + noisy Indian English |
| [../launch-video/](../launch-video/README.md) | Launch video (Remotion): scenes, how to render, recording shot list |

---

**Reading order suggestions:**
- *New here / want to use it:* [SETUP_GUIDE](SETUP_GUIDE.md) → [USAGE](USAGE.md).
- *Understand the build:* [genesis/plan.md](genesis/plan.md) → [SYSTEM_DESIGN](SYSTEM_DESIGN.md) → [BUILD_LOG](BUILD_LOG.md).
