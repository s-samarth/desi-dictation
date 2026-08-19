#!/usr/bin/env bash
# preflight.sh — THE one command before every push. Mirrors exactly what CI
# runs, so a green preflight means a green pipeline:
#   1. swift build (app + cli + tests)      3. app↔web parity check
#   2. desi-tests (119+ assertions)         4. web demo unit tests
#   5. dictation latency budget (local models only; skips in CI)
#
# Usage: ./scripts/preflight.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# CLT 6.3.3 manifest workaround (BUILD_LOG FM#17) — harmless elsewhere.
[ -d "$HOME/.swiftpm-fixed-libs" ] && export SWIFTPM_CUSTOM_LIBS_DIR="$HOME/.swiftpm-fixed-libs"

echo "══ 1/5 build"
(cd "$ROOT/app" && swift build)

echo "══ 2/5 desi-tests"
"$ROOT/app/.build/debug/desi-tests" | tail -1

echo "══ 3/5 app ↔ web parity"
"$ROOT/scripts/check_parity.sh"

echo "══ 4/5 web unit tests"
python3 "$ROOT/web/test_web.py" | tail -1

# The gate that would have caught the 2026-08 slowness: release-to-paste on a
# SHORT clip, per language (docs/PERF_RCA_2026-08.md).
echo "══ 5/5 dictation latency"
"$ROOT/scripts/latency_gate.sh"

echo
echo "✅ preflight green — safe to push."
