"""Shared machinery for eval sources: load chosen row groups, build clips.

A *clip* is a dict: {audio (16 kHz float32), ref, source, speaker, region,
gender, env}. `download_data.py` adds seconds/bucket/quick and writes it.
Every clip carries its `source`, so a substituted dataset can never again
masquerade as another one in a report (BUILD_LOG FM#24).
"""

from __future__ import annotations

import json
import random
from concurrent.futures import ThreadPoolExecutor

import numpy as np

from hf_parquet import HF, _get, decode, fetch, list_files, scan, seconds_of
from sampling import choose_rowgroups, clean_ref, est_seconds, runs, spread, stitch


def clip(audio: np.ndarray, ref: str, source: str, speaker: str = "",
         region: str = "", gender: str = "", env: str = "") -> dict:
    return {"audio": audio, "ref": clean_ref(ref), "source": source,
            "speaker": str(speaker or ""), "region": str(region or ""),
            "gender": str(gender or "").lower(), "env": str(env or "")}


def load_units(repo: str, files: list[str], meta_cols: list[str], keep,
               group, units: int, fetch_cols: list[str],
               rng: random.Random) -> list[dict]:
    """Scan metadata, choose `units` row groups maximizing distinct `group`
    values, download only those, and return their kept rows in file order
    with the fetched columns merged in."""
    rows = [r for r in scan(repo, files, meta_cols) if keep(r)]
    chosen = choose_rowgroups(rows, units, group, rng)

    def one(unit):
        return unit, fetch(repo, unit[0], unit[1], fetch_cols)

    with ThreadPoolExecutor(max_workers=4) as pool:
        fetched = dict(pool.map(one, chosen))
    out = []
    for row in rows:
        unit = (row["_file"], row["_rg"])
        if unit in fetched:
            merged = {**row, **fetched[unit][row["_i"]]}
            if not merged.get("duration"):  # real length for bucketing/stitching
                merged["duration"] = next((d for c in fetch_cols
                                           if (d := seconds_of(merged.get(c)))), None)
            out.append(merged)
    out.sort(key=lambda r: (r["_file"], r["_rg"], r["_i"]))
    print(f"    {repo}: {len(chosen)} row groups, {len(out)} candidate rows, "
          f"{len({group(r) for r in out})} distinct groups")
    return out


def speaker_runs(rows: list[dict], speaker, secs, n: int, rng: random.Random,
                 lo: float, hi: float, same=lambda a, b: True, exclude=frozenset(),
                 accept=lambda parts: True):
    """Up to n runs of ONE speaker's consecutive segments totalling lo..hi s,
    spread across speakers, keeping runs `accept` likes.
    Returns (runs, ids of the rows they consumed)."""
    by_speaker: dict = {}
    for r in rows:
        if id(r) not in exclude:
            by_speaker.setdefault(speaker(r), []).append(r)
    candidates = [run for members in by_speaker.values()
                  for run in runs(members, same, lo, hi, secs) if accept(run)]
    picked = spread(candidates, n, lambda parts: speaker(parts[0]), rng)
    return picked, {id(r) for parts in picked for r in parts}


def stitched(parts: list[dict], audio_key: str, text_key: str, source: str,
             speaker: str, region: str = "", gender: str = "", env: str = "") -> dict:
    audio, ref = stitch([(decode(p[audio_key]), p[text_key]) for p in parts])
    return clip(audio, ref, source, speaker, region, gender, env)


def pick_files(repo: str, prefix: str, contains: str, k: int,
               rng: random.Random) -> list[str]:
    files = list_files(repo, prefix, contains)
    return sorted(rng.sample(files, min(k, len(files))))


# --- sources shared by more than one suite ---------------------------------

SVQ = "google/svq"


def svq(locale: str, per_env: int, rng: random.Random) -> list[dict]:
    """Google Simple Voice Questions: short spoken queries by Indian speakers,
    recorded clean AND with people talking in the background (office noise)."""
    out = []
    for env in ("clean", "background_speech"):
        files = list_files(SVQ, "1.0.0/audio", f"utts_{locale}_{env}.parquet")
        rows = load_units(SVQ, files, ["utt_id", "speaker_id", "speaker_gender", "text"],
                          lambda r: bool(r["text"]), lambda r: r["speaker_id"], 1,
                          ["waveform"], rng)
        for r in spread(rows, per_env, lambda r: r["speaker_id"], rng):
            out.append(clip(decode(r["waveform"]), r["text"], f"svq_{locale}",
                            r["speaker_id"], "", r["speaker_gender"], env))
    return out


def fleurs(config: str, n: int, source: str) -> list[dict]:
    """FLEURS read speech (Wikipedia sentences), every 4th row for speaker
    spread. Kept as a *control* so new numbers stay comparable to old ones."""
    from datasets import Audio, load_dataset

    ds = load_dataset("google/fleurs", config, split="test", streaming=True)
    ds = ds.cast_column("audio", Audio(sampling_rate=16000))
    out = []
    for i, row in enumerate(ds):
        if i % 4:
            continue
        audio = np.asarray(row["audio"]["array"], dtype=np.float32)
        # FLEURS publishes no speaker id — only gender.
        out.append(clip(audio, row["transcription"], source, "", "", row.get("gender", "")))
        if len(out) >= n:
            break
    return out


def cs_fleurs(n: int, rng: random.Random) -> list[dict]:
    """CS-FLEURS read/test, human-read hin-eng code-switched sentences.
    (Its `default` config interleaves 113 language pairs — filter ourselves.)"""
    base = f"{HF}/datasets/byan/cs-fleurs/resolve/main/read/test"
    meta = [json.loads(l) for l in _get(f"{base}/metadata.jsonl").text.splitlines() if l]
    rows = [r for r in meta if r.get("language") == "hin-eng"]
    picks = spread(rows, n, lambda r: r.get("speaker", r["file_name"]), rng,
                   seconds=lambda r: est_seconds(r, "text"))
    out = []
    for r in picks:
        audio = decode({"bytes": _get(f"{base}/{r['file_name']}").content})
        out.append(clip(audio, r["text"], "csfleurs_hin_eng", r.get("speaker", "")))
    return out
