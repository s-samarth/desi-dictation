# Review before paste (implementation)

**Status:** built 2026-10-28 on branch `feat/review-before-paste` (on top of
PR #14). Tests, preflight and the confidence measurement ran on a Mac (M3).
**Not checked live:** the panel taking the keyboard and handing the paste
back to the app you dictated into. That needs a person at the mic.
Plan: [VOCABULARY_NEXT.md](../VOCABULARY_NEXT.md) §2.

**Problem.** Some words come out wrong, and today you only find out after
they're pasted. **Answer.** An opt-in panel between transcription and ⌘V
shows the text with the shaky words underlined and offers alternatives from
your own words.

## What the user sees

Dictation → Options → **Review before paste**: Off (default) / **Only when
unsure** / **Always**. The panel:

- text in an editable box, unsure words underlined (orange dots);
- **Tab** / **⇧Tab** jump between them; the word is selected and its
  alternatives show as "Maybe: 1 Saraswat" (low confidence) or "Sounds
  like: 1 Claude" (sound-alike);
- **1–5** pick an alternative while an underlined word is selected;
  otherwise digits type. Typing edits anything;
- **Enter** pastes, **Esc** copies (the panel's buttons do the same);
- **Remember your fixes?** lists each word changed in the panel with *Just
  this once* (default) / *Always* / *When it fits* (English, checker
  installed). Not shown for हिन्दी, which has no word list.

## How a dictation flows

1. **Engines** fill `TranscriptionResult.words` (`ScoredWords.swift`,
   `EngineWords.swift`): each word with its **weakest token's probability**.
   - whisper.cpp: `whisper_full_get_token_p`, text tokens only (id < EOT),
     a new word at each leading space. Token bytes are joined per word
     before decoding (a Devanagari letter can span two tokens).
   - Parakeet: `parakeet_token_data.p`, words at `is_word_start`.
   - transcribe.cpp: word rows, else token rows. **Qwen3-ASR has neither**
     (its max timestamp kind is NONE; asking for token timestamps fails), so
     its words are empty and it gets sound-alikes only.
2. **Controller:** `transcribeRaw` collects each call's words (chunks and
   tail) in `sessionWords` on the worker queue; they reach `deliver` on main.
3. **`deliver`** records timings first (reading time isn't latency), then
   `review(…)` (`DictationController+Review.swift`) decides; otherwise
   `commit` (history, then paste) as before.
4. **What's underlined** (`ReviewPlanner.unsure`):
   - `UnsureWords.find`: model words are aligned to the *final* text (after
     numbers, replacements, dictionary, vocabulary) by LCS on lowercased,
     punctuation-free words. Words our own rules wrote match nothing and
     are never underlined. Below the engine's threshold → underlined.
   - `ReviewAlternatives.soundAlikes`: words that sound like one of the
     user's words (dictionary + screen, `IndicPhonetics`, distance ≤ 0.35,
     same onset on the keys), skipping common words unless the dictionary
     names them, and skipping When it fits words the context checker
     already judged.
5. **Alternatives** (`ReviewAlternatives.candidates`): the dictionary pair
   for that word first, then sound-alikes, up to 5. English with the context
   checker installed: re-ordered by how well each fits the sentence
   (`ContextFit` scoring), off the main thread.
6. **Panel** (app target: `ReviewPanel`, `ReviewView`, `ReviewTextView`,
   `ReviewModel`): calls back once with `.paste(text)` or `.copy(text)`;
   `commit` pastes or copies. Fixes chosen to keep go to
   `PersonalDictionary` via `ReviewPlanner.remember` and the activity log.

**Focus.** The panel is a `.nonactivatingPanel` that *can* become key: it
takes the keyboard without activating Desi Dictation, so the app you
dictated into stays the active app. On Enter the panel closes, waits 0.12 s,
then `TextInserter` pastes as usual (it still waits for modifiers, FM#31).
A new dictation while the panel is open copies the waiting text.

## Measured (2026-10-28, M3, quick tier, `evals/word_confidence.py`)

A word is "wrong" if it's a substitution or insertion after the suite's
normalizer (nWER English, crWER otherwise). Recall = wrong words caught;
precision = underlined words that were wrong.

| Suite · model | Words | Wrong | Flag 5 %: recall / precision (p <) | Flag 10 % | Flag 15 % |
|---|---|---|---|---|---|
| English · Parakeet | 1,495 | 9.5 % | 27 % / 51 % (0.50) | **39 % / 37 %** (0.61) | 54 % / 34 % (0.72) |
| Hinglish · Prime | 852 | 14.9 % | 14 % / 42 % (0.57) | **32 % / 48 %** (0.71) | 45 % / 45 % (0.84) |
| हिन्दी · Vaani | 550 | 9.6 % | 21 % / 39 % (0.61) | **38 % / 36 %** (0.75) | 45 % / 29 % (0.83) |
| English · Qwen3-ASR | — | — | no per-word confidence | | |

**Against the plan's target** (lowest 5 % catches ≥ 40 % of errors): **not
met** (14–27 %). The target was out of reach for Hinglish by arithmetic:
with 15 % of words wrong, flagging 5 % can catch at most a third. What the
numbers do show is a real signal: an underlined word is wrong 36–51 % of
the time against 10–15 % for a random word, 3–5× better.

**Shipped thresholds** (`UnsureWords.threshold`): the ~10 % points above,
Parakeet 0.61, whisper 0.71 (measured on Prime; Apex/Turbo use it too),
Vaani 0.75. A 20-word dictation gets about two underlines, one of them
usually a real error. The setting is off by default, and "Always" doesn't
depend on these numbers.

## Changing it

- Thresholds: `UnsureWords.threshold(forModel:)`. Re-run
  `cd evals && uv run word_confidence.py` (add `--suites english --models
  qwen3-asr` etc.) and pick from its `by_rate` rows.
- Sound-alike looseness: `ReviewAlternatives.maxSoundDistance` (0.35;
  the auto-corrector uses 0.2 because it *applies* changes).
- Keys: `ReviewTextView.keyDown` (digits), the coordinator's
  `doCommandBy` (Tab, Enter, Esc).
- Tests: `DesiTests/ReviewTests.swift`. UI snapshot: `UISnapshots`
  renders `review.png`.

## Not built

- Confidence for Qwen3-ASR: needs token rows from transcribe.cpp's Qwen
  family (upstream change).
- Alternatives from the speech model itself (n-best / beam): whisper's
  greedy decode keeps one hypothesis.
- Translate/tone output is reviewed as text, but its words can't carry
  confidence (they're the LLM's, not the speech model's).
