"""Scoring breakdowns + report files for run_eval.py.

One number per suite hides exactly what the rebuilt suites exist to show —
"fine on read speech, falls apart on 1-second clips or on chatter" — so every
result also carries per-source and per-length-bucket slices.
"""

from __future__ import annotations

import json
import statistics
from collections import defaultdict
from pathlib import Path

from metrics import score

BUCKET_ORDER = ["xs", "s", "m", "l", "xl"]


def summarize(pairs: list[tuple[dict, dict]]) -> dict:
    """pairs = [(manifest entry, desi-cli output)] -> metrics + latency."""
    refs = [e["ref"] for e, _ in pairs]
    hyps = [o["text"] for _, o in pairs]
    secs = sorted(o["seconds"] for _, o in pairs)
    audio = sum(o["audio_seconds"] for _, o in pairs)
    return {
        "clips": len(pairs), **score(refs, hyps),
        "median_s": round(statistics.median(secs), 2),
        "p90_s": round(secs[max(0, int(0.9 * len(secs)) - 1)], 2),
        "rtf": round(audio / max(sum(secs), 0.001), 1),
        "audio_minutes": round(audio / 60, 1),
    }


def breakdown(pairs: list[tuple[dict, dict]], field: str) -> dict:
    groups: dict = defaultdict(list)
    for entry, out in pairs:
        groups[entry.get(field) or "?"].append((entry, out))
    return {k: summarize(v) for k, v in groups.items()}


def write(rows: list[dict], meta: dict, reports_dir: Path) -> Path:
    reports_dir.mkdir(exist_ok=True)
    json_path = reports_dir / f"report_{meta['timestamp']}.json"
    json_path.write_text(json.dumps({"meta": meta, "results": rows},
                                    ensure_ascii=False, indent=2))
    md_path = json_path.with_suffix(".md")
    md_path.write_text("\n".join(_markdown(rows, meta)) + "\n")
    return md_path


def _markdown(rows: list[dict], meta: dict) -> list[str]:
    lines = [f"# Eval report {meta['timestamp']} (commit {meta['git_commit']}, "
             f"{meta['tier']} tier)", "",
             "Primary metric: nWER for english, crWER for hindi/hinglish. "
             "Latency = per clip, model resident.", "",
             "| suite | model | mode | clips | crWER | nWER | WER | median | p90 |",
             "|---|---|---|---|---|---|---|---|---|"]
    for r in sorted(rows, key=lambda r: (r["suite"], r["crwer"])):
        lines.append(f"| {r['suite']} | {r['model']} | {r['mode']} | {r['clips']} "
                     f"| {r['crwer']:.1%} | {r['nwer']:.1%} | {r['wer']:.1%} "
                     f"| {r['median_s']} s | {r['p90_s']} s |")
    for r in rows:
        metric = "nwer" if r["suite"] == "english" else "crwer"
        lines += ["", f"## {r['suite']} × {r['model']} — {metric} by slice", "",
                  "| slice | clips | " + metric + " | median |", "|---|---|---|---|"]
        buckets = sorted(r["by_bucket"].items(),
                         key=lambda kv: BUCKET_ORDER.index(kv[0]) if kv[0] in BUCKET_ORDER else 9)
        for label, part in [("length", buckets), ("source", sorted(r["by_source"].items()))]:
            for name, s in part:
                lines.append(f"| {label}: {name} | {s['clips']} | {s[metric]:.1%} "
                             f"| {s['median_s']} s |")
    return lines
