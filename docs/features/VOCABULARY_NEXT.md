# Vocabulary — what's next (decided 2026-10-28)

Follows [implementation/AUTO_VOCABULARY.md](implementation/AUTO_VOCABULARY.md).
Order: 1 → 2. §1 is built and measured:
[implementation/CONTEXT_FIT.md](implementation/CONTEXT_FIT.md). §2 is built:
[implementation/REVIEW_BEFORE_PASTE.md](implementation/REVIEW_BEFORE_PASTE.md).

## 1 · Context scorer: "cloud" or "Claude"? (English only)

**Problem:** a dictionary pair is a hard rule. *cloud → Claude* is right in
"I asked Claude to refactor this" and wrong in "our data sits in the cloud".
Keyword lists run out; the sentence decides.

**Shape:** a small local LM **scores, never writes**. For each sound-alike
candidate it compares the log-probability of the sentence with and without
the swap, and keeps the winner. It can only choose among candidates the
phonetic layer offers, so it can't hallucinate (the 1–1.5B models in
LLM_ENGINE.md hallucinated because they *generated*).

- **Model:** ≤ 400 MB (e.g. Qwen3-0.6B, 4-bit). Runtime llama.cpp or MLX;
  Ollama can't score a given sentence. New dependency approved 2026-10-28.
- **Prompt:** a compact prefix, ≤ ~60 tokens, built from confirmed fixes:
  `Words I use: Claude (AI assistant), Kavya (person).` Updated when a fix
  is accepted; the oldest entries drop first.
- **Runs only** when a "When it fits" pair or a low-confidence word with a
  sound-alike candidate is in the sentence. Most dictations pay nothing.
- **Extra votes:** the term is on screen, the app is Claude, how often the
  user accepted this swap before.
- **Hinglish:** not yet. Small models are weak on Roman Hinglish; revisit
  with a Hinglish test set.

**UI:** the proposal popup gets a third button, **Only when it fits**, shown
only once the scorer model is downloaded. Your words lets any entry switch
between *Always* and *When it fits*.

**Test before shipping** (single clips + quick tier, no full evals):
1. Does confidence find errors? Dump per-word confidence (min token `p`);
   flagging the lowest 5 % of words should catch ≥ 40 % of errors.
2. Scorer accuracy on low-confidence words and on a cloud/Claude-style
   sentence set: rules only vs LM vs LM + prefix.
3. Latency per scored sentence, measured on M-series (not assumed).

## 2 · Review before paste

Setting: **Off / Only when unsure / Always**. A panel shows the text with
unsure words underlined. Tab jumps between them, 1–5 picks an alternative,
typing edits freely, Enter pastes, Esc copies instead. A fix made here
offers *Always / When it fits / Just this once*.

**Hard part:** keyboard focus. The panel takes focus so you can type, then
must hand it back to the original app before ⌘V (same family as FM#31's
paste timing). Reviewed text is also the only trustworthy label for any
later fine-tune.

## Decided against (for now)

- **Spell a word by voice:** dropped. Letters (B/D/E/P/T/V) are the hardest
  thing for ASR, and typing in the review panel is faster.
- **Per-app vocabularies:** skipped. Screen context already makes vocabulary
  app-aware, and lists to maintain go against the goal.
- **Personal fine-tune:** parked. Revisit only if review-panel data shows
  accent errors, not names, dominate what users fix.
