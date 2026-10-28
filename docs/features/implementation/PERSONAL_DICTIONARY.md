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
   older one.

## Where it runs in the pipeline

`DictationController.finishRecording` snapshots `entries` on the main actor,
then on the work queue applies **legacy replacements first, dictionary second**
(dictionary is the authoritative layer; the old `replacementRules` text field
still works and is now labeled "advanced"). Order matters: the LLM stages
(translate/tone) run *after*, so they receive corrected text — verified by the
combination tests.

## Changing it

- Different matching (e.g. Devanagari boundaries): all logic is in `apply` +
  `casedLike`; tests in `DesiTests/DictionaryTests.swift` pin current behavior.
- Auto-learn ("it noticed you re-typed a word"): built as **proposals** in
  [AUTO_VOCABULARY.md](AUTO_VOCABULARY.md). A popup plus a Suggestions list,
  and accepted pairs land here via `add()`. Nothing is learned silently.
- Import/export: it's one small JSON file; a share button would be trivial.
