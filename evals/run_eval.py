"""Run every model against every eval suite through the REAL shipping engine
(desi-cli --batch = whisper.cpp with the app's exact params/VAD), score with
metrics.py, and write a versioned report.

Usage:
    uv run run_eval.py                       # all installed models, all suites
    uv run run_eval.py --suites hindi --models apex-q5_0
Output:
    reports/report_<UTC>.json   (schema in README.md)
    reports/report_<UTC>.md     (human table)
"""

from __future__ import annotations

import argparse
import json
import platform
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

from metrics import score

ROOT = Path(__file__).parent.parent
DATA_DIR = Path(__file__).parent / "data"
REPORTS_DIR = Path(__file__).parent / "reports"
CLI = ROOT / "app/.build/release/desi-cli"
MODELS_DIR = Path.home() / "Library/Application Support/DesiDictation/models"

# Which language mode each model family runs in, per suite. Hinglish models
# always emit Roman ("en" token); stock/vaani follow the suite's language.
def mode_for(model_name: str, suite: str) -> str:
    if "hinglish" in model_name:
        return "hinglish"
    return {"hindi": "hindi", "english": "english", "hinglish": "hindi"}[suite]


def serves(model_name: str, suite: str) -> bool:
    """Parakeet is English-only for us (no Devanagari, no Roman-Hinglish), so
    scoring it on the Hindi/Hinglish suites would just log noise.
    Mirrors ModelManager.score()."""
    return "parakeet" not in model_name or suite == "english"


def installed_models() -> list[Path]:
    return sorted(p for p in MODELS_DIR.glob("ggml-*.bin")
                  if "silero" not in p.name)


def run_batch(model: Path, suite_dir: Path, mode: str) -> dict[str, dict]:
    """Returns {file: {text, seconds, audio_seconds}} from desi-cli --batch."""
    proc = subprocess.run(
        [str(CLI), str(model), "--batch", str(suite_dir / "clips"), mode],
        capture_output=True, text=True, timeout=3600)
    results = {}
    for line in proc.stdout.splitlines():
        try:
            rec = json.loads(line)
            results[rec["file"]] = rec
        except json.JSONDecodeError:
            continue
    return results


def evaluate(model: Path, suite: str) -> dict | None:
    if not serves(model.name, suite):
        return None
    suite_dir = DATA_DIR / suite
    manifest_file = suite_dir / "manifest.jsonl"
    if not manifest_file.exists():
        return None
    manifest = [json.loads(l) for l in manifest_file.read_text().splitlines()]
    mode = mode_for(model.stem, suite)
    outputs = run_batch(model, suite_dir, mode)

    refs, hyps, total_audio, total_time = [], [], 0.0, 0.0
    for entry in manifest:
        out = outputs.get(entry["file"])
        if out is None:
            continue
        refs.append(entry["ref"])
        hyps.append(out["text"])
        total_audio += out["audio_seconds"]
        total_time += out["seconds"]
    if not refs:
        return None

    metrics = score(refs, hyps)
    return {
        "suite": suite, "model": model.stem, "mode": mode,
        "clips": len(refs),
        **metrics,
        "rtf": round(total_audio / max(total_time, 0.001), 1),
        "audio_minutes": round(total_audio / 60, 1),
    }


def git_commit() -> str:
    try:
        return subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT,
                              capture_output=True, text=True).stdout.strip()
    except Exception:
        return "unknown"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suites", nargs="+", default=["hindi", "english", "hinglish"])
    parser.add_argument("--models", nargs="+", default=None,
                        help="substring filters, e.g. apex swift (default: all)")
    args = parser.parse_args()

    models = installed_models()
    if args.models:
        models = [m for m in models if any(f in m.name for f in args.models)]

    rows = []
    for model in models:
        for suite in args.suites:
            print(f"==> {model.stem} × {suite}")
            result = evaluate(model, suite)
            if result:
                rows.append(result)
                print(f"    crWER {result['crwer']:.1%}  WER {result['wer']:.1%}  "
                      f"{result['rtf']}x realtime  ({result['clips']} clips)")

    stamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    REPORTS_DIR.mkdir(exist_ok=True)
    report = {
        "meta": {
            "timestamp": stamp, "git_commit": git_commit(),
            "machine": platform.machine(), "engine": "whisper.cpp (desi-cli)",
        },
        "results": rows,
    }
    json_path = REPORTS_DIR / f"report_{stamp}.json"
    json_path.write_text(json.dumps(report, ensure_ascii=False, indent=2))

    lines = [f"# Eval report {stamp} (commit {report['meta']['git_commit']})", "",
             "| suite | model | mode | clips | crWER | nWER | WER | CER | RTF |",
             "|---|---|---|---|---|---|---|---|---|"]
    for r in sorted(rows, key=lambda r: (r["suite"], r["crwer"])):
        lines.append(f"| {r['suite']} | {r['model']} | {r['mode']} | {r['clips']} "
                     f"| {r['crwer']:.1%} | {r['nwer']:.1%} | {r['wer']:.1%} "
                     f"| {r['cer']:.1%} | {r['rtf']}x |")
    md_path = json_path.with_suffix(".md")
    md_path.write_text("\n".join(lines) + "\n")
    print(f"\nReport: {md_path}")


if __name__ == "__main__":
    main()
