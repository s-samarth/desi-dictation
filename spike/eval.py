"""Evaluate candidate models against a personal Hinglish eval set.

Eval set layout:
    audio/refs.tsv       tab-separated: filename<TAB>reference transcript
    audio/*.wav          16kHz mono recordings referenced by refs.tsv

Usage:
    uv run eval.py --models swift apex          # compare two models
    uv run eval.py --models swift --limit 5     # quick pass

Outputs results/eval_<timestamp>.json and prints a markdown table
with raw WER and normalized WER (Hinglish spelling variants collapsed).
"""

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

import jiwer

from download_models import MODELS
from normalize import normalize
from transcribe import build_pipeline, transcribe

AUDIO_DIR = Path(__file__).parent / "audio"
RESULTS_DIR = Path(__file__).parent / "results"


def load_refs() -> list[tuple[Path, str]]:
    """Read refs.tsv -> [(audio_path, reference_text)]."""
    refs_file = AUDIO_DIR / "refs.tsv"
    if not refs_file.exists():
        raise SystemExit(
            f"No {refs_file}. Record clips (see README) and create refs.tsv first."
        )
    pairs = []
    for line in refs_file.read_text().strip().splitlines():
        name, ref = line.split("\t", 1)
        path = AUDIO_DIR / name
        if path.exists():
            pairs.append((path, ref.strip()))
        else:
            print(f"warn: {name} listed in refs.tsv but missing on disk — skipped")
    return pairs


def eval_model(model_key: str, pairs, limit: int | None) -> dict:
    """Transcribe all clips with one model and score."""
    pipe = build_pipeline(model_key)
    rows, hyps, refs = [], [], []
    for path, ref in pairs[:limit]:
        hyp, secs = transcribe(pipe, str(path))
        rows.append({"file": path.name, "ref": ref, "hyp": hyp, "seconds": round(secs, 2)})
        hyps.append(hyp)
        refs.append(ref)
    return {
        "model": MODELS[model_key],
        "clips": rows,
        "wer_raw": round(jiwer.wer(refs, hyps), 4),
        "wer_normalized": round(
            jiwer.wer([normalize(r) for r in refs], [normalize(h) for h in hyps]), 4
        ),
        "avg_seconds_per_clip": round(sum(r["seconds"] for r in rows) / len(rows), 2),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--models", nargs="+", default=["swift"], choices=list(MODELS))
    parser.add_argument("--limit", type=int, default=None, help="max clips per model")
    args = parser.parse_args()

    pairs = load_refs()
    print(f"==> {len(pairs)} labeled clips found")

    results = {m: eval_model(m, pairs, args.limit) for m in args.models}

    RESULTS_DIR.mkdir(exist_ok=True)
    out = RESULTS_DIR / f"eval_{int(time.time())}.json"
    out.write_text(json.dumps(results, ensure_ascii=False, indent=2))

    print("\n| model | raw WER | normalized WER | avg s/clip |")
    print("|---|---|---|---|")
    for key, res in results.items():
        print(
            f"| {key} | {res['wer_raw']:.2%} | {res['wer_normalized']:.2%} "
            f"| {res['avg_seconds_per_clip']} |"
        )
    print(f"\nDetails: {out}")


if __name__ == "__main__":
    main()
