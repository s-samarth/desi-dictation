# Phase 0 Spike — Hinglish Model Evaluation

Validates the core bet (Oriserve Hindi2Hinglish models beat stock Whisper on YOUR
speech) before the Swift app depends on it. Python because model wrangling is faster
here; the app itself is Swift.

## Setup

```bash
cd spike
uv sync          # installs torch, transformers, jiwer, soundfile
```

## 1. Record your eval set (~40–60 clips)

Record yourself dictating the way you actually would — Hinglish WhatsApp messages,
work Slack messages, tech vocabulary, pauses included.

Easiest path on macOS (no extra installs):
1. **QuickTime Player → File → New Audio Recording**, save as `.m4a`, or use Voice Memos.
2. Convert to 16 kHz mono WAV (what Whisper expects):
   ```bash
   afconvert -f WAVE -d LEI16@16000 -c 1 input.m4a audio/clip01.wav
   ```
3. Write the reference transcript — **exactly how YOU would type it on WhatsApp** —
   into `audio/refs.tsv` (tab-separated):
   ```
   clip01.wav	kal meeting hai please deck ready rakhna
   clip02.wav	bhai is bug ko fix karna hai warna release slip ho jayegi
   ```

Suggested mix: ~20 Hinglish, ~10 pure Hindi, ~10 Indian English, ~10 hard cases
(code terms, names, numbers).

## 2. Quick single-file test

```bash
uv run transcribe.py audio/clip01.wav --model swift   # 72M, fast
uv run transcribe.py audio/clip01.wav --model apex    # 0.8B, best quality
```

## 3. Full comparison

```bash
uv run eval.py --models swift prime apex
```

Prints raw WER + **normalized WER** (Hinglish spelling variants collapsed via
`normalize.py` — extend its `VARIANTS` map as you spot new ones) and writes JSON to
`results/`. For Hinglish, also do a blind read of the `hyp` columns — preference
matters more than WER here.

## 4. GGML conversion (feeds the Swift app)

```bash
../scripts/convert_model.sh swift    # -> ../models/ggml-hinglish-swift.bin
../scripts/convert_model.sh apex    # -> ../models/ggml-hinglish-apex.bin (+ q5_0 quant)
```

## Decision gate (from plan.md)

Build proceeds only if: Apex/Prime beats stock Whisper on Hinglish **preference**
decisively AND runs ≥5× realtime via whisper.cpp on this Mac. Record the verdict in
`results/RESULTS.md`.
