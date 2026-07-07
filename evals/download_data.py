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
    ds = load_dataset("google/fleurs", "hi_in", split="test", streaming=True)
    ds = ds.cast_column("audio", Audio(sampling_rate=16000))
    _write_suite("hindi", ds, limit)


def suite_english(limit: int) -> None:
    # Svarah (Indian-accented English) is gated — needs `hf auth login`.
    # Fall back to FLEURS en_us (generic English) when unauthenticated.
    try:
        ds = load_dataset("ai4bharat/Svarah", split="train", streaming=True)
        ds = ds.cast_column("audio", Audio(sampling_rate=16000))
        _write_suite("english", ds, limit)
    except Exception as error:
        print(f"[english] Svarah unavailable ({str(error)[:80]}…) — "
              "falling back to FLEURS en_us. Run `hf auth login` for Svarah.")
        ds = load_dataset("google/fleurs", "en_us", split="test", streaming=True)
        ds = ds.cast_column("audio", Audio(sampling_rate=16000))
        _write_suite("english", ds, limit)


def suite_hinglish(limit: int) -> None:
    """CS-FLEURS read/test subset (human speech), language == hin-eng only.

    The dataset's `default` config interleaves 113 language pairs (the naive
    first-N rows are Arabic-English!), so we filter the metadata ourselves and
    fetch just the matching audio files.
    """
    from huggingface_hub import hf_hub_download

    meta_path = hf_hub_download("byan/cs-fleurs", "read/test/metadata.jsonl",
                                repo_type="dataset")
    rows = [json.loads(l) for l in open(meta_path)]
    rows = [r for r in rows if r["language"] == "hin-eng"][:limit]
    print(f"[hinglish] {len(rows)} human-read hin-eng clips from cs-fleurs read/test")

    suite_dir = DATA_DIR / "hinglish"
    clips = suite_dir / "clips"
    clips.mkdir(parents=True, exist_ok=True)
    manifest = []
    for i, row in enumerate(rows):
        audio_path = hf_hub_download(
            "byan/cs-fleurs", f"read/test/{row['file_name']}", repo_type="dataset")
        arr, sr = sf.read(audio_path, dtype="float32")
        if arr.ndim > 1:
            arr = arr.mean(axis=1)
        if sr != 16000:  # linear resample — fine for eval speech
            target_len = int(len(arr) * 16000 / sr)
            arr = np.interp(np.linspace(0, len(arr) - 1, target_len),
                            np.arange(len(arr)), arr).astype(np.float32)
        fname = f"{i:04d}.wav"
        sf.write(clips / fname, arr, 16000)
        manifest.append({"file": fname, "ref": row["text"].strip()})
    with open(suite_dir / "manifest.jsonl", "w") as f:
        for entry in manifest:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    print(f"[hinglish] wrote {len(manifest)} clips -> {suite_dir}")


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
