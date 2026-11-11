# Hinglish Learning — implementation

**Built 2026-11-11 (user request).** A review setting for Hinglish only. The
panel opens on every Hinglish dictation and asks which spelling is yours. It
remembers each answer and learns spelling habits, then suggests stopping
once nothing needs fixing.

## Why a separate mode

The underline levels (Conservative → Bindaas) measure *how sure the model is
that it heard you*. That's the wrong question for Hinglish. Prime usually
hears "chahiye" fine and writes "chaahie", and neither spelling is wrong.
There is no standard Roman Hindi, and each person sticks to one spelling
(P1_HINGLISH_ACCURACY.md *(private)*). So Hinglish needs a mode that asks
*which spelling is yours*, not *did I hear you*.

Bindaas also showed nothing at all in Hinglish: it keeps only the purple
words, and the context checker doesn't score Hinglish (2026-11-11 user
report, together with FM#46).

## What the user sees

Settings → Dictation → Review → **Hinglish**: **Learning** or **Same as above**
(the default). The picker shows only while Review before paste is on.

With Learning, on every Hinglish dictation:

1. The panel opens, even with "Only when unsure".
2. Words from the spelling list that you haven't settled yet are
   underlined in **blue**: "Your spelling? Leave it, or pick:", followed by
   the other spellings (chahiye · chahie · chaahiye).
   - Leaving a word as it is counts as choosing it.
   - Orange "hard to hear" underlines still appear, at least at Liberal's bar
     (under Bindaas, Learning uses Liberal's).
   - Where both apply to one word, orange wins.
3. Fixes default to **Always** instead of Just this once, because fixing a
   spelling here means teaching it.
4. When your fixes show a habit twice (vaise → waise, vo → wo), the panel
   asks: *Always write w instead of v at the start of Hindi words?*
   - Yes adopts it, No stops asking, and no answer asks again later.
5. After 10 Hinglish dictations in a row with no fix, a green banner offers
   **Stop learning** (back to Same as above) or **Keep learning**. What it
   learned stays either way.

**From then on, in every Hinglish dictation in any mode:**
- A word whose spelling you chose is written your way, whatever variant the
  model produced ("Chahie" → "Chahiye", capitals kept).
- Adopted habits apply to other Hindi words.

## Where it lives

| Piece | File |
|---|---|
| The spelling list: 48 groups, each one word in its common spellings | `DesiDictationKit/Review/HinglishSpellings.swift` |
| Habits (`wNotV`, `vNotW`, `shortA`, `iyeEnding`): rewrite a word, find the habits a fix shows | `Review/HinglishStyleRule.swift` |
| `HinglishStyle`: chosen spellings and habits, applied to a dictation | `Review/HinglishStyle.swift` |
| `HinglishLearning`: the setting, what was learned, the streak (UserDefaults `hinglish.*`) | `Review/HinglishLearning.swift` |
| Pipeline step: dictionary → **`hinglishStyle.apply`** → vocabulary | `DictationController.swift` |
| Opening the panel, blue underlines, `ReviewPlanner.merge` | `DictationController+Review.swift`, `ReviewPlanner.swift` |
| Panel: default Always, habit rows, done banner, underline colours | `ReviewModel.swift`, `ReviewLearningViews.swift` |
| Settings picker | `ReviewSection.swift` |
| Tests | `DesiTests/HinglishLearningTests.swift` |

## Guards (why it can't turn one word into another)

- **The list holds only safe groups.** A spelling that is also an English
  word or a different Hindi word is left out:
  - or/aur, to/toh, me/mein, bad/baad, thick/theek;
  - kam (less) / kaam (work), kaha (said) / kahan (where), main (I) / mein (in).

  So applying a chosen spelling never changes the meaning.
- **Habits never touch:**
  - English words: `WordLexicon.system` (Webster's), so "video" never becomes "wideo";
  - capitalized words, which may be names ("Vikas" stays);
  - non-ASCII words;
  - `vNotW` never touches "wh…".
- **A chosen spelling beats a habit.** If you kept "vaise", the w habit
  leaves it alone.
- **A habit is offered only after two fixes show it**
  (`HinglishLearning.habitAfter`), and only habits that fully explain a fix
  count. chaahie → chahiye shows `shortA` + `iyeEnding`; ladki → larki shows none.
- **Learning only from what the user did in the panel.** No screen text and
  no audio are stored. Settings are local UserDefaults, and `forgetAll()` clears them.

## Decisions

- **"Same as above" is the default.** Opening on every dictation is opt-in.
- **Leaving a blue word means "that's mine."** Otherwise the same word would
  be asked forever. The label says so ("Leave it, or pick").
- **Always by default only in Learning.** The rest of review keeps the
  2026-10-29 decision: Just this once.
- **The spelling list is curated, not generated.** A rule-based generator
  would underline almost every Hindi word. Add groups as users report them.
- **v ↔ w also counts for edit-learning.** `HinglishVariants.isStyleEdit`
  now treats v and w as one sound, so vaalon → waalon is offered outside
  Learning too. Before, the same-first-sound check rejected it.

## Changing it

- **Add a word:** add a group to `HinglishSpellings.groups` (common spelling first), and
  check no spelling is an English word or another Hindi word.
- **Add a habit:** add a case to `HinglishStyleRule` with `question` and
  `rewrite`, and a test in `HinglishLearningTests`.
- **Picture of the panel:** `DESI_UI_SNAPSHOTS=… app/.build/debug/desi-dictation`
  renders `review-learning.png`.
