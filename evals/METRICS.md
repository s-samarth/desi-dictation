# Metrics Explained — what we measure, why, and when each one lies

You'll see five numbers in every eval report. Here's what each actually
computes, with worked examples from our real use case, and the failure modes
that make each one mislead. Rule of thumb up front: **we rank models by crWER,
sanity-check with CER, and quote WER only when comparing against published
papers.**

---

## 1. WER — Word Error Rate

**What it computes:** align the hypothesis (model output) to the reference
(ground truth) word-by-word using edit distance, then:

```
WER = (Substitutions + Deletions + Insertions) / (words in reference)
```

**Worked example:**
```
ref:  kal meeting hai please deck ready rakhna     (7 words)
hyp:  kal meeting he please deck ready             (6 words)
      S: he↔hai (1)  D: rakhna (1)  I: 0
WER = (1+1+0)/7 = 28.6%
```

**Intuition:** "what fraction of words did the model get wrong." 0% = perfect;
can exceed 100% (if the model inserts more garbage than there are words —
that's why you saw 103% in report #1: hallucination plus wrong script counts
every word twice, once as deletion, once as insertion).

**Why it lies for us, badly:**
- `nahi` vs `nahin` → full error, but both are correct Hinglish.
- `प्लीज` vs `please` → full error, but it's the same word in another script.
- `time` vs `time,` → error (punctuation!), `Kal` vs `kal` → error (case!).

In report #1, turbo's English raw WER was 24.6% while its crWER was 4.2% —
**over 80% of the "errors" were punctuation and casing**, not mishearings.
That gap is WER lying.

**When to use anyway:** comparing against published numbers (papers report
raw WER), and tracking OUR OWN trend where the bias is constant.

---

## 2. CER — Character Error Rate

**What:** same edit-distance formula, but over characters instead of words.

**Why it exists:** words are a big unit for Indic text. One wrong matra
(`तयार` vs `तैयार`) makes a whole word wrong in WER (100% for that word), but
CER counts it as 1 character in 6 (≈17%). CER answers *"how wrong was it,
really?"* — a model that misspells slightly is much better than one that
substitutes different words, and CER separates them where WER can't.

**Reading the pair:** high WER + low CER = spelling/orthography problems
(fixable with dictionaries/normalization). High WER + high CER = genuine
mishearing (only a better model fixes that). This diagnostic pair is how we
decide "extend VARIANTS map" vs "consider fine-tuning" (FINETUNING.md Part 3).

---

## 3. nWER — normalized WER

**What:** WER after lowercasing both texts, stripping punctuation, and writing
numbers one way (`evals/numbers_en.py`): spoken and written forms of the same
number are equal — `Rs. 400` = `rupees four hundred`, `15,000` = `fifteen
thousand`, `1999` = `nineteen ninety nine`, `2nd` = `second`, `70s` =
`seventies`, and an account number read digit by digit (`six eight four
four…`, `double nine`) = the digits. Lakh/crore scales and Indian grouping
(`4,00,000`) follow the app's own number handling.

**Why:** dictation users don't care about `Kal,` vs `kal` — normalization
removes exactly the noise class that inflated turbo's English WER to 24.6%.
This is standard practice (Whisper's own paper evaluates with a normalizer,
numbers included). Before numbers were normalized, ref `transfer Rs. 400 to my
6844663153262` vs hyp `transfer rupees four hundred to my six eight four four…`
cost 16 errors for a perfect transcript; formatting was ~38 % of all word
errors in the english clips that contain digits.

**Deliberate edges:** 3+ single digits in a row join (`two three` stays `2 3`,
`one two three` = `123`); `eighteen`/`nineteen`/`twenty` + 10–99 reads as a
year (`eleven thirty` stays a time). Hindi number words (`unnis sau nabbe`) are
not converted.

**What it still can't fix:** cross-script comparison (`प्लीज` vs `please`) and
Hinglish spelling variance (`kyaa` vs `kya`). For those we need…

---

## 4. crWER — collapsed-roman WER (our primary metric) ⭐

**What:** both reference and hypothesis are mapped into ONE canonical Roman
form, then WER is computed there. The mapping (evals/metrics.py):
1. Devanagari → Roman **the way Hinglish is written** (`evals/devanagari.py`):
   the inherent vowel is dropped where Hindi drops it (एक → `ek`, वजह →
   `vajah`, निकलने → `nikalne`, समझता → `samajhta`; ना/ता keep their written
   ā), nasal marks become `n`/`m` before a consonant (पाँच → `panch`, संभव →
   `sambhav`) and vanish word-finally (में → `me`, हैं → `hai`), ज्ञ → `gy`,
   ज़ → `z`, ड़ → `d`
2. nWER's normalization (case, punctuation, numbers)
3. drop the y-glide (`liye` = लिए), `chh` → `ch`, collapse long vowels
   (`kyaa`→`kya`, `jaldii`→`jaldi`)
4. drop word-final nasalization on the Roman side too (`yahan`, `hun`,
   `logon`, `hamein`), then the known-variants map (`nahin`→`nahi`, `mein`→`me`,
   …) — the same map the app's own normalization uses

Until 2026-09-23 step 1 was ITRANS, which spells what is *written*: में →
`mem`, वजह → `vajaha`, एक → `eka`, हालाँकि → `hala nki`. Every correct Roman
word of that kind scored as an error — hinglish crWER roughly **halved** when
it was replaced (evals/README.md has the before/after). Numbers from before
then (metrics v1) are not comparable with later ones.

**Worked example (the case every other metric fails):**
```
ref (CS-FLEURS, mixed script):  इसने हमें train, car दिए हैं
hyp (Apex, Roman):              isne hamein train car diye hain
raw WER: ~100% (zero literal matches)   crWER: ~0% (same words, same script after collapse)
```

**Why you should trust it:** it operationalizes what a Hinglish USER calls
correct — "did it write the words I said, in readable Roman, regardless of
which valid spelling." It's our implementation of "script-unified WER" from
the Indic ASR literature; Sarvam's public argument that plain WER is unfit for
Indic evaluation is the same point.

**Its honest limitations (know them):**
- Romanization is rule-based: compounds (घोषणापत्र) and loanwords written in
  Devanagari (फिल्म → `philm` vs `film`) still differ, as do `w`/`v`
  (`wala`/वाला) and `j`/`z` — merging those would also merge English
  `west`/`vest`. Spellings that keep a medial vowel Hindi drops (Apex's
  `niklane`, `dekhane` for निकलने, देखने) stay errors on purpose: forgiving
  them would also forgive मिलना vs मिलाना (meet vs mix — different words).
- Word-final nasalization is ignored on both sides, so है = हैं and
  करे = करें (as VARIANTS already had hain = hai). nWER still separates them.
- The VARIANTS map is curated by us; an unmapped variant still counts as an
  error. (That's fine — the map is versioned with the product, and growing it
  improves the app AND the metric together.)
- It deliberately ignores script choice. If you specifically want Devanagari
  out (हिन्दी mode correctness-of-script), check nWER too: a model writing
  Roman when you wanted Devanagari will show crWER good / nWER terrible —
  exactly how vaani (99% on english suite) got correctly disqualified.

---

## 5. RTF — real-time factor

**What:** `audio_duration / processing_time`. RTF 14× = one minute of speech
transcribes in ~4.3s. In reports it's throughput on the eval machine (M3, via
the actual whisper.cpp engine) — user-perceived latency is better than this
suggests because the app transcribes in chunks *while you speak*.

**Why it matters:** it's the accuracy-vs-speed axis of every model decision
(vaani: best Hindi crWER at 1.1× — accuracy-worth-it; swift: 40× but +5–7
crWER points).

---

## How to read a report (the 60-second protocol)

1. Sort by **crWER** within a suite → that's the quality ranking.
2. **crWER vs nWER gap** big? → script/orthography differences dominate
   (expected for Hinglish models on mixed refs; not a real quality problem).
3. **WER high but CER low?** → spelling variants; extend VARIANTS, don't
   panic.
4. **All metrics ~100%?** → wrong model-mode pairing or hallucination;
   inspect transcripts before concluding anything.
5. Check **RTF** ≥ ~3× for anything meant for interactive dictation.
6. Trends over releases → `reports/AGGREGATE.md`; a model change ships only if
   crWER holds or improves on its target suite AND the personal set.

## What we deliberately DON'T use (yet)

- **Semantic/LLM-judge metrics** ("did the meaning survive?") — right idea,
  heavier machinery, non-deterministic judge; revisit post-launch.
- **Human preference A/B** — gold standard, expensive; reserved for big
  decisions (model default changes, fine-tune ship gates) on the personal set.
