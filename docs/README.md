# Documentation Index

Everything written about Desi Dictation — engineering, product, strategy, and business. The repo is private, so strategy/business docs live here too (they used to be gitignored). Grouped by purpose; start wherever your question sits.

## 🛠 Engineering & product (how it's built and run)
| Doc | What |
|---|---|
| [SYSTEM_DESIGN.md](SYSTEM_DESIGN.md) | Architecture deep-dive — the full pipeline, key decisions |
| [PERFORMANCE.md](PERFORMANCE.md) | Latency engineering: applied + deferred levers |
| [BUILD_LOG.md](BUILD_LOG.md) | Chronological build steps + every failure mode (FM#1–16) |
| [SECURITY_AUDIT.md](SECURITY_AUDIT.md) | Privacy/security posture, verified |
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

## 🧭 Product: vision, features, problems
| Doc | What |
|---|---|
| [PRODUCT.md](PRODUCT.md) | Product & features reference |
| [PRODUCT_VISION.md](PRODUCT_VISION.md) | The long-range product vision |
| [features/](features/) | Planned features — [personas](features/PERSONAS.md), [translation](features/TRANSLATION.md), [speak-desi-write-English](features/TRANSCRIBE_TRANSLATE.md), [structure-thoughts](features/STRUCTURE_THOUGHTS.md), [10 ideas](features/IDEAS.md) |
| [features/implementation/](features/implementation/) | **How the built features actually work** (0.6 wave, 2026-07-10) — LLM engine, dictionary, per-app modes, translate ×2, structure, tones, testing |
| [problems/](problems/) | The problems that decide the product — [P1 Hinglish accuracy](problems/P1_HINGLISH_ACCURACY.md), [P2 OOD words](problems/P2_OOD_WORDS.md), [P3 freshness/data](problems/P3_MODEL_FRESHNESS.md), [P4 personalization](problems/P4_PERSONALIZATION.md), [10 more](problems/ADDITIONAL_PROBLEMS.md) |
| [platforms/](platforms/) | Platform expansion — [Windows](platforms/WINDOWS.md) (easiest, first) → [Android](platforms/ANDROID.md) (the India must-have; voice-IME) → [iOS](platforms/IOS.md) (hardest; app-hop) — flows, min specs, and the one-shot Claude build prompts |
| [cloud/](cloud/) | Opt-in cloud transcription — [strategy](cloud/README.md), [the endpoint explained + API design](cloud/ARCHITECTURE.md), [infra phases & scaling](cloud/INFRA_AND_SCALING.md), [unit economics](cloud/COSTS.md), [serving stack: what's overkill when](cloud/SERVING_STACK.md) |

## 📣 Go-to-market, research, competition
| Doc | What |
|---|---|
| [GTM.md](GTM.md) | Go-to-market plan (+ privacy-safe feedback architecture) |
| [MARKET_STUDY.md](MARKET_STUDY.md) | Deep voice-AI market study |
| [ICP.md](ICP.md) | Ideal customer profiles — B2C, B2B, B2G, platform/OEM, anti-ICP |
| [MONETIZATION.md](MONETIZATION.md) | Every monetization model, comparables, pricing, the plan |
| [MODEL_RESEARCH.md](MODEL_RESEARCH.md) | Model landscape & selection research |
| [FINETUNING.md](FINETUNING.md) | Fine-tuning deep-dive (when/how/cost/data) |
| [LAUNCH.md](LAUNCH.md) | Launch/distribution plan |
| [competitors/](competitors/) | Standalone deep-dives per competitor across all layers + [PATTERNS.md](competitors/PATTERNS.md) synthesis |

## 🎯 Strategy log & founder-decision docs
| Doc | What |
|---|---|
| [STRATEGY.md](STRATEGY.md) | **Dated strategy log** (newest entry first) — positioning, venture-scale reassessment, expansion, funding |
| [PRODUCT_MARKET_FIT.md](PRODUCT_MARKET_FIT.md) | First-principles PMF: the beachhead, the MVP, measuring PMF under no-telemetry, the decision scorecard |
| [PRACTICAL_OUTCOME_REALITY.md](PRACTICAL_OUTCOME_REALITY.md) | Honest odds of getting rich, job-vs-startup, the hedge + quit-trigger |
| [YC_CREDITS_PLAN.md](YC_CREDITS_PLAN.md) | How to burn the startup credits into permanent model/data assets |

---

**Reading order suggestions:**
- *New here / want to use it:* [SETUP_GUIDE](SETUP_GUIDE.md) → [USAGE](USAGE.md).
- *Understand the build:* [genesis/plan.md](genesis/plan.md) → [SYSTEM_DESIGN](SYSTEM_DESIGN.md) → [BUILD_LOG](BUILD_LOG.md).
- *Understand the strategy:* [STRATEGY](STRATEGY.md) → [PRODUCT_MARKET_FIT](PRODUCT_MARKET_FIT.md) → [ICP](ICP.md) → [competitors/PATTERNS](competitors/PATTERNS.md) → [PRACTICAL_OUTCOME_REALITY](PRACTICAL_OUTCOME_REALITY.md).
