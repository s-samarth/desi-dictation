#!/usr/bin/env bash
# preflight.sh — THE one command before every push. Mirrors exactly what CI
# runs, so a green preflight means a green pipeline:
#   1. swift build (app + cli + tests)      3. app↔web parity check
#   2. desi-tests (95+ assertions)          4. web demo unit tests
#
# Usage: ./scripts/preflight.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# CLT 6.3.3 manifest workaround (BUILD_LOG FM#17) — harmless elsewhere.
[ -d "$HOME/.swiftpm-fixed-libs" ] && export SWIFTPM_CUSTOM_LIBS_DIR="$HOME/.swiftpm-fixed-libs"

echo "══ 1/4 build"
(cd "$ROOT/app" && swift build)

echo "══ 2/4 desi-tests"
"$ROOT/app/.build/debug/desi-tests" | tail -1

echo "══ 3/4 app ↔ web parity"
"$ROOT/scripts/check_parity.sh"

echo "══ 4/4 web unit tests"
python3 "$ROOT/web/test_web.py" | tail -1

echo
echo "✅ preflight green — safe to push."
