#!/usr/bin/env bash
# check_parity.sh — the app (Swift) and web demo (Python) carry PORTED copies
# of two things: the Hindi number normalizer and the LLM prompts. This script
# fails loudly the moment they drift.
#
#   1. Number parity: run identical sentences through BOTH implementations
#      (desi-cli --normalize vs web/hindi_numbers.py) and diff the outputs.
#   2. Prompt sentinels: web/test_web.py greps the load-bearing prompt lines.
#
# Run standalone or via scripts/preflight.sh; CI runs it on every push.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI="$ROOT/app/.build/debug/desi-cli"
[ -x "$CLI" ] || { echo "build first: (cd app && swift build)"; exit 1; }

CASES=(
  "maine do lakh pachaas hazaar ka order diya tha"
  "assi hazaar ka loss lekin teen lakh ka profit"
  "dedh lakh advance aur paanch sau cash"
  "do hazaar chaar sau bees rupaye do"
  "sava crore ka ghar, sach mein"
  "paanch minute late ho jaunga yaar"
  "teen features nahi ho payenge is sprint mein"
  "mere saath hazaar log the us din"
  "lakh koshish kar lo, nahi hoga"
  "Assi hazaar, phir se bhej do!"
)

FAIL=0
for sentence in "${CASES[@]}"; do
  swift_out="$("$CLI" --normalize "$sentence")"
  py_out="$(cd "$ROOT/web" && python3 -c "import sys; from hindi_numbers import normalize; print(normalize(sys.argv[1]))" "$sentence")"
  if [ "$swift_out" == "$py_out" ]; then
    echo "  ok   $swift_out"
  else
    echo "  DRIFT for: $sentence"
    echo "     swift:  $swift_out"
    echo "     python: $py_out"
    FAIL=1
  fi
done

echo "── prompt sentinels + python unit tests"
python3 "$ROOT/web/test_web.py" >/dev/null || FAIL=1

if [ "$FAIL" -ne 0 ]; then
  echo "PARITY BROKEN — update the other port (HindiNumbers.swift ↔ web/hindi_numbers.py,"
  echo "PromptTemplates.swift ↔ web/prompts.py) before shipping."
  exit 1
fi
echo "parity: app ↔ web in sync"
