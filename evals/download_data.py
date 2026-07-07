"""Download labeled eval data (audio + reference transcripts) per use case.

Suites (each -> evals/data/<suite>/clips/*.wav + manifest.jsonl):
  hindi    : google/fleurs hi_in test        (Devanagari refs)
  english  : ai4bharat/Svarah                (Indian-accented English)
  hinglish : byan/cs-fleurs Hindi-English    (code-switched refs)

Data is NOT committed to git (see .gitignore) — rerun this script to rebuild.

Usage: uv run download_data.py [--limit 50] [--suites hindi english hinglish]
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import soundfile as sf
from datasets import Audio, get_dataset_config_names, load_dataset

DATA_DIR = Path(__file__).parent / "data"

TEXT_KEYS = ["transcription", "text", "sentence", "transcript", "raw_transcription"]


def _find_text(row: dict) -> str | None:
    for key in TEXT_KEYS:
        if key in row and isinstance(row[key], str) and row[key].strip():
            return row[key].strip()
    return None


def _write_suite(name: str, rows, limit: int) -> None:
    suite_dir = DATA_DIR / name
    clips = suite_dir / "clips"
    clips.mkdir(parents=True, exist_ok=True)
    manifest = []
    for i, row in enumerate(rows):
        if i >= limit:
            break
        audio = row["audio"]
        ref = _find_text(row)
        if ref is None:
            continue
        arr = np.asarray(audio["array"], dtype=np.float32)
        fname = f"{i:04d}.wav"
        sf.write(clips / fname, arr, 16000)
        manifest.append({"file": fname, "ref": ref})
    with open(suite_dir / "manifest.jsonl", "w") as f:
        for entry in manifest:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    print(f"[{name}] wrote {len(manifest)} clips -> {suite_dir}")


def suite_hindi(limit: int) -> None:
    ds = load_dataset("google/fleurs", "hi_in", split="test", streaming=True,
                      trust_remote_code=True)
    ds = ds.cast_column("audio", Audio(sampling_rate=16000))
    _write_suite("hindi", ds, limit)


def suite_english(limit: int) -> None:
    ds = load_dataset("ai4bharat/Svarah", split="train", streaming=True)
    ds = ds.cast_column("audio", Audio(sampling_rate=16000))
    _write_suite("english", ds, limit)


def suite_hinglish(limit: int) -> None:
    configs = get_dataset_config_names("byan/cs-fleurs")
    # prefer a Hindi-English pair; print options if layout differs
    candidates = [c for c in configs if "hi" in c.lower() and "en" in c.lower()] or configs
    print(f"[hinglish] cs-fleurs configs: {configs[:20]} -> using {candidates[0]}")
    ds = load_dataset("byan/cs-fleurs", candidates[0], split="test", streaming=True)
    ds = ds.cast_column("audio", Audio(sampling_rate=16000))
    _write_suite("hinglish", ds, limit)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit", type=int, default=50, help="clips per suite")
    parser.add_argument("--suites", nargs="+",
                        default=["hindi", "english", "hinglish"])
    args = parser.parse_args()

    for suite in args.suites:
        try:
            {"hindi": suite_hindi, "english": suite_english,
             "hinglish": suite_hinglish}[suite](args.limit)
        except Exception as error:  # keep going; report what failed
            print(f"[{suite}] FAILED: {error}")


if __name__ == "__main__":
    main()
