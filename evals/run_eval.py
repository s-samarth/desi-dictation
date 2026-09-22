"""Score models on the eval suites through the REAL shipping engine
(desi-cli --batch = the app's EngineRouter, exact params + VAD).

Default = the quick tier, the shipping model per suite (a few minutes).
The full tier / every installed model are opt-in — the estimate printed at
start says what you're signing up for.

Usage:
    uv run run_eval.py                          # quick tier, shipping models
    uv run run_eval.py --tier full              # every clip (before a model change)
    uv run run_eval.py --all-models             # compare every installed model
    uv run run_eval.py --suites english --models turbo
Output:
    reports/report_<UTC>.json + .md   (overall + per-source + per-length slices)
"""

from __future__ import annotations

import argparse
import json
import platform
import subprocess
from datetime import datetime, timezone
from pathlib import Path

import report
from metrics import VERSION as METRICS_VERSION

ROOT = Path(__file__).parent.parent
DATA_DIR = Path(__file__).parent / "data"
REPORTS_DIR = Path(__file__).parent / "reports"
CLI = ROOT / "app/.build/release/desi-cli"
MODELS_DIR = Path.home() / "Library/Application Support/DesiDictation/models"

# What the app picks per language (ModelManager.score) — the default run.
SHIPPING = {"english": "parakeet", "hindi": "vaani", "hinglish": "hinglish-apex"}

# Engine seconds per clip ~= a + b * audio seconds, fitted on the quick tier
# (M3 Air, model resident, 2026-09-22). Vaani is content-dependent — dense
# speech can run slower than realtime — so it is modelled per audio second.
# Turbo shares Apex's architecture; small/base/swift are rough. M1 Air ~1.8x.
COST = {"parakeet": (0.05, 0.025), "apex": (1.43, 0.091), "turbo": (1.43, 0.091),
        "prime": (1.43, 0.091), "vaani": (0.0, 1.1), "small": (0.7, 0.03),
        "swift": (0.4, 0.02), "base": (0.3, 0.01)}


def mode_for(model_name: str, suite: str) -> str:
    """Hinglish models always emit Roman; others follow the suite's language."""
    if "hinglish" in model_name:
        return "hinglish"
    return {"hindi": "hindi", "english": "english"}.get(suite, "hindi")


def serves(model_name: str, suite: str) -> bool:
    """Mirrors ModelManager.score(): Parakeet is English-only; Vaani is a
    Hindi fine-tune that scores ~100 % WER on English (July report)."""
    if "parakeet" in model_name:
        return suite == "english"
    return not ("vaani" in model_name and suite == "english")


def installed_models() -> list[Path]:
    return sorted(p for p in MODELS_DIR.glob("ggml-*.bin") if "silero" not in p.name)


def manifest(suite: str, tier: str) -> list[dict]:
    path = DATA_DIR / suite / "manifest.jsonl"
    if not path.exists():
        return []
    entries = [json.loads(l) for l in path.read_text().splitlines() if l]
    # Pre-2026-09 manifests have no tiers: every clip counts as quick.
    return [e for e in entries if tier == "full" or e.get("quick", True)]


def est_seconds(model_name: str, entries: list[dict]) -> float:
    a, b = next((v for k, v in COST.items() if k in model_name), (2.0, 0.1))
    return sum(a + b * e.get("seconds", 10) for e in entries)


def tier_dir(suite: str, tier: str, entries: list[dict]) -> Path:
    """desi-cli transcribes a whole directory, so a tier is a folder of
    symlinks into clips/ (rebuilt each run; only our own symlinks are removed)."""
    clips = DATA_DIR / suite / "clips"
    if tier == "full":
        return clips
    folder = DATA_DIR / suite / ".tiers" / tier
    folder.mkdir(parents=True, exist_ok=True)
    for link in folder.iterdir():
        if link.is_symlink():
            link.unlink()
    for e in entries:
        (folder / e["file"]).symlink_to(clips / e["file"])
    return folder


def run_batch(model: Path, folder: Path, mode: str) -> dict[str, dict]:
    """{file: {text, seconds, audio_seconds}} from desi-cli --batch."""
    proc = subprocess.run([str(CLI), str(model), "--batch", str(folder), mode],
                          capture_output=True, text=True, timeout=4 * 3600)
    results = {}
    for line in proc.stdout.splitlines():
        try:
            rec = json.loads(line)
            results[rec["file"]] = rec
        except json.JSONDecodeError:
            continue
    return results


def evaluate(model: Path, suite: str, tier: str) -> dict | None:
    entries = manifest(suite, tier)
    if not entries or not serves(model.name, suite):
        return None
    mode = mode_for(model.stem, suite)
    outputs = run_batch(model, tier_dir(suite, tier, entries), mode)
    pairs = [(e, outputs[e["file"]]) for e in entries if e["file"] in outputs]
    if len(pairs) < len(entries):  # desi-cli died mid-batch — say so, loudly
        print(f"    !! {len(entries) - len(pairs)} of {len(entries)} clips got no output")
    if not pairs:
        return None
    return {"suite": suite, "model": model.stem, "mode": mode, "tier": tier,
            **report.summarize(pairs),
            "by_source": report.breakdown(pairs, "source"),
            "by_bucket": report.breakdown(pairs, "bucket"),
            "per_clip": [{"file": e["file"], "source": e["source"], "audio_s": e["seconds"],
                          "engine_s": o["seconds"], "ref": e["ref"], "hyp": o["text"]}
                         for e, o in pairs]}


def git_commit() -> str:
    try:
        return subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT,
                              capture_output=True, text=True).stdout.strip()
    except Exception:
        return "unknown"


def plan(args) -> list[tuple[Path, str]]:
    models = installed_models()
    if args.models:
        models = [m for m in models if any(f in m.name for f in args.models)]
    jobs = []
    for suite in args.suites:
        for model in models:
            shipping = SHIPPING.get(suite, "") in model.name  # personal: all
            if (args.all_models or args.models or shipping) and serves(model.name, suite):
                jobs.append((model, suite))
    return jobs


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--suites", nargs="+", default=["english", "hindi", "hinglish"])
    parser.add_argument("--tier", choices=["quick", "full"], default="quick")
    parser.add_argument("--all-models", action="store_true",
                        help="every installed model, not just the shipping pick")
    parser.add_argument("--models", nargs="+", default=None,
                        help="substring filters, e.g. apex turbo")
    args = parser.parse_args()

    jobs = plan(args)
    total = sum(est_seconds(m.name, manifest(s, args.tier)) for m, s in jobs)
    print(f"{len(jobs)} runs, {args.tier} tier — est. {total / 60:.0f} min on an M3 Air "
          f"(~{total * 1.8 / 60:.0f} min on an M1 Air), plus model loads\n")

    rows = []
    for model, suite in jobs:
        print(f"==> {model.stem} × {suite}", flush=True)
        result = evaluate(model, suite, args.tier)
        if result:
            rows.append(result)
            print(f"    nWER {result['nwer']:.1%}  crWER {result['crwer']:.1%}  "
                  f"median {result['median_s']} s  ({result['clips']} clips)")

    meta = {"timestamp": datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S"),
            "git_commit": git_commit(), "machine": platform.machine(),
            "tier": args.tier, "engine": "desi-cli (EngineRouter)",
            "metrics": METRICS_VERSION}
    print(f"\nReport: {report.write(rows, meta, REPORTS_DIR)}")


if __name__ == "__main__":
    main()
