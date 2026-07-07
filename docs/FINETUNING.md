# Fine-Tuning Deep Dive — Speech Models for an LLM Developer

Everything about if/when/how to fine-tune our Hinglish ASR, written for someone
fluent in LLMs and deep learning but new to speech. Read top to bottom once;
then Parts 3, 8, 9 are the operational bits you'll return to.

---

## Part 0 — The verdict up front

- **Don't fine-tune yet.** Oriserve Apex already IS a fine-tune of exactly the
  kind we'd build (~1,000 h, same base family). Beat-it-or-buy-it math says:
  exhaust cheaper levers first (user dictionary, prompt-free normalization,
  better VAD, Parakeet for English).
- **Fine-tune when** the eval suite (evals/) shows a *systematic* error class
  that post-processing can't fix — see the trigger checklist in Part 3.
- **When you do:** LoRA on large-v3-turbo-class, 50–200 h of transliterated
  Hindi data, ~$50–300 of rented GPU, 1–2 weeks part-time, expect **15–40 %
  relative** crWER improvement on your target distribution. Full recipe in Part 8.
- **Hard constraint from our runtime:** the fine-tune must NOT add tokens or
  change vocab size (51,866 for v3-family), or whisper.cpp can't load it
  (BUILD_LOG failure mode #16 — this killed Trelis for us).

---

## Part 1 — Speech models, translated into LLM concepts

You know transformers; here's what's different when the input is sound.

### 1.1 The input: from waveform to "image tokens"
Audio is a 1-D float array (we use 16 kHz mono — 16,000 samples/sec). Nobody
feeds raw samples to a transformer. Instead:
1. **STFT** over ~25 ms windows, hopped every 10 ms → spectrogram (time × frequency).
2. Frequencies warped onto the **mel scale** (human-hearing-spaced bins; Whisper
   large-v3 uses 128 mel bins) and log-compressed → **log-mel spectrogram**.
3. Think of it as a grayscale image: X = time (100 frames/sec), Y = pitch bands.

So an ASR encoder input is basically a 2-D feature map — closer to ViT patches
than to token embeddings. **Whisper fixes the input at 30 seconds** (3,000
frames, zero-padded if shorter). That's why long dictation needs chunking
(which our app does) and why silence handling matters (padding ≠ silence the
model saw in training).

### 1.2 The architecture: it's just an encoder-decoder transformer
Whisper = classic seq2seq:
- **Encoder**: conv downsampling (3,000 → 1,500 positions) + N transformer
  layers over the mel "image". Output: 1,500 audio embeddings. No masking —
  bidirectional, like BERT over sound.
- **Decoder**: a normal autoregressive LM (BPE vocab ~52k, byte-level, same
  family as GPT-2's) that **cross-attends** into those audio embeddings and
  emits text tokens. Sampling = greedy or beam, exactly like an LLM.
- Control tokens steer it, prompt-style: `<|startoftranscript|><|hi|><|transcribe|><|notimestamps|>`.
  The language token is literally a soft instruction — that's why Oriserve's
  Hinglish models "listen Hindi, write Roman" when given `<|en|>`: the
  fine-tune redefined what the instruction means. There is no hardcoded
  language logic — it's all learned conditioning.

Mental model: **Whisper's decoder is a small LLM whose "context" is an audio
encoder's output instead of a text prefix.** Everything you know about LLM
decoding, prompting, and fine-tuning transfers with that one substitution.

(Alternatives you'll see in the literature: **CTC** models (wav2vec2) — encoder-
only, emit per-frame characters, no LM decoder, fast but no built-in language
modeling; **Transducers/TDT** (Parakeet) — streaming-friendly encoder+predictor;
**Conformer** = convolution-augmented transformer encoder, the dominant encoder
in production ASR. Whisper's seq2seq design is what makes *output-script*
fine-tuning easy, which is why our whole Hinglish story rides on it.)

### 1.3 How Whisper was pretrained (and why it matters for us)
- **680,000 hours** of (audio, transcript) pairs scraped from the web — *weak
  supervision*: no human labeling pass, just filtered found data. The
  transcripts' formatting quirks became the model's habits (punctuation,
  casing, occasionally *translating* instead of transcribing).
- Multitask from day one: same model does transcribe + translate + language-ID
  + timestamps, all selected by control tokens.
- **large-v3**: 1.55 B params, 128-mel. **large-v3-turbo**: same encoder,
  decoder pruned 32→4 layers then re-trained (distillation-ish) → 809 M params,
  ~6× faster, ~1–2 % WER cost. Apex is a fine-tune in this family.
- Hindi was a small slice of pretraining (low-resource in Whisper terms):
  strong acoustic model, weaker Hindi language model, near-zero Roman-Hinglish
  (the web's Hindi transcripts are Devanagari). **The gap we care about was
  baked in at pretraining.**

### 1.4 What "hallucination" means here
With a padded/silent input, the decoder is an LM free-running with weak
acoustic grounding — it emits plausible text (repeated phrases, "thanks for
watching") exactly like an LLM with an empty prompt. Mitigations we already
ship: VAD (cut silence before the model sees it), `no_context` (don't feed
previous output back), and buffer sanity checks.

---

## Part 2 — What fine-tuning an ASR actually changes

Map to LLM intuition:

| LLM concept | ASR equivalent | Our Hinglish case |
|---|---|---|
| Instruction tuning (style/format) | **Output orthography/script adaptation** | THE task: same words, written Roman instead of Devanagari |
| Domain adaptation (legal/medical LM) | Accent + vocabulary adaptation | Indian English, tech vocab |
| Knowledge injection | (mostly N/A — acoustics don't store facts) | — |
| Catastrophic forgetting | Forgetting other languages/pure-English | Real risk; Part 6 |
| RAG instead of fine-tune | Post-processing/user dictionary instead of fine-tune | Our current replacements layer |

Two insights fall out of this table:
1. **Script adaptation is "cheap" learning** — the acoustic encoder barely
   needs to change; you're mostly re-teaching the decoder's writing habits.
   That's why Oriserve got big gains from ~1 k hours and why encoder-frozen /
   decoder-LoRA works: it's instruction tuning on a 4-layer LM.
2. **If a problem is fixable with text post-processing, fix it there** — it's
   the RAG-vs-fine-tune argument, same conclusion: cheaper, reversible,
   per-user. Fine-tune only for what happens *inside* decoding (mishearing,
   wrong-script commitment, dropped code-switches).

---

## Part 3 — WHEN to fine-tune (trigger checklist)

Fine-tune when evals show errors that are **(a) systematic, (b) in-decoder,
(c) on-distribution**. Concretely — any two of:

- [ ] crWER on the `hinglish` suite + your personal set plateaus above ~12–15 %
      after dictionary/normalization improvements.
- [ ] **Error taxonomy** (read 30 mis-transcribed clips, classify): >40 % of
      errors are *substitutions of Hindi words with wrong-but-similar words* or
      *English words rendered as Hindi phonetics* — acoustic/decoder problems.
      (If most errors are spelling variants → extend VARIANTS map, don't train.)
- [ ] A user population you care about (e.g., specific regional accent) is
      consistently worse than your own voice on identical content.
- [ ] You need a capability that doesn't exist: e.g., true mixed-script output
      compatible with whisper.cpp (Trelis has the feature but wrong vocab —
      training our own WITHOUT added tokens fixes FM #16 properly).

**Anti-triggers** (do NOT train): spelling preferences, punctuation style,
proper nouns (dictionary), speed (engine work), English quality (use Parakeet).

---

## Part 4 — Expected gains (calibrated from literature)

| Evidence | Setup | Gain |
|---|---|---|
| Oriserve Apex/Swift model cards | full FT, ~700–1,000 h Indian audio | **42–57 % relative** vs stock Whisper on Indian benchmarks |
| [Springer: Whisper low-resource strategies](https://link.springer.com/article/10.1186/s13636-024-00349-3) | various PEFT, tens of hours | 20–50 % relative typical |
| Indic LoRA fine-tunes (Vistaar-family work) | LoRA, ~100 h/lang | **~15 % relative** WER, ~16 % CER |
| [Fine-tuning Whisper on low-resource langs](https://arxiv.org/abs/2412.15726) | small curated data + real-world focus | double-digit relative gains; data *quality* dominated quantity |
| ARTPARK Vaani-Hindi (our हिन्दी model) | full FT large-v3, 718 h | beat stock turbo on our own A/B today |

Rule-of-thumb curve for OUR task (Roman-Hinglish, starting from Apex-quality):
- **+10 h** targeted data (your voice + friends): fixes person/domain quirks, ~5–15 % rel on personal set — *the highest ROI tier*.
- **+50–200 h** transliterated public Hindi: 15–30 % rel on broad Hinglish, if labels are consistent.
- **+1,000 h**: chasing Oriserve-scale; diminishing returns unless data is
  conversational + noisy like real usage. Not worth it solo, yet.

Temper expectations: we'd be fine-tuning *on top of* an already-fine-tuned
model (or re-doing Apex's job from turbo). The big published deltas are
"vs stock Whisper" — our achievable delta vs Apex is the 10–30 % band, not 50 %.

---

## Part 5 — Data: the real project

### 5.1 What a training example is
`(audio ≤30 s, target text)` — that's it. The art is in the *target text*: for
us it must be **consistent Roman-Hinglish orthography** (one spelling per word,
English words in dictionary spelling). Inconsistent labels = the model learns
to be inconsistent = the exact disease we're curing.

### 5.2 Sources (audio with Hindi transcripts, all open)
| Dataset | Size | Notes | Link |
|---|---|---|---|
| **IndicVoices** (AI4Bharat) | ~700 h Hindi (of 7k+ total) | natural + conversational, 22 langs, CC-BY-4.0, the best single source | [HF](https://huggingface.co/datasets/ai4bharat/indicvoices) |
| **Vaani** (ARTPARK/Google) | 2,041 h transcribed across 59 langs | massive district-level diversity | [HF](https://huggingface.co/datasets/ARTPARK-IISc/Vaani) |
| **Shrutilipi** (AI4Bharat) | ~1,600 h Hindi | mined from All India Radio; clean read speech | [AI4Bharat](https://ai4bharat.iitm.ac.in/shrutilipi) |
| **Common Voice hi** | ~20 h | crowdsourced, gated-but-free | [CV](https://commonvoice.mozilla.org/hi) |
| **Kathbath** (AI4Bharat) | ~150 h Hindi | read speech, phone-quality | [AI4Bharat](https://ai4bharat.iitm.ac.in/datasets) |
| **CS-FLEURS train** | 128 h synthetic code-switched TTS (16 pairs) | augmentation only — synthetic voices | [HF](https://huggingface.co/datasets/byan/cs-fleurs) |
| **Svarah** (AI4Bharat) | 9.6 h Indian English | eval + English-retention mixing | [HF](https://huggingface.co/datasets/ai4bharat/Svarah) |
| **Your usage flywheel** | grows forever | opt-in "correct this transcript" in-app → gold pairs from REAL dictation distribution | (build later — the long-term moat) |

### 5.3 The label pipeline (Devanagari → Roman-Hinglish)
This is where the project lives or dies:
1. **Transliterate** references with [IndicXlit](https://github.com/AI4Bharat/IndicXlit)
   (AI4Bharat's 11 M-param seq2seq transliteration model, trained on
   [Aksharantar](https://huggingface.co/datasets/ai4bharat/Aksharantar), 26 M
   name/word pairs) — NOT rule-based ITRANS (academic, unnatural).
2. **Normalize** with an expanded version of our VARIANTS map → one canonical
   spelling per common word. Freeze this map as `orthography-v1` — it IS the
   spec of your output language.
3. **Restore English words**: transliteration turns "मीटिंग" into "meeting" only
   if you detect loanwords; use a frequency dictionary of English + an LLM pass
   ("rewrite this Roman-Hindi sentence with English loanwords in standard
   English spelling") — this is a perfect cheap-LLM batch job (Haiku-class,
   ~$5–20 for 200 h of transcripts).
4. **Human QA sample**: hand-check 2–3 % of labels; if error rate > ~5 %,
   iterate the pipeline before training. (Whisper's own paper showed
   label noise is the dominant quality ceiling.)

### 5.4 Augmentation (standard speech tricks, cheap wins)
- **SpecAugment** (mask random time/freq stripes of the mel input — the
  dropout of ASR; built into HF's Whisper trainer flags).
- Speed/tempo perturb (0.9×/1.1×), background noise mixing (MUSAN), synthetic
  room reverb — makes MacBook-mic-at-a-café robustness.
- TTS synthetic data (CS-FLEURS-style): fine as ≤30 % garnish, never the base.

---

## Part 6 — Method: what to actually train

### 6.1 Choose the base
- **large-v3-turbo** (809 M): the pragmatic base — 4-layer decoder = fast
  script-adaptation, GGML-friendly, our whole stack is tuned for it.
- Apex itself: attractive (already Hinglish) but you inherit unknown data
  quirks; fine as a second experiment.
- vaani-large-v3: best Hindi acoustics, full-size decoder (slower to serve).

### 6.2 Choose the method
| Method | Trainable params | VRAM | When |
|---|---|---|---|
| **LoRA on decoder** (q,v projections, r=8–32) + frozen encoder | ~0.1–1 % | fits 24 GB (4090) easily, even 16 GB w/ 8-bit | **start here** — script adaptation is decoder work; freezing encoder also fights forgetting |
| LoRA everywhere | ~1 % | 24–40 GB | if audio-side errors persist |
| Full fine-tune | 100 % | 80 GB (or multi-GPU / DeepSpeed) | only with 200 h+ and evidence LoRA saturated |
| QLoRA (4-bit base) | ~0.1 % | 12 GB | budget option; ~80–90 % of full-FT quality per [2026 guides](https://www.spheron.network/blog/how-to-fine-tune-llm-2026/) |

### 6.3 Anti-forgetting (critical — we ship ONE model per mode)
Fine-tuning on Hinglish-only measurably nukes pure-English performance
([documented repeatedly](https://medium.com/@ccibeekeoc42/advancing-multilingual-speech-recognition-fine-tuning-whisper-for-enhanced-low-resource-34529b525f90)).
Mitigations, in order of effectiveness:
1. **Data mixing**: 60–70 % Hinglish-labeled, 20–30 % pure Hindi (Devanagari,
   with `<|hi|>` token), 10–20 % English (Svarah/LibriSpeech slice) — the model
   keeps all three "modes" sharp and the language token stays meaningful.
2. Frozen encoder / adapter-only training.
3. Low LR + few epochs (see 6.4) — most forgetting happens late in training.

### 6.4 Hyperparameters (canonical starting point)
Per the [HF Whisper fine-tuning blog](https://huggingface.co/blog/fine-tune-whisper)
+ Indic recipes: `lr 1e-5` (full) / `1e-4…5e-4` (LoRA), linear warmup 500–1,000
steps, effective batch 32–64 (grad accumulation), bf16, 3,000–8,000 steps
(≈2–5 epochs on 100 h — **checkpoint every 500 steps and eval-early-stop on
crWER**, not loss), SpecAugment on, `<|notimestamps|>` training mode (we never
use timestamps).

### 6.5 The non-negotiable constraint (learned the hard way)
**Do not add tokens. Do not resize embeddings.** Keep `vocab_size` exactly
51,866. Express everything through training data + existing control tokens
(`<|en|>` = "write Roman" is pure convention — Oriserve proved it). Violating
this breaks whisper.cpp conversion (FM #16 / Trelis). Check `config.json`
before AND after training.

---

## Part 7 — Compute, cost, time (concrete)

| Item | Estimate |
|---|---|
| Label pipeline (IndicXlit + LLM pass, 100–200 h transcripts) | $10–30 API + 2–3 evenings |
| LoRA turbo, 100 h audio, ~5k steps | **8–20 A100-hours** ≈ **$15–50** (A100 80GB $0.44–2.40/hr — [io.net](https://io.net/blog/llm-fine-tuning-budget-guide-gpu-costs-timelines-and-what-to-spend), [vessl](https://vessl.ai/en/blog/lora-finetuning-cost-a100-h100-b200)); or free-ish on a rented 4090 |
| Full FT turbo, 200 h | ~60–100 A100-hours ≈ $100–300 |
| Storage/transfer | ~50–150 GB datasets; negligible cost |
| **Wall-clock, solo, part-time** | **1–2 weeks** first iteration; day-scale reruns after |
| GGML conversion + eval | minutes (existing scripts) |

Where: RunPod / Lambda / Modal / Vast for GPUs (spot A100s at the low end).
Don't train on the Mac — MPS training of Whisper is possible but 10×+ slower;
the Mac's job is inference + evals.

---

## Part 8 — The recipe, end to end

```bash
# 1. DATA (Python, one-time ~2-3 evenings)
#    pull Hindi audio+Devanagari refs (IndicVoices/Vaani slices)
#    → IndicXlit transliteration → orthography-v1 normalization
#    → LLM loanword-restoration pass → 2% human QA
#    output: train.jsonl {"audio": path, "text": roman_hinglish}
#    + mix in 25% Devanagari-Hindi rows + 15% English rows

# 2. TRAIN (rented GPU, HF stack: transformers + peft + datasets)
#    base: openai/whisper-large-v3-turbo
#    LoRA r=16 on decoder q/v, lr 2e-4, bf16, batch 64 (accum), 5k steps,
#    SpecAugment on, eval every 500 steps on a held-out slice with crWER

# 3. MERGE + CONVERT (existing pipeline)
peft merge → save_pretrained → verify config.json vocab_size == 51866
./scripts/convert_model.sh <local-path>   # → GGML + q5_0

# 4. EVALUATE (the gate)
cd evals && uv run run_eval.py --models <new-model>
uv run aggregate.py
#    SHIP only if: crWER improves on hinglish suite AND personal set,
#    AND doesn't regress english/hindi suites by >1 point (forgetting check),
#    AND blind A/B preference on 20 personal clips favors new model.

# 5. RELEASE
shasum -a 256 …  → ModelManager catalog entry → publish_models.sh
```

---

## Part 9 — How this plugs into what we've already built

- **evals/ is the referee**: every claim in Part 4 becomes a measured number on
  our suites; `aggregate.py` shows the trend line across attempts.
- **spike/normalize.py VARIANTS** graduates into `orthography-v1` — label spec
  and metric normalization stay in lockstep (same file), which keeps training
  and evaluation honest with each other.
- **The flywheel end-state**: in-app opt-in corrections → monthly labeled batch
  from real usage → quarterly LoRA refresh → eval gate → catalog push. That
  loop, not any single model, is the durable moat (nobody else has YOUR
  distribution of Hinglish dictation).

## Part 10 — Pitfall checklist (tape to monitor before training)

- [ ] Labels: one orthography, loanwords restored, 2 % human-QA'd
- [ ] No added tokens / vocab resize (FM #16)
- [ ] Data mix includes Hindi + English retention slices
- [ ] `<|notimestamps|>`; ≤30 s clips; 16 kHz mono
- [ ] Eval on crWER (not loss, not raw WER); early stop
- [ ] Forgetting check on english + hindi suites
- [ ] Personal-set blind A/B before shipping
- [ ] Eval clips NEVER in training data (hash-check overlap)
- [ ] Silence/hallucination spot-check (feed 5 s of room tone; expect empty)

## Part 11 — Reading list

**Foundations:** [Whisper paper (Radford et al.)](https://arxiv.org/abs/2212.04356) · [HF fine-tune Whisper blog (the canonical tutorial)](https://huggingface.co/blog/fine-tune-whisper) · [Distil-Whisper](https://arxiv.org/abs/2311.00430) · [LoRA](https://arxiv.org/abs/2106.09685) · [SpecAugment](https://arxiv.org/abs/1904.08779)
**Low-resource/Indic:** [Whisper low-resource strategies (Springer)](https://link.springer.com/article/10.1186/s13636-024-00349-3) · [Fine-tuning Whisper for real-world low-resource apps](https://arxiv.org/abs/2412.15726) · [Vistaar: Indic ASR benchmarks](https://arxiv.org/abs/2305.15386) · [IndicVoices](https://huggingface.co/datasets/ai4bharat/indicvoices) · [Vaani paper](https://arxiv.org/pdf/2603.28714)
**Transliteration:** [Aksharantar/IndicXlit](https://huggingface.co/datasets/ai4bharat/Aksharantar) · [IndicXlit code](https://github.com/AI4Bharat/IndicXlit)
**Code-switching:** [CS-FLEURS](https://arxiv.org/abs/2509.14161) · [Trelis Whisper-Hinglish notes](https://trelis.substack.com/p/whisper-hinglish) · [Sarvam on Indic ASR metrics](https://www.sarvam.ai/blogs/evaluating-indian-language-asr)
**Cost/infra:** [SageMaker Whisper LoRA](https://aws.amazon.com/blogs/machine-learning/fine-tune-whisper-models-on-amazon-sagemaker-with-lora/) · [GPU cost guides](https://io.net/blog/llm-fine-tuning-budget-guide-gpu-costs-timelines-and-what-to-spend)
