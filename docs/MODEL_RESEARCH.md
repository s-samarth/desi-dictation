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
[Trelis announcement](https://trelis.substack.com/p/whisper-hinglish) · [Trelis HF card](https://huggingface.co/Trelis/whisper-hinglish-preview) · [Sarvam models](https://www.sarvam.ai/models) · [Saaras v3](https://www.sarvam.ai/blogs/asr) · [Sarvam on ASR metrics](https://www.sarvam.ai/blogs/evaluating-indian-language-asr) · [Sarvam 30B/105B open-sourcing](https://www.sarvam.ai/blogs/sarvam-30b-105b) · [IndicConformer 600M](https://huggingface.co/ai4bharat/indic-conformer-600m-multilingual) · [whisper-large-v3-vaani-hindi](https://huggingface.co/ARTPARK-IISc/whisper-large-v3-vaani-hindi) · [Vaani dataset](https://huggingface.co/datasets/ARTPARK-IISc/Vaani) · [Vaani paper](https://arxiv.org/pdf/2603.28714) · [Vistaar benchmarks](https://arxiv.org/pdf/2305.15386) · [Aksharantar/IndicXlit](https://www.researchgate.net/publication/376402890_Aksharantar_Open_Indic-language_Transliteration_datasets_and_models_for_the_Next_Billion_Users) · [Oriserve Apex](https://huggingface.co/Oriserve/Whisper-Hindi2Hinglish-Apex) · [Open ASR leaderboard](https://github.com/huggingface/open_asr_leaderboard)
