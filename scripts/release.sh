#!/usr/bin/env bash
# release.sh — cut a signed release from THIS Mac.
#
# Why local and not CI: the signing identity ("Desi Dictation Dev") lives in
# this machine's login keychain. Until its .p12 is in GitHub secrets (see
# docs/LAUNCH.md § "Signing beta builds"), a CI-built DMG can only be ad-hoc
# signed — and ad-hoc means every update looks like a new app to macOS, so
# users must re-grant Accessibility + Input Monitoring each time
# (TROUBLESHOOTING.md §1). A stable identity is the whole point.
#
# Usage: ./scripts/release.sh v0.6.1 [--draft]
#   - refuses to run on a dirty tree or if the tag ≠ the bundle version
#   - runs the full preflight gate first
#   - tags, pushes, builds, signs, packages, publishes with `gh release`
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TAG="${1:-}"
[ -n "$TAG" ] || { echo "usage: ./scripts/release.sh v0.6.1 [--draft]"; exit 2; }
DRAFT=""
[ "${2:-}" = "--draft" ] && DRAFT="--draft"

[ -z "$(git status --porcelain)" ] || { echo "✗ working tree is dirty — commit first"; exit 1; }

[ -d "$HOME/.swiftpm-fixed-libs" ] && export SWIFTPM_CUSTOM_LIBS_DIR="$HOME/.swiftpm-fixed-libs"

echo "══ preflight"
./scripts/preflight.sh >/dev/null || { echo "✗ preflight failed — run it directly to see why"; exit 1; }
echo "   green"

echo "══ build + sign"
./scripts/build_app.sh >/dev/null
BUNDLE="$ROOT/app/dist/Desi Dictation.app"
VERSION="$(defaults read "$BUNDLE/Contents/Info.plist" CFBundleShortVersionString)"
[ "v$VERSION" = "$TAG" ] || {
  echo "✗ tag $TAG ≠ bundle v$VERSION — bump CFBundleShortVersionString in scripts/build_app.sh"
  exit 1
}

# The identity check is the point of this script: shipping an ad-hoc DMG by
# accident is a silent downgrade for every existing user's permissions.
SIGINFO="$(codesign -dvv "$BUNDLE" 2>&1 || true)"
AUTHORITY=""
while IFS= read -r line; do
  case "$line" in Authority=*) AUTHORITY="${line#Authority=}"; break ;; esac
done <<< "$SIGINFO"
if [ -z "$AUTHORITY" ]; then
  echo "✗ bundle is ad-hoc signed — run ./scripts/make_dev_cert.sh, then retry."
  echo "  (Ad-hoc updates make macOS forget Accessibility/Input Monitoring.)"
  exit 1
fi
echo "   signed by: $AUTHORITY"

echo "══ dmg"
./scripts/make_dmg.sh >/dev/null
DMG="$ROOT/app/dist/DesiDictation-$VERSION.dmg"
[ -f "$DMG" ] || { echo "✗ expected $DMG"; exit 1; }
codesign --verify --deep --strict "$BUNDLE" && echo "   seal verified"

echo "══ tag + publish"
git rev-parse "$TAG" >/dev/null 2>&1 || { git tag "$TAG"; git push origin "$TAG"; }

NOTES="$(mktemp)"
cat > "$NOTES" <<EOF
Signed with the project's own certificate (beta). macOS shows "Apple could not
verify…" on first open → **System Settings → Privacy & Security → Open Anyway**,
once. Because every build carries the same identity, your Accessibility and
Input Monitoring grants carry over between updates.

**Updating:** quit the app from the menu bar first, then drag the new one into
Applications and choose Replace. Do **not** uninstall — settings, history,
dictionary and downloaded models are kept.

**One-line install / update** (no "Open Anyway" step needed):
\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/s-samarth/desi-dictation/main/install.sh | bash
\`\`\`

Install guide: [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)
EOF

# Stable-named copy + checksums: install.sh fetches
# releases/latest/download/DesiDictation.dmg, so the newest release is always
# one fixed URL, and it verifies the .sha256 before installing.
STABLE="$ROOT/app/dist/DesiDictation.dmg"
cp "$DMG" "$STABLE"
for f in "$DMG" "$STABLE"; do
  (cd "$(dirname "$f")" && shasum -a 256 "$(basename "$f")" > "$(basename "$f").sha256")
done

gh release create "$TAG" "$DMG" "$DMG.sha256" "$STABLE" "$STABLE.sha256" --title "Desi Dictation $VERSION" \
  --notes-file "$NOTES" --generate-notes $DRAFT
rm -f "$NOTES"
echo "✅ released $TAG"
