# Evals — Desi Dictation

Labeled, repeatable evaluation of every model across our three use cases,
scored through the **actual shipping engine** (`desi-cli --batch` = the app's
EngineRouter: Parakeet for English, whisper.cpp with the app's exact params + VAD
otherwise) — so numbers reflect what users get.

**Data and reports are NOT committed** (`evals/data/`, `evals/reports/` are
gitignored — dataset licenses + noise). The tooling is committed; data rebuilds
with one command.

## Setup & run

```bash
cd evals
uv sync
uv run download_data.py                # build all suites (~12 min once, ~180 MB kept)
uv run run_eval.py                     # QUICK tier, shipping model per suite (~6 min)
uv run run_eval.py --tier full         # every clip — before shipping a model change
uv run run_eval.py --all-models        # compare every installed model
uv run run_eval.py --suites english --models turbo parakeet
uv run aggregate.py                    # trend table across all past reports
```

`run_eval.py` prints its time estimate before it starts. Parakeet only runs
the english suite (no Hindi, no Devanagari); Vaani never runs english.

## Cost — time and disk

Measured / fitted on an M3 Air, model resident (the estimator in
`run_eval.py` is fitted on the quick tier; an M1 Air is ~1.8× slower):

| Run | Runs | M3 Air | M1 Air (est.) |
|---|---|---|---|
| **quick, shipping models** (default) | 3 | **5.8 min** (measured) | ~11 min |
| quick, all models | 9 | ~20 min | ~36 min |
| full, shipping models | 3 | ~31 min | ~55 min |
| full, all models | 9 | ~96 min | ~2.9 h |

Almost all of it is Vaani (हिन्दी): it costs ~1.1 s per second of audio and
is content-dependent (one 18.6 s clip took 55 s, a similar-length one 7 s).
Parakeet does the whole english full tier in about a minute.

Disk: `data/` is **~180 MB** (527 clips, ~97 min of 16 kHz mono WAV) vs 49 MB
before. Building it streams only the Parquet row groups holding the chosen
clips (~1.5 GB transferred once, nothing cached — `hf_parquet.py`).

## Suites (labeled public data, rebuilt 2026-09-22)

Every clip records `source`, `speaker`, `region`, `gender`, `env`, `seconds`,
`bucket` and `quick` in `manifest.jsonl`; reports break every result down by
source and by length bucket. Buckets: **xs** <2.5 s · **s** <6 s · **m** <15 s
· **l** <35 s · **xl** ≥35 s (up to ~110 s, crossing whisper's 30 s window).

| Suite | Clips (quick) | Sources | Speakers / regions |
|---|---|---|---|
| `english` | 298 (59) | **Svarah** — Indian English from speakers of 19 native languages (Nepali, Kannada, Urdu, Tamil, Bodo, Kashmiri…), 65 districts, plus 15–35 s / 45–90 s stretches of one recording · SD-QA — the *same* questions read by North- and South-Indian speakers, + US control · Google SVQ en_in — short voice queries, clean + background chatter · NPTEL — Indian professors, technical English · EdAcc Indian English — unscripted conversation, plus 15–35 s and 45–110 s single-speaker stretches · FLEURS en_us — the old suite, kept as a control | ~130 named, 45 regions (Svarah gives native-language breadth, NPTEL ~one lecturer per clip) |
| `hindi` | 117 (23) | FLEURS hi_in (read) · SVQ hi_in (short queries, clean + chatter) · IndicVoices spontaneous Hindi (conversation + extempore, 0.4 s "haan" to 90 s) | 59 speakers, 27 districts (UP, MP, Bihar, Rajasthan) |
| `hinglish` | 112 (23) | CS-FLEURS hin-eng (read) · IndicVoices code-mixed turns (≥15 % English words) + 15–35 s / 45–90 s code-mixed stretches | 71 speakers, 30 districts |

Sources and their datasets: [WillHeld/SD-QA](https://huggingface.co/datasets/WillHeld/SD-QA) ·
[google/svq](https://huggingface.co/datasets/google/svq) ·
[skbose/indian-english-nptel-test](https://huggingface.co/datasets/skbose/indian-english-nptel-test) ·
[edinburghcstr/edacc](https://huggingface.co/datasets/edinburghcstr/edacc) ·
[google/fleurs](https://huggingface.co/datasets/google/fleurs) ·
[byan/cs-fleurs](https://huggingface.co/datasets/byan/cs-fleurs) ·
[IndicVoices re-cut](https://huggingface.co/datasets/dianavdavidson/indic-voices-hinglish-nospeakeroverlap-spon3.3-acronyms-fixed2)
(CC-BY-4.0, from ai4bharat/IndicVoices). Data stays local — never committed
or redistributed.

**Selection rules** (`sampling.py`, deterministic): spread across speakers
first, then across length buckets; skip refs that spell numbers out ("r three
minus r one" — that scores formatting, not hearing); drop annotation tags and
EdAcc's `IGNORE_TIME_SEGMENT_IN_SCORING` turns. Long clips are one speaker's
consecutive segments joined with 0.4 s pauses — the shape of a real dictation.

**Not used, and why:**
- **ai4bharat Lahaja / IndicVoices / Kathbath** — gated; our HF account isn't
  approved for them (403). Svarah was approved 2026-09-23 and is now in; before
  that the `english` suite silently fell back to FLEURS **US** English while docs
  called it Svarah (BUILD_LOG FM#24). Lahaja (Hindi, speakers of many native
  languages) is the next addition if approved. Gated sets need `hf auth login`;
  `hf_parquet.py` sends that token only to huggingface.co.
- **MUCS 2021 Hinglish** — segment audio is misaligned with its transcripts
  and English terms are written in Devanagari.

**Known limits:** `desi-cli --batch` transcribes each file whole, so xl clips
test the engine's own long-form path, not the app's 25–35 s chunker. The 20
FLEURS en_us clips are very quiet (~−50 dBFS peaks) — left as-is for continuity.

Plus (manual, most important): the **personal set** — record your own clips per
spike/README.md and drop them into `evals/data/personal/` with a
`manifest.jsonl`; the runner picks it up like any suite (`--suites personal`).

## Metrics — and why WER alone lies here

| Metric | What | When it misleads |
|---|---|---|
| **WER** | verbatim word errors | punishes valid Hinglish spellings (nahi/nahin), punctuation, script choice |
| **CER** | character errors | fairer for Devanagari conjuncts; still script-bound |
| **nWER** | WER after case/punct normalization | removes formatting noise only |
| **crWER** ⭐ | both sides mapped to one **collapsed Roman** form: Devanagari→ITRANS, long vowels collapsed (kyaa=kya), known variant map (nahin=nahi) | **primary metric** — the only fair way to score a Roman-Hinglish hypothesis against a Devanagari reference, and robust to Hinglish orthography variance |
| RTF | × realtime speed | — |

crWER is our implementation of "script-unified WER" (what Indic ASR literature
uses to handle romanization ambiguity; Sarvam's blog on Indic ASR metrics makes
the same argument). Judgment calls (vowel collapse, variant map) are in
`metrics.py` — extend `spike/normalize.py`'s VARIANTS as new spellings appear.
Future: LLM-judged semantic accuracy (heavier; post-launch).

**crWER overstates errors (known, 2026-09-22) — compare models with it, don't
quote it as accuracy.** ITRANS keeps the inherent vowel and the nasal mark, so
a correct Roman hypothesis still misses: में→`mem` vs "mein"→`me`, वजह→`vajaha`
vs "vajah", एक→`eka` vs "ek". Apex's near-perfect "Television reports mein plant
se niklane vaala white smoke dikhaaya gaya hai" scores 17 %. Fixing it (schwa
deletion, anusvara handling in `collapse_roman`) is the next metrics change; it
will shift every hindi/hinglish number, so re-baseline when it lands.

## Report format

`reports/report_<UTC>.json`:
```json
{
  "meta": {"timestamp": "...", "git_commit": "abc1234", "machine": "arm64",
           "tier": "quick", "engine": "desi-cli (EngineRouter)"},
  "results": [
    {"suite": "hindi", "model": "ggml-vaani-hindi-q5_0", "mode": "hindi", "tier": "quick",
     "clips": 23, "wer": 0.28, "cer": 0.16, "nwer": 0.27, "crwer": 0.26,
     "median_s": 2.95, "p90_s": 5.91, "rtf": 0.9, "audio_minutes": 4.2,
     "by_source": {"ivh_hi": {"clips": 10, "crwer": 0.17, "...": "..."}},
     "by_bucket": {"xs": {"...": "..."}, "xl": {"...": "..."}},
     "per_clip": [{"file": "0069.wav", "source": "ivh_hi_long", "audio_s": 64.1,
                   "engine_s": 142.2, "ref": "...", "hyp": "..."}]}
  ]
}
```
Plus a rendered `.md` per run (overall table, then per-length and per-source
slices). `aggregate.py` builds `reports/AGGREGATE.md`: crWER trends per
suite × model × tier across every report (tiers aren't comparable with each
other, nor with pre-2026-09 "legacy" reports, which used a different suite).

## Rules

1. Run the quick tier after **every** engine or model change (commit hash is
   embedded); the full tier before shipping one.
2. A model change ships only if crWER improves (or holds) on its target suite.
3. Never tune on the eval clips (no peeking; VARIANTS map additions must come
   from real usage, not from eval errors).
