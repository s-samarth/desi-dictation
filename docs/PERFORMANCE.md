# Performance Engineering — Desi Dictation

Every latency/quality lever we know about: what's applied, what's measured, and
what's deliberately deferred (with the exact plan to apply it). Update when any
number changes. (User-visible symptoms → fixes: BUILD_LOG.md.)

## Where dictation time actually goes

```
keypress ──► mic capture ──► release ──► encode+decode ──► post-process ──► paste
   ~0ms       (speaking)                  THE bottleneck        ~0–30ms       ~50ms
   (warm mic)                             (model-dependent)
```

## Measured

**Realtime-factor is the wrong headline number** and cost us a slow release:
whisper encodes a padded 30 s window per call, so RTF looks great on a long clip
while every short dictation pays a fixed ~1.5 s (M3) / ~3 s (M1 Air). Latency is
now measured directly and gated (`scripts/latency_gate.sh`).

**Per call, model resident, short clip (M3 Air, 2026-08-19):**

| Language | Model | Per call |
|---|---|---|
| English | **Parakeet TDT 0.6B v3 q4_k** (416 MB) | **0.21 s** |
| Hinglish | Apex q5_0 (574 MB) | 1.47 s |
| हिन्दी | Vaani q5_0 (1.06 GB) | 3.55 s ← slowest path we ship |
| (English, previous default) | large-v3-turbo q5_0 | 1.94 s |

**Throughput, for reference (M3, 23 s Hinglish clip):**

| Configuration | Speed | Notes |
|---|---|---|
| Apex q5_0, VAD on | **13–15× realtime** | shipping default for Hinglish |
| Apex q5_0, VAD off | 14× realtime | VAD costs ~nothing, kills silence hallucination |
| Apex **q8_0** | 10× realtime | **slower than q5_0 on Metal** — bench before assuming bigger-quant-is-faster; q8 deleted |
| Swift (72 M) | 30–40× realtime | free-tier / low-power option |
| Model cold load | 0.15–0.76 s (by size) | model kept resident; first-ever load also pays Metal shader JIT |

## Applied optimizations (v0.4 → v0.6.1)

1. **Warm mic + 0.3 s pre-roll ring** — mic runs while dictation is enabled;
   keypress starts a session instantly and *includes the 0.3 s before it*.
   Fixes "first words lost" (mic spin-up is 200–500 ms) and most short-utterance
   misses. Off-switch in Options ("Instant mic") for privacy-conscious users.
   Self-heals on audio-device changes: default-input switch, unplug, or a
   sample-rate change reopens the mic, mid-session included (v0.6.2).
   Cold open of the input-only unit measured at ~80 ms (DGM20 USB and built-in).
2. **Chunked incremental transcription, above 30 s only** (thresholds corrected
   2026-08 — PERF_RCA_2026-08.md RC2). Long dictations cut at quiet moments
   every ≥25 s (forced at 35 s) and transcribe in the background while you keep
   talking. Below 30 s of speech nothing is chunked: a chunk call costs a full
   padded window, so the old 12 s cut charged ordinary dictations for extra
   full-price calls and made the tail queue behind a chunk still decoding.
   (`no_context=true` makes chunks independent, so joining is safe.)
3. **Silero VAD** — trims silence pre-decode (quality + speed on pause-heavy audio).
4. **`no_context = true`** — stops cross-window error cascades in long form.
5. **Model residency + preload** — load once per enable/mode-switch, never per
   dictation. Preload also fires when a **per-app rule** changes the language,
   so a model swap never lands inside the transcribing phase.
6. **Greedy decoding** — beam search buys little for dictation, costs 2–3×.
7. **q5_0 quantization** — benched, not assumed (see table).
8. **Serial engine queue** — no locks, no races, chunk jobs naturally ordered.
9. **Parakeet TDT for English** (v0.6.1) — a second engine, chosen by model file
   (`EngineRouter`). No 30 s padding: 0.21 s vs 1.94 s per call at
   equal-or-better accuracy on Indian-accented English (MODEL_RESEARCH.md §E).
10. **Flash attention ON** (v0.6.1) — FM#12's NaN issue did not reproduce on 18
    clips across apex/turbo/vaani q5_0; ~11 % less encode time. Kill switch in
    Options for bisecting a future upstream regression.
11. **Per-dictation timings** (v0.6.1) — `DictationTimings` records speech
    seconds, engine calls, engine time and release→paste, shows the last one in
    the Dictation pane, and logs it at `.notice` so `log show` can reconstruct a
    complaint after the fact.

## Deferred — documented so they're one decision away (ranked by value)

1. **CoreML/ANE encoder** (~3× encoder speedup, better battery — the single
   biggest remaining lever). Now matters most for **हिन्दी and Hinglish**:
   English left the whisper path entirely, and Vaani at 3.55 s/call is the
   slowest thing we ship.
   Blockers: needs `WHISPER_COREML=ON` rebuild + generating the CoreML encoder
   (`models/generate-coreml-model.sh`, Python coremltools) + `.mlmodelc`
   compilation which normally needs Xcode — workaround: compile at first run
   in-app via `MLModel.compileModel(at:)`. Effort: ~1–2 days. Do before v1.0.
2. **A lighter हिन्दी model** — Vaani is a 1.06 GB large-v3 and now the worst
   latency we ship. Either an ANE encoder (above) or a distilled/quantized Hindi
   fine-tune; Parakeet cannot help (no Hindi, no Devanagari).
3. **whisper.cpp version pin + scheduled bumps** — currently `--depth 1` HEAD
   at clone time; pin a commit, bump deliberately with the regression suite.
   Now doubly relevant: Parakeet support lives in that same tree.
4. **Streaming partial text in the overlay** — cosmetic "words appear live";
   real work, do after PMF.
5. **Distil/turbo-class Hinglish fine-tune** — would need training our own
   model on Hinglish data (Oriserve's Apex is large-v3-turbo-class already);
   revisit if Apex latency is the top complaint after ANE.

## Regression guard

`./scripts/preflight.sh` step 5 runs `scripts/latency_gate.sh`: a **short** clip
per language, through the app's own engine path, with the model resident —
release→paste must stay inside the per-language budget (English 0.75 s,
Hinglish 2.0 s, हिन्दी 4.0 s on an M3 Air; halve the machine, roughly double the
number). Budgets get tightened as the engine improves and are never loosened to
turn a red gate green.

Throughput still matters for long dictations, so also re-run:
```bash
app/.build/release/desi-cli models/ggml-hinglish-apex-q5_0.bin spike/audio/test-long.wav hinglish --repeat
```
and stay ≥ 10× realtime with unchanged text output. (Real-mic eval set from
spike/README.md remains the accuracy gate.)
