"""Does per-word confidence find the words the model got wrong?

Stage 1 of Review before paste (docs/features/implementation/REVIEW_BEFORE_PASTE.md):
run the shipping model on the quick tier with `desi-cli --batch --words`,
align every hypothesis word to the reference, and ask what share of the wrong
words lands among the least confident 5 % (target: >= 40 %).

A word is wrong if it is a substitution or an insertion after normalization
(the same normalizers as run_eval: nWER for English, crWER otherwise).
Deleted words have no hypothesis word to underline, so they are reported
separately and don't count against recall.

Usage:
    uv run word_confidence.py                       # all three suites
    uv run word_confidence.py --suites english --models qwen3-asr
    uv run word_confidence.py --cli ../app/.build/debug/desi-cli
"""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

from metrics import basic_normalize, collapse_roman
from run_eval import CLI, MODELS_DIR, manifest, mode_for, tier_dir

DEFAULT_MODELS = {"english": "parakeet", "hinglish": "hinglish-prime", "hindi": "vaani"}
RATES = [0.05, 0.10, 0.15, 0.20]


def normalize(suite: str, text: str) -> list[str]:
    return (basic_normalize(text) if suite == "english" else collapse_roman(text)).split()


def align(hyp: list[str], ref: list[str]) -> list[bool]:
    """Levenshtein alignment; True per hypothesis token that is wrong."""
    n, m = len(hyp), len(ref)
    d = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(n + 1):
        d[i][0] = i
    for j in range(m + 1):
        d[0][j] = j
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1,
                          d[i - 1][j - 1] + (hyp[i - 1] != ref[j - 1]))
    wrong = [False] * n
    i, j = n, m
    while i > 0:
        if j > 0 and d[i][j] == d[i - 1][j - 1] + (hyp[i - 1] != ref[j - 1]):
            wrong[i - 1] = hyp[i - 1] != ref[j - 1]
            i, j = i - 1, j - 1
        elif d[i][j] == d[i - 1][j] + 1:
            wrong[i - 1] = True          # insertion
            i -= 1
        else:
            j -= 1                       # deletion: nothing to underline
    return wrong


def score_clip(suite: str, words: list, ref: str) -> list[tuple[float, bool]]:
    """(confidence, wrong) per hypothesis word with a known confidence."""
    pieces, owner = [], []
    for k, (text, _) in enumerate(words):
        for token in normalize(suite, text):
            pieces.append(token)
            owner.append(k)
    wrong_tokens = align(pieces, normalize(suite, ref))
    wrong = [False] * len(words)
    for k, bad in zip(owner, wrong_tokens):
        wrong[k] = wrong[k] or bad
    return [(conf, wrong[k]) for k, (_, conf) in enumerate(words)
            if conf is not None and any(o == k for o in owner)]


def run(cli: Path, model: Path, suite: str) -> list[tuple[float, bool]]:
    entries = manifest(suite, "quick")
    folder = tier_dir(suite, "quick", entries)
    proc = subprocess.run([str(cli), str(model), "--batch", str(folder),
                           mode_for(model.stem, suite), "--words"],
                          capture_output=True, text=True, timeout=3600)
    outputs = {}
    for line in proc.stdout.splitlines():
        try:
            rec = json.loads(line)
            outputs[rec["file"]] = rec
        except json.JSONDecodeError:
            continue
    rows = []
    for e in entries:
        if e["file"] in outputs:
            rows += score_clip(suite, outputs[e["file"]].get("words", []), e["ref"])
    return rows


def report(suite: str, model: str, rows: list[tuple[float, bool]]) -> dict:
    if not rows:
        return {"suite": suite, "model": model, "words": 0}
    rows = sorted(rows, key=lambda r: r[0])
    errors = sum(bad for _, bad in rows)
    out = {"suite": suite, "model": model, "words": len(rows), "wrong": errors,
           "base_rate": round(errors / len(rows), 3), "by_rate": []}
    for rate in RATES:
        k = max(1, round(rate * len(rows)))
        caught = sum(bad for _, bad in rows[:k])
        out["by_rate"].append({"flag": rate, "threshold": round(rows[k - 1][0], 3),
                               "recall": round(caught / max(errors, 1), 3),
                               "precision": round(caught / k, 3)})
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--suites", nargs="+", default=list(DEFAULT_MODELS))
    parser.add_argument("--models", nargs="+", default=None,
                        help="substring per suite, in the same order as --suites")
    parser.add_argument("--cli", type=Path, default=CLI)
    args = parser.parse_args()
    for n, suite in enumerate(args.suites):
        wanted = args.models[n] if args.models else DEFAULT_MODELS[suite]
        model = next((p for p in sorted(MODELS_DIR.glob("ggml-*.bin")) if wanted in p.name), None)
        if model is None:
            print(f"{suite}: no installed model matching {wanted!r}")
            continue
        result = report(suite, model.stem, run(args.cli, model, suite))
        print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
