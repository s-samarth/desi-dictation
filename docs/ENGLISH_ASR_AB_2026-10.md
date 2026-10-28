# English A/B — Parakeet v3 vs the challengers (2026-10-28)

Follow-up to [ENGLISH_ASR_SCOUT_2026-10.md](ENGLISH_ASR_SCOUT_2026-10.md). The
user asked to test every candidate that looked tempting there, on English only,
and to focus on Indian accents. Nothing shipped changes from this doc.

## Setup

- **Clips:** the quick tier of the `english` suite: 55 clips of Indian English
  (Svarah, SD-QA North and South, EdAcc, SVQ en_in) plus a US control.
  **Noisy** is the same 55 clips with pink noise at 5 dB SNR, deterministic per
  file, the same condition as the 2026-09-22 Redux test.
- **Scoring:** the repo's own `evals/metrics.py` and `report.py` (nWER).
  **Paired** counts compare each clip against shipping Parakeet: the number of
  clips where the candidate was better or worse.
- **Runtimes:** the best one available on this Mac for each model, all in a
  scratch dir, with nothing installed into the app:
  - **Shipping engine** (`desi-cli` → whisper.cpp): Parakeet v3, Turbo, and
    Parakeet v2, which was converted with whisper.cpp's own
    `convert-parakeet-to-ggml.py`.
  - **MLX** (`mlx-audio` 0.6.2, 8-bit weights, Metal): Qwen3-ASR.
  - **NeMo 3.0.0** (NVIDIA's reference, CPU): the two unified models.
- **Calibration**, the same Parakeet v3 through each runtime: shipping 14.9 %,
  NeMo 14.8 %, MLX 15.6 %. The runtimes agree within ~1 point, and our q4_k
  build loses nothing against NVIDIA's reference.
- **Latency:** shipping-engine and MLX numbers are real Metal per-clip latency
  with the model resident. NeMo ran on CPU in PyTorch, so its timings say
  nothing about Metal. MLX ran v3 at the same 0.14 s median as our engine.

## Results

The **≤ 35 s** columns leave out the 4 clips of 45–110 s. The app never
decodes those in one call (it chunks at 25–35 s), so these columns match real
dictations best.

| Model | Size | All clean | All noisy | ≤ 35 s clean | ≤ 35 s noisy | Paired clean (better/worse) | Median per clip |
|---|---|---|---|---|---|---|---|
| **Parakeet v3 q4_k (shipping)** | 0.6B, 416 MB | 14.9 % | **20.4 %** | 10.7 % | 14.5 % | — | **0.14 s** |
| Whisper large-v3-turbo q5_0 (shipping fallback) | 0.8B, 574 MB | 16.4 % | 33.0 % | 11.0 % | 18.5 % | 15 / 19 | 1.44 s |
| Parakeet v2 q5_0 (English-only) | 0.6B, 427 MB | 16.9 % | 21.4 % | 12.4 % | 15.3 % | 8 / 19 | 0.13 s |
| **Qwen3-ASR-1.7B** (MLX 8-bit) | 2B | **13.2 %** | 22.0 % | **8.9 %** | 15.2 % | **19 / 9** | 0.64 s |
| Qwen3-ASR-0.6B (MLX 8-bit) | 0.9B | 15.3 % | 25.1 % | 10.7 % | 16.4 % | 14 / 15 | 0.25 s |
| **Parakeet unified-EN 0.6B** (NeMo, CPU) | 0.6B | 17.8 % | 24.2 % | 10.1 % | **13.4 %** | 11 / 12 | (CPU) |
| Nemotron-labs unified 0.6B (NeMo, CPU) | 0.6B | 16.5 % | 22.7 % | 10.9 % | 17.4 % | 8 / 10 | (CPU) |
| Cohere Transcribe 03-2026 | 2B | — | — | — | — | — | not run (gated) |

Noisy paired counts against v3: Qwen3-ASR-1.7B 16 / 15, unified-EN 14 / 14,
v2 10 / 14, Turbo 13 / 25, Qwen3-ASR-0.6B 13 / 24, Nemotron-labs 8 / 17.

Peak memory: Qwen3-ASR-1.7B at 8-bit reached 4.3 GB of MLX memory, and 0.6B
reached 2.8 GB. Parakeet v3 in our engine peaks around 0.7 GB (2026-09-22).
Note that MLX's own Parakeet run also reported 4.1 GB, so MLX peaks include
caches and aren't a like-for-like footprint.

## What it means

1. **Parakeet v3 stays the default.** No challenger beats it on both clean and
   noisy speech at its speed. That includes NVIDIA's newer models.
2. **Qwen3-ASR-1.7B is the accuracy winner on clean Indian English.** Its
   errors are 11 % lower than Parakeet's on everything, and 17 % lower on
   dictation-length clips. It is better on 19 clips and worse on 9. The costs:
   - it is ~4.5× slower (0.64 s median, 1.95 s p90);
   - it holds ~2B parameters in memory;
   - in noise it is no better than Parakeet (16 better / 15 worse). The
     aggregate is worse, because a few EdAcc clips fell apart.

   That makes it a fit for an opt-in **"Accurate English"** mode for quiet
   rooms, not for the default.
3. **Parakeet unified-EN is the interesting same-size model.** On
   dictation-length clips it beat v3 clean (10.1 vs 10.7) and noisy (13.4 vs
   14.5), and it adds streaming. On 45–110 s clips it collapsed (27 % vs 20 %),
   but the app never feeds it those. Per clip it is still a tie (11 / 12). It
   needs an RNNT decode path, which `libparakeet` doesn't have.
4. **Rejected on our clips:**
   - **Parakeet v2:** worse than v3 on clean and noisy speech, despite its
     leaderboard edge.
   - **Qwen3-ASR-0.6B:** no better clean, much worse noisy.
   - **Nemotron-labs unified:** worse clean and noisy.
   - **Turbo:** 33 % in noise. This also confirms v3 over Turbo as the default.
5. **Our suite and the leaderboard disagree on v2 and Nemotron-labs.** That is
   the reason we measure on our own clips.

## Caveats

- 55 clips (51 ≤ 35 s) is a quick tier. Differences of about 1 point are
  within noise. The two leads worth confirming, Qwen3-ASR-1.7B and unified-EN,
  should go on the full `english` tier (278 clips) before any engine work.
  That run needs the user's OK (CLAUDE.md rule 8).
- Unified-EN and Nemotron-labs were scored in NeMo's offline mode. Their
  streaming modes would be less accurate (NVIDIA's cards: +0.2 to +2.5 points).
- NeMo 3.0.0 prints an OpenTelemetry line ("no exporters… no telemetry data
  will be collected"). It sent nothing, but it would need auditing before any
  NeMo code went near the app.
- **Cohere Transcribe was not run.** The repo is gated, and accepting
  Cohere's terms on Hugging Face is the user's decision.

## How to reproduce

The scripts live outside the repo (scratchpad), and BUILD_LOG FM#33 records
the two traps. The steps:

1. Convert v2 with
   `vendor/whisper.cpp/models/convert-parakeet-to-ggml.py --model … --out-dir …`.
2. Quantize it with `parakeet-quantize … q5_0`. Use q5_0, **not q4_k** (FM#33).
3. Run the converted models with `desi-cli <model> --batch <dir> english`.
4. Run the others through `mlx_audio.stt.utils.load(...).generate(audio, language="English")`
   or NeMo's `ASRModel.restore_from(...).transcribe(...)`.
5. Score every output through `report.summarize` / `report.breakdown`.
