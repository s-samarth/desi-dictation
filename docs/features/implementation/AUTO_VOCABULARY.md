# Auto vocabulary — research, plan, decisions

**Status:** plan, awaiting approval (2026-10-28). No Swift written yet.
**Goal:** the user never maintains a dictionary by hand. Names and terms come
from three places: corrections the user makes, the window they're dictating
into, and (opt-in) Contacts. Then they're applied without inventing errors.
**The pain it targets:** the model hears the name correctly, but spells a
*plausible wrong word*: "Rohan" → "Rowan", "Saraswat" → "Saraswath" /
"Sara swat", "Kavya" → "Cavia". The cause can be accent (v/w, t/th, d/dh merge
in Indian English) or context (the language model prefers a common word).

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

## 2 · Plan

### (a) Learn from corrections: `EditWatcher`
1. After a `.pasted` outcome, read the focused element via AX: role, `AXValue`,
   `AXSelectedTextRange`. Secure fields, values over 20k characters and
   non-string values are skipped.
2. Poll that **same element** once a second for 30 s. Stop early if focus
   moves to another element/app, or a new dictation starts.
3. When the value has been stable for 2 s, diff it against the post-paste
   snapshot. Common prefix/suffix gives the edited span, which must overlap
   our inserted span. A word-level LCS alignment of inserted vs edited words
   gives 1→1, 1→2 and 2→1 substitutions.
4. A pair is proposed only if it looks like a *spelling fix*, not a rewrite:
   - sound + spelling similarity pass §3's thresholds;
   - the two words aren't both common words ("their" → "there" is grammar);
   - the pair isn't already in the dictionary or the reject list.
5. Proposal: a clickable, **non-activating** panel by the overlay (never takes
   key focus) says *Always write "Rowan" as "Rohan"?* with **Add**/**Not now**.
   Unanswered proposals queue in **Settings → Dictionary → Suggestions**.
   "Add" calls `PersonalDictionary.add`. "Not now" ×2 sends the pair to the
   reject list. Field text is RAM-only and dropped when the watch ends.

### (b) Screen context: `ScreenContextReader` + `ContactsVocabulary`
- **At recording start**, on a background queue with a 100 ms AX messaging
  timeout and a 150 ms total budget, read from the frontmost app:
  - focused field text (±2,000 characters around the caret);
  - focused window title;
  - up to 400 `AXStaticText`/`AXTextField` values from the focused window
    (breadth-first, depth ≤ 12).
- `TermExtractor` keeps likely names and terms: Capitalised words not at
  sentence start, CamelCase, ALL-CAPS ≥ 2 characters, `@handles`. It drops
  common words. Capped at 150 terms.
- Held in memory for **this dictation only**. Cleared after paste. Never
  written to disk, history or logs.
- **Contacts** (separate opt-in): `CNContactStore` given/family/nick names,
  loaded into memory on enable and refreshed on `CNContactStoreDidChange`. We
  store nothing.

### (c) Use it per engine: `VocabularyCorrector` + engine hook
For each dictation, `ActiveVocabulary` = dictionary written forms ∪ this
dictation's screen terms ∪ contact names. Each term is tagged with its source.

**Parakeet / whisper (no biasing) → post-correction**, after the dictionary
step. For each output word (and each adjacent pair, for "Sara swat"), find the
terms whose phonetic key is close, then decide with the rules in §3.
`TranscriptionResult` gains optional per-word confidence. Parakeet's word
confidence is the min of `parakeet_full_get_token_p` over its sub-tokens.
Whisper's comes from `whisper_full_get_token_p`.

**Future Qwen3-ASR → hotwords.** A protocol
`HotwordBiasing { func setHotwords(_: [String]) }`. `EngineRouter` passes ≤ 30
terms when the active engine conforms. Since there's no transcript yet,
`HotwordSelector` ranks them: screen terms (focused field first) →
dictionary → contacts that are also on screen. Post-correction still runs
after (idempotent). **Cohere Transcribe:** no biasing, so post-correction only.

### Settings and onboarding (all **off** by default)
In Settings → Dictionary, a new **"Smart vocabulary"** section:
- [ ] Suggest words from my corrections
- [ ] Fix near-misses of my names and words
- [ ] Read names from the window I'm dictating into
- [ ] Use names from Contacts

Each toggle has a one-line privacy note. Onboarding gets one optional page
with the same toggles. The Contacts toggle triggers the system prompt. Info.plist
gains `NSContactsUsageDescription`.

## 3 · Wrong-replacement guards (all enforced in pure, tested code)
1. **Whole words only**, with a minimum length of 3. Never touch Devanagari
   (हिन्दी mode is skipped entirely).
2. **Phoneme distance.** `IndicPhonetics.key()`: lowercase, digraphs
   (ph→f, bh→b, dh→d, th→t, kh→k, gh→g, sh→s, ch→c, ck→k), w→v, z→j, x→ks,
   collapse doubles, drop h after a consonant, vowels folded to one class
   except at the start. Then a weighted Levenshtein on the *keys*, where
   Indian-English confusions (v/w, t/d, s/sh, j/z, vowel↔vowel) cost 0.3.
   Accept only if normalized distance ≤ 0.2 **and** spelling similarity
   ≥ 0.5 (Levenshtein ratio on the raw words).
3. **Short relevant list.** Candidates come only from the phonetic bucket of
   each output word. Hotwords are capped at 30. The best match must beat the
   runner-up by a clear margin, otherwise no change.
4. **Tiers by what the heard word is:**
   - *Common word* (built-in list of ~1,000 English + ~300 Hinglish words):
     **never replaced.** Only a confirmed dictionary pair changes it, which
     the existing exact-match step already handles.
   - *Real but uncommon word* (in macOS `/usr/share/dict/words`, e.g. rowan,
     cavia): replaced only if the term is **on screen in this dictation**, or
     is a dictionary term **and** the word's ASR confidence is < 0.6. Contacts
     alone never override a real word. In Hinglish mode every non-common word
     is treated as this tier.
   - *Non-word* (Saraswath, Kavia): replaced against any enabled source.
5. **Reject list:** pairs the user undid are never applied or proposed again.
6. **Visible and undoable:**
   - After the paste, an overlay notice says "Fixed: Rowan → Rohan".
   - The History row lists each fix with its source.
   - Right-click a fix → "Don't change this again", which adds it to the
     reject list.
   - "Copy original" copies the pre-fix text, which is kept as History `raw`.
7. **Tests** go in `DesiTests/AutoVocabularyTests.swift`:
   - false positives: common words untouched; "rise"/"origin" untouched
     without screen evidence; Hinglish words untouched; no partial-word edits;
     near-ties rejected; rejected pairs skipped;
   - true positives: Saraswath, Sara swat, Kavia, Rowan-with-screen;
   - edit-diff extraction (spelling fix vs rewrite);
   - term extraction.

## 4 · Decisions (and the one that needs approval)
- **No new dependencies.** Double Metaphone is ~1k lines of English-specific
  code that also scores *worse* on Indian merges. The in-repo
  `IndicPhonetics` is ~120 lines and tuned to our confusions. Contacts and
  Accessibility are Apple system frameworks we already link or that ship with
  macOS.
- **Common-word list is hand-curated in-repo.** Norvig's count_1w has no data
  licence, so it's out. `/usr/share/dict/words` (Webster's 2nd, public domain,
  on every Mac) is used only to tell "real word" from "non-word". If it's
  missing, every word counts as real (the safe direction).
- **Polling over AXObserver** for the edit watch: it's simpler, needs no run
  loop per app, and costs nothing measurable at 1 Hz for 30 s.
- **Proposals, never silent learning**, as PERSONAL_DICTIONARY.md requires.
  Screen terms and contacts *fix* words but are never *learned* into the
  dictionary.
- **Latency.** The screen read overlaps recording. Correction is O(words ×
  bucket) and takes under 5 ms. Everything is off by default, so the latency
  gate is unaffected.
- **Out of v1:** LLM post-correction, Whisper `initial_prompt` biasing
  (silence-hallucination risk, P2-S2), and per-app vocabularies.

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
[23] lists.apple.com/archives/accessibility-dev/2013/Jan/msg00010.html
