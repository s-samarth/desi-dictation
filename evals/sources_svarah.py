"""Svarah (AI4Bharat) — Indian-accented English, the english suite's core.

6,656 clips from speakers of 19 native languages (Nepali, Kannada, Urdu,
Malayalam, Tamil, Bodo, Kashmiri, …) across 17 states / 65 districts, read AND
extempore. Gated: needs `hf auth login` with an account approved on its HF page
(approved 2026-09-23; before that the suite silently used US English — FM#24).

Singles are spread across native languages. Long clips are consecutive chunks
of ONE recording (file names are `<id>_f<rec>_chunk_<n>.wav`); chunks of a
recording are scattered across row groups, so recordings are chosen greedily
by how few *new* row groups they need — that keeps the download bounded.
"""

from __future__ import annotations

import random
import re
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor

from hf_parquet import decode, fetch, list_files, scan
from sampling import choose_rowgroups, runs, spelled_numbers, spread, stitch
from sources_common import clip

REPO = "ai4bharat/Svarah"
META = ["audio_filepath.path", "duration", "gender", "primary_language",
        "native_place_state", "native_place_district", "text"]
_NAME = re.compile(r"(\d+)_(f\d+)_chunk_(\d+)")
MAX_UNITS = 16                      # row groups (~18 MB each) we allow ourselves


def svarah(rng: random.Random, n: int = 80, n_mid: int = 6, n_long: int = 6) -> list[dict]:
    rows = [r for r in scan(REPO, list_files(REPO, "data"), META)
            if r["text"] and not spelled_numbers(r["text"])]
    for r in rows:
        ident, rec, chunk = _NAME.match(r["audio_filepath"]["path"]).groups()
        r["rec"], r["chunk"] = f"{ident}_{rec}", int(chunk)
    l1 = lambda r: r["primary_language"]
    units = set(choose_rowgroups(rows, 8, l1, rng))
    longs = _runs(rows, 45.0, 90.0, n_long, units, rng)
    mids = _runs(rows, 15.0, 35.0, n_mid, units, rng,
                 skip={r["rec"] for p in longs for r in p})
    audio = _fetch(units)

    def sound(r):
        return decode(audio[(r["_file"], r["_rg"])][r["_i"]]["audio_filepath"])

    def meta(r):  # speaker = recording id (Svarah publishes no speaker id)
        return (r["rec"], f"{r['native_place_district']}, {r['native_place_state']}"
                f" · L1 {r['primary_language']}", r["gender"])

    out = []
    for source, picked in (("svarah_long", longs), ("svarah_mid", mids)):
        for parts in picked:
            joined, ref = stitch([(sound(p), p["text"]) for p in parts])
            out.append(clip(joined, ref, source, *meta(parts[0])))
    used = {id(r) for p in longs + mids for r in p}
    pool = [r for r in rows if (r["_file"], r["_rg"]) in units and id(r) not in used]
    for r in spread(pool, n, l1, rng, seconds=lambda r: r["duration"]):
        out.append(clip(sound(r), r["text"], "svarah", *meta(r)))
    return out


def _runs(rows, lo, hi, n, units, rng, skip=frozenset()) -> list[list[dict]]:
    """n single-recording runs of lo..hi s, preferring ones needing the fewest
    new row groups (then a native language not yet covered). Adds to units."""
    by_rec = defaultdict(list)
    for r in rows:
        if r["rec"] not in skip:
            by_rec[r["rec"]].append(r)
    candidates = []
    for members in by_rec.values():
        members.sort(key=lambda r: r["chunk"])
        consecutive = lambda a, b: b["chunk"] == a["chunk"] + 1
        candidates += runs(members, consecutive, lo, hi, lambda r: r["duration"])
    rng.shuffle(candidates)
    picked, langs = [], set()
    while candidates and len(picked) < n:
        need = lambda p: {(r["_file"], r["_rg"]) for r in p} - units
        best = min(candidates, key=lambda p: (len(need(p)), p[0]["primary_language"] in langs))
        if len(units | need(best)) > MAX_UNITS:
            break
        candidates.remove(best)
        picked.append(best)
        units |= need(best)
        langs.add(best[0]["primary_language"])
    return picked


def _fetch(units: set) -> dict:
    with ThreadPoolExecutor(max_workers=4) as pool:
        return dict(zip(sorted(units), pool.map(
            lambda u: fetch(REPO, u[0], u[1], ["audio_filepath"]), sorted(units))))
