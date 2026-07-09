# Cloud Infra & Scaling — phase-wise

One container image (see [ARCHITECTURE.md](ARCHITECTURE.md)) deployed three ways as
volume grows. Never skip a phase upward; each phase is ~a weekend of work from the
previous one.

## Phase 0 — plumbing prototype (1 week, ~$0)

Point `CloudEngine` at **Groq's hosted whisper-large-v3-turbo** (~$0.04/audio-hour)
just to build and test the app-side plumbing: consent sheet, Opus upload, fallback,
timeouts. **Never ships to users** (stock Whisper's Hinglish is worse than our local
Apex — shipping it would make cloud mode an anti-demo). Kill it as soon as Phase 1 works.

## Phase 1 — LAUNCH: serverless GPU running OUR model

**Platform: RunPod Serverless (or Modal — try both, they're a day each).**
Deploy the container; the platform gives you an HTTPS URL; you pay **per second of
GPU time, ₹0 when idle** (scale-to-zero).

- GPU: **NVIDIA L4** (~$0.84/hr ⇒ $0.000233/sec on RunPod). Apex fp16 ≈ 1.6–3 GB
  VRAM — an L4 (24 GB) holds it with huge batching headroom.
- Cold starts: RunPod FlashBoot is often sub-second, but budget for occasional 3–10 s
  warmups → the API's `503 warming` response + app-side "first cloud dictation of
  the day may take a few seconds" toast. Keep 1 worker floor-warm during Indian
  daytime once there are >100 cloud users (~$5/day) to erase cold starts when it matters.
- The auth/quota gateway (FastAPI + Redis) is too light to need a GPU — run it on a
  $5–10/mo VPS or a free-tier small instance; it proxies validated requests to the
  serverless URL.

**Why serverless first:** dictation traffic is *bursty* (seconds of GPU per request,
long gaps, deep night troughs). Paying per-second matches the load shape exactly;
an always-on GPU at launch volume would idle >95% of the time.

## Phase 2 — SCALE: own instances on AWS Mumbai (burn the YC credits)

Move when EITHER: serverless bill > ~$400/mo sustained, OR cold-start complaints
persist, OR we want the [YC credits](../YC_CREDITS_PLAN.md) ($10k AWS + $10k Azure)
paying for it.

- Instance: **g6.xlarge (1× L4, ~$0.80/hr on-demand ≈ $580/mo; ~60% off on 1-yr
  savings plan or spot)** in **ap-south-1 (Mumbai)** — user latency matters and
  L4s have decent Mumbai availability (verify quota early; new accounts start at 0
  GPU quota — file the increase request week 1, it takes days).
- Topology: ALB → auto-scaling group of g6.xlarge workers (same container) +
  1 small always-on box for the gateway/Redis. Scale policy on GPU-seconds-per-
  minute or queue depth; min 1 / max N.
- Cheap trick while small: **1 reserved g6.xlarge (base load) + serverless RunPod as
  the overflow valve** — hybrid gives fixed low cost AND burst absorption.
- Azure credits: mirror the container to an NC-series VM as DR / A-B region later;
  don't run two clouds for fun.

## Phase 3 — only if the developer-API business takes off

Multi-region (Mumbai + Singapore/Frankfurt), streaming websockets, dedicated
capacity, an SRE hire. Out of scope now; noted so we don't architect against it
(stateless design already permits it).

## The scaling math (why this is comfortably cheap)

Throughput of ONE L4 running turbo-class faster-whisper, batch mode: **30–40×
realtime**, dozens of concurrent streams (INT8 turbo ≈ 1.6 GB VRAM leaves room for
large batches).

Demand model (dictation is tiny audio volumes — this is the key intuition):
- Average active cloud user: ~40 audio-min/month (heavy: 150).
- 10,000 cloud users ⇒ ~400k audio-min/mo ⇒ at 30× realtime ⇒ ~222 GPU-hours/mo
  ⇒ **~0.3 L4s of average load**. One g6.xlarge carries 10k users with headroom.
- What actually sizes the fleet is **peak concurrency**, not volume: 10k users,
  Indian-workday peak, ~1–2% dictating in any second ⇒ 100–200 concurrent
  streams ⇒ 2–4 L4s at peak with batching ⇒ autoscale 1→4. Off-peak: back to 1
  (or 0 on serverless).

Rule of thumb to remember: **one L4 ≈ one lakh casual users' average load is false —
but one L4 ≈ 10–30k users' average load is right; peaks cost 2–4×.**

## Ops you must actually set up (the minimum, not the MLOps fantasy)

1. `/healthz` + UptimeRobot (free) → phone alert.
2. Structured request logs (no content!) → CloudWatch/Grafana Cloud free tier:
   p50/p95 latency, error rate, GPU-seconds/day, quota-denials/day.
3. A daily cost alarm: "if today's spend > 3× trailing average, email me."
4. One dashboard number that predicts the bill: **GPU-seconds per audio-minute**
   (efficiency). If it drifts up, batching broke.
5. Load test before launch: replay 200 concurrent fixture clips (locust/k6), verify
   p95 < 2 s and zero 5xx. This is the whole "distributed systems" course you need
   for v1 — the [learning roadmap](../../app/dist/DesiDictation-Learning-Roadmap.pdf)
   Phase 4 covers the rest when Phase 2 arrives.

## Failure modes & answers

| Failure | Blast radius | Answer |
|---|---|---|
| Serverless cold start storm (morning peak) | Slow first requests | Warm floor worker on IST daytime schedule |
| GPU provider outage | Cloud mode down | App auto-falls back to local model (already designed) — our outage story is *uniquely* good |
| License-key sharing / abuse | GPU bill spike | Per-key quotas + per-key concurrency cap (2) + daily anomaly alarm |
| Huge file / junk upload | Worker stall | 60 s / 2 MB hard limits at the gateway, before GPU |
| Gumroad API down | Can't validate new keys | Cache validated keys 7 days; fail-open for cached, fail-closed for unknown |
| Mumbai L4 quota denied | Phase 2 blocked | Stay on RunPod (they run Indian DCs too); or g4dn/T4 fallback (slower but fine) |
