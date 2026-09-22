"""English suite sources — Indian-accented first, across the whole length range.

English is what most users dictate, so this suite is the largest:
  sdqa_ind_n / sdqa_ind_s  the SAME questions read by North- and South-Indian
                           speakers (+ a US control) — a clean accent A/B
  svq_en_in                short voice queries, clean + background chatter
  nptel                    Indian professors, technical lecture English
  edacc_in                 Indian-English conversation, natural short→long turns
  edacc_in_mid / _long     15–35 s and 45–90 s single-speaker dictations
  fleurs_en_us             US read speech — the pre-2026-09 suite, as a control
"""

from __future__ import annotations

import random

from hf_parquet import decode, list_files
from sampling import est_seconds, spelled_numbers, spread
from sources_common import (clip, fleurs, load_units, pick_files, speaker_runs,
                            stitched, svq)

LONG_MIN_S, LONG_MAX_S = 45.0, 90.0


def sdqa(rng: random.Random, n: int = 30, n_usa: int = 12) -> list[dict]:
    """SD-QA dev (TyDi-QA questions, spoken per English dialect)."""
    repo = "WillHeld/SD-QA"
    files = pick_files(repo, "data", "dev", 4, rng)
    rows = load_units(repo, files, ["id", "question"], lambda r: bool(r["question"]),
                      lambda r: r["id"], 3, ["ind_n", "ind_s", "usa"], rng)
    out = []
    for i, r in enumerate(spread(rows, n, lambda r: r["id"], rng)):
        for dialect in ("ind_n", "ind_s") + (("usa",) if i < n_usa else ()):
            if r.get(dialect) and r[dialect].get("bytes"):
                src = "sdqa_usa" if dialect == "usa" else f"sdqa_{dialect}"
                out.append(clip(decode(r[dialect]), r["question"], src,
                                f"sdqa-{dialect}", "US" if dialect == "usa" else "India"))
    return out


def svq_en(rng: random.Random) -> list[dict]:
    return svq("en_in", 20, rng)


def nptel(rng: random.Random, n: int = 40) -> list[dict]:
    """NPTEL lecture segments — the speaker-breadth source (~one lecturer per
    clip). Refs are lower-case/no-punct (fine for nWER); rows that spell
    numbers out are skipped (see sampling.spelled_numbers)."""
    repo = "skbose/indian-english-nptel-test"
    files = pick_files(repo, "data", "test", 4, rng)
    keep = lambda r: (len(str(r["transcription_normalised"]).split()) >= 3
                      and not spelled_numbers(r["transcription_normalised"]))
    rows = load_units(repo, files, ["speaker_name", "transcription_normalised"], keep,
                      lambda r: r["speaker_name"], 6, ["audio"], rng)
    secs = lambda r: est_seconds(r, "transcription_normalised")
    return [clip(decode(r["audio"]), r["transcription_normalised"], "nptel",
                 r["speaker_name"], "India")
            for r in spread(rows, n, lambda r: r["speaker_name"], rng, seconds=secs)]


def edacc(rng: random.Random, n: int = 40, n_mid: int = 8, n_long: int = 8) -> list[dict]:
    """EdAcc (Edinburgh accents corpus), its 5 Indian-English speakers, test +
    validation: unscripted conversation — hesitations, fast speech, real turn
    lengths — plus 15–35 s and 45–90 s dictations stitched from one speaker's
    consecutive turns (the lengths real dictations reach)."""
    repo = "edinburghcstr/edacc"
    files = list_files(repo, "data")
    keep = lambda r: (r["accent"] == "Indian English" and not spelled_numbers(r["text"])
                      and "IGNORE_TIME_SEGMENT" not in r["text"])  # corpus "don't score"
    rows = load_units(repo, files, ["speaker", "text", "accent", "l1", "gender"], keep,
                      lambda r: r["speaker"], 8, ["audio"], rng)
    speaker, secs = (lambda r: r["speaker"]), (lambda r: est_seconds(r, "text"))
    longs, used = speaker_runs(rows, speaker, secs, n_long, rng, LONG_MIN_S, LONG_MAX_S)
    mids, used_mid = speaker_runs(rows, speaker, secs, n_mid, rng, 15.0, 35.0, exclude=used)
    used |= used_mid
    out = [stitched(p, "audio", "text", "edacc_in_long", p[0]["speaker"], "India") for p in longs]
    out += [stitched(p, "audio", "text", "edacc_in_mid", p[0]["speaker"], "India") for p in mids]
    rest = [r for r in rows if id(r) not in used]
    for r in spread(rest, n, speaker, rng, seconds=secs):
        out.append(clip(decode(r["audio"]), r["text"], "edacc_in", r["speaker"],
                        "India", r.get("gender", "")))
    return out


def fleurs_en(rng: random.Random) -> list[dict]:
    return fleurs("en_us", 20, "fleurs_en_us")


SOURCES = [sdqa, svq_en, nptel, edacc, fleurs_en]
