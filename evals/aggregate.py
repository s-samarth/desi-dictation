"""Aggregate all eval reports into one trend view.

Answers "are we getting better?" across model/engine changes: for each
suite × model, shows the primary metric (crWER) over every report, newest last.

Usage: uv run aggregate.py           # writes reports/AGGREGATE.md and prints it
"""

from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path

REPORTS_DIR = Path(__file__).parent / "reports"


def main() -> None:
    reports = sorted(REPORTS_DIR.glob("report_*.json"))
    if not reports:
        print("No reports yet — run run_eval.py first.")
        return

    # (suite, model) -> {timestamp: (crwer, rtf)}
    grid: dict[tuple[str, str], dict[str, tuple[float, float]]] = defaultdict(dict)
    stamps: list[str] = []
    for path in reports:
        data = json.loads(path.read_text())
        stamp = data["meta"]["timestamp"][:13]  # YYYYMMDD_HHMM
        commit = data["meta"].get("git_commit", "?")
        label = f"{stamp} ({commit})"
        stamps.append(label)
        for r in data["results"]:
            # Tiers aren't comparable with each other (different clips), nor
            # with pre-2026-09 reports (a different, US-English suite — FM#24).
            tier = r.get("tier", "legacy")
            grid[(r["suite"], f"{r['model']} [{tier}]")][label] = (r["crwer"], r["rtf"])

    lines = ["# Eval trends — crWER (lower is better), RTF in parens", ""]
    header = "| suite | model | " + " | ".join(stamps) + " |"
    lines += [header, "|---" * (2 + len(stamps)) + "|"]
    for (suite, model) in sorted(grid):
        cells = []
        for label in stamps:
            if label in grid[(suite, model)]:
                crwer, rtf = grid[(suite, model)][label]
                cells.append(f"{crwer:.1%} ({rtf}x)")
            else:
                cells.append("—")
        lines.append(f"| {suite} | {model} | " + " | ".join(cells) + " |")

    # Per-suite current champion (latest report)
    latest = json.loads(reports[-1].read_text())["results"]
    best: dict[str, dict] = {}
    for r in latest:
        if r["suite"] not in best or r["crwer"] < best[r["suite"]]["crwer"]:
            best[r["suite"]] = r
    lines += ["", "## Current champions (latest report)", ""]
    for suite, r in sorted(best.items()):
        lines.append(f"- **{suite}** → `{r['model']}` (crWER {r['crwer']:.1%}, {r['rtf']}x)")

    output = "\n".join(lines) + "\n"
    (REPORTS_DIR / "AGGREGATE.md").write_text(output)
    print(output)


if __name__ == "__main__":
    main()
