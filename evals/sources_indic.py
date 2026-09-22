"""Hindi and Hinglish suite sources — real Indian voices, read AND spontaneous.

hindi:    fleurs_hi (read, control) · svq_hi_in (short queries, clean+chatter)
          ivh_hi (IndicVoices spontaneous Hindi — UP/MP/Bihar/Rajasthan,
          farmers to students, 0.5 s "haan" to long extempore) · ivh_hi_long
hinglish: csfleurs_hin_eng (read) · ivh_mix (spontaneous, >=15 % English
          words) · ivh_mix_mid/_long (one speaker's code-mixed conversation)

Rejected: MUCS 2021 Hinglish (dianavdavidson/MUCS-Hinglish) — its segment
audio is misaligned with its transcripts (clip "टेक्स्ट का फोंट साइज़ चुनते है"
actually says "attribute panel se text size button ko chunte hain…") and it
writes English terms in Devanagari, which no Roman-output model can match.

IndicVoices itself is gated (our HF account isn't approved — BUILD_LOG FM#24);
`dianavdavidson/indic-voices-hinglish-*` is an open CC-BY-4.0 re-cut of its
test data with speaker/region metadata and a mixed-script reference
(Devanagari Hindi + Latin English), which crWER scores fairly.
"""

from __future__ import annotations

import random
from functools import lru_cache

from hf_parquet import decode
from sampling import spread
from sources_common import (clip, cs_fleurs, fleurs, load_units, pick_files,
                            speaker_runs, stitched, svq)

IVH = "dianavdavidson/indic-voices-hinglish-nospeakeroverlap-spon3.3-acronyms-fixed2"
IVH_TEXT = "hinglish_mixed_scripts"
LONG_MIN_S, LONG_MAX_S = 45.0, 90.0


@lru_cache(maxsize=1)
def _ivh_rows(seed: int) -> tuple:
    """One download shared by the hindi and hinglish suites."""
    rng = random.Random(seed)
    files = pick_files(IVH, "data", "test", 8, rng)
    meta = ["duration", "state", "district", "scenario", "ratio_english_words",
            "speaker_id", "gender"]
    rows = load_units(IVH, files, meta, lambda r: r["duration"] and r["duration"] > 0.3,
                      lambda r: r["speaker_id"], 12, ["audio_filepath", IVH_TEXT], rng)
    return tuple(r for r in rows if (r[IVH_TEXT] or "").strip())


def _ivh_clip(r: dict, source: str) -> dict:
    return clip(decode(r["audio_filepath"]), r[IVH_TEXT], source, r["speaker_id"],
                f"{r['district']}, {r['state']}", r["gender"], r["scenario"])


def _english_pct(r: dict) -> float:
    return float(r["ratio_english_words"] or 0)


def ivh_hi(rng: random.Random, n: int = 45, n_long: int = 6) -> list[dict]:
    rows = [r for r in _ivh_rows(11) if _english_pct(r) < 5]
    speaker, secs = (lambda r: r["speaker_id"]), (lambda r: float(r["duration"]))
    longs, used = speaker_runs(rows, speaker, secs, n_long, rng, LONG_MIN_S, LONG_MAX_S)
    out = [_ivh_stitched(p, "ivh_hi_long") for p in longs]
    rest = [r for r in rows if id(r) not in used]
    return out + [_ivh_clip(r, "ivh_hi") for r in spread(rest, n, speaker, rng, seconds=secs)]


def ivh_mix(rng: random.Random, n: int = 60, n_mid: int = 6, n_long: int = 6) -> list[dict]:
    """Code-mixed turns (>=15 % English words) + 15–35 s / 45–90 s stretches
    of one speaker's conversation that mix in English overall (>=8 %)."""
    rows = _ivh_rows(11)
    speaker, secs = (lambda r: r["speaker_id"]), (lambda r: float(r["duration"]))
    mixed = lambda parts: sum(map(_english_pct, parts)) / len(parts) >= 8
    longs, used = speaker_runs(rows, speaker, secs, n_long, rng, LONG_MIN_S, LONG_MAX_S,
                               accept=mixed)
    mids, used_mid = speaker_runs(rows, speaker, secs, n_mid, rng, 15.0, 35.0,
                                  exclude=used, accept=mixed)
    used |= used_mid
    out = [_ivh_stitched(p, "ivh_mix_long") for p in longs]
    out += [_ivh_stitched(p, "ivh_mix_mid") for p in mids]
    singles = [r for r in rows if id(r) not in used and _english_pct(r) >= 15]
    return out + [_ivh_clip(r, "ivh_mix") for r in spread(singles, n, speaker, rng, seconds=secs)]


def _ivh_stitched(parts: list[dict], source: str) -> dict:
    first = parts[0]
    return stitched(parts, "audio_filepath", IVH_TEXT, source, first["speaker_id"],
                    f"{first['district']}, {first['state']}", first["gender"],
                    first["scenario"])


def fleurs_hi(rng: random.Random) -> list[dict]:
    return fleurs("hi_in", 40, "fleurs_hi")


def svq_hi(rng: random.Random) -> list[dict]:
    return svq("hi_in", 13, rng)


def csfleurs(rng: random.Random) -> list[dict]:
    return cs_fleurs(40, rng)


HINDI_SOURCES = [fleurs_hi, svq_hi, ivh_hi]
HINGLISH_SOURCES = [csfleurs, ivh_mix]
