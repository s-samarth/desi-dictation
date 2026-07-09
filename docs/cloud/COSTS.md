# Cloud Costs — unit economics

All numbers rounded, July 2026, USD (₹ at ~84). The headline: **cloud transcription
costs us roughly ₹1–8 per user per month** against Pro pricing of ₹799–1,499/yr —
gross margin on the cloud feature is ~95%+ at every scale. Cost is not the risk;
*abuse and idle GPUs* are, and both are handled in [INFRA_AND_SCALING.md](INFRA_AND_SCALING.md).

## Cost per audio-minute, by option

| Option | $/audio-min | ₹/audio-min | Notes |
|---|---|---|---|
| Groq hosted turbo (Phase 0 only) | $0.00067 | ₹0.06 | Stock Whisper — bad Hinglish, prototype only |
| Fireworks/Together hosted | ~$0.001 | ₹0.08 | Same catch |
| Deepgram Nova batch | $0.0036 | ₹0.30 | Different model family entirely |
| OpenAI whisper-1 | $0.006 | ₹0.50 | The expensive baseline everyone quotes |
| **RunPod serverless L4, our model** | **~$0.0005–0.001** | **₹0.04–0.08** | $0.84/hr ÷ 30× realtime + overhead/cold starts |
| **Own g6.xlarge @ 30% utilization** | **~$0.0015** | **₹0.13** | $580/mo ÷ 400k min; falls as utilization rises |
| Own g6.xlarge @ 70% utilization | ~$0.0006 | ₹0.05 | Scale economics kick in |

Takeaway: hosting **our own model** serverlessly is *already as cheap as the cheapest
stock API* — because dictation audio is short and turbo-class models are fast. There is
no cost argument for Option A, and the quality argument is against it.

## Cost per user per month

Usage assumptions (dictation ≠ meeting transcription — bursts, not hours):
light 10 min/mo · average 40 min/mo · heavy 150 min/mo · abusive cap 600 min/mo.

| User type | Serverless (₹/mo) | Own-instance @scale (₹/mo) |
|---|---|---|
| Light | ₹0.4–0.8 | ₹0.5 |
| Average | ₹1.6–3.2 | ₹2 |
| Heavy | ₹6–12 | ₹7.5 |
| At the 600-min cap | ₹24–48 | ₹30 |

Versus revenue: Pro at ₹999/yr ≈ ₹83/mo → an *average* cloud user costs ~2–4% of
revenue; even a capped heavy user costs ~35–55% — which is why the fair-use cap
exists. The free 30-min/mo taste costs ≤ ₹2.4/user/mo — cheap CAC for exactly the
low-end-device users who can't otherwise experience the product.

## Monthly bill scenarios (total infra)

Includes GPU + gateway VPS ($10) + bandwidth (Opus is tiny — ~1 GB per 3,300 audio-min).

| Scale | Cloud users | Audio min/mo | Phase | Est. bill/mo |
|---|---|---|---|---|
| Beta | 100 | 4k | 1 (serverless) | **$15–25** (~₹1.5–2k) |
| Early | 1,000 | 40k | 1 (+warm floor worker IST-daytime ~$150) | **$60–200** (~₹5–17k) |
| Growth | 10,000 | 400k | 2 (1 reserved g6 + burst) | **$450–800** (~₹38–67k) |
| Big | 50,000 | 2M | 2 (3–5 L4 ASG) | **$1.5–3k** (~₹1.3–2.5L) |

With **YC credits** ($10k AWS): Phase 2 runs free for ~1–1.5 years at Growth scale.
That's the correct use of the credits — funding a *revenue-generating* endpoint, not
experiments (consistent with [YC_CREDITS_PLAN.md](../YC_CREDITS_PLAN.md): credits →
permanent assets; here the asset is the serving stack + margin history for fundraising).

## Sensitivity — what changes these numbers

1. **Realtime factor** (30× assumed): if our fine-tune runs slower (e.g. full large-v3
   at 8×), costs ×3–4. Turbo-class architecture for the cloud model is a *cost*
   decision, not just a latency one.
2. **Utilization** (own-instance only): the ₹/min triples below ~15% utilization.
   Hence: don't leave Phase 1 early; serverless *is* 100% utilization by definition.
3. **Streaming (v2)**: continuous decode ⇒ 3–5× GPU-seconds per audio-min ⇒ treat as
   a separate paid feature when it comes, never bundled silently.
4. **Free-tier abuse**: 30 min × many throwaway keys — mitigated by device-bound trial
   keys and per-key concurrency caps; watch the quota-denial metric.

## The pricing implication (feeds MONETIZATION.md)

- Cloud mode belongs in **Pro** (₹799–1,499/yr) with the 600-min fair-use cap —
  costs ≤5% of revenue for typical users.
- A **cloud-only cheap tier** becomes possible for low-end Android (₹49–99/mo,
  no local model at all — their phone can't run it anyway): COGS ~₹2–12/mo →
  ~85–95% margin, and it monetizes the largest Indian device segment which the
  on-device product physically cannot serve. This is the most interesting new
  revenue door cloud opens; decide after Android ships.
