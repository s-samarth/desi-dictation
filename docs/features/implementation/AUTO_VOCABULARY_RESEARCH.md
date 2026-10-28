# Auto vocabulary — research (with sources)

Companion to [AUTO_VOCABULARY.md](AUTO_VOCABULARY.md), which has the plan
and decisions. Researched 2026-10-28. `[n]` refers to the sources at the end.

## 1 · Research: how others do it

| Product / paper | What it does | Applies to us? |
|---|---|---|
| **Wispr Flow** | You fix a word's spelling in the field and press Enter, and Flow adds the pair to an **"Auto-learned"** dictionary tab. Names get added automatically. [1] | Yes. But we never add silently: we *propose* (PERSONAL_DICTIONARY.md rule). |
| **Superwhisper Super Mode** | Reads the active app, the focused field, the window title, and visible names/usernames through Accessibility. It also captures selected text at start and clipboard text from ≤3 s before. All of it is passed to an LLM. [2][3] | Yes, the AX reading part. Our "LLM" step is a deterministic matcher (§3). |
| **Aqua Voice** | Reads screen text via Accessibility ("Deep Context") to get domain terms and to adapt to the target field. Plus a manual dictionary (capped per plan). [4][5] | Yes. We copy its memory-only handling: read at start, drop after paste. |
| **Dragon** | "Learn from sent email" adds contact names. "Learn from documents" scans files for new words. Both end in a **review list** before anything is added. [6][7] | Contacts: yes (opt-in). Document scanning: no. Too broad, and the screen covers it. |
| **Apple** | Siri/keyboard ASR inject the user's contact names at decode time (class-based FST). Their LLM work retrieves *phonetically similar* entries from the personal contact list. `SFSpeechRecognizer.contextualStrings` reportedly did nothing on-device. [8][9][10] | Phonetic retrieval against contacts: yes. Decode-time FST: not possible on Parakeet. |
| **Gboard** | Learned words stay on the device, and "Delete learned words" clears them. [11] | Same deal: local JSON, clearable. |
| **BR-ASR** (arXiv 2505.19179) | Retrieves bias words before the speech LLM. Accuracy **drops as the bias list grows** past ~10k entries. Homophone hard negatives in training gave **+30.6 % recall**. [12] | Pass a *short, relevant* list. Homophones are the hard case. |
| **CMT-LLM** (arXiv 2506.12059) | Uses **two-stage filtering** of a large bias list down to the relevant rare words, then puts them in the LLM prompt. [13] | Same shape: filter first, bias second. |
| **Huber & Waibel** (arXiv 2608.05759) | Word-list biasing cut biased-word WER by up to 88 % relative. Speech LLMs are **sensitive to the number of distractors and their order** in the prompt. [14] | Qwen3-ASR hotwords must be few and ordered by relevance. |
| **Qwen3-ASR** | Trained to use the context in its system prompt. mlx-audio exposes this as `system_prompt`/hotwords. One integration fixed "incubator" → "Ecobee" with a prompt of "Vocabulary: Ecobee." [15] | The hotword path for a future engine (§3.4). |
| **Phonetic NE correction** (DANCER 2403.17645; RAG pipeline 2608.22872; DeRAGEC 2506.07510) | Standard pipeline: phonetic code (Double Metaphone) blocks candidates, then edit distance re-ranks, then **a threshold accepts**. **Homophone confusion grows with list size.** DeRAGEC filters retrieved candidates by phonetic score first and gets −28 % WER. [16][17][18] | Our core for Parakeet. It runs on-device in microseconds. |
| **LLM post-correction** (2505.17410; GEC-RAG 2501.10734) | A text-only LLM **over-corrects** and fails on rare words. It works when it is given N-best lists plus phonetic context. [19][20] | Not v1. It would need Ollama (opt-in, slow) and LLM_ENGINE.md shows rules beat bigger models here. |
| **Hinglish normalization** (1604.03136; 1804.00804; `dhvani`) | Romanized Hindi has "no universal protocol". Variants (bahut/bohot/boht/bhot) are found by phonetic folding and by sharing the same context. Rule-based noisy-channel normalization reached 74 % accuracy. [24][25][26] | Automatic folding guesses wrong a quarter of the time, so we **learn the user's choice** (proposals) and only fold strictly. |
| **Indian-English phonology** | v/w merge (व sits between them). th → t/d. Aspirated/retroflex t, d. Vowel-length confusions (ship/sheep). [21][22] | These set the **cheap-substitution pairs** in our phoneme distance. |

**How apps see the user's edit after a paste.** No vendor documents this.
The AX route is: keep the focused `AXUIElement` and its `AXValue` right after
the paste, then compare later values. AXObserver notifications need a run loop
and are unreliable per app [23]. Wispr's "press Enter" is a clue: they wait
for the edit to *settle*. Electron/Chrome expose `AXValue` only when
accessibility is on. Secure fields expose nothing.

**On-device summary.** Phonetic + edit-distance matching, confidence gating
(Parakeet exposes per-token `p`), AX screen reading and Contacts are all local
and cheap. N-best is not available (Parakeet runs greedy here). LLM correction
stays out of v1.

## Sources
[1] wispr.notion.site/Dictionary-1992ebdc733481a08064efd983f19f0f ·
[2] superwhisper.com/docs/modes/super · [3] superwhisper.com/docs/common-issues/context ·
[4] aquavoice.com/use-cases/arc · [5] dynamicbusiness.com/ai-tools/aqua-voice-voice-to-text-for-professionals.html ·
[6] dummies.com/article/how-to-build-dragon-professional-individual-vocabulary-from-sent-emails-138642 ·
[7] nuance.com/products/help/dragon15/dragon-for-pc/enx/dpg-cp/Content/Vocabulary/adding_words_to_your_vocabulary.htm ·
[8] arxiv.org/abs/1603.03185 · [9] arxiv.org/abs/2409.15353 · [10] developer.apple.com/forums/thread/650927 ·
[11] support.google.com/gboard/answer/12373137 · [12] arxiv.org/abs/2505.19179 ·
[13] arxiv.org/abs/2506.12059 · [14] arxiv.org/abs/2608.05759 ·
[15] huggingface.co/Qwen/Qwen3-ASR-1.7B-hf; github.com/Blaizzy/mlx-audio-swift/pull/126 ·
[16] arxiv.org/abs/2403.17645 · [17] arxiv.org/abs/2608.22872 · [18] arxiv.org/abs/2506.07510 ·
[19] arxiv.org/abs/2505.17410 · [20] arxiv.org/abs/2501.10734 ·
[21] talkdrill.com/blog/pronunciation/indian-english/indian-english-pronunciation/ ·
[22] brainscape.com/flashcards/phonological-differences-in-indian-engli-16677926/packs/22267740 ·
[23] lists.apple.com/archives/accessibility-dev/2013/Jan/msg00010.html ·
[24] arxiv.org/abs/1604.03136 · [25] arxiv.org/abs/1804.00804 · [26] pypi.org/project/dhvani/
