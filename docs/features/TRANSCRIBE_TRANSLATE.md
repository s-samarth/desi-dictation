# Feature: Speak Desi, Write English (Transcribe → Translate)

> **Status (2026-07-10): BUILT** as `LanguageMode.anyToEnglish` — Apex ASR +
> gemma3:4b translation stage, two-stage overlay, raw-transcript fallback, both
> texts in History. §7's prediction held: 1.5B failed the spike, 4B passed.
> How it works: [implementation/SPEAK_DESI_WRITE_ENGLISH.md](implementation/SPEAK_DESI_WRITE_ENGLISH.md).
> Still open: the ~500-utterance spoken-Hinglish eval (§7) before this leaves beta.

## 1 · Explainer

A new dictation mode: the user speaks naturally — Hindi, Hinglish, broken English, all mixed — and what gets pasted is **polished, complete English**. No intermediate step, no user interference: hold key → speak → release → English appears.

This is different from Translate-on-Demand (TRANSLATION.md): there the user *asks* for a translation of existing text; here translation is part of the dictation pipeline itself. One is a tool, this is a *mode* — sitting next to Hinglish/English/हिन्दी in the language picker as **"English (from any language) ✨"** or similar.

The pasted English is normal text — the user can edit it after pasting like anything else.

## 2 · The user

The core insight (Samarth, 2026-07-08): **Indians understand English far better than they produce it.** A user prompting ChatGPT, writing a work email, or filling a form needs *complete, fluent English* — but their natural speech is Hinglish or broken English. Today they either type slowly and self-consciously, or dictate Hinglish and manually rewrite it.

The killer use case is **giving context to AI**: LLMs work best with rich, detailed prompts, and rich detail flows out of people in their mother tongue. Speak two minutes of Hinglish about your problem → get two paragraphs of clean English context to paste into ChatGPT/Claude. The user can verify it (they *read* English fine) — they just couldn't have written it that fast.

Secondary: work emails, LinkedIn posts, complaint letters, visa/government forms — anywhere "proper English" is socially expected.

## 3 · User flow

1. Menu bar mic → Language → **English (from any language)**. One-time: if the translation model isn't installed, the menu item triggers the download inline (progress in the overlay).
2. User clicks into the ChatGPT input box.
3. Holds Right ⌥, speaks: *"mujhe ek aisa script chahiye jo mere saare invoices ko padhe aur ek excel mein daal de, invoices PDF mein hain aur unka format har vendor ke liye alag hai"*
4. Releases. Overlay shows "Transcribing…" then "Translating…" (two stages visible, so slower total time is understood, not mysterious).
5. Pasted: *"I need a script that reads all my invoices and puts them into an Excel sheet. The invoices are PDFs, and each vendor uses a different format."*
6. Clipboard holds the English (house rule). **History stores both** the raw transcript and the English — so if the translation mangled something, the user can see what was heard vs. what was written, and use *Report Last Transcription* on either.

Failure handling (house rules apply):
- Translation stage fails → paste the raw transcript instead, overlay says "Translation failed — pasted the original". Never lose the user's words.
- Too-long input (>~2 min) → translate in chunks; worst case, same fallback.

## 4 · Technical plan

Reuses everything from TRANSLATION.md §4 — same `TranslationEngine`, same llama.cpp vendoring, same model download. Build order is therefore: engine + Translate-on-Demand first (easier to debug, user can see intermediate text), then this mode is mostly pipeline wiring:

- `LanguageMode` gains `.anyToEnglish` case. `resolveModel(for:)` maps it to **Apex** for the transcription stage (it handles the Hindi/Hinglish/English mix best); `catalogEntry(for:)` maps its "required models" to Apex + translation model.
- `DictationController`: after `transcribe()` returns, if mode == `.anyToEnglish`, run `translationEngine.translate(text, to: .english)` on the same serial workQueue before `TextInserter.insert`. New phase `.translating` for the overlay.
- **Chunked-transcription interaction**: today we transcribe ~12 s chunks while the user speaks. Keep that; run translation **once on the full assembled transcript** at release (translation needs whole-message context — sentence-by-sentence translation of code-mixed speech reads disjointed). Latency budget: transcription is already mostly done at release; a 1.5B Q4 model on Metal does ~40–80 tok/s, so a 60-word message ≈ 1.5–3 s of translation. Show the "Translating…" stage honestly.
- Prompt template (v1): system prompt fixing the task ("You translate mixed Hindi/English speech transcripts into natural written English. Output only the translation."), few-shot with 3 real examples. Keep templates in a resource file so they're tunable without rebuilds.
- **Memory (8 GB Air)**: Apex q5_0 ≈ 550 MB + 1.5B Q4 LLM ≈ 1 GB — coexists fine. Document the ceiling: if we ever offer a bigger LLM, gate it on RAM check.
- Whisper's own `translate: true` flag (built-in X→English) is the tempting shortcut — **test it in the spike**, but expect it to fail on Hinglish: Apex is fine-tuned for transcription output and Whisper's translate path produces stilted English from Hindi. If it's surprisingly good, we ship v0 with zero new dependencies. Cheap to check first.

### Eval before ship
Extend `evals/` with a small translation suite: 30 held-out Hinglish clips → pipeline → human-rated 1–5 adequacy/fluency (self-rated by us + 2 beta friends). No standard metric needed at this scale; a rubric doc in evals/ suffices. Gate: median ≥4 adequacy.

## 5 · Rollout & feedback

- **Spike (same spike as TRANSLATION.md)** answers: whisper's translate flag vs. LLM stage, model choice, latency on M1.
- **Beta as a visible mode with a ✨/(beta) suffix** in the picker — sets expectations that it's newer/rougher than the core modes.
- Beta guide gets a "Speak desi, write English" section pitching the ChatGPT-context use case explicitly — that's the demo that sells it in the WhatsApp group. Ask friends to try exactly that once and reply with a screenshot.
- Feedback: history keeps raw + translated side by side → *Report Last Transcription* email includes both automatically. The single question to ask testers: **"did you have to fix the English before using it?"**
- Ambient signal (no telemetry): translation-model download count on HF is a direct proxy for interest in both translation features.

## 6 · What makes it good

- **The two-minute-context test**: a user speaks freely for 2 minutes and pastes the result into an LLM *unedited*. If beta testers do this twice, they're retained — this becomes their default way of talking to AI.
- English is **natural written English**, not translationese: "I need to postpone" not "It is required by me to postpone".
- Total wait after release ≤ ~3 s for a normal message; the two-stage overlay makes longer waits legible.
- Meaning is never inverted or dropped — fallback-to-transcript on any doubt beats confident hallucination.
- It strengthens the brand line: *the only tool where your broken English becomes fluent English without your voice leaving your laptop.* Cloud tools (Wispr Flow etc.) can do this server-side; nobody else does it on-device for Indian speech. If quality hits the bar, this is arguably the headline feature, not an add-on.

## 7 · Research validation (web research, 2026-07-09)

**The hypothesis** — "current translation models are small, good, and fast enough to translate captured Hindi/Hinglish into English on-device" — **is largely validated, but it splits into two problems of different difficulty.**

### Path A: Hindi → English — solved, ship-ready tech (8.5/10)

- [AI4Bharat IndicTrans2](https://github.com/AI4Bharat/IndicTrans2) ([paper](https://arxiv.org/pdf/2305.16307)) beats or matches Google/commercial MT on Indic→English (+1–5 chrF++ on FLORES-200/IN22), and its **distilled ~200M-param variants retain nearly all of the 1.1B model's quality** — smaller than our Swift ASR model, CPU-realtime, trivially on-device.
- Catch: IndicTrans2 expects **Devanagari** input. Our Apex output is Roman-script Hinglish → this path applies to the हिन्दी mode's output, or needs a transliteration hop (AI4Bharat IndicXlit) — extra moving part, evaluate in the spike.

### Path B: Hinglish (code-mixed, Roman) → English — the frontier (6.5/10 zero-shot, ~8/10 fine-tuned)

- Dedicated MT models (IndicTrans2, NLLB) assume clean single-language input and stumble on code-mix; even **Google Translate and Bing measurably fail on code-mixed text** — the headline finding of [PHINC](https://arxiv.org/abs/2004.09447) ([HF dataset](https://huggingface.co/datasets/LingoIITGN/PHINC), 13,738 human-translated Hinglish→English pairs, the main public benchmark). Also relevant: [WMT MixMT 2022](https://www.statmt.org/wmt22/code-mixed-translation-task.html), [COMI-LINGUA](https://arxiv.org/pdf/2503.21670) (expert-annotated Hindi-English code-mix, 2025).
- **Small LLMs are the right tool**: Gemma-3-4B-class models reach COMET parity with much larger models on translation ([empirical study](https://arxiv.org/pdf/2502.02481)) and handle code-mix reasonably zero-shot; capability is actively improving ([RLAIF for code-mixing](https://arxiv.org/html/2411.09073v1), [2026 code-mixing playbook](https://arxiv.org/html/2602.11181)). §4's 1.5B-Q4 plan may be optimistic for code-mix — spike should compare 1.5B vs 4B (4B-Q4 ≈ 2.5 GB: fine on Macs, too big for mid-Android → cloud endpoint covers those).
- **A LoRA fine-tune on PHINC/MixMT + our own data is where this becomes ours** — the small-LLM bet from STRATEGY.md Entry 002, made concrete.

### How accuracy is measured

- Standard metrics: **BLEU** (word overlap, dated), **chrF++** (character-level, better for Indic), **COMET-22** (neural meaning-preservation score, best human correlation). Mechanically like our crWER harness: test set of source→reference pairs, score model output against references.
- **The gap nobody's benchmark covers:** public benchmarks are *text→text*; our pipeline is *speech→text→English*, so ASR errors compound into translation. **No public spoken-Hinglish→English benchmark exists — we must build one** (~500 spoken utterances + human English references, COMET + LLM-judge scoring). It slots into `evals/` beside crWER and doubles as fine-tune data. Building it is a moat asset, not a chore. (§4's 30-clip human-rated gate stays as the ship gate; this is the bigger instrument behind it.)

### Cheapest validation step (before any of the above)

One evening, zero cost: run ~50 real dictations through IndicTrans2-200M (Hindi path) and Gemma-3-4B zero-shot (Hinglish path) locally; eyeball + LLM-judge. If the zero-shot floor already clears "usable", the feature is green-lit and fine-tuning becomes an optimization, not a prerequisite.

### Why the bar is reachable

Users *read* English well (§2) — output must be **faithful and clear, not literary**. That lower bar is one current small models already clear for most utterances.
