# Auto vocabulary — implementation

**Status:** built 2026-10-28 (branch `feat/auto-vocabulary`), all switches
**off** by default. Research and sources: [AUTO_VOCABULARY_RESEARCH.md](AUTO_VOCABULARY_RESEARCH.md)
(`[n]` = its source list).
**Goal:** the user never maintains a dictionary by hand, and **an edit the
user makes after a dictation is respected**. A retyped word becomes a
one-click proposal, and an undone auto-fix is never made again.
**Pain 1:** the model hears a name correctly but spells a plausible wrong
word: "Rohan" → "Rowan", "Saraswat" → "Saraswath" / "Sara swat", "Kavya" →
"Cavia". The cause is the accent (v/w, t/th, d/dh) or context (the LM prefers
a common word).
**Pain 2 (Hinglish):** Apex writes *nahin* when the user writes *nahi*. Roman
Hinglish has no standard spelling, and each person is self-consistent
(P1_HINGLISH_ACCURACY.md §4), so the user's own spelling is the target.

| Mode | Model | How vocabulary reaches it |
|---|---|---|
| English (default) | Parakeet TDT 0.6B v3 (libparakeet) | post-correction (the model can't be biased) |
| English — Accurate (engine: separate PR) | **Qwen3-ASR-1.7B** (MLX) | **hotwords** via `HotwordBiasing`, then post-correction |
| Hinglish, any→English | Hinglish Apex (whisper.cpp) | post-correction **+ the user's spelling style** |
| हिन्दी | multilingual whisper | skipped (Devanagari) |

**Why this shape (research):**
- Wispr Flow auto-learns corrected spellings; Dragon reviews before adding;
  Superwhisper and Aqua read the window via AX, and Aqua keeps it in RAM only.
- Bias lists must be short and relevant [12][13][14].
- Unbiasable models use phonetic blocking → edit distance → threshold
  [16][17][18].
- LLM correction over-corrects [19]. Hinglish normalizers are ~74 % accurate
  [24], so we learn the user's own choices.

## Where it lives (`DesiDictationKit/Vocabulary/`, all new files)

| Piece | File | Pure / tested |
|---|---|---|
| Sound key + weighted distance tuned for Indian English | `IndicPhonetics.swift` | ✓ |
| Protected words (~1,000 English + ~300 Hinglish) | `CommonWords.swift` | ✓ |
| "Is it a real word?" (`/usr/share/dict/words` + suffix stripping) | `WordLexicon.swift` | ✓ |
| Whole-word tokens (skips emails, URLs, acronyms, contractions) | `WordTokens.swift` | ✓ |
| The corrector and its tiers | `VocabularyCorrector.swift`, `TermIndex.swift` | ✓ |
| Hinglish variants (strict key, style edits, field spelling) | `HinglishVariants.swift` | ✓ |
| Paste-vs-now diff, and what's worth proposing | `EditDiff.swift`, `CorrectionLearner.swift` | ✓ |
| Names from screen text | `TermExtractor.swift` | ✓ |
| Qwen3-ASR seam + ≤ 30-term selection | `HotwordSelector.swift` | ✓ |
| Switches, proposals, reject list (`autovocab.json`) | `AutoVocabularyStore.swift` | ✓ |
| AX reads (timeout-bounded, no secure fields, not our app) | `AXReader.swift`, `ScreenContextReader.swift` | live only |
| Post-paste watch (1 Hz, 30 s, settles after 2 s) | `EditWatcher.swift` | diff ✓, AX live only |
| One dictation's state (screen terms, hotwords, fixes) | `VocabularySession.swift` | — |
| Pipeline hooks | `DictationController+Vocabulary.swift` | — |
| UI: switches + suggestions, popup, History rows | `SmartVocabularyView.swift`, `VocabularyPromptPanel.swift`, `HistoryView.swift` | — |

Tests: `DesiTests/VocabularyCorrectorTests.swift`, `VocabularyLearningTests.swift`.

## The flow, one dictation

1. **Key down** (`beginVocabulary`): stop any old edit watch. If enabled, read
   the screen on a background queue while the user talks:
   - focused field text (±2,000 characters around the caret);
   - the window title;
   - up to 400 static texts, breadth-first.

   AX timeout is 100 ms per message, with a 150 ms budget overall.
   `TermExtractor` keeps CamelCase words, capitals mid-sentence, and words in
   short name labels ("Rohan Mehta"). It drops sentence-start capitals,
   lowercase words and common words (Hindi words typed by others never become
   terms). It also computes hotwords.
2. **Each engine call** (`applyHotwords`): an engine conforming to
   `HotwordBiasing` gets this dictation's ≤ 30 terms:
   1. field terms;
   2. window terms;
   3. dictionary written forms.

   Parakeet and whisper.cpp don't conform. To hook up Qwen, add in
   `EngineRouter.swift`: `extension EngineRouter: HotwordBiasing {
   public func setHotwords(_ t: [String]) { (active as? HotwordBiasing)?.setHotwords(t) } }`.
3. **After transcription** (work queue): legacy rules → PersonalDictionary
   (exact pairs) → **`VocabularyCorrector`** → translate/tone. Anything the
   screen read hadn't finished by then is skipped.
4. **Paste:** History stores the fixes and the pre-fix text, and the overlay
   says "Fixed: Rowan → Rohan".
5. **Watch** (if learning is on, or a fix was made): `EditWatcher` polls the
   same focused element. Once the field settles, `EditDiff` aligns our words
   with the field's.
   - If the user typed an auto-fix back, `respect()` rejects that pair at once
     and the popup says "Got it".
   - Any other spelling-like edit becomes a proposal: the popup asks *Always
     write X as Y?* with **Add** / **Not now**, and the proposal is also queued
     in Vocabulary → Suggestions.

   Field text lives only in the watch and is dropped when it ends.

## Guards against wrong replacements (all in pure code)

1. Whole words, length ≥ 3. Possessive "'s" is kept outside the replacement.
   Emails, URLs, handles, acronyms and contractions are skipped.
2. **Sound + spelling:**
   - phoneme distance ≤ 0.2 (v/w, t/d, s/sh, j/z, g/k cost 0.3; h and vowels
     cost 0.5);
   - spelling similarity ≥ 0.5;
   - same first sound (Soundex-style blocking; stops "defeating" → "Feeting").
3. **Near-tie → no change.** Each word only sees the terms in its length band.
4. **Tiers by the heard word:**
   - *Common* → never replaced (only an exact dictionary pair changes it).
   - *Real word* ("rowan"; inflections stripped, so "meetings" counts) → only
     when the term is on screen in this dictation. In Hinglish every
     non-common word is in this tier, and a fix must keep the last letter,
     because Hindi inflects at the end (*milenga/milenge*).
   - *Non-word* ("Saraswath") → against any enabled source.
5. **Reject list** (`rejected` in `autovocab.json`). A pair goes on it from:
   - an undo in the field;
   - History → "Don't change X to Y again";
   - "Never", or two "Not now"s.

   Rejected pairs are never applied or proposed again. Vocabulary →
   "Allow them again" resets the list.
6. **Visible:**
   - an overlay notice after the paste;
   - a green "fixed:" line on the History row;
   - History → "Copy as heard (before fixes)".

**Proposal rules** (`CorrectionLearner`; looser than auto-fixing, because the
user confirms):
- **Proposed:**
  - sound ≤ 0.35 with spelling ≥ 0.4, or spelling ≥ 0.6;
  - capitalizing a non-common word ("kavya" → "Kavya");
  - Hinglish style edits (`isStyleEdit`: vowel length, final nasal, *h*
    after a consonant, dropped inner vowels like *nhi*/*nahi*).
- **Not proposed:**
  - grammar between common words (*their/there*);
  - inflections (*deploy/deployed*);
  - Hindi inflection pairs (*raha/rahi*, *hai/hain*);
  - rewrites of more than 4 words.

**Hinglish field spelling** (its own switch): if the field already writes a
strict variant ≥ 2 times (*kya*) and never uses Apex's spelling (*kyaa*), the
field's spelling wins for this dictation. It's never learned.

## Decisions

- **No new dependencies.** Double Metaphone (~1k lines, Anglo rules) splits
  exactly the merges an Indian accent makes. `IndicPhonetics` is ~120 lines.
- **No Contacts** (user decision, 2026-10-28): no extra permission prompt.
  Names come from the screen, your corrections and your dictionary.
- **Common-word list hand-curated:** Norvig's frequency data has no licence.
  If `/usr/share/dict/words` is missing, every word counts as real, which is
  the safe direction.
- **Polling over AXObserver:** no per-app run loop, and delivery varies by
  app. Chrome/Electron web text is visible only when their accessibility mode
  is already on; we don't force it (it slows those apps).
- **Never silent learning** (PERSONAL_DICTIONARY.md rule). Screen terms fix
  words but are never stored. The one automatic write is a *rejection* after
  an undo: it only stops a change.
- **Latency:** the screen read overlaps recording, and correction takes
  milliseconds. Everything is off by default, so the latency gate is
  unaffected.
- **Deferred:**
  - per-word ASR confidence: needs `TranscriptionResult` and engine changes,
    left until the Qwen PR lands. Until then a dictionary term alone can't
    change a real word, the stricter rule;
  - the Qwen engine itself;
  - LLM post-correction;
  - per-app vocabularies;
  - Apex `initial_prompt` biasing (a fine-tune may be destabilized by a
    prompt; measure on the Hinglish quick tier plus the silence clips first).

## Changing it

- **Thresholds:** they're the constants at the top of `VocabularyCorrector`,
  and the false-positive tests pin them. Add a failing example before
  loosening anything.
- **A new biasable engine:** conform to `HotwordBiasing`.
- **A new source:** add a `VocabularySource` case. Its `isOnScreen` decides
  whether it may replace real words.
