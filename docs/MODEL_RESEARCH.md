# Hinglish STT Model Landscape — Deep Research (2026-07)

The question: is there anything better than what we ship, and if the field is
thin — why? Answer: one genuinely new SOTA option exists (Trelis, June 2026),
the API giants are closed, and the thinness is **structural** (data + orthography
+ eval economics), which is exactly our opportunity. Sources at bottom.

## The landscape, by output script (what matters for dictation)

### A. Pure Roman-script Hinglish ("kal meeting hai") — OUR default mode
| Model | Verdict |
|---|---|
| **Oriserve Hindi2Hinglish Apex/Prime/Swift** (Apache 2.0) | **Still the only serious open family for pure-Roman output.** We ship it. ~1,000 h conversational Indian audio, #1 on Speech-to-Text Arena preference. |

Nothing found — on HF, in Indian lab releases, or LinkedIn-era announcements —
that beats Apex *for this exact output format*. That's not because it's
unbeatable; see "bottleneck" below.

### B. Mixed-script Hinglish ("मेरा favourite festival Diwali है")
| Model | Verdict |
|---|---|
| **Trelis/whisper-hinglish-preview** (June 2026, Apache 2.0, whisper-large-v3 arch, ~1.5B) | **The big new find.** `<|mixedcode|>` token → each word in its native script. WER 10.2–13.7 on code-switch benchmarks; **beats or approaches Sarvam & ElevenLabs Scribe-v2** on code-switch/HIACC; weaker on pure English. Whisper arch = our GGML pipeline works unchanged → conversion already running. |
| shunyalabs/zero-stt-hinglish (OpenRAIL) | Whisper-Medium base; decent, weaker license, superseded by Trelis. |
| Srota (Qwen3-ASR-0.6B fine-tune) | Good numbers, **wrong architecture** (needs MLX path, not whisper.cpp) — parked. |

### C. Devanagari Hindi (our "हिन्दी" mode)
| Model | Verdict |
|---|---|
| **ARTPARK-IISc/whisper-large-v3-vaani-hindi** | Best open Hindi Whisper: large-v3 + **718 h** (Vaani, Gramvaani, IndicVoices, FLEURS, CommonVoice). Whisper arch → convertible. Candidate to replace stock turbo for Hindi mode. Also the base Trelis built on. |
| AI4Bharat IndicConformer-600M (MIT, 22 languages) | Great work, **NeMo Conformer arch — incompatible** with whisper.cpp; Devanagari-only. Not for us (v1). |
| AI4Bharat IndicWhisper / IndicWav2Vec | Older; Vaani models supersede for Hindi. |

### D. The closed ceiling (API-only — inaccessible to a local-first app)
- **Sarvam Saaras v3** — explicitly positioned for "Indian accents, code-mixed
  speech"; ₹30/hr API. Sarvam open-sourced their **LLMs** (30B/105B, Apache) but
  **ASR weights stay closed** — it's their B2B revenue engine.
- **ElevenLabs Scribe v2**, Google Chirp — same story.
- Implication: the best Indian ASR lives behind APIs. **A local-first app cannot
  use them — and that's our moat, not our weakness.**

### E. English mode — the 2026-08 bake-off (decided: Parakeet TDT)

Question asked: a **lighter** English model that is still *really* good, because
English is what most people try first. Answer found by measuring, not reading
leaderboards — and the measurement changed the reasoning.

**The insight:** whisper always encodes a **padded 30-second window**, so a
3-second dictation costs the same as a 30-second one (docs/PERF_RCA_2026-08.md).
Nothing whisper-shaped fixes that. Distil-Whisper v3.5 doesn't either — it keeps
large-v3's encoder **frozen** and only trims decoder layers, and the encoder is
our bottleneck. A different **architecture** was needed, not a smaller whisper.

**Measured** — 20 clips of `ai4bharat/Svarah` (Indian-accented English, 117
speakers), through the shipping engine path on an M3 Air, nWER (normalized):

| Engine | nWER | per call | size | note |
|---|---|---|---|---|
| **Parakeet TDT 0.6B v3 q4_k** | **4.3 %** | **0.39 s** | **416 MB** | shipped default for English |
| Parakeet TDT 0.6B v3 q8_0 | 4.5 % | 0.44 s | 669 MB | no accuracy gain for 253 MB |
| Whisper large-v3-turbo q5_0 | 4.5 % | 1.94 s | 574 MB | previous default, now the fallback |
| Whisper small (multi) | 7.3 % | 0.71 s | 488 MB | |
| Whisper base (multi) | 11.4 % | 0.28 s | 148 MB | |
| Hinglish Apex q5_0 | 12.5 % | 1.93 s | 574 MB | good Indian English ≠ good English |

With the model resident (the real app state) Parakeet answers a 10 s clip in
**0.21 s** vs turbo's ~1.9 s. Accuracy is equal-or-better *on Indian-accented
English specifically*, which is the only English that matters for us.

**Why it's fast:** FastConformer-TDT encodes the audio it was actually given, so
short dictations get radically cheaper. The trade-off is that its compute buffer
grows with audio length (0.64 GB at 12 s, 1.8 GB at 138 s), which is why long
sessions still chunk.

**License:** CC-BY-4.0, commercial use permitted (NVIDIA). Ships as
`ggml-org/parakeet-GGUF`, converted by the whisper.cpp project itself.

**Scope — English only, deliberately.** Parakeet v3 covers English + 24
European languages. It has **no Hindi**, cannot emit Devanagari, and cannot emit
Roman-Hinglish. `ModelManager.score()` therefore returns 0 for it in every mode
except English, and the pickers never show it there.

**Runtime:** whisper.cpp ships `libparakeet` (own static lib over the same ggml
backends — no duplicate symbols), so it's a second engine behind
`TranscriptionEngine`, chosen by filename in `EngineRouter`. Whisper stays the
engine for Hinglish and हिन्दी.

**Not chosen, and why:** distil-large-v3.5 (same frozen large encoder → same
per-call cost); whisper small/base (accuracy loss too big); Canary-Qwen 2.5B and
IBM Granite Speech (top of the Open ASR Leaderboard but far too heavy for a
menu-bar app on an 8 GB Air); parakeet.cpp as a separate project (unnecessary —
support is in whisper.cpp itself).

## Why so few open Hinglish models? (the bottleneck, as asked)

1. **Economics.** Code-mixed Indian ASR monetizes as B2B voice-bot/call-center
   APIs (Sarvam, Gnani, ElevenLabs). Open weights would cannibalize the product.
   Open releases happen only as marketing (Oriserve), research mandate
   (AI4Bharat — whose mission is the 22 *official* languages in *native
   scripts*, so Roman Hinglish is out of scope for them), or indie work (Trelis).
2. **Data is Devanagari-labeled.** Essentially all transcribed Hindi speech —
   Vaani (2,041 h transcribed), IndicVoices, Shrutilipi, Common Voice — uses
   native script. Roman-Hinglish labels barely exist as datasets.
3. **No standard orthography.** "nahi/nahin/nhi" are all correct Romanizations.
   Annotators disagree, so labels are noisy; WER punishes valid outputs, so
   **benchmarks make honest models look bad** (even Sarvam published a blog
   arguing Indic ASR needs semantic metrics beyond WER).
4. **Eval vacuum → no leaderboard → no glory.** Researchers optimize what's
   measurable; Roman Hinglish isn't. (Oriserve resorts to Arena-style human
   preference to claim #1.)

Structural gaps don't close by themselves — this is why a product that *owns*
the Roman-Hinglish experience (model + normalization dictionary + user
replacements + eval set) can stay ahead of generic players.

## Post-research lab results (same day)

- **Trelis → whisper.cpp: BLOCKED (for now).** The `<|mixedcode|>` token grows
  the vocab to 51,867 vs stock 51,866; whisper.cpp derives its language-token
  table from vocab size → `unknown language id 100`, decode unusable. The
  model is good; the runtime can't host custom-vocab Whispers. Options:
  (a) trim the added token at conversion → works but loses the mixed-script
  feature (its whole point); (b) patch whisper.cpp for added-token vocabs +
  prompt-token injection — real engineering, upstream-worthy, roadmap item for
  the "Mixed script" mode. q5_0 conversion kept on disk for when (b) lands.
- **Vaani (standard vocab) converts cleanly** → evaluated as the हिन्दी-mode
  upgrade instead.

## Actions

1. **Now (running):** convert Trelis → GGML; eval vs Apex on the personal eval
   set. If it holds up → ships as the **Mixed script** language mode (4th mode)
   and possibly as a robustness alternative for Hinglish mode (user OK with
   slower/robust: large-v3 q5_0 ≈ 1.1 GB, est. 5–8× realtime on M3).
2. **Next:** convert `vaani` the same way → candidate upgrade for हिन्दी mode.
3. **Fine-tune feasibility (if we want to OWN pure-Roman SOTA):** the recipe is
   proven — it's how Oriserve did it:
   - **Base:** whisper-large-v3-vaani-hindi (best Hindi acoustics) or Apex.
   - **Data:** IndicVoices/Vaani/Common Voice Hindi audio (open); labels
     transliterated Devanagari → Roman with **AI4Bharat IndicXlit** (11M-param
     open transliteration model), normalized by our spelling map for consistent
     orthography.
   - **Method:** LoRA fine-tune, ~100–600 h audio, fp16, lr 1e-5 (per published
     Indic Whisper recipes; LoRA gave ~15 % relative WER cuts in comparable work).
   - **Cost estimate:** a few hundred dollars of rented A100 time + 1–2 weeks
     part-time. Cheap enough to do post-launch if Apex's ceiling starts hurting.
   - **Gate:** must beat Apex on the personal eval set (blind preference), else
     it doesn't ship.

## Sources
[Trelis announcement](https://trelis.substack.com/p/whisper-hinglish) · [Trelis HF card](https://huggingface.co/Trelis/whisper-hinglish-preview) · [Sarvam models](https://www.sarvam.ai/models) · [Saaras v3](https://www.sarvam.ai/blogs/asr) · [Sarvam on ASR metrics](https://www.sarvam.ai/blogs/evaluating-indian-language-asr) · [Sarvam 30B/105B open-sourcing](https://www.sarvam.ai/blogs/sarvam-30b-105b) · [IndicConformer 600M](https://huggingface.co/ai4bharat/indic-conformer-600m-multilingual) · [whisper-large-v3-vaani-hindi](https://huggingface.co/ARTPARK-IISc/whisper-large-v3-vaani-hindi) · [Vaani dataset](https://huggingface.co/datasets/ARTPARK-IISc/Vaani) · [Vaani paper](https://arxiv.org/pdf/2603.28714) · [Vistaar benchmarks](https://arxiv.org/pdf/2305.15386) · [Aksharantar/IndicXlit](https://www.researchgate.net/publication/376402890_Aksharantar_Open_Indic-language_Transliteration_datasets_and_models_for_the_Next_Billion_Users) · [Oriserve Apex](https://huggingface.co/Oriserve/Whisper-Hindi2Hinglish-Apex) · [Open ASR leaderboard](https://github.com/huggingface/open_asr_leaderboard) · [Parakeet TDT 0.6B v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) · [parakeet-GGUF](https://huggingface.co/ggml-org/parakeet-GGUF) · [distil-large-v3.5](https://huggingface.co/distil-whisper/distil-large-v3.5) · [Svarah](https://huggingface.co/datasets/ai4bharat/Svarah)
