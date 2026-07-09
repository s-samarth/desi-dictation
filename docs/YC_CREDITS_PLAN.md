# Cloud & API Credits — Burn Plan (private)

> Written 2026-07-09. How to spend the startup credits from YC Startup School (and stack more) to buy **speed, traction, and a higher-quality product** — and specifically to reduce dependence on fundraising by converting *expiring credits into permanent assets*. Gitignored. Companion to STRATEGY.md (Entry 002 — this is the concrete funding of the "own the model + data" and "small-LLM layer" plays) and PRODUCT_MARKET_FIT.md.

---

## 0 · Inventory (verify exact expiries — they differ, act on the soonest)

| Credit | Amount | Best-for | Typical expiry* |
|---|---|---|---|
| **AWS** | $10,000 | GPU training, storage, data pipeline, hosting | ~1–2 yrs (Activate) |
| **Azure** | $10,000 | GPU training, managed ML, storage | ~1 yr |
| **OpenAI** | $2,500 | Synthetic data, labeling, distillation teacher, dev | often 3–12 mo — likely **soonest** |
| **Anthropic** | $500 | Claude Code (dev speed), data normalization, judging | 3–12 mo |
| **Fireworks** | $500 | Cheap/fast open-model bulk inference (synthetic data) | varies |
| **Total** | **≈ $23,500 (~₹20L)** | | |
| **+ friend's identical set** | **≈ $47,000 combined (~₹40L)** | | |

*\*Verify each program's real expiry the day you read this and put the dates in a calendar. The LLM-API credits (OpenAI/Anthropic/Fireworks) almost always expire first and are the highest-leverage — spend those earliest.*

**First action, today:** log into each console, record exact expiry + balance, set billing alerts (so you never spend *past* the credit into your own card by accident), and — for AWS/Azure — **request GPU quota now** (§4, it has weeks of lead time).

---

## 1 · The thesis: burn compute to mint IP

STRATEGY.md Entry 002 said the two things that would make this venture-scale — **owning your own model** and **the small-LLM workflow layer** — need capital, mostly for *data + training*. **These credits are exactly that capital, for free.** So the governing principle:

> **Spend expiring credits to create permanent, fundraising-reducing assets: (1) your own fine-tuned models (ASR + small on-device LLM), and (2) a proprietary convention-normalized Hinglish dataset. Both outlive the credits. Both raise the defensibility score. Everything else (dev speed, evals) is bonus.**

The trap to avoid (stated up front because it's the easy mistake): **do NOT use credits to stand up cloud *product* infrastructure.** Your product is on-device — its whole moat is that it runs nothing in the cloud. If you build a service that *depends* on cloud GPU, the day credits expire you inherit a bill you didn't want and a brand contradiction. Credits are for **making things (models, data) and going faster (dev)** — not for **running things** you'll have to keep paying for. Mint assets; don't rent a habit.

---

## 2 · The single highest-leverage play — the data→distillation→model flywheel

This one play uses *every* credit pool and produces *both* durable assets. It is where the majority of the value is.

1. **Generate & clean the dataset with LLM-API credits** (OpenAI/Anthropic/Fireworks, ~$3.5k):
   - Use frontier LLMs to **normalize** existing open Hinglish/Hindi transcripts to your P1 spelling **convention** (the tedious human-scale job — automate it).
   - **Transliterate** Devanagari corpora → convention-Roman Hinglish to create paired training text.
   - **Generate** synthetic convention-Hinglish sentences (slang-dense, profanity, code-switch-heavy, domain-realistic) for the tail P2/P3 can't cover.
   - **Label/verify** with LLM-as-judge; flag low-confidence for human review.
   - Fireworks specifically: cheap fast open-model inference for **bulk** generation (10–100× cheaper per token than GPT for the volume passes).
2. **Turn text into audio** with TTS (a slice of AWS/Azure or the API budget): synthesize the new-vocabulary sentences to create paired audio+transcript (P3-S4), mixed at a small % with real audio.
3. **Train your own models with AWS/Azure GPU credits** (~$20k, but you'll use far less):
   - **ASR fine-tune** (P1-S4): Whisper/IndicWhisper/Apex base → your convention-normalized dataset → *your* Hinglish model. Cost: ~$400–1,200/run (§4) — you can afford *dozens* of experimental runs.
   - **Small on-device LLM** (rung-2 workflow layer): LoRA-fine-tune a 1–3B (Qwen/Gemma) for Hinglish→English, structuring, tone — **distilled from the frontier LLM's outputs** (use GPT/Claude as the *teacher* generating gold translations/structurings; your small model learns to imitate them). This is how the on-device workflow layer gets *good* cheaply.
4. **Export the assets before credits die**: push trained GGUFs to HF, archive the dataset locally + cloud storage you control. The models and data are yours forever; the credits were just the forge.

**Why this is the play:** it directly executes P1 (the existential problem), builds the ARPU/moat layer (rung 2), removes the Oriserve single-supplier dependency, *and* creates a proprietary dataset no competitor has — all funded by money that would otherwise evaporate. It converts "app on someone else's model" into "our own SOTA-for-niche models + our own data." That is the highest-value thing you can do with a year and $23.5k of free compute.

---

## 3 · Per-credit-pool playbook

### AWS $10k + Azure $10k (≈$20k compute/storage) — the training + pipeline budget
- **ASR fine-tuning runs** (the core IP) — the main spend, and it's cheap per run.
- **Small-LLM LoRA training** for the workflow layer.
- **Large eval sweeps** — run the full evals/ suite across many model candidates/checkpoints in parallel (embarrassingly parallel, credit-friendly).
- **Synthetic-audio TTS generation** at scale for P3 data.
- **Object storage** (S3 / Blob) for datasets, checkpoints, audio — cheap, and where a lot of the "always-on" credit naturally goes; fine, it's an asset store.
- **Managed training** (SageMaker / Azure ML) — lowers ops burden for a solo/small team; sometimes has different GPU availability than raw EC2/VM (§4).
- **P3 data-donation endpoint** (receive-only, tiny) — the one legitimate always-on service, cheap, and it feeds the flywheel.
- **Split by strength:** Azure's startup GPU story (ND-series) and AWS's storage/SageMaker are both fine; run *different* experiments on each to parallelize and to hedge quota availability. Don't try to move data back and forth constantly (egress isn't free even on credits — keep each workload within one cloud).

### OpenAI $2,500 + Anthropic $500 + Fireworks $500 (≈$3.5k API) — the data + dev budget (spend first, expires first)
- **Synthetic data generation + convention normalization + transliteration + labeling** (the §2 flywheel input) — the single best use of API credits; it creates the dataset that the GPU credits then train on.
- **Distillation teacher outputs** — GPT/Claude generate gold Hinglish→English translations and structured docs; your small on-device LLM learns from them. This is how you get the Pro-tier quality on-device.
- **LLM-as-judge evals** — score translation/structuring adequacy at scale (TRANSCRIBE_TRANSLATE rubric) instead of hand-rating everything.
- **Dev productivity** — Anthropic credits into **Claude Code** to accelerate the actual build (this repo). Direct speed. (You're already doing this; the credits subsidize it.)
- **Prompt/template engineering** — build and A/B the styling/tone/structuring prompt packs that ship in the app.
- **Fireworks = the volume workhorse** — when you need to generate *millions* of tokens of synthetic Hinglish cheaply/fast, Fireworks-hosted open models beat GPT on $/token; use it for bulk, use GPT/Claude for the highest-quality teacher passes.

---

## 4 · The GPU-availability reality (you were right to flag it)

Verified July 2026: high-end GPU is genuinely capacity-constrained, and this shapes the plan.

- **A100/H100 remain in persistent shortage**; AWS *raised* GPU reservation prices again (P5/H100 ~$5.19/GPU-hr July 2026). Securing top-end capacity often needs quotas or reservations.
- **Azure starts every subscription at *zero* GPU quota per region** — you must request an increase before launching a single GPU VM; common series approve in days, **ND H100 v5 in popular regions can take 1–4 weeks.**
- **Most-available instances are the smaller ones** — T4/L4 (AWS/GCP), A10 (Azure).

**What this means for us — and it's mostly fine, because ASR fine-tuning is not LLM pretraining:**
1. **Request quota NOW** (today), in multiple regions, for the GPUs you'll actually use — the lead time is the real risk, not the credits.
2. **You don't need H100s.** Fine-tuning Whisper-large (~800M–1.5B params) runs fine on a **single A100, or even A10/L4 with more wall-clock**. Target the *available* mid-tier GPUs; you trade a few hours of runtime, not model quality. Same for LoRA on a 1–3B LLM.
3. **Use less-contended regions** and managed training (SageMaker/Azure ML sometimes schedules capacity raw VMs can't get).
4. **Hedge with own money where it's cheap:** if cloud high-end is booked when you need a burst, dedicated GPU clouds (Lambda/Runpod/Modal) rent **H100 at ~$1.5–2/hr** — an entire serious fine-tune is $400–1,200, so even *paying out of pocket* for training is trivially affordable. Reserve AWS/Azure credits for storage, data pipeline, managed services, and available-GPU training; spend a little cash on a dedicated cloud only if you hit a capacity wall on a deadline. (Note: you generally **cannot** spend AWS/Azure credits on third-party GPU clouds — plan around that.)
5. **Bottom line:** availability is a scheduling annoyance, not a blocker, *because our models are small.* The credits' value is real; just don't architect around scarce H100s you don't need.

Sources: [AWS GPU reservation price hike July 2026 (BigGo)](https://finance.biggo.com/news/bb770b7e-aca0-4f4b-b576-765e13e1e017), [Azure GPU quota starts at zero (Microsoft Q&A)](https://learn.microsoft.com/en-us/answers/questions/5538289/), [H100 rental prices across clouds (IntuitionLabs)](https://intuitionlabs.ai/articles/h100-rental-prices-cloud-comparison), [GPU price report 2026 (Cast AI)](https://cast.ai/reports/gpu-price-report/).

---

## 5 · Stack more credits (you're applying to incubators — this is a big lever)

The YC Startup School credits are a *starter*. The major startup programs stack, and together they dwarf what you have — but most require you to be **incorporated** (a registered company). Incorporating is the key that unlocks the bigger vault:

- **Microsoft for Startups Founders Hub** — up to ~**$150k Azure** + OpenAI/Anthropic model access, low barrier to enter. The single biggest easy win.
- **AWS Activate** — up to ~**$100k** (tiered; more via accelerators/VCs).
- **Google for Startups Cloud Program** — up to ~**$200k+** GCP (AI-heavy startups get the top tier).
- **NVIDIA Inception** — **most relevant to us**: GPU/compute credits + discounts, DGX Cloud access, technical support, and eval/hardware help for AI startups. Apply.
- **OpenAI / Anthropic startup programs** — larger API allotments than the Startup-School grants.
- **Hugging Face** (Enterprise/compute credits), **Modal / Lambda / Runpod** startup credits, **Together/Fireworks** startup tiers — GPU + inference.
- Ancillary: GitHub, Notion, Linear, Vercel, etc. (dev-tool credits — small but free).

**Action:** incorporate (even a lean entity) to unlock Founders Hub + Activate + NVIDIA Inception; apply to all of the above; each incubator you get into typically adds another tranche. Realistically this can turn ~$23.5k into **$200k–500k+** of stacked compute over the next year — genuinely enough to build the model layer *without* a priced round. That's the "credits reduce fundraising need" thesis at full strength.

---

## 6 · Combining with your friend's credits

- If your friend **joins the venture** (co-founder / same company), both credit sets legitimately serve one roadmap — effectively doubling everything to ~$47k, and each of you can incorporate-and-stack (§5) for even more. Cleanest path.
- If separate: you can still **parallelize** — run non-overlapping experiments on each account (e.g., you do the ASR fine-tune on your AWS, he runs the small-LLM distillation on his Azure) to cover more ground before expiry. But **don't try to pool/transfer credits across unrelated accounts** — provider ToS forbids credit sharing across entities and can claw back for abuse. Coordinate *work*, not *balances*.
- Either way: **two YC-Startup-School alumni is also a credit-stacking multiplier** — two shots at every incubator program in §5.

---

## 7 · The burn schedule (sequenced against expiry)

| When | Do | Credits used |
|---|---|---|
| **Now (week 0)** | Record expiries + balances; set billing alerts; **request GPU quotas** (multi-region); incorporate; start incubator applications (§5) | — |
| **Week 0–6** | Build the dataset: normalize/transliterate/generate + label the convention corpus (the flywheel input). Stand up storage. Start distillation-teacher generation. | OpenAI/Anthropic/Fireworks (spend the soon-expiring API credits **first**) |
| **Week 3–12** | First ASR fine-tune experiments; small-LLM LoRA/distillation for the workflow layer; eval sweeps | AWS/Azure GPU + storage |
| **Week 6–20** | Synthetic-audio TTS data; iterate models against evals; personal-eval + convention eval as the gate | AWS/Azure + a little API |
| **Throughout** | Claude Code for the build; prompt-pack engineering | Anthropic/OpenAI |
| **Before each expiry** | **Export durable assets**: push trained GGUFs to HF, archive datasets to storage you control. The models/data must outlive the credits. | — |

**Rule:** spend the *shortest-expiry, highest-leverage* credits first (LLM APIs → dataset), because the dataset is the input to everything else. Don't leave the API credits unspent while doing GPU work — the order is data *then* training.

---

## 8 · Watch-outs

- **Expiry management** is the #1 way to waste this — calendar every date; the API credits will lapse first.
- **Quota lead time** (Azure 1–4 weeks for top GPUs) — request before you need it.
- **Don't build cloud lock-in** — credits fund *asset creation + dev speed*, never a production dependency your on-device product can't afford post-credits (repeat of §1, because it's the expensive mistake).
- **Don't let free compute pull you off-strategy** — credits make it tempting to over-build (train 5 models, chase 10 languages) before PMF. Discipline: the credits serve the PMF-critical work (P1 quality, the wedge, the workflow layer), not a science-fair. PRODUCT_MARKET_FIT.md still governs *what's worth building*; credits only change *how cheaply you can build it*.
- **Egress/idle burn** — turn off idle GPU instances (they drain credits fast); mind cross-region/cross-cloud data-transfer costs even on credits.
- **ToS on multi-account** — coordinate work, don't pool balances (§6).

---

## 9 · One-paragraph summary

You have ~$23.5k (₹20L) of expiring credits, ~$47k with your friend, and a path to $200k–500k+ by incorporating and stacking incubator programs (Microsoft Founders Hub, AWS Activate, NVIDIA Inception, Google, OpenAI/Anthropic startup tiers). **Spend them to mint two permanent assets: your own fine-tuned models (ASR + small on-device LLM) and a proprietary convention-normalized Hinglish dataset** — via the flywheel where LLM-API credits generate/clean the data and GPU credits train the models on it. Spend the short-expiry API credits first (they make the dataset), then the GPU credits (they make the models), export everything to storage you own before expiry, and never build a cloud dependency your on-device product can't sustain. Done right, this year of free compute funds the exact capital-intensive work that would otherwise force an early raise — letting you bootstrap through PMF and raise later, from strength, on your terms.
