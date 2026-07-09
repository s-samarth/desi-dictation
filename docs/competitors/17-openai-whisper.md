# OpenAI Whisper (+ whisper.cpp / WhisperKit ecosystem)

> **Layer:** Infra / foundation model · **Verdict:** the ground we stand on. Whisper is the base architecture of our model, whisper.cpp is our runtime — this is less a competitor than a description of our own foundations and their limits.

## Snapshot

| | |
|---|---|
| **Whisper** | OpenAI's open-source (MIT) speech-recognition model family; tiny → large-v3 → large-v3-turbo; 100+ languages |
| **whisper.cpp** | ggml/ggerganov's C/C++ port — CPU/Metal/GPU, quantized, no Python; **our runtime** |
| **WhisperKit** | Argmax's Core ML / Apple-Neural-Engine optimized Whisper (used by MacWhisper for streaming); a faster on-device path we don't yet use |
| **Faster-Whisper / insanely-fast-whisper** | CTranslate2 / optimized inference variants (server-side) |
| **License** | Whisper MIT; whisper.cpp MIT — fully commercial-safe |
| **Confidence** | High — our own build experience + ecosystem knowledge |

## What it is

Whisper is the encoder-decoder transformer that reset the ASR field: robust, multilingual, open, and fine-tunable — which is *why* an Oriserve could make a Hinglish variant and why we could ship it. whisper.cpp is the runtime that lets that model run on a MacBook with no Python, no cloud, quantized to a few hundred MB — the reason our on-device product is even possible. WhisperKit is the faster Apple-Silicon path (Core ML + Neural Engine) that competitors use for streaming and we've noted as a roadmap upgrade.

## Why it's in the competitor map

Three reasons this foundation deserves a strategic file rather than a footnote:

1. **It defines our ceiling and floor.** Our accuracy, latency, and language behavior are Whisper's, plus Oriserve's fine-tune, plus our post-processing. Whisper's architectural limits (limited context window, ~30s chunworking, code-switch weakness, suppressed tokens — see P2) are *our* limits until we change engines. Understanding Whisper is understanding our own constraints.
2. **Everyone shares this foundation.** MacWhisper, VoiceInk, Raycast's extension, Superwhisper — all Whisper/whisper.cpp under the hood. On the base model, we have **zero moat**: it's the same engine for all of us. Differentiation must come from the fine-tune, the post-processing, and the product — never the base model.
3. **The foundation is being surpassed.** NVIDIA's Parakeet/Canary now beat Whisper-large-v3 on English while being ~10× faster ([nvidia-parakeet-canary.md](18-nvidia-parakeet-canary.md)). Whisper is no longer automatically the best base — which is both a threat (competitors may jump to faster engines) and an opportunity (we could too).

## Strengths (as our foundation)

Open, MIT, fine-tunable (enabled Apex); huge ecosystem and tooling; whisper.cpp's quantized on-device performance with embedded Metal; battle-tested; 100+ languages; the entire fine-tuning knowledge base (convert scripts, quantization) is mature.

## Weaknesses / limits we inherit

- **Code-switching weakness** (P1) — architectural, not just data.
- **Suppressed tokens / filtered training** (P2) — profanity/OOD aversion baked into base weights.
- **Latency/streaming**: vanilla whisper.cpp isn't real-time-streaming-native (why MacWhisper's live dictation lags ~2.4s; why we built chunked transcription; why WhisperKit exists).
- **Fixed vocabulary** (FM#16) — can't add tokens without breaking whisper.cpp; caps some OOD fixes.
- **Being out-sped** by Parakeet/Canary on English.

## Strategic implications

- **No moat at the base layer** — accept it, differentiate above it. This is the single most important framing: never pitch "we use Whisper" as an advantage; everyone does.
- **Engine upgrade paths worth tracking:** WhisperKit (Core ML/ANE) for faster on-device + streaming; Parakeet for English speed. Our `TranscriptionEngine` protocol was designed for exactly this swap — a real asset.
- **Our fine-tune (P1-S4) is where base-model choice matters:** we could fine-tune from Whisper (Oriserve's lineage, whisper.cpp-compatible) or explore other bases — but whisper.cpp compatibility is a hard constraint (FM#16) that keeps us in the Whisper family unless we change runtimes too.

Sources: our own [BUILD_LOG.md](../../docs/BUILD_LOG.md) and setup scripts; [Best open-source STT 2026 (Northflank)](https://northflank.com/blog/best-open-source-speech-to-text-stt-model-in-2026-benchmarks); OpenAI Whisper + ggerganov/whisper.cpp + Argmax WhisperKit project docs.
