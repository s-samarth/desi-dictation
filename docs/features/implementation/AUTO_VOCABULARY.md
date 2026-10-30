# Auto vocabulary — implementation

**Status:** built 2026-10-28 (branch `feat/auto-vocabulary`), all switches
**off** by default. **2026-10-29: the corrector no longer applies anything.**
"plus" → "PRs" (on screen), "pressed" → "Pushed", "Another" → "Enter" were
written into real messages; the user's rule is that only words they told it
to write are written. `VocabularyCorrector`'s fixes are now recorded as
suggestions (`VocabularySession.recordSuggestions`) and shown in Review
before paste as underlines with the guess as choice 1 (reason "Did you
mean:"). Exact dictionary pairs and When it fits still apply. Read the
"fix" wording below as "suggest". Research and sources: [AUTO_VOCABULARY_RESEARCH.md](AUTO_VOCABULARY_RESEARCH.md)
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
| Post-paste watch (every 0.3 s, 2 min, settles after 2 s or on send) | `EditWatcher.swift`, `EditTracker.swift` (pure timing) | tracker ✓, AX live only |
| Electron accessibility switch (`AXManualAccessibility`) | `AccessibilityPrimer.swift` | live only (FM#37) |
| "What it's been doing" list (memory only) | `VocabularyActivity.swift`, `VocabularyActivityView.swift` | — |
| One dictation's state (screen terms, hotwords, fixes) | `VocabularySession.swift` | — |
| Pipeline hooks | `DictationController+Vocabulary.swift` | — |
| UI: Vocabulary page (switches, waiting suggestions, your words), popup, History rows | `SmartVocabularyView.swift` (`VocabularyPane`), `GuidePane.swift` (plain-words explainer, sections 4–7), `VocabularyPromptPanel.swift`, `HistoryView.swift` | — |

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

   Parakeet and whisper.cpp don't conform. `EngineRouter` forwards to the
   active engine, and `QwenASREngine` passes the terms as transcribe.cpp's
   `transcribe_run_params::vocabulary` (the runtime formats them for
   Qwen3-ASR). Measured on one synthetic clip: without hotwords Qwen wrote
   "Pinkavia and Mr. Saras went about the eco B rollout"; with
   `Kavya,Saraswat,Ecobee` it wrote "Kavya … Saraswat … Ecobee" (+0.03 s).
   Reproduce with `desi-cli <model> clip.wav english --hotwords "A,B"`.
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
     in Vocabulary → Waiting for you.

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
   - "Never".

   Rejected pairs are never applied or proposed again. Vocabulary →
   Advanced → "Allow again" resets the list. **"Not now" is a snooze, not a
   rejection** (FM#38): the pair is asked again on its 3rd sighting, then
   6th, 12th and every 24th (`snoozed` in `autovocab.json`). Files written
   before this (no `version`) drop the pairs two "Not now"s had rejected.
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
  app. Every 0.3 s, so a chat edit sent with Enter is still caught: when the
  field empties, the last text before it is judged (`EditTracker`).
- **Electron is switched on, browsers aren't (FM#37):** Electron apps report
  no focused element at all until `AXManualAccessibility` is set, which made
  the whole feature dead in Claude, Slack, VS Code. We set it when such an
  app comes to the front (a little memory for that app). Chrome would need
  `AXEnhancedUserInterface`, which upsets window managers, so not yet.
- **Two neighbouring words fixed** ("Samar Saraswath" → "Samarth
  Saraswat") are judged word by word; before FM#37 they counted as a rewrite
  and nothing was proposed. Proposals also need the same first sound, like
  the corrector (Sharma → Verma is a different name).
- **Never silent learning** (PERSONAL_DICTIONARY.md rule). Screen terms fix
  words but are never stored. The one automatic write is a *rejection* after
  an undo: it only stops a change.
- **Latency:** the screen read overlaps recording, and correction takes
  milliseconds. Everything is off by default, so the latency gate is
  unaffected.
- **Built since (2026-10-28):** the context scorer for sound-alike real
  words (cloud/Claude), [CONTEXT_FIT.md](CONTEXT_FIT.md) ("When it fits"),
  and Review before paste with per-word ASR confidence,
  [REVIEW_BEFORE_PASTE.md](REVIEW_BEFORE_PASTE.md). Confidence only
  underlines words for the user; the corrector still never changes a real
  word on a dictionary term alone.
- **Deferred:**
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

## Checking it on a real window

"Use names on screen" and "Hinglish: match my spelling" depend on reading
another app's window, which unit tests can't cover. `ScreenCheck` reads the
front window the way a dictation does at key-down, runs a sentence through
the corrector, and writes what Review would offer:

```bash
open -n -a "Desi Dictation" --args --screen-check 3 "send it to Kartick" english /tmp/check.txt
# within 3 s, click into a text field in the window to test; then:
cat /tmp/check.txt
```

It has to run as the installed app. A tool started from a terminal (or by
Claude) gets "cannot complete" (-25204) from the Accessibility server for
every app, even though its `AXIsProcessTrusted()` says yes (2026-10-30). That
run has its parent's grant, not an Accessibility identity of its own.
`open` makes LaunchServices start the app as itself, with its own grant.
