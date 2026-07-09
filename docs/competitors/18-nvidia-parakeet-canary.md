# NVIDIA Parakeet & Canary (NeMo)

> **Layer:** Infra / foundation model · **Verdict:** the model family that dethroned Whisper on English speed+accuracy — our most credible *engine-upgrade path*, and a lever competitors may pull before we do.

## Snapshot

| | |
|---|---|
| **Vendor** | NVIDIA (NeMo framework) |
| **Models** | **Parakeet** (TDT, speed-optimized; v3 = 600M params, 25 languages, auto language detection) · **Canary** (accuracy-optimized; 1B v2, ASR + speech translation) |
| **Performance** | Canary-1B-v2 **beats Whisper-large-v3 on English while ~10× faster**; Parakeet TDT hits RTFx >2,000 (among the fastest on Open ASR Leaderboard) |
| **Accuracy** | Open ASR Leaderboard multilingual avg WER: Canary-1B-v2 ~4.60, Parakeet-TDT-0.6B-v3 ~4.81 |
| **License** | Open (NVIDIA open-model licenses); models on Hugging Face |
| **Languages** | ~25 **European** languages (v3) — **not Indian languages** (the crucial caveat for us) |
| **Confidence** | High — NVIDIA blogs + arXiv + Open ASR Leaderboard |

## What it is

NVIDIA's speech-AI push: a family of open ASR/translation models built on FastConformer that prioritize either raw speed (Parakeet TDT — real-time-plus throughput) or accuracy (Canary). Together they've displaced Whisper as the top open English/European ASR on the leaderboards, at a fraction of the compute. MacWhisper already ships Parakeet as a Pro engine, which proves it's productizable on Apple Silicon today.

## Why it's in our map

- **Our English engine's upgrade path.** Our English mode uses Whisper large-v3-turbo. Parakeet/Canary would be faster and more accurate for English — directly improving the English mode and our latency story. MacWhisper's adoption shows it works in a shipping Mac app.
- **A competitor lever.** Any competitor can swap to Parakeet for English and instantly out-speed us on that mode. Our `TranscriptionEngine` protocol makes matching them feasible, but we have to actually do it.
- **The Indian-language gap is the whole story for us.** Parakeet/Canary cover *European* languages — **no Hindi, no Hinglish.** So on our core market they're irrelevant as a model; NVIDIA hasn't pointed this firepower at Indian speech. If they (or someone via NeMo) did, the model layer would shift fast — but there's no sign of it.

## Strengths

Best-in-class English/European ASR speed and accuracy; open licenses; on-device-viable on Apple Silicon (proven by MacWhisper); NeMo framework lets others fine-tune to new languages; auto language detection.

## Weaknesses (for us)

- **No Indian languages** — useless for Hinglish/Hindi today; only helps our English mode.
- **Different runtime** — NeMo/Parakeet isn't whisper.cpp; adopting it means new integration work and a second engine to maintain (though WhisperKit-style Core ML ports of Parakeet exist, which is how MacWhisper does it).
- Larger/newer tooling surface than our current lean whisper.cpp path.

## Threat & strategic implications

**Threat: low on our market, medium on our English competitiveness.** Nobody's using Parakeet to beat us at *Hinglish* (it can't). But competitors using it for English makes our English mode look slow by comparison, and English is the commodity half of our product.

**Implications:**
1. **Roadmap item (already noted):** evaluate a Parakeet/Canary path for the English mode — faster, more accurate, and neutralizes a competitor speed advantage. Cost: a second engine integration (Core ML/NeMo), weighed against staying all-whisper.cpp for simplicity.
2. **Don't over-invest** — English is our commodity, not our moat; a "good enough, fast" English is fine, and Parakeet is a nice-to-have, not a must.
3. **Watch NeMo for Indian languages** — if NVIDIA or a community effort fine-tunes Parakeet/Canary for Hindi/code-mix, the model-supply landscape (Oriserve/AI4Bharat/Sarvam) gets a fast new entrant. Low signal now; high impact if it happens.

Sources: [Parakeet-TDT-0.6b-v3 (HF)](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3), [NVIDIA NeMo Canary blog](https://developer.nvidia.com/blog/new-standard-for-speech-recognition-and-translation-from-the-nvidia-nemo-canary-model/), [Canary/Parakeet paper (arXiv)](https://arxiv.org/pdf/2509.14128), [Best open-source STT 2026 (Northflank)](https://northflank.com/blog/best-open-source-speech-to-text-stt-model-in-2026-benchmarks).
