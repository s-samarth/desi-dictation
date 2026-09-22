"""Diversity-first sampling for the eval suites.

The old downloader took "the first N rows" — which on most datasets means one
or two speakers reading back to back. Here every pick is spread across
speakers / regions / conditions AND across length buckets, deterministically
(fixed seed), so the same command rebuilds the same set.
"""

from __future__ import annotations

import random
import re
from collections import defaultdict

import numpy as np

SR = 16000
# Upper bounds in seconds. xs = "haan", "send it"; xl = a long dictation that
# crosses whisper's 30 s window (and the app's chunker).
BUCKETS = [("xs", 2.5), ("s", 6.0), ("m", 15.0), ("l", 35.0), ("xl", float("inf"))]
WORDS_PER_SECOND = 2.5          # proxy for sources with no duration column

_TAGS = re.compile(r"<[^>]*>|\[[^\]]*\]|\([^)]*\)")
_NUMBER_WORDS = re.compile(
    r"\b(zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|"
    r"thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|"
    r"thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred|thousand|"
    r"million|lakh|crore|percent)\b", re.IGNORECASE)


def bucket_of(seconds: float) -> str:
    return next(name for name, upper in BUCKETS if seconds < upper)


def est_seconds(row: dict, text_key: str) -> float:
    """Real duration if the source has one, else a words-per-second guess."""
    if row.get("duration"):
        return float(row["duration"])
    return len(str(row.get(text_key) or "").split()) / WORDS_PER_SECOND


def clean_ref(text: str) -> str:
    """Drop annotation tags (<laugh>, [noise], (inaudible)) and extra spaces."""
    return " ".join(_TAGS.sub(" ", text or "").split())


def spelled_numbers(text: str) -> bool:
    """Refs that verbalize numbers ("r three minus r one") score formatting,
    not hearing, against models that write digits — such rows are skipped."""
    return bool(_NUMBER_WORDS.search(text or ""))


def spread(rows: list[dict], n: int, key, rng: random.Random,
           seconds=None) -> list[dict]:
    """Pick n rows round-robin across groups (key) and, within each group,
    across length buckets — so no speaker or length dominates."""
    groups: dict = defaultdict(list)
    for row in rows:
        groups[key(row)].append(row)
    queues = []
    for members in groups.values():
        rng.shuffle(members)
        if seconds:  # interleave buckets inside the group
            by_bucket = defaultdict(list)
            for m in members:
                by_bucket[bucket_of(seconds(m))].append(m)
            members = _interleave(list(by_bucket.values()))
        queues.append(members)
    rng.shuffle(queues)
    return _interleave(queues)[:n]


def _interleave(queues: list[list]) -> list:
    out, i = [], 0
    while any(i < len(q) for q in queues):
        out += [q[i] for q in queues if i < len(q)]
        i += 1
    return out


def choose_rowgroups(rows: list[dict], k: int, key, rng: random.Random) -> list[tuple]:
    """k (file, row group) units maximizing distinct groups (speakers/states)
    — the row group is the unit of audio download, so this bounds bytes."""
    units: dict = defaultdict(set)
    for row in rows:
        units[(row["_file"], row["_rg"])].add(key(row))
    order = list(units)
    rng.shuffle(order)
    chosen, seen = [], set()
    while order and len(chosen) < k:
        best = max(order, key=lambda u: len(units[u] - seen))
        order.remove(best)
        chosen.append(best)
        seen |= units[best]
    return chosen


def stitch(parts: list[tuple[np.ndarray, str]], gap: float = 0.4) -> tuple[np.ndarray, str]:
    """Consecutive segments of ONE speaker -> one long dictation, with short
    pauses — the shape of a real 1-minute dictation."""
    silence = np.zeros(int(gap * SR), dtype=np.float32)
    audio = np.concatenate([x for a, _ in parts for x in (a, silence)][:-1])
    return audio, " ".join(ref for _, ref in parts)


def runs(rows: list[dict], same, target_s: float, max_s: float, seconds) -> list[list[dict]]:
    """Split ordered rows into runs of consecutive same-speaker segments
    totalling target_s..max_s seconds (for stitched long-form clips)."""
    out, cur, total = [], [], 0.0
    for row in rows:
        if cur and (not same(cur[-1], row) or total + seconds(row) > max_s):
            if total >= target_s:
                out.append(cur)
            cur, total = [], 0.0
        cur.append(row)
        total += seconds(row)
    if cur and total >= target_s:
        out.append(cur)
    return out


def mark_quick(entries: list[dict], per_source: dict[str, int], seed: int = 7) -> None:
    """Flag a fixed, stratified subset as the quick tier (source x bucket)."""
    rng = random.Random(seed)
    by_source: dict = defaultdict(list)
    for e in entries:
        by_source[e["source"]].append(e)
    for source, members in by_source.items():
        picks = {id(e) for e in spread(members, per_source.get(source, 0),
                                       lambda e: e["bucket"], rng)}
        for e in members:
            e["quick"] = id(e) in picks
