#!/usr/bin/env bash
# build_app.sh — release build + .app bundle (no Xcode required).
#
# SwiftPM produces a bare executable; macOS features (mic TCC prompts, menu bar
# identity, Launch at Login) need a real .app bundle with an Info.plist, so we
# assemble one by hand and ad-hoc codesign it.
#
# Usage: ./scripts/build_app.sh
# Output: app/dist/Desi Dictation.app
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/app"
# Homebrew toolchain: system CLT SwiftPM is broken (docs/BUILD_LOG.md #4)
SWIFT="${DESI_SWIFT:-/opt/homebrew/Cellar/swift/6.3.2/Swift-6.3.xctoolchain/usr/bin/swift}"
[ -x "$SWIFT" ] || SWIFT="swift"   # fall back to PATH (e.g. machines with working Xcode)

echo "==> Release build ($SWIFT)"
(cd "$APP_DIR" && "$SWIFT" build -c release)

BIN="$APP_DIR/.build/release/desi-dictation"
BUNDLE="$APP_DIR/dist/Desi Dictation.app"
CONTENTS="$BUNDLE/Contents"

echo "==> Assembling bundle: $BUNDLE"
rm -rf "$BUNDLE"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN" "$CONTENTS/MacOS/Desi Dictation"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>              <string>Desi Dictation</string>
    <key>CFBundleDisplayName</key>       <string>Desi Dictation</string>
    <key>CFBundleIdentifier</key>        <string>com.desi.dictation</string>
    <key>CFBundleExecutable</key>        <string>Desi Dictation</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key>           <string>1</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>LSMinimumSystemVersion</key>    <string>14.0</string>
    <key>LSUIElement</key>               <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Desi Dictation records your voice to transcribe it into text. Audio never leaves your Mac.</string>
    <key>NSHumanReadableCopyright</key>  <string>© 2026 Samarth Saraswat</string>
</dict>
</plist>
PLIST

echo "==> Ad-hoc codesigning (replace '-' with Developer ID for distribution)"
codesign --force --deep --sign - "$BUNDLE"

echo "==> Done:"
codesign -dv "$BUNDLE" 2>&1 | head -2
du -sh "$BUNDLE"
