# Serving stack — what's production-grade, what's overkill, when to migrate

Decision record, 2026-07-14. Question asked: "do we need vLLM/SGLang or some
production serving stack to serve this well?" Short answer: **not for the
demo, and when production arrives the big swap is on the ASR side
(faster-whisper), not the LLM side.**

## The framing that decides everything

The workload is two very different engines:

1. **ASR (whisper/Apex)** — every request hits this. This is the product.
2. **LLM refine (gemma3:4b)** — optional post-processing, a minority of
   requests, tiny model.

vLLM and SGLang are **LLM** serving engines — they do nothing for whisper. A
perfect vLLM setup would optimize the smaller half of the traffic. The
production tech that matters here is whisper serving with **dynamic
batching**: faster-whisper (CTranslate2) — already the plan in
[ARCHITECTURE.md](ARCHITECTURE.md) — runs turbo-class models at 30–40×
realtime on one L4 and lets dozens of users share a GPU. whisper.cpp stays
the *client* engine (Mac app); CT2 becomes the *server* engine.

## Layer by layer

| Layer | Demo (now) | Production | Verdict |
|---|---|---|---|
| ASR serving | whisper.cpp server | **faster-whisper / CTranslate2** (dynamic batching) | The one migration that matters. Do it at cloud Phase 1, not before. |
| LLM serving | Ollama | **vLLM** — only if LLM features ship in the cloud path with real concurrency | Overkill today. Ollama serializes, but demo traffic never queues. |
| Gateway | FastAPI + uvicorn | Same, + Redis for quota/auth | Production-grade as-is. Never needs replacing. |
| TLS / front door | Caddy or Cloudflare tunnel | Same (ALB at Phase 2) | Done. |
| Packaging | processes + systemd | **One Docker image** (the cloud-docs plan) | Adopt at production; optional for the demo. |
| Job queue (Celery/Redis workers) | — | — | **Overkill at every phase.** Requests are synchronous + stateless; batching lives inside the serving engine. |
| Kubernetes | — | — | **Overkill.** Serverless GPU (RunPod/Modal) then an ASG covers Phases 1–2. |
| Triton / TensorRT-LLM | — | — | **Overkill** — last-20% tooling for teams with an infra hire. |
| Observability | server logs | /healthz + UptimeRobot + no-content logs + cost alarm ([INFRA_AND_SCALING.md](INFRA_AND_SCALING.md)) | The minimal set is genuinely enough. |
| Load testing | — | locust/k6, ~200 concurrent fixture clips pre-launch | Cheap, worth it, already planned. |

## vLLM vs SGLang, specifically

**What they buy:** continuous batching (concurrent generations share the GPU
instead of queueing), paged KV-cache, and **prefix caching** — relevant
someday, because our prompts are a long fixed system prompt + few-shots with
only the user's sentence changing (SGLang RadixAttention / vLLM automatic
prefix caching skip recomputing that prefix).

**What they cost:** heavy CUDA dependency tree, multi-GB images, slower cold
starts (bad for scale-to-zero serverless), and differently-sourced/quantized
models — re-validating exact behavior we pinned against Ollama
(`think:false`, temperature, output quirks — LLM_ENGINE.md).

**Decision rule: stay on Ollama until concurrent refine requests actually
queue** (≳5–10 simultaneous LLM calls sustained). If LLM post-processing
becomes a paid cloud feature (the "v2+" second endpoint in ARCHITECTURE.md),
deploy **vLLM** at that moment — pick it over SGLang for ecosystem maturity
and RunPod/Modal templates, unless doing heavy structured-output serving
(we aren't).

## The migration story (small and known)

- **Now:** whisper.cpp + Ollama + FastAPI + Caddy/tunnel. Change nothing —
  at demo scale the UX bottleneck is model quality and network, not serving.
- **Cloud Phase 1 (serverless):** swap whisper.cpp → faster-whisper inside
  one Docker image; keep FastAPI; add Redis quota. LLM stays out of the
  cloud path.
- **Only if LLM-in-cloud takes off:** add vLLM as a second service on the
  same GPU.

Nothing in the demo stack is throwaway except the whisper.cpp *server*
binary — and that swap is one command
(`ct2-transformers-converter --model Oriserve/Whisper-Hindi2Hinglish-Apex …`)
plus re-running the eval clips against both engines to confirm identical
output conventions.
