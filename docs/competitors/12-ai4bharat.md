# AI4Bharat

> **Layer:** Indian model (open-source research lab) · **Verdict:** not a product competitor at all — a *supply-chain alternative and asset*. The open-source Indic ASR/MT lab whose models we could adopt, benchmark against, or fine-tune from.

## Snapshot

| | |
|---|---|
| **Org** | AI4Bharat — research lab at **IIT Madras**, permissively-licensed open models |
| **Category** | Open-source Indic speech + language models (ASR, TTS, MT) |
| **Key ASR** | **IndicWhisper** (Whisper fine-tune for Indian languages, Apache 2.0); **IndicConformer** (conformer ASR, all 22 official languages; a 30M-param variant deployable **on Android** via websockets; MIT/permissive) |
| **Key MT** | **IndicTrans2** (best-in-class open Indic↔English translation) |
| **License** | Permissive (Apache 2.0 / MIT) — usable in commercial products |
| **Confidence** | High — official site, HF, GitHub, 2026 coverage |

## What it is

The academic backbone of Indian open-source language AI: production-quality ASR and TTS for all 22 scheduled languages under permissive licenses, plus the IndicTrans2 translation models. It is *not* a company selling a product — it's a wellspring of models and datasets that everyone else (including potentially us, and our competitors) builds on. For us it is less "competitor," more "the other half of the supply chain besides Oriserve," and a direct input to two of our roadmaps (P1 fine-tuning, the translation features).

## Direct relevance to our roadmap

- **Model supply alternative to Oriserve:** IndicWhisper is a permissively-licensed Whisper fine-tune we could evaluate as an alternative/complement to Apex — reducing our single-supplier risk (currently we depend on Oriserve's fine-tune; see [oriserve.md](15-oriserve.md)).
- **IndicConformer's 30M on-device Android variant** is directly interesting for our Android future — a tiny ASR model designed to run on-device on Android is exactly the kind of thing our eventual Android port needs.
- **IndicTrans2** is a leading candidate (evaluated in TRANSLATION.md) for our translation features — though it expects Devanagari input, so Roman Hinglish needs a transliteration pre-pass (the reason we lean toward a small LLM instead).
- **Datasets** (Shrutilipi, Kathbath, IndicVoices, etc.) are training/eval fuel for our P1 fine-tune and P3 freshness pipeline.

## Strengths

Permissive licensing (commercial-safe); breadth (all 22 languages); academic rigor and benchmarks; on-device-friendly small models (IndicConformer 30M); a real dataset ecosystem; no commercial agenda competing with us.

## Weaknesses (as inputs, not products)

- **Devanagari-oriented**: their ASR outputs and MT expect/produce Devanagari Hindi, not Roman-script Hinglish — the same transliteration gap we hit everywhere. Our value-add (convention-normalized Roman output) sits *on top* of models like these.
- **Not a polished consumer artifact**: raw models/checkpoints, not an app — someone has to do the product work (that's us).
- Conformer models need their own runtime (not whisper.cpp) — integration cost if we adopt IndicConformer vs. staying in the Whisper/whisper.cpp lane.

## Threat to us & how we differentiate

**Threat: essentially none — treat as asset and hedge.** AI4Bharat will never ship a consumer dictation app; it's a lab. The only "threat" is indirect: their open models lower the barrier for *anyone* (a competitor, a fork) to build Indian-language speech products. But that same openness is our benefit — we can consume it too.

**Strategic use:** (1) De-risk supplier concentration — benchmark IndicWhisper/IndicConformer against Oriserve Apex on our eval set; if competitive, we gain an alternative and a fine-tune base we fully control. (2) IndicTrans2 as a translation-feature candidate (with the transliteration caveat). (3) Their datasets as P1/P3 fuel. (4) The 30M Android conformer as an Android-port building block. In short: **AI4Bharat is where our future self-trained models likely start.**

Sources: [AI4Bharat](https://ai4bharat.iitm.ac.in/), [IndicConformer (GitHub)](https://github.com/AI4Bharat/IndicConformerASR), [indic-conformer-600m (HF)](https://huggingface.co/ai4bharat/indic-conformer-600m-multilingual), [Open-source voice AI India 2026 (Caller Digital)](https://caller.digital/blog/open-source-voice-ai-india-sarvam-ai4bharat-bhasini-2026).
