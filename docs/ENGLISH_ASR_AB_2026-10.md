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
  - **MLX** (`mlx-audio` 0.6.2, Metal): Qwen3-ASR (8-bit) and Cohere
    Transcribe (bf16, unquantized; the user accepted its HF gate).
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
| **Cohere Transcribe 03-2026** (MLX bf16) | 2B | 15.9 % | 20.7 % | 9.1 % | **11.9 %** | 15 / 12 | 0.38 s |

Noisy paired counts against v3: Cohere 16 / 13, Qwen3-ASR-1.7B 16 / 15, unified-EN 14 / 14,
v2 10 / 14, Turbo 13 / 25, Qwen3-ASR-0.6B 13 / 24, Nemotron-labs 8 / 17.

Cohere vs Qwen3-ASR-1.7B head to head: Qwen wins clean (18 / 13), Cohere wins
noisy (19 / 14). On the read-speech Svarah clips Cohere was the best model
tested (4.1 % clean, 5.9 % noisy, vs v3's 8.6 % / 14.8 %).

Peak memory: Cohere at bf16 reached 4.6 GB of MLX memory, Qwen3-ASR-1.7B at
8-bit reached 4.3 GB, and 0.6B reached 2.8 GB. Parakeet v3 in our engine peaks around 0.7 GB (2026-09-22).
Note that MLX's own Parakeet run also reported 4.1 GB, so MLX peaks include
caches and aren't a like-for-like footprint.

## Full tier — 278 clips (supersedes the quick-tier ranking)

The user approved the full `english` tier for the three finalists, clean and
5 dB-pink-noise. The three ran in parallel, so accuracy comes from these runs
and **latency from the uncontended quick-tier runs** above. Groups: **short**
< 6 s (173 clips: xs + s), **medium** 6–35 s (89: m + l), **long** ≥ 35 s (16:
xl, which the app always chunks). "Better/worse" is per clip vs v3, with a
two-sided sign-test p.

| Group | v3 | Cohere | Qwen3-ASR-1.7B | Cohere vs v3 | Qwen vs v3 |
|---|---|---|---|---|---|
| **Clean, short** | 12.8 % | **9.2 %** | 10.2 % | −28 %, 36/16, p 0.008 | −21 %, 37/17, p 0.009 |
| Clean, medium | 10.3 % | 10.7 % | **9.0 %** | +4 %, 27/25, p 0.89 | −12 %, 38/15, p 0.002 |
| Clean, long | 18.5 % | 20.5 % | **17.0 %** | +11 %, 6/9, n.s. | −8 %, 8/7, n.s. |
| **Clean, overall** | 14.3 % | 14.6 % | **12.6 %** | +2 %, 69/50, p 0.10 | **−11 %, 83/39, p < 0.001** |
| **Noisy, short** | 22.5 % | 20.1 % | **16.2 %** | −11 %, 50/30, p 0.03 | **−28 %, 59/30, p 0.003** |
| Noisy, medium | 13.5 % | **12.4 %** | 12.9 % | −8 %, 37/25, n.s. | −5 %, 36/24, n.s. |
| Noisy, long | 23.6 % | 23.7 % | **22.8 %** | 0 %, 9/6, n.s. | −4 %, 9/5, n.s. |
| **Noisy, overall** | 19.5 % | 18.6 % | **17.7 %** | −4 %, 96/61, p 0.006 | **−9 %, 104/59, p 0.001** |

Head to head on all 278 clips, Qwen beats Cohere 70/42 clean and 80/65
noisy. Cohere's weak spot is very short noisy clips, where it scored 44.9 % on
xs vs v3's 39.1 %. That is its card's warning that it is "eager to transcribe"
non-speech. It was also worse than v3 on EdAcc conversation.

**Latency** (uncontended, median / p90 per clip):

| Group | v3 | Cohere (bf16) | Qwen (8-bit) |
|---|---|---|---|
| Short | 0.09 / 0.12 s | 0.23 / 0.29 s | 0.39 / 0.55 s |
| Medium | 0.20 / 0.43 s | 0.48 / 0.88 s | 0.94 / 1.71 s |
| Long (one call) | 1.87 / 2.65 s | 3.49 / 4.92 s | 7.10 / 10.3 s |

In the app, long dictations are chunked while the user talks, so the wait
after release is roughly the "medium" row, not the "long" one.

**Revised verdict:** the quick tier's "Cohere is best in noise" was sample
noise. Across 278 clips:
- **Qwen3-ASR-1.7B is the only model that beats v3 significantly overall**,
  both clean and noisy, and it gains most on short noisy dictations (−28 %).
- **Cohere only clearly wins on clean short clips.**

**Recommendation:** replace Turbo with **Qwen3-ASR-1.7B** as the opt-in
"Accurate English" model. It also takes `hotwords`, which the auto-vocabulary
work can feed. **Parakeet v3 stays the default**: it is 4× faster on short
dictations (0.09 s vs 0.39 s).

## What it means (quick tier — see the full-tier verdict above)

1. **Parakeet v3 stays the default.** No challenger beats it on both clean and
   noisy speech at its speed (0.14 s). That includes NVIDIA's newer models.
2. **Turbo has no job left in English.** It is less accurate than v3 in quiet
   and much worse in noise (18.5 % vs 14.5 %), at 10× the latency. The user
   uses it for English only, so its slot is free.
3. **Cohere Transcribe is the best "Accurate English" candidate.** On
   dictation-length clips:
   - it is close to Qwen in quiet (9.1 % vs 8.9 %);
   - it is the best of every model in noise: 11.9 %, 18 % fewer errors than
     v3;
   - it is ~2× faster than Qwen (0.38 s median, 0.98 s p90), even
     unquantized.

   Its all-clips number (15.9 %) is dragged down by the 45–110 s clips, which
   the app never decodes whole. It needs about 2.4 GB at 8-bit. It covers 14
   languages but not Hindi, which is fine for an English-only slot.
4. **Qwen3-ASR-1.7B is the runner-up.** It has the fewest errors in quiet
   (19 better / 9 worse than v3), but in noise it is no better than v3, and it
   is the slowest of the three (0.64 s median, 1.95 s p90). Its edge is
   `hotwords` context biasing, which could feed the Personal Dictionary.
5. **Parakeet unified-EN is the likely successor to v3 as the default.** It is
   the same size as v3 and adds streaming. On dictation-length clips it beat
   v3 in quiet (10.1 vs 10.7) and in noise (13.4 vs 14.5), but per clip it is
   a tie (11 / 12). It collapsed on 45–110 s clips. It needs an RNNT decode
   path, and its speed on Metal is unmeasured.
6. **Rejected on our clips:**
   - **Parakeet v2:** worse than v3 clean and noisy, despite its leaderboard
     edge.
   - **Qwen3-ASR-0.6B:** no better clean, much worse noisy.
   - **Nemotron-labs unified:** worse clean and noisy.
7. **Our suite and the leaderboard disagree on v2 and Nemotron-labs.** That is
   the reason we measure on our own clips.

**Suggested next steps** (not done; each needs the user's go-ahead):
1. Replace Turbo with **Cohere Transcribe** as the opt-in "Accurate English"
   model.
2. Confirm it first on the full `english` tier (278 clips) against Qwen and v3.
3. Test 8-bit Cohere for speed and size.
4. Shipping it means a third engine. The most likely runtime is
   `transcribe.cpp` (MIT, ggml + Metal, C API). It also runs Qwen3-ASR and
   unified-EN, so one integration covers all three. Building it needs the
   user's permission, and its vendored ggml must not clash with whisper.cpp's.
5. The Cohere repo is gated, so the app would download a converted copy from
   our own HF repo. Apache-2.0 allows that redistribution.

## Caveats

- 55 clips (51 ≤ 35 s) is a quick tier. Differences of about 1 point are
  within noise. The leads worth confirming, Cohere, Qwen3-ASR-1.7B and unified-EN,
  should go on the full `english` tier (278 clips) before any engine work.
  That run needs the user's OK (CLAUDE.md rule 8).
- Unified-EN and Nemotron-labs were scored in NeMo's offline mode. Their
  streaming modes would be less accurate (NVIDIA's cards: +0.2 to +2.5 points).
- NeMo 3.0.0 prints an OpenTelemetry line ("no exporters… no telemetry data
  will be collected"). It sent nothing, but it would need auditing before any
  NeMo code went near the app.
- Cohere ran unquantized (bf16) and Qwen at 8-bit. An 8-bit Cohere may be
  faster, with a small accuracy change to measure.

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
