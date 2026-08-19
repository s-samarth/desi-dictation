#!/usr/bin/env bash
# make_dmg.sh — package the .app into a distributable DMG (uses built-in hdiutil,
# no extra dependencies). Run build_app.sh first.
#
# Usage: ./scripts/make_dmg.sh
# Output: app/dist/DesiDictation-<version>.dmg
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="$ROOT/app/dist/Desi Dictation.app"
[ -d "$BUNDLE" ] || { echo "Run scripts/build_app.sh first"; exit 1; }

VERSION="$(defaults read "$BUNDLE/Contents/Info.plist" CFBundleShortVersionString)"

# Whoever signed the bundle is what users inherit. Ad-hoc is legal but costs
# every existing user their Accessibility/Input Monitoring grants on update
# (TROUBLESHOOTING.md §1), so say it out loud rather than shipping it quietly.
SIGINFO="$(codesign -dvv "$BUNDLE" 2>&1 || true)"
AUTHORITY="$(printf '%s\n' "$SIGINFO" | sed -n 's/^Authority=//p' | head -1)"
if [ -n "$AUTHORITY" ]; then
  echo "==> Signed by: $AUTHORITY"
else
  echo "==> ⚠️  Bundle is AD-HOC signed — fine for local testing, but every"
  echo "    update will reset users' permission grants. For distribution run"
  echo "    ./scripts/make_dev_cert.sh once, rebuild, and re-package."
fi
DMG="$ROOT/app/dist/DesiDictation-$VERSION.dmg"
STAGING="$(mktemp -d)"

cp -R "$BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create -volname "Desi Dictation" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
rm -rf "$STAGING"

echo "==> $DMG"
du -sh "$DMG"
