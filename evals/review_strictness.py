"""Which words should Review before paste underline, at each strictness?

Two signals per word (REVIEW_BEFORE_PASTE.md "Strictness"):
  conf      the speech model's confidence (low = unclear audio)
  surprise  the context checker's -log p of the word in its sentence
            (high = odd in context: "watch one PC Luffy", unusual names)

For each strictness level a share of words may be flagged (its budget). Per
signal combination, the thresholds that catch the most wrong words within
that budget are found on the quick tier, and recall/precision reported.
Rows are cached, so re-running the analysis doesn't re-run the speech model.

Usage (the checker model is needed for surprise):
    DESI_CHECKER=~/Downloads/ctxfit/Qwen3-0.6B-Base.Q4_K_M.gguf uv run review_strictness.py
    uv run review_strictness.py --cached          # analyse the last run again
    uv run review_strictness.py --cached --suites english --models qwen3-asr
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from statistics import median

from run_eval import CLI, MODELS_DIR
from ordinary_words import is_ordinary
from word_confidence import DEFAULT_MODELS, run

LEVELS = {"conservative": 0.15, "moderate": 0.08, "liberal": 0.04}
# What the app ships (ReviewStrictness.swift): (confidence below, surprise above)
# per level, keyed by suite/model. Printed after the search so a re-run shows
# whether they still hold.
SHIPPED = {
    # English: everyday words need 8 nats more (EVERYDAY_EXTRA, shape "plus8").
    "english/parakeet": {"conservative": (0.66, 7.0), "moderate": (0.50, 8.0), "liberal": (0.43, 14.0)},
    "english/qwen3-asr": {"conservative": (None, 1.5), "moderate": (None, 3.6), "liberal": (None, 8.0)},
    "hinglish/hinglish-prime": {"conservative": (0.84, None), "moderate": (0.64, None), "liberal": (0.52, None)},
    "hindi/vaani": {"conservative": (0.59, 11.3), "moderate": (0.59, 19.4), "liberal": (0.54, 25.3)},
}
CACHE = Path(__file__).parent / "reports" / "review_strictness_rows.json"


def surprise(row: dict, clip: list[dict], how: str) -> float | None:
    """The surprise signal, in one of three shapes:
    raw       as scored
    opener    sentence-opening words discounted (anything may start a sentence)
    relative  minus the clip's median, for text the checker finds odd
              everywhere (romanised Hinglish)
    names     everyday words (ordinary_words) never count: casual grammar
              makes them odd, names never are everyday words
    plusN     everyday words need N more nats"""
    s = row["surprise"]
    if s is None:
        return None
    if how == "names" or how.startswith("plus"):
        if not is_ordinary(row.get("text", "")):
            return s
        return None if how == "names" else s - float(how[4:])
    if how == "opener":
        return s * 0.5 if row["opens"] else s
    if how == "relative":
        return s - median(r["surprise"] for r in clip if r["surprise"] is not None)
    return s


def best(rows: list[tuple], budget: float, use_conf: bool, use_surprise: bool) -> dict:
    """Thresholds within `budget` that catch the most wrong words. Each row is
    (conf, surprise, wrong); a word is flagged if conf < tc or surprise > ts."""
    n = len(rows) or 1
    errors = sum(r[2] for r in rows) or 1
    confs = sorted({r[0] for r in rows if r[0] is not None})
    surps = sorted({r[1] for r in rows if r[1] is not None}, reverse=True)
    tcs = ([c for i, c in enumerate(confs) if i % max(1, len(confs) // 200) == 0] + [None]) if use_conf else [None]
    tss = ([s for i, s in enumerate(surps) if i % max(1, len(surps) // 200) == 0] + [None]) if use_surprise else [None]
    top = {"flagged": 0, "recall": 0.0, "precision": 0.0, "conf_below": None, "surprise_above": None}
    for tc in tcs:
        for ts in tss:
            flagged = caught = 0
            for c, s, bad in rows:
                if (tc is not None and c is not None and c < tc) or (ts is not None and s is not None and s > ts):
                    flagged += 1
                    caught += bad
            if flagged / n > budget or caught / errors <= top["recall"]:
                continue
            top = {"flagged": round(flagged / n, 3), "recall": round(caught / errors, 3),
                   "precision": round(caught / max(flagged, 1), 3),
                   "conf_below": tc, "surprise_above": None if ts is None else round(ts, 2)}
    return top


def measure(rows: list[tuple], tc: float | None, ts: float | None) -> str:
    flagged = caught = 0
    for c, s, bad in rows:
        if (tc is not None and c is not None and c < tc) or (ts is not None and s is not None and s > ts):
            flagged += 1
            caught += bad
    errors = sum(r[2] for r in rows) or 1
    return (f"flag {flagged / len(rows):.1%}  recall {caught / errors:.1%}  "
            f"precision {caught / max(flagged, 1):.1%}")


def analyse(key: str, clips: list[list[dict]]) -> None:
    suite = key.split("/")[0]
    words = sum(len(c) for c in clips)
    wrong = sum(r["wrong"] for c in clips for r in c)
    print(f"\n== {key}: {words} words, {wrong} wrong ({wrong / max(words, 1):.1%})")
    shapes = ("raw", "names", "plus4", "plus8") if any("text" in r for c in clips for r in c) else ("raw", "opener", "relative")
    for how in shapes:
        rows = [(r["conf"], surprise(r, c, how), r["wrong"]) for c in clips for r in c]
        for level, budget in LEVELS.items():
            out = {"conf": best(rows, budget, True, False),
                   f"surprise:{how}": best(rows, budget, False, True),
                   f"both:{how}": best(rows, budget, True, True)}
            if how != "raw":
                out.pop("conf")
            for name, r in out.items():
                print(f"  {level:12} {name:18} flag {r['flagged']:.1%}  recall {r['recall']:.1%}  "
                      f"precision {r['precision']:.1%}  conf<{r['conf_below']}  surprise>{r['surprise_above']}")
    # As the app scores: everyday words need 8 nats more (never true for Devanagari).
    app = [(r["conf"], surprise(r, c, "plus8"), r["wrong"]) for c in clips for r in c]
    for level, (tc, ts) in SHIPPED.get(key, {}).items():
        print(f"  shipped {level:12} conf<{tc} surprise>{ts}: {measure(app, tc, ts)}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--suites", nargs="+", default=list(DEFAULT_MODELS))
    parser.add_argument("--models", nargs="+", default=None,
                        help="substring per suite, in the same order as --suites")
    parser.add_argument("--cli", type=Path, default=CLI)
    parser.add_argument("--cached", action="store_true", help="reuse the last run's rows")
    args = parser.parse_args()
    data = json.loads(CACHE.read_text()) if args.cached and CACHE.exists() else {}
    for n, suite in enumerate(args.suites):
        wanted = args.models[n] if args.models else DEFAULT_MODELS[suite]
        key = f"{suite}/{wanted}"
        if key not in data:
            model = next((p for p in sorted(MODELS_DIR.glob("ggml-*.bin")) if wanted in p.name), None)
            if model is None:
                print(f"{suite}: no installed model matching {wanted!r}")
                continue
            data[key] = run(args.cli, model, suite)
            CACHE.parent.mkdir(exist_ok=True)
            CACHE.write_text(json.dumps(data))
        analyse(key, data[key])


if __name__ == "__main__":
    main()
