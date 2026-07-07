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
DMG="$ROOT/app/dist/DesiDictation-$VERSION.dmg"
STAGING="$(mktemp -d)"

cp -R "$BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create -volname "Desi Dictation" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
rm -rf "$STAGING"

echo "==> $DMG"
du -sh "$DMG"
