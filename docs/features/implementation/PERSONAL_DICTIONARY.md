# Personal Dictionary — implementation

**Spec:** P4-S1 (problems/P4_PERSONALIZATION.md), IDEAS.md #3, and
competitors/PATTERNS.md §1 ("the only serious app without it — overdue").
**The pitch:** "always write it as…" — names (Saraswath→Saraswat), brands
(jira→Jira), code terms (gpt→GPT). Per-user accuracy no shared model can give.

## What it's made of

- **`DesiDictationKit/PersonalDictionary.swift`** — `DictionaryEntry{heard,
  written}` + an `ObservableObject` store persisting to
  `~/Library/Application Support/DesiDictation/dictionary.json` (same pattern
  as HistoryStore: JSON file, atomic writes, `init(fileURL:)` injectable so
  tests never touch real data).
- **`DesiDictationApp/DictionaryView.swift`** — `DictionarySettings` (the list
  section "Your words" on the Vocabulary page: ~~heard~~ → written rows with remove
  buttons) + `AddDictionaryEntrySheet` (two fields, used by both Settings and
  History).
- **Two lists (2026-10-28):** `DictionaryEntry.scope` is `WordScope`
  `.english` / `.hinglish`, picked by the dictation language
  (`WordScope(mode:)`; `anyToEnglish` → Hinglish; हिन्दी → none, so no
  vocabulary at all). `entries(for: mode)` feeds the pipeline, the corrector's
  terms and the learner's duplicate check. Older entries decode as English.
- **Always / When it fits (2026-10-28):** `DictionaryEntry.mode`
  (`EntryMode`, older entries decode as `.always`). `apply` only runs
  Always entries; When it fits entries (English) are judged per sentence by
  [CONTEXT_FIT.md](CONTEXT_FIT.md). The picker shows on English rows once the
  context checker is downloaded.
- **Suggest in Learning (Hinglish meaning pairs).** The Vocabulary picker and
  Learning review can switch an existing pair such as kam → kaam to
  `.whenItFits` on the same dictionary entry. The Hinglish review offers the
  two meanings. Confirmations are stored separately from Always entries.
  See [Hinglish Learning](HINGLISH_LEARNING.md).
- **Right-click anywhere:** a non-AI Services entry, "Always write as… (Desi
  Dictation)" (`ServiceProvider.alwaysWriteAs`), opens `AddDictionaryEntrySheet`
  prefilled with the selection in a small floating window. `build_app.sh`
  keeps it when it drops the AI Translate services.
- **History affordance** — right-click any entry in HistoryView → *"Always
  write a word as… (add to dictionary)"* opens the sheet. This is the intended
  main path: corrections come from real dictations.

## The matching engine (`PersonalDictionary.apply` — pure, static, tested)

1. Per entry, builds `\b<escaped-heard>\b` case-insensitive regex → **whole
   words only** ("meating"→"meeting" can never corrupt "defeating"). If the
   pattern won't compile (exotic input), falls back to plain case-insensitive
   replacement rather than dropping the rule.
2. Replacements walk matches **in reverse** so ranges stay valid while editing.
3. `casedLike(original:replacement:)` preserves context casing: sentence-start
   `Meating`→`Meeting`, shouty `MEATING`→`MEETING`, otherwise the dictionary's
   exact spelling wins (that's the point — `saraswath`→`Saraswat`).
4. Case-only rules are legitimate (`jira`→`Jira`); only exact self-mappings are
   rejected at `add()`. Latest correction for the same heard-form replaces the
   older one. Saving an identical rule preserves its ID and produces no new
   learning activity. Review reports a failed dictionary write.
5. The Hinglish style pass preserves complete Always written forms, including
   when the recognizer already produced the desired spelling. For example,
   a single-a habit still allows an explicit sath → saath exception.

## Where it runs in the pipeline

`DictationController.finishRecording` snapshots `entries` on the main actor,
then on the work queue applies **legacy replacements first, dictionary second**
(dictionary is the authoritative layer; the old `replacementRules` text field
still works and is now labeled "advanced"). Order matters: the LLM stages
(translate/tone) run *after*, so they receive corrected text — verified by the
combination tests.

## English sentences in Hinglish mode (2026-11-24, FM#47)

Prime writes the same "to" for English *to* and Hindi *toh*, so a Hinglish
rule `to → toh` used to turn "how to fix" into "how toh fix".
`apply(_:entries:lexicon:)` now takes a lexicon (the pipeline passes
`WordLexicon.system`; desi-cli and old tests pass none and keep the old
behaviour) and asks `Vocabulary/EnglishContext.swift`:

- **Which rules are checked** (`isGuarded`): Hinglish, one word, the heard
  word is English and the written one is a Hindi spelling. to → toh,
  tab → tabh, relay → reelien. Not view → review (English to English) or
  nahin → nahi (heard word isn't English): those always apply.
- **When a match is skipped** (`surrounds`): the two words on each side, in
  the same sentence, include an English word and no Hindi one. Names and
  numbers count for neither, and a lowercase word that isn't English counts
  as Hindi. Nothing around it, or any Hindi word, means the rule applies.
  "how to fix" stays; "mujhe to pata nahi" and "meeting to cancel kar do"
  get "toh".
- **The word lists:** `hindiWords` decides first, because Webster's lists
  many Romanized Hindi words (hum, ye, ho, par). Words that are everyday
  English as well (me, main, hi, do, so) are left out. `englishWords` adds
  everyday English that Webster's base-form list lacks ("has", "okay").

There is no setting; it follows from the rule itself. Tests:
`DesiTests/EnglishContextTests.swift`.

## Changing it

- Different matching (e.g. Devanagari boundaries): all logic is in `apply` +
  `casedLike`; tests in `DesiTests/DictionaryTests.swift` pin current behavior.
- Auto-learn ("it noticed you re-typed a word"): built as **proposals** in
  [AUTO_VOCABULARY.md](AUTO_VOCABULARY.md). A popup plus a Suggestions list,
  and accepted pairs land here via `add()`. Nothing is learned silently.
- Import/export: it's one small JSON file; a share button would be trivial.
