# English ASR scout — can we beat Parakeet? (2026-10-28)

The question (the user's, paraphrased): Parakeet is fast and pretty good for
English. Is there something clearly better at the same speed? Compare against
Parakeet and large-v3-turbo.

**Answer: Parakeet v3 is already at the frontier for its speed class.** No
open model at Parakeet's size and speed is clearly more accurate. Its
English-only sibling (v2) is ~6 % better on the leaderboard's Indian-English set, and it
runs on our existing engine. The models that are clearly more accurate (~15 %)
are 2–3× bigger LLM- or encoder-decoder models that would cost several times
Parakeet's latency and memory. Two bounded A/Bs are worth running (below).
Nothing ships from this doc.

## What we ship (unchanged)

| | Parakeet TDT 0.6B v3 q4_k | Whisper large-v3-turbo q5_0 |
|---|---|---|
| Role | English default (Auto) | English fallback |
| Runtime | whisper.cpp `libparakeet` (ggml, Metal) | whisper.cpp (ggml, Metal) |
| File | 416 MB, `ggml-org/parakeet-GGUF` | 574 MB, `ggerganov/whisper.cpp` |
| License | CC-BY-4.0 | MIT |

### Measured today — quick tier, `english` suite (Indian English)

`uv run run_eval.py --suites english --models turbo parakeet`, 55 clips, M3 Air,
model resident, worktree build of b0d8a1b. This is the first turbo run on the
rebuilt Indian-English suite (FM#24); every earlier turbo number was US English.

| Model | nWER | median / p90 per clip |
|---|---|---|
| **Parakeet v3 q4_k** | **14.9 %** | **0.14 s** / 0.43 s |
| large-v3-turbo q5_0 | 16.4 % | 1.44 s / 1.62 s |

Parakeet wins on accuracy and is 10× faster. One nuance: turbo was better on
**Svarah** (read Indian English, 16 clips: 3.5 % vs 8.6 %), and Parakeet was
better on conversation and voice queries (EdAcc, SD-QA, SVQ). The samples are
small, so treat this as a hint, not a finding.

## The public numbers — Open ASR Leaderboard, 26 Oct 2026

Read from the live Space (`hf-audio/open_asr_leaderboard`). Its results dataset
is gated, so the table was taken from the Space's `/config`. **Avg** is the
11-set English short-form average. **Monsoon** is Voice Arena's *conversational
English with an Indian accent* set, the column closest to our users.
**Noisy** is URGENT24 (degraded or noisy speech, the "I spoke less clearly"
complaint). **Conv** is the private conversational average. RTFx is measured on
a datacenter GPU: use it only to rank speed within one architecture, never as
Mac latency (PERFORMANCE.md).

| Model | Params | Avg | Monsoon | Noisy | Conv | RTFx | License |
|---|---|---|---|---|---|---|---|
| **parakeet-tdt-0.6b-v3** (ours) | 0.6B | 6.18 | 4.14 | 11.52 | 13.44 | 6,132 | CC-BY-4.0 |
| whisper-large-v3-turbo (ours) | 0.8B | 7.64 | 4.77 | 13.69 | 15.40 | 794 | MIT |
| Qwen3-ASR-1.7B | 2B | **5.40** | 3.50 | 9.93 | **12.14** | 819 | Apache-2.0 |
| granite-speech-5.0-2b | 2B | 5.68 | 3.94 | 10.22 | 13.79 | 545 | Apache-2.0 |
| cohere-transcribe-03-2026 | 2B | 5.77 | 3.44 | **9.50** | 13.46 | 902 | Apache-2.0 (gated) |
| ARK-ASR-0.6B (Edge0) | 1B | 5.93 | **3.43** | 12.49 | 12.57 | 661 | Apache-2.0 |
| canary-qwen-2.5b | 2.5B | 5.94 | 3.60 | 13.02 | 13.41 | 862 | CC-BY-4.0 |
| **parakeet-tdt-0.6b-v2** (English-only) | 0.6B | 6.02 | 3.89 | 11.42 | 13.58 | 5,988 | CC-BY-4.0 |
| Qwen3-ASR-0.6B | 0.9B | 6.24 | 4.23 | 11.57 | 12.74 | 745 | Apache-2.0 |
| granite-speech-5.0-470m-turboctc | 0.5B | 6.38 | 4.75 | 11.79 | 14.03 | 21,174 | Apache-2.0 |
| nemotron-speech-streaming-en-0.6b | 0.6B | 6.60 | 4.44 | 12.54 | 13.28 | 1,111 | NVIDIA Open Model |
| distil-large-v3.5 | 0.8B | 6.76 | 3.60 | 12.42 | 14.43 | 887 | MIT |
| Phonon-2 (compressed Parakeet v3) | — | 6.87 | 4.91 | 14.90 | 14.14 | 1,967 | CC-BY-4.0 |
| canary-1b-v2 | 1B | 7.27 | 4.97 | 14.56 | 15.16 | 1,821 | CC-BY-4.0 |
| Voxtral-Mini-4B-Realtime | 4B | 8.44 | 8.86 | 17.95 | 17.45 | 103 | Apache-2.0 |

Reading it:
- **Turbo is behind Parakeet on every column**, including Indian English
  (Monsoon 4.77 vs 4.14), which agrees with our own measurement above.
- **Same size, same runtime:** Parakeet **v2** (English-only) edges v3 on
  Monsoon (3.89, −6 % relative) and Avg, ties on Noisy, and is slightly worse
  on Conv. It is the only candidate that could run in our existing
  `libparakeet` path. That makes it a small but nearly free gain, if our own
  suite agrees.
- **Qwen3-ASR-0.6B and Granite 470M** are no better than v3.
- **Clearly better on Indian English:** Cohere Transcribe and ARK-ASR (−17 %
  on Monsoon), Qwen3-ASR-1.7B (−15 %), canary-qwen and distil-v3.5 (−13 %).
  All of them have an autoregressive decoder (distil also keeps whisper's
  padded 30 s window, MODEL_RESEARCH.md §E), so each call costs several times
  what Parakeet's does. Of these, only Qwen3-ASR-1.7B and Cohere are also
  clearly better on Noisy (−14 %, −18 %).

## Per-candidate notes

| Candidate | Mac runtime that fits | Mac speed (published) | Streaming | Network / telemetry | Verdict |
|---|---|---|---|---|---|
| **Qwen3-ASR-1.7B** | MLX (`mlx-audio`, Swift `speech-swift`), CoreML ports, ggml via `transcribe.cpp` | 36× RT, 1.9 GB peak RAM at 5-bit (M5 Pro, soniqo). A CoreML port reports a 7.5 ms/s encoder and a 254 tok/s decoder on an 8 GB M3 | yes (vLLM only upstream) | none in the weights; ports download from HF | **A/B** — best accuracy we could run locally |
| **Cohere Transcribe 03-2026** | ggml via `transcribe.cpp`, MLX | none published for Mac | not stated | gated HF download | **A/B**: best Noisy score and joint-best Monsoon; about the size of large-v3 |
| Granite Speech 5.0 2B | MLX, `transcribe.cpp` | — | no | none | A/B only if the two above disappoint |
| **parakeet-tdt-0.6b-v2** | whisper.cpp `libparakeet`. The converter reads `n_vocab` from config, so v2's 1,024-token vocab should convert with only a warning (not verified). No ggml-format file is published; the `mudler/parakeet-cpp-gguf` files are parakeet.cpp's format | same as v3 | no | none | **A/B first**: no new runtime, −6 % on Monsoon. English-only, which is fine since Parakeet only serves English here |
| **nemotron-labs-unified-asr-0.6b** (released 2026-10-27) | NeMo only. RNNT decoder, which `libparakeet` (TDT) can't run; `transcribe.cpp` already runs `parakeet-unified-en` | — | yes (buffered) | none | **Watch.** Claims 4.68 vs v3's 4.93 offline on the 7-set average. Not on the board yet |
| parakeet-unified-en-0.6b (Apr 2026) | `transcribe.cpp` | — | yes | none | Claims 5.91 vs v2's 6.04. Marginal; same watch |
| Parakeet "Ultra" (FluidAudio) | CoreML / ANE | LS-clean 2.13 vs 2.27 (community post) | no | none | Unverified, vendor-only claim; watch |
| FluidAudio (Parakeet v2/v3 on ANE) | Swift package, CoreML | ~190× RT on M4 Pro | EOU 120M streaming | model download only, offline mode exists | Same model, so no accuracy gain. Our median is already 0.14 s; revisit only for battery |
| WhisperKit / Argmax | CoreML turbo | ~12× RT (M5 Pro) | yes | none (OSS) | Turbo accuracy, so it can't beat Parakeet |
| Granite 470M TurboCTC | MLX, `transcribe.cpp` | very fast (CTC) | no | none | Worse than v3; the better `-nc` variant is non-commercial |
| Moonshine v2 (streaming, ≤245M) | ONNX, `transcribe.cpp` | fast | **yes** | none | Claims Medium 6.65 on its own; not on the current board. Worse than v3 |
| Kyutai STT, Phi-4-multimodal, ARK-ASR-0.6B | MLX (Kyutai) / PyTorch remote code | — | Kyutai yes | none | Not on the current board (Kyutai, Phi-4), 5.6B (Phi-4), or PyTorch-only with custom code (ARK, despite its strong Monsoon score) |
| Phonon-2, Parakeet Redux | CoreML / PyTorch | fast | no | Redux: hostname every 60 s | Compressed Parakeets, both less accurate (Redux rejected 2026-09-22) |
| TheStageAI whisper-turbo (Avg 5.91, Monsoon 3.72) | proprietary SDK | — | — | **needs an account token and network** | Rejected: no-telemetry rule |
| canary-qwen-2.5b, distil-v3.5 | NeMo / whisper.cpp | — | no | none | Better on Monsoon, but no better on Noisy; canary-qwen is 2.5B, and distil keeps whisper's 30 s padded window (rejected 2026-08) |
| canary-1b-v2, Voxtral Mini / Realtime | various | — | Voxtral RT yes | none | Worse than v3 on every column |

## Recommendation

1. **Keep Parakeet v3 as the English default.** Nothing in its speed class
   is clearly better, and on our own Indian-English clips it beats turbo on
   accuracy while running 10× faster.
2. **A/B 1, cheap: Parakeet TDT 0.6B v2.** Convert the `.nemo` with
   whisper.cpp's own `convert-parakeet-to-ggml.py`, quantize to q4_k, and run
   `run_eval.py --suites english --models parakeet` with both files installed.
   No app code changes are needed: it is the same engine, picked by filename.
   It ships only if it beats v3 on our suite overall and on the noisy clips.
   Costs: a ~2.4 GB NeMo download, plus torch in a scratch venv to convert it.
3. **A/B 2, bigger: Qwen3-ASR-1.7B and Cohere Transcribe as an opt-in
   "Accurate English" model**, not a replacement. Run both with the
   `transcribe.cpp` CLI (MIT, ggml + Metal, GGUFs for both) on the quick
   `english` suite, scored with our `metrics.py`, in a scratch dir with nothing
   in the app. To ship it needs: at least 10 % fewer relative errors than
   Parakeet on our suite, a median per clip under ~0.6 s on the M3 Air (still
   under half of turbo), and peak RAM that's acceptable on an 8 GB Air.
   Costs: ~1.5–2.5 GB of downloads each, plus building `transcribe.cpp`.
4. **Watch NVIDIA's unified models** (`nemotron-labs-unified-asr-0.6b`,
   `parakeet-unified-en-0.6b`). They are the only same-size models claiming a
   real offline gain (4.68 vs v3's 4.93), and they add streaming. Re-check
   when they reach the leaderboard. Running them needs an RNNT path, either
   `transcribe.cpp` or upstream whisper.cpp.
5. **If A/B 2 wins, integration is the real cost.** It means a third engine
   behind `TranscriptionEngine` and `EngineRouter`. `transcribe.cpp` vendors
   its own ggml, so linking it next to whisper.cpp's ggml needs a symbol-clash
   check, and that is a new dependency (ask first). The MLX route (`speech-swift`)
   needs macOS 15 and pulls in mlx-swift.

Every download and build above needs the user's OK first (CLAUDE.md).

## Sources
[Open ASR Leaderboard (Space)](https://huggingface.co/spaces/hf-audio/open_asr_leaderboard) ·
[Leaderboard trends post](https://huggingface.co/blog/open-asr-leaderboard) ·
[Qwen3-ASR-0.6B](https://huggingface.co/Qwen/Qwen3-ASR-0.6B) ·
[Cohere Transcribe](https://huggingface.co/CohereLabs/cohere-transcribe-03-2026) ·
[Granite Speech 5.0 470M](https://huggingface.co/ibm-granite/granite-speech-5.0-470m-turboctc) ·
[ARK-ASR-0.6B](https://huggingface.co/Edge0/ARK-ASR-0.6B) ·
[parakeet-tdt-0.6b-v2](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2) ·
[parakeet-unified-en-0.6b](https://huggingface.co/nvidia/parakeet-unified-en-0.6b) ·
[nemotron-labs-unified-asr-0.6b](https://huggingface.co/nvidia/nemotron-labs-unified-asr-0.6b) ·
[nemotron-speech-streaming-en-0.6b](https://huggingface.co/nvidia/nemotron-speech-streaming-en-0.6b) ·
[Phonon-2](https://huggingface.co/FermionResearch/Phonon-2) ·
[TheStageAI whisper-turbo](https://huggingface.co/TheStageAI/thewhisper-large-v3-turbo) ·
[FluidAudio](https://github.com/FluidInference/FluidAudio) ·
[speech-swift](https://github.com/soniqo/speech-swift) ·
[soniqo Apple Silicon benchmarks](https://soniqo.audio/benchmarks) ·
[transcribe.cpp](https://github.com/handy-computer/transcribe.cpp) ·
[Moonshine v2 paper](https://arxiv.org/html/2602.12241) ·
[QwenASRKit-Pro (CoreML, M3 timings)](https://huggingface.co/aoiandroid/qwenasrkit-pro)
