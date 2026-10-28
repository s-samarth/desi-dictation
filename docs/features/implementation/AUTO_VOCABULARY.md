# Auto vocabulary — research, plan, decisions

**Status:** plan v2 (Qwen3-ASR + Hinglish style), awaiting approval (2026-10-28). No Swift yet.
**Goal:** the user never maintains a dictionary by hand. Names and terms come
from three places: corrections the user makes, the window they're dictating
into, and (opt-in) Contacts. Then they're applied without inventing errors.
**The pain it targets:** the model hears the name correctly, but spells a
*plausible wrong word*: "Rohan" → "Rowan", "Saraswat" → "Saraswath" /
"Sara swat", "Kavya" → "Cavia". The cause can be accent (v/w, t/th, d/dh merge
in Indian English) or context (the language model prefers a common word).
**The second pain (Hinglish):** Apex writes नहीं as *nahin* when the user
writes *nahi*. Roman Hinglish has no standard spelling. Each person is
self-consistent, but people differ from one another (P1_HINGLISH_ACCURACY.md
§4). "Correct" Hinglish is a fact about *this user*, so this mode needs to
learn the user's spelling style, not just names.

**Models (decided 2026-10-28):**
| Mode | Model | Runtime | How vocabulary reaches it |
|---|---|---|---|
| English (default) | Parakeet TDT 0.6B v3 | libparakeet | post-correction (no biasing in the model) |
| English — Accurate (opt-in; engine lands in a later PR) | **Qwen3-ASR-1.7B** | MLX | **hotwords** in its system-prompt context, then post-correction |
| Hinglish, any→English | Hinglish Apex (Oriserve whisper fine-tune, q5_0) | whisper.cpp | post-correction **+ personal spelling style** |
| हिन्दी | vaani-hindi / multilingual | whisper.cpp | skipped in v1 (Devanagari) |

## 1 · Research

Full findings and sources: [AUTO_VOCABULARY_RESEARCH.md](AUTO_VOCABULARY_RESEARCH.md)
(`[n]` = its source list). What shaped the plan:
- **Wispr Flow** auto-learns corrected spellings; **Dragon** reviews first;
  Superwhisper/Aqua read the window via AX (Aqua: RAM only).
- Bias lists must be **short and relevant**: accuracy falls as lists grow,
  and speech LLMs are sensitive to distractors and their order [12][13][14].
- For an unbiasable model, the standard fix is **phonetic blocking → edit
  distance → threshold** [16][17][18]. Homophones are the hard case.
- LLM correction over-corrects without N-best, so it's out [19].
- Hinglish has no standard spelling, and automatic normalizers are ~74 %
  accurate [24], so we learn the user's own spellings.

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
   - the two words aren't both common words ("their" → "there" is grammar),
     except Hinglish variants of one word (*nahin → nahi*, see (d));
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

### (c) Use it per model: one vocabulary, two delivery paths
For each dictation, `ActiveVocabulary` = dictionary written forms ∪ this
dictation's screen terms ∪ contact names, each tagged with its source.

**Path 1, post-correction (`VocabularyCorrector`): Parakeet and Apex.**
Neither model can be biased, so this is the main path for both the default
English and the Hinglish model. It runs after the dictionary step and before
translate/tone, so any→English translates the corrected names. For each output
word (and each adjacent pair, for "Sara swat"), it finds terms with a close
phonetic key, then decides with §3. `TranscriptionResult` gains optional
per-word confidence: the min sub-token `p` from `parakeet_full_get_token_p` or
`whisper_full_get_token_p`.

**Path 2, hotwords: Qwen3-ASR-1.7B (Accurate English).** Qwen3-ASR was trained
to use its system-prompt context; mlx-audio exposes it as hotwords. This PR
adds the seam, not the engine:
- a protocol `HotwordBiasing { func setHotwords(_: [String]) }`;
- `EngineRouter` passes terms when the active engine conforms;
- `HotwordSelector` picks ≤ 30 terms *before* audio exists (speech LLMs are
  sensitive to distractor count and order [14]): focused-field terms →
  window terms → dictionary written forms → contacts that are also on screen.
  The whole contact list is never passed.

Post-correction runs after Qwen too (idempotent). That catches what the prompt
missed. The Qwen engine PR only has to conform to `HotwordBiasing`.

### (d) Hinglish: learn the user's spelling style (Apex)
- **From corrections.** (a) runs in Hinglish mode too. A Hinglish edit like
  *nahin → nahi* or *kyaa → kya* is a style fix, so it is proposed even
  though both words are "common". The test: the two words share a strict
  `HinglishVariants.key` (vowel length folded: aa→a, ee/ii→i, oo/uu→u;
  doubled letters collapsed). Accepted pairs go into `PersonalDictionary` as
  usual. The exact-match step then applies them, and keeps the user's casing.
- **From the field being edited** (opt-in toggle). If the focused field
  already uses a variant with the same strict key as an output word (*nahi*
  in the field, *nahin* from Apex), use the field's spelling. This needs ≥ 2
  uses in the field, and the output spelling must not appear there at all. It
  applies to this dictation only and is never learned.
- **Never folded:** the final nasal *n* (*hai*/*hain* are different words),
  h-dropping (*bhai*/*bai*), and anything across the confirmed reject list.
  Automatic normalizers get ~1 in 4 wrong [24], so the strict key only fixes
  vowel length, and everything wider comes from the user's own corrections.
- **Names** in Hinglish (WhatsApp, Slack chats) use Path 1, with the stricter
  "real word" tier for every non-common word (§3.4).

### Settings and onboarding (all **off** by default)
In Settings → Dictionary, a new **"Smart vocabulary"** section:
- [ ] Suggest words from my corrections
- [ ] Fix near-misses of my names and words
- [ ] Read names from the window I'm dictating into
- [ ] Use names from Contacts
- [ ] Hinglish: match the spelling already in the text I'm editing

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
   - Hinglish: *hai* never becomes *hain*, *pita* stays with only 1 field
     use, *nahin → nahi* is proposed but *their → there* is not;
   - true positives: Saraswath, Sara swat, Kavia, Rowan-with-screen;
   - edit-diff extraction (spelling fix vs rewrite);
   - term extraction and hotword selection (cap, order, no bare contacts).

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
- **Out of this PR:**
  - the Qwen3-ASR engine itself (its own PR; it plugs into `HotwordBiasing`);
  - LLM post-correction;
  - per-app vocabularies;
  - Apex `initial_prompt` biasing with the user's names and spellings. This is
    P1-S2's cheap lever, but a fine-tune may ignore or be destabilized by a
    prompt (silence hallucinations, FM#30's `nan`). Follow-up: measure it on
    the Hinglish quick tier plus the silence clips before shipping.
