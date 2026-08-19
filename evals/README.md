# Evals — Desi Dictation

Labeled, repeatable evaluation of every model across our three use cases,
scored through the **actual shipping engine** (`desi-cli --batch` = whisper.cpp
with the app's exact params + VAD) — so numbers reflect what users get.

**Data and reports are NOT committed** (`evals/data/`, `evals/reports/` are
gitignored — dataset licenses + noise). The tooling is committed; data rebuilds
with one command.

## Setup & run

```bash
cd evals
uv sync
uv run download_data.py --limit 50     # ~3 suites × 50 labeled clips
uv run run_eval.py                     # all installed models × all suites
                                       # (Parakeet runs the english suite only —
                                       #  no Hindi, no Devanagari, no Hinglish)
uv run aggregate.py                    # trend table across all past reports
```

## Suites (labeled public data)

| Suite | Source | What it tests |
|---|---|---|
| `hindi` | [google/fleurs](https://huggingface.co/datasets/google/fleurs) `hi_in` test | शुद्ध हिन्दी, Devanagari refs |
| `english` | [ai4bharat/Svarah](https://huggingface.co/datasets/ai4bharat/Svarah) | Indian-accented English (117 speakers, 65 districts) |
| `hinglish` | [byan/cs-fleurs](https://huggingface.co/datasets/byan/cs-fleurs) Hindi–English | code-switched speech |

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

## Report format

`reports/report_<UTC>.json`:
```json
{
  "meta": {"timestamp": "...", "git_commit": "abc1234", "machine": "arm64",
            "engine": "whisper.cpp (desi-cli)"},
  "results": [
    {"suite": "hindi", "model": "ggml-vaani-hindi-q5_0", "mode": "hindi",
     "clips": 50, "wer": 0.18, "cer": 0.07, "nwer": 0.14, "crwer": 0.09,
     "rtf": 2.4, "audio_minutes": 7.5}
  ]
}
```
Plus a rendered `.md` table per run. `aggregate.py` builds
`reports/AGGREGATE.md`: crWER trends per suite×model across every report
(newest last) + current champions.

## Rules

1. Run after **every** engine or model change; commit hash is embedded.
2. A model change ships only if crWER improves (or holds) on its target suite.
3. Never tune on the eval clips (no peeking; VARIANTS map additions must come
   from real usage, not from eval errors).
