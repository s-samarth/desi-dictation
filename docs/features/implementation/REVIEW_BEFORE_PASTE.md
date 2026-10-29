# Review before paste (implementation)

**Status:** built 2026-10-28 (PR #16, merged); strictness, "odd in context"
and the panel sized to the text added 2026-10-29 (`feat/review-strictness`).
Tests, preflight and both measurements ran on a Mac (M3).
**Not checked live:** the panel taking the keyboard and handing the paste
back to the app you dictated into. That needs a person at the mic.
Plan: [VOCABULARY_NEXT.md](../VOCABULARY_NEXT.md) §2.

**Problem.** Some words come out wrong, and today you only find out after
they're pasted. **Answer.** An opt-in panel between transcription and ⌘V
shows the text with the shaky words underlined and offers alternatives from
your own words.

## What the user sees

Dictation → **Review**: **Review before paste** Off (default) / **Only when
unsure** / **Always**, and **Underline words** Conservative / Moderate /
**Moderate** (default; see Strictness). Onboarding step 5 offers both. The
panel:

- opens sized to the text so it can be checked in one look: 680 pt wide
  (820 past 400 characters), a text box of 6 to 20 lines, scrolling only
  past 20 or when the screen is shorter (`ReviewLayout`). That size is the
  panel's minimum; it can be dragged bigger (FM#41);
- text in an editable box, unsure words underlined in dots: **orange** when
  the speech model wasn't sure ("Hard to hear. Maybe:") or the word sounds
  like one of yours ("Sounds like:"), **purple** when it was heard clearly
  but is odd in its sentence ("Odd here. Maybe:"). Nothing is changed;
- **Tab** / **⇧Tab** jump between them; the word is selected and its
  alternatives show after the reason;
- **1–5** pick an alternative while an underlined word is selected, **0**
  ("Looks right") drops its underline and leaves the word; otherwise digits
  type. Typing edits anything. The header's count follows the underlines
  still in the text (`ReviewModel.remaining`);
- **Enter** pastes, **Esc** copies (the panel's buttons do the same);
- **Remember your fixes?** lists each word changed in the panel with *Just
  this once* / *Always* / *When it fits*, **When it fits by default** where
  offered (English, llama runtime in the build; user decision 2026-10-29),
  else Just this once. Without the checker downloaded, a note says it
  judges sentences only once installed. Not shown for हिन्दी.
- The **context checker's status** (installed, or Get · 397 MB, and what it
  adds) shows under the Review settings and on the Vocabulary page
  (`ContextCheckerRow`), and Guide card 10 lists what needs it.

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
   - **The vocabulary corrector's guesses** (near-misses of dictionary
     words, names on screen, Hinglish field spellings): never applied since
     2026-10-29, only underlined here with the guess as choice 1 ("Did you
     mean:"). Found by whole-word match in the final text.
   - `UnsureWords.find`: model words are aligned to the *final* text (after
     numbers, replacements, dictionary, vocabulary) by LCS on lowercased,
     punctuation-free words. Words our own rules wrote match nothing and
     are never underlined. Below the engine's threshold → underlined.
   - **Odd in context** (`SentenceSurprise`, context checker installed,
     English and हिन्दी): the checker's model reads the final text once
     (`desi_lm_token_scores`, per-token log-probabilities after the neutral
     `ContextFit.prompt`) and each word's surprise is the sum of −log p over
     its tokens. Above the strictness bar → underlined, unless it has digits
     or is one of the user's dictionary words (both written on purpose).
     **Everyday words** (`OrdinaryWords`) must clear the bar by 8 more nats:
     see "Everyday words" below.
     Long text is scored in sentence groups of ≤ 1,200 bytes (512-token
     context). Runs off the main thread, so with the checker installed
     `review` always takes the dictation and commits it itself when nothing
     needs a look; the checker warms up at key-down when review is on.
   - `ReviewAlternatives.soundAlikes`: words that sound like one of the
     user's words (dictionary + screen, `IndicPhonetics`, distance ≤ 0.35,
     same onset on the keys), skipping **everyday words** unless the
     dictionary names them, and skipping When it fits words the context
     checker already judged. Other forms of the same word ("Models" for
     "model") are never offered.
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

## Everyday words (2026-10-29)

First live use (Qwen3-ASR, review Always, checker not installed) underlined
five fine words in a casual sentence: "general", "reasoning", "works",
"model"… All were **sound-alikes of screen words**: a Claude chat is full of
capitalised headings ("Models", "Moderate"), which `TermExtractor` takes as
terms. And casual speech makes everyday words look odd to the checker too.

`OrdinaryWords` answers "is this an everyday word?": macOS's own word list
(`/usr/share/dict/words`, Webster's 2nd, 236k lowercase entries; capitalised
names excluded) plus `CommonWords`, with endings stripped (models → model,
running → run, making → make). Names (Luffy, Shlok, Prabjot, Kavya),
acronyms (PC) and garbled words are not in it. Two rules:

- a screen word never underlines an everyday word by sound;
- an everyday word must be 8 nats odder than the bar to be underlined as
  odd in context (`ReviewStrictness.everydayExtra`). Leaving everyday words
  out entirely was tried: Qwen3-ASR then catches at most 19 % of mistakes,
  because many of its mistakes are real words.

The quick tier is read-aloud, grammatical text, so it can't show what this
saves on casual dictation; it shows the cost (below). On the sentence that
prompted it, Liberal now underlines one word ("onboarding", too modern for
the 1934 list) instead of five, and the "one PC Luffy" sentence gets PC,
Luffy, Shlok and Prabjot and no everyday words.

## Strictness

One setting decides how readily words are underlined. Every level uses both
signals; they differ in how many words they may underline (a share of all
words: Conservative ~15 %, Moderate ~8 %, Liberal ~4 %). For each engine,
`evals/review_strictness.py` found the thresholds that catch the most wrong
words within that share; `ReviewStrictness.swift` ships rounded ones, in
order (Conservative underlines the most).

**Measured before the everyday-word rule** (2026-10-29, M3, quick tier; recall = wrong words caught,
precision = underlined words that were wrong):

| Suite · model (wrong words) | Signal | Conservative | **Moderate** | Liberal |
|---|---|---|---|---|
| English · Parakeet (9.5 %) | confidence only | 54 % / 34 % | 35 % / 41 % | 23 % / 59 % |
| | **+ odd in context** | **56 % / 36 %** | **40 % / 49 %** | **25 % / 67 %** |
| English · Qwen3-ASR (7.3 %) | confidence | none | none | none |
| | **odd in context** | **41 % / 22 %** | **33 % / 30 %** | **24 % / 49 %** |
| Hinglish · Prime (14.9 %) | confidence only (shipped) | 44 % / 46 % | 24 % / 45 % | 13 % / 57 % |
| | + odd in context (not shipped) | 45 % / 45 % | 24 % / 46 % | 14 % / 53 % |
| हिन्दी · Vaani (9.6 %) | confidence only | 45 % / 31 % | 28 % / 34 % | 17 % / 41 % |
| | **+ odd in context** | **47 % / 30 %** | **30 % / 39 %** | **21 % / 46 %** |

**With the everyday-word rule** (shipped; English only, Devanagari is never
"everyday"):

| English | Conservative | **Moderate** (default) | Liberal |
|---|---|---|---|
| Parakeet | 56 % / 35 % | 43 % / 49 % | 28 % / 67 % |
| Qwen3-ASR | 42 % / 22 % | 32 % / 29 % | 22 % / 40 % |

Shipped thresholds (confidence below / surprise above, nats; English
everyday words +8):

| | Conservative | Moderate | Liberal |
|---|---|---|---|
| Parakeet | 0.66 / 7.0 | 0.50 / 8.0 | 0.43 / 14.0 |
| Qwen3-ASR | — / 1.5 | — / 3.6 | — / 8.0 |
| whisper (Prime, Apex) | 0.84 / — | 0.64 / — | 0.52 / — |
| Vaani | 0.59 / 11.3 | 0.59 / 19.4 | 0.54 / 25.3 |

**Default: Moderate** (briefly Liberal on 2026-10-29). Underlining fine
words costs trust: a review that cries wolf gets turned off. But the five
fine words of the first real use were sound-alikes of screen headings, now
fixed, not the strictness level. With that fixed, two real Qwen3-ASR
dictations decided it:

| Real dictation | Liberal | Moderate |
|---|---|---|
| "…does **Luke bomb** fit…" (meant "Shlok Bum") | nothing; panel didn't open | Luke (12.5), bomb (11.7) |
| casual sentence, all words fine but "onboarding" | onboarding | onboarding ("Yeah", 11.2, just under) |

Liberal's bar for an everyday word (8 + 8 = 16 for Qwen3-ASR) is above
what a name misheard as everyday words scores. Moderate's (3.6 + 8 =
11.6) caught it with no false underline, by thin margins (bomb +0.1,
"Yeah" −0.4): two sentences, not a measurement. Add real dictations like
these to the eval before retuning.

How to read it:

- **English is where the checker pays off.** With Parakeet it lifts
  Moderate from 35 % to 40 % of mistakes caught while making underlines
  more often right (41 → 49 %). For Qwen3-ASR, which gives no confidence,
  it is the only signal: from nothing underlined to a third of mistakes.
- **Hinglish: off.** The checker's model has seen little romanised
  Hinglish, so most words look odd to it; it caught almost nothing
  confidence didn't. The checker's other variants (sentence openers
  discounted, surprise relative to the dictation's median) didn't help
  either. Revisit with a model that knows Hinglish.
- **हिन्दी: a small gain on a small sample** (53 wrong words; one word is
  2 points). Keep an eye on it.
- **Surprise also marks rare names**, which is wanted: their spelling
  can't be heard. The 2026-10-29 example ("watch one PC Luffy … a friend
  named Shlok Bum … called Prabjot", Qwen3-ASR) underlines Luffy, Shlok,
  Bum and Prabjot at Moderate; **"PC" (10.5) only at Conservative**.
  Raw surprise was as good as the other shapes tried, so it ships raw.
- Measured on read-aloud clips with few names; real dictation has more.
  Add real misses to the eval before retuning.

### Confidence alone (2026-10-28, `evals/word_confidence.py`)

| Suite · model | Words | Wrong | Flag 5 %: recall / precision (p <) | Flag 10 % | Flag 15 % |
|---|---|---|---|---|---|
| English · Parakeet | 1,495 | 9.5 % | 27 % / 51 % (0.50) | **39 % / 37 %** (0.61) | 54 % / 34 % (0.72) |
| Hinglish · Prime | 852 | 14.9 % | 14 % / 42 % (0.57) | **32 % / 48 %** (0.71) | 45 % / 45 % (0.84) |
| हिन्दी · Vaani | 550 | 9.6 % | 21 % / 39 % (0.61) | **38 % / 36 %** (0.75) | 45 % / 29 % (0.83) |

The first plan's target (lowest 5 % catches ≥ 40 % of errors) was not met
(14–27 %); for Hinglish it was out of reach by arithmetic (15 % of words
wrong, 5 % flagged). Underlined words are still wrong 3–5× more often than
a random word.

## Changing it

- Thresholds: `ReviewStrictness.swift`, mirrored in `SHIPPED` in
  `evals/review_strictness.py`. Re-run
  `DESI_CHECKER=<checker.gguf> uv run review_strictness.py` (add
  `--suites english --models qwen3-asr`; `--cached` re-analyses the last
  run); its "shipped" lines show how the current thresholds do.
- See one sentence's surprise: `desi-cli --surprise "text"` (checker from
  `$DESI_CHECKER` or the installed one).
- Sound-alike looseness: `ReviewAlternatives.maxSoundDistance` (0.35;
  the auto-corrector uses 0.2 because it *applies* changes).
- Keys: `ReviewTextView.keyDown` (digits), the coordinator's
  `doCommandBy` (Tab, Enter, Esc).
- Tests: `DesiTests/ReviewTests.swift`, `StrictnessTests.swift`. UI
  snapshots: `UISnapshots` renders `review.png` and `review-long.png`.

## Not built

- Suggestions from the checker itself: its own guesses for an odd word,
  kept only if they sound like what was heard, ranked by the whole
  sentence. Today an odd word with nothing in the dictionary or on screen
  says "no suggestions; type the right word".
- "When it fits" asking instead of guessing: a close call between swap and
  keep could underline the word with the swap as suggestion 1.
- Odd in context for Hinglish (see Strictness).

- Confidence for Qwen3-ASR: needs token rows from transcribe.cpp's Qwen
  family (upstream change).
- Alternatives from the speech model itself (n-best / beam): whisper's
  greedy decode keeps one hypothesis.
- Translate/tone output is reviewed as text, but its words can't carry
  confidence (they're the LLM's, not the speech model's).
