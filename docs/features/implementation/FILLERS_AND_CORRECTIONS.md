# Fillers and spoken corrections (implementation)

**Status:** built 2026-10-29 (`feat/fillers-corrections`). Tests, the filler
measurement and the correction rules ran on a Mac (M3); not yet tried in a
live dictation.

**Rule from the user:** nothing changes their words unless they told it to.
So only two kinds of change happen on their own, each behind a switch:

| What | Default | Where it happens |
|---|---|---|
| um, uh, hmm, er (and umm, uhh…) | **removed** ("Remove um and uh", on) | pipeline, all languages |
| like, you know, I mean, basically, literally, actually, kind of, sort of, yeah | **offered** in review as "Filler?" | review panel (English, checker) |
| the same, when the checker is sure | removed only with "Remove fillers when sure" (off) | pipeline (English, checker) |
| "2, no, make it 3", "two. No, make it three", "Rohan, sorry, Rahul" | **offered** in review as "You probably meant:" | review panel (English, Hinglish) |
| "scratch that" | **offered** in review as **Remove this text** | review panel (English, Hinglish) |

"yeah" is a sometimes-filler, not a sound: in "yeah, sounds good" it is the
answer.

## Pieces (`DesiDictationKit/Cleanup/`)

- `TextSpans`: removing a word so the sentence still reads right ("I, uh,
  think" → "I think"; "Um, I think" → "I think"; capitalises a new sentence
  start). The review panel's **Remove** uses the same function.
- `Fillers`:
  - `removeSounds`: a regex for the sounds. Not "huh" or "uh-huh", which
    mean something.
  - `candidates`: for each sometimes-filler, the context checker compares
    how likely the rest of the sentence is **with and without it** (the
    rest, after the prompt and the words before). Higher means the sentence
    reads better without it, so it's likely filler.
    - At a sentence start the checker gives no signal (every opener scores
      −7 to −8), so there only "you know", "I mean", "like" and
      "basically" followed by a comma are offered, without a score.
  - `removeSure`: removes the candidates scoring above `removeAbove`.
- `Corrections`: rules for spoken corrections.
  - **Triggers:** ", no," / ", no wait" / ", no make it" / ", sorry," /
    ", actually" / ", I mean", after a comma.
  - **At a sentence start** too, but only with "make it" or "wait": the
    speech engine often hears the pause as a full stop ("meet at two. No,
    make it three tomorrow", live 2026-10-29). "No, three people came" and
    anything after a "?" stay alone: there "No" is an answer.
  - **Without "make it",** the new words must be one or two, and of the same
    kind as an earlier word in the clause (number, weekday, month, name).
    That's what they replace.
  - **With "make it / make that",** up to four words. The context checker
    picks which earlier words they replace, if it's installed.
  - **"scratch that"** takes back the sentence so far, or the previous
    sentence if it opens one.
- `CleanupReview`: turns these into review underlines (`UnsureWord.Reason`
  `.filler` / `.correction`). A filler inside a correction's span goes with
  the correction.
- `CleanupSettings`: the two switches, kept out of the full `SettingsStore`.
- `DictationController+Cleanup`: applies the switched-on parts after
  vocabulary.

## Measured (2026-10-29, M3, Qwen3-0.6B Base checker)

`desi-cli --fillers evals/fillers/cases.tsv`: 41 sentences, each phrase
labelled filler (21) or real word (20).

| Bar (nats) | Fillers caught | Real words flagged |
|---|---|---|
| ask: > −1.5 | **15 / 21** | 3 / 20 |
| remove when sure: > +2.0 | 8 / 21 | **0 / 20** |

- **Misses:** "kind of", "sort of", most "literally", and "It's fine, I
  mean, it works". Those stay as said.
- **Wrongly asked:** "As you know the deadline…", "He was basically right",
  "The numbers are actually lower". Answer them with 0 (looks right).
- **Size:** 41 hand-written sentences pick the thresholds; they don't
  promise these rates on real speech. Add real misses to `cases.tsv`.

The correction rules are covered by `DesiTests/CleanupTests.swift`, including
sentences that must not trigger ("I said no, make it simple", "He tried to
call, no answer", "It's fine, actually it's great").

## Tried and dropped: suggestions for odd words

Idea: for a purple word with no sound-alike in the user's words, offer
everyday words that sound like it (macOS's word list, `IndicPhonetics`),
kept only if the checker preferred the sentence with them.

Tested on the 34 real substitution errors in the English quick tier that
review underlines as odd (Qwen3-ASR and Parakeet). The right word was
offered for **4 / 34**. Something was offered for **21 / 34**, nearly
always wrong:
- "Cuttack" → Kodak, "Kutta" → Cute, "Patides" → Potatoes;
- in a live sentence, "Luffy" → Life.

Odd words are mostly names, and an everyday word list can't spell names.
Building the index also cost ~5 s. Not shipped: a wrong suggestion in front
of the user is worse than "type the right word". Names keep coming from the
user's dictionary and the screen.

## Changing it

- Thresholds: `Fillers.askAbove` / `removeAbove`. Re-run
  `desi-cli --fillers evals/fillers/cases.tsv` (checker from
  `$DESI_CHECKER` or the installed one).
- Try one sentence: `desi-cli --cleanup "…"`.
- Which words: `Fillers.sometimes`, `Fillers.openers`, `Fillers.soundPattern`.
- Correction triggers: `Corrections.replace` / `scratch`; kinds in
  `Corrections.Kind`.
