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

## Measured (M3, release build, 23 s Hinglish clip)

| Configuration | Speed | Notes |
|---|---|---|
| Apex q5_0, VAD on | **13–15× realtime** | shipping default |
| Apex q5_0, VAD off | 14× realtime | VAD costs ~nothing, kills silence hallucination |
| Apex **q8_0** | 10× realtime | **slower than q5_0 on Metal** — bench before assuming bigger-quant-is-faster; q8 deleted |
| Swift (72 M) | 30–40× realtime | free-tier / low-power option |
| Model cold load | ~8 s once | Metal shader JIT; model kept resident |

## Applied optimizations (v0.4)

1. **Warm mic + 0.3 s pre-roll ring** — mic runs while dictation is enabled;
   keypress starts a session instantly and *includes the 0.3 s before it*.
   Fixes "first words lost" (mic spin-up is 200–500 ms) and most short-utterance
   misses. Off-switch in Options ("Instant mic") for privacy-conscious users.
   Self-heals on audio-device changes (AVAudioEngineConfigurationChange → rebuild).
2. **Chunked incremental transcription** — every ~12 s of speech (cut at quiet
   moments, forced at 20 s) is transcribed in the background *while you keep
   talking*; on release only the tail is pending. Perceived latency for long
   dictations: ~length-independent ≈1–2 s. (`no_context=true` makes chunks
   independent, so joining is safe.) This is the same class of trick that makes
   competitors feel "instant".
3. **Silero VAD** — trims silence pre-decode (quality + speed on pause-heavy audio).
4. **`no_context = true`** — stops cross-window error cascades in long form.
5. **Model residency + preload** — load once per enable/mode-switch, never per
   dictation.
6. **Greedy decoding** — beam search buys little for dictation, costs 2–3×.
7. **q5_0 quantization** — benched, not assumed (see table).
8. **Serial engine queue** — no locks, no races, chunk jobs naturally ordered.

## Deferred — documented so they're one decision away (ranked by value)

1. **CoreML/ANE encoder** (~3× encoder speedup, better battery — the single
   biggest remaining lever; it's how MacWhisper feels fast on turbo).
   Blockers: needs `WHISPER_COREML=ON` rebuild + generating the CoreML encoder
   (`models/generate-coreml-model.sh`, Python coremltools) + `.mlmodelc`
   compilation which normally needs Xcode — workaround: compile at first run
   in-app via `MLModel.compileModel(at:)`. Effort: ~1–2 days. Do before v1.0.
2. **Parakeet V3 for English mode** — 2026's best local English model (~6.3 %
   WER, ~10× Whisper speed, silence-proof). whisper.cpp in our build already
   ships Parakeet support (`parakeet-quantize` exists). Needs: GGML Parakeet
   weights + a runner path in `WhisperCppEngine` (API differs slightly).
   Also answers "English quality still meh" — turbo is the stock ceiling.
3. **flash_attn retest** — disabled due to NaN with quantized models on Metal
   (FM #12). Upstream fixes land regularly; retest on each whisper.cpp bump
   (worth ~20–30 % decode speed).
4. **whisper.cpp version pin + scheduled bumps** — currently `--depth 1` HEAD
   at clone time; pin a commit, bump deliberately with the regression suite.
5. **Streaming partial text in the overlay** — cosmetic "words appear live";
   real work, do after PMF.
6. **Distil/turbo-class Hinglish fine-tune** — would need training our own
   model on Hinglish data (Oriserve's Apex is large-v3-turbo-class already);
   revisit if Apex latency is the top complaint after ANE.

## Regression guard

Any engine/model change must re-run:
```bash
app/.build/release/desi-cli models/ggml-hinglish-apex-q5_0.bin spike/audio/test-long.wav hinglish --repeat
```
and stay ≥ 10× realtime with unchanged text output. (Real-mic eval set from
spike/README.md remains the accuracy gate.)
