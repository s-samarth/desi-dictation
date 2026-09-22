#!/usr/bin/env bash
# latency_gate.sh — guards the number users actually feel: how long after the
# key comes up the text appears.
#
# Why this exists: the old guard measured realtime-factor on ONE long clip and
# demanded ≥10x. Whisper encodes a padded 30 s window per call, so a fixed
# ~1.5 s per-call cost sails through that gate while short dictations — the
# common case — feel slow (docs/PERF_RCA_2026-08.md). So we gate on wall-clock
# for a SHORT clip too, per language, against the model the app would pick.
#
# Budgets are per language and reflect what we can honestly promise TODAY on an
# M3 Air; halve the machine and roughly double the number. Tighten them as the
# engine improves — never loosen one to make a red gate green.
#
# The clip comes from the suite's manifest, never "first file in clips/": the
# suites get rebuilt, and english 0000.wav became a 46 s Svarah stretch that
# failed the English budget with the engine unchanged (BUILD_LOG FM#29).
#
# Usage: ./scripts/latency_gate.sh [slack_multiplier]   (default 1.0)
# Skips (exit 0) when models or clips are absent — CI has neither.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SLACK="${1:-1.0}"
CLI="$ROOT/app/.build/release/desi-cli"
MODELS="$HOME/Library/Application Support/DesiDictation/models"

[ -x "$CLI" ] || CLI="$ROOT/app/.build/debug/desi-cli"
if [ ! -x "$CLI" ] || [ ! -d "$MODELS" ]; then
  echo "   (skipped — no desi-cli or no models on this machine)"
  exit 0
fi

# mode:model:suite:budget — the app's default model for each language.
# english  Parakeet TDT — no 30 s padding, so it is an order faster.
# hinglish Apex q5_0 — one full whisper window.
# hindi    Vaani q5_0 is a 1.06 GB large-v3: the slowest path we ship, and the
#          reason CoreML/ANE (PERFORMANCE.md deferred #1) matters most here.
CASES=(
  "english:ggml-parakeet-tdt-0.6b-v3-q4_k.bin:english:0.75"
  "hinglish:ggml-hinglish-apex-q5_0.bin:hinglish:2.0"
  "hindi:ggml-vaani-hindi-q5_0.bin:hindi:4.0"
)

# A short dictation: the manifest's "s" bucket (2.5–6 s, evals/sampling.py)
# clip closest to TARGET_S, ties broken by file name. Chosen by length, not by
# position, so a re-ordered or rebuilt manifest still times the same length.
TARGET_S=4.0
pick_clip() {  # suite dir → "<path>\t<seconds>", or nothing
  python3 - "$1" "$TARGET_S" <<'PY' 2>/dev/null || true
import json, os, sys
suite, target = sys.argv[1], float(sys.argv[2])
rows = [json.loads(l) for l in open(os.path.join(suite, "manifest.jsonl")) if l.strip()]
short = [r for r in rows if r.get("bucket") == "s"
         and os.path.isfile(os.path.join(suite, "clips", r["file"]))]
if short:
    r = min(short, key=lambda r: (abs(r["seconds"] - target), r["file"]))
    print(f'{os.path.join(suite, "clips", r["file"])}\t{r["seconds"]:.2f}')
PY
}

fail=0
for case in "${CASES[@]}"; do
  IFS=: read -r mode model suite base <<< "$case"
  budget="$(awk "BEGIN{printf \"%.2f\", $base * $SLACK}")"
  IFS=$'\t' read -r clip dur <<< "$(pick_clip "$ROOT/evals/data/$suite")" || true
  if [ ! -f "$MODELS/$model" ] || [ -z "${clip:-}" ]; then
    printf "   %-9s skip (model or short clip missing)\n" "$mode"
    continue
  fi
  printf "   %-9s clip %s/%s (%ss)\n" "$mode" "$suite" "$(basename "$clip")" "$dur"
  # Third run: model resident, page cache warm — the state a real dictation
  # finds the app in.
  secs="$("$CLI" "$MODELS/$model" "$clip" "$mode" --repeat 2>/dev/null \
          | awk '/^\[run 3\]/ {gsub(/s$/, "", $3); print $3}' || true)"
  [ -n "$secs" ] || { echo "   $mode: FAILED to produce a timing"; fail=1; continue; }
  if awk "BEGIN{exit !($secs > $budget)}"; then
    printf "   %-9s %ss  ✗ over %ss budget\n" "$mode" "$secs" "$budget"
    fail=1
  else
    printf "   %-9s %ss  ✓ (budget %ss)\n" "$mode" "$secs" "$budget"
  fi
done

[ "$fail" -eq 0 ] || {
  echo "   Latency regression: a short dictation got slower than we promise."
  echo "   See docs/PERF_RCA_2026-08.md before raising the budget."
  exit 1
}
