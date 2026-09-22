"""Build the eval suites: diverse, labeled, small (see README "Suites").

Each suite -> evals/data/<suite>/clips/*.wav + manifest.jsonl, one line per clip:
  {file, ref, source, speaker, region, gender, env, seconds, bucket, quick}

Only the Parquet row groups holding the chosen clips are downloaded (a few
hundred MB total, streamed, nothing cached); ~150 MB of 16 kHz WAV is kept.
Deterministic: the same command rebuilds the same set. An existing suite is
moved to the Trash first, never deleted. Data is NOT committed to git.

Usage: uv run download_data.py [--suites english hindi hinglish]
"""

from __future__ import annotations

import argparse
import json
import random
import shutil
import sys
import time
import zlib
from collections import Counter
from pathlib import Path

import soundfile as sf

import sources_en
import sources_indic
from sampling import SR, bucket_of, mark_quick

DATA_DIR = Path(__file__).parent / "data"

SUITES = {
    "english": sources_en.SOURCES,
    "hindi": sources_indic.HINDI_SOURCES,
    "hinglish": sources_indic.HINGLISH_SOURCES,
}

# Clips per source in the quick tier (stratified by length bucket). The
# quick tier is what you run routinely; the full tier before a model change.
QUICK = {
    "svarah": 16, "svarah_mid": 1, "svarah_long": 1,
    "sdqa_ind_n": 5, "sdqa_ind_s": 5, "sdqa_usa": 3, "svq_en_in": 8,
    "edacc_in": 8, "edacc_in_mid": 2, "edacc_in_long": 2, "fleurs_en_us": 4,
    "fleurs_hi": 6, "svq_hi_in": 6, "ivh_hi": 10, "ivh_hi_long": 1,
    "csfleurs_hin_eng": 6, "ivh_mix": 14, "ivh_mix_mid": 2, "ivh_mix_long": 1,
}


def build_suite(name: str) -> list[str]:
    """Collect every source's clips; returns the names of sources that failed."""
    clips, failed = [], []
    for source in SUITES[name]:
        rng = random.Random(zlib.crc32(source.__name__.encode()))
        start = time.time()
        print(f"[{name}] {source.__name__} …", flush=True)
        try:
            got = source(rng)
        except Exception as error:  # loud, never a silent substitute (FM#24)
            print(f"[{name}] !! {source.__name__} FAILED: {error}", file=sys.stderr)
            failed.append(source.__name__)
            continue
        clips += [c for c in got if len(c["audio"]) > SR // 4 and c["ref"]]
        print(f"[{name}]    {len(got)} clips in {time.time() - start:.0f}s", flush=True)
    write_suite(name, clips)
    return failed


def write_suite(name: str, clips: list[dict]) -> None:
    suite_dir = DATA_DIR / name
    if suite_dir.exists():
        trash = Path.home() / ".Trash" / f"eval-{name}-{time.strftime('%Y%m%d-%H%M%S')}"
        shutil.move(str(suite_dir), str(trash))
    (suite_dir / "clips").mkdir(parents=True)
    manifest = []
    for i, c in enumerate(clips):
        fname = f"{i:04d}.wav"
        sf.write(suite_dir / "clips" / fname, c["audio"], SR, subtype="PCM_16")
        seconds = round(len(c["audio"]) / SR, 2)
        manifest.append({"file": fname, "ref": c["ref"], "source": c["source"],
                         "speaker": c["speaker"], "region": c["region"],
                         "gender": c["gender"], "env": c["env"],
                         "seconds": seconds, "bucket": bucket_of(seconds)})
    mark_quick(manifest, QUICK)
    with open(suite_dir / "manifest.jsonl", "w") as f:
        for entry in manifest:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    summarize(name, manifest, suite_dir)


def summarize(name: str, manifest: list[dict], suite_dir: Path) -> None:
    minutes = sum(e["seconds"] for e in manifest) / 60
    size_mb = sum(p.stat().st_size for p in (suite_dir / "clips").iterdir()) / 1e6
    quick = [e for e in manifest if e["quick"]]
    print(f"\n[{name}] {len(manifest)} clips, {minutes:.1f} min, {size_mb:.0f} MB "
          f"— quick tier {len(quick)} clips, "
          f"{sum(e['seconds'] for e in quick) / 60:.1f} min")
    print(f"  sources : {dict(Counter(e['source'] for e in manifest))}")
    print(f"  buckets : {dict(sorted(Counter(e['bucket'] for e in manifest).items()))}")
    print(f"  speakers: {len({e['speaker'] for e in manifest if e['speaker']})} named, "
          f"regions: {len({e['region'] for e in manifest if e['region']})}\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suites", nargs="+", default=list(SUITES), choices=list(SUITES))
    args = parser.parse_args()
    failed = [f"{s}/{src}" for s in args.suites for src in build_suite(s)]
    if failed:
        print(f"FAILED sources (suite built without them): {failed}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
