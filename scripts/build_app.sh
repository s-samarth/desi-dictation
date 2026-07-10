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

# App icon: generate once (CoreGraphics script), reuse thereafter
ICNS="$APP_DIR/Resources/AppIcon.icns"
if [ ! -f "$ICNS" ]; then
  echo "==> Generating app icon"
  mkdir -p "$APP_DIR/Resources"
  ICONSET="$(mktemp -d)/AppIcon.iconset"
  "$SWIFT" "$ROOT/scripts/generate_icon.swift" "$ICONSET"
  iconutil -c icns "$ICONSET" -o "$ICNS"
fi
cp "$ICNS" "$CONTENTS/Resources/AppIcon.icns"

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
    <key>CFBundleShortVersionString</key><string>0.6.0</string>
    <key>CFBundleVersion</key>           <string>2</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>LSMinimumSystemVersion</key>    <string>14.0</string>
    <key>LSUIElement</key>               <true/>
    <key>CFBundleIconFile</key>          <string>AppIcon</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Desi Dictation records your voice to transcribe it into text. Audio never leaves your Mac.</string>
    <key>NSHumanReadableCopyright</key>  <string>© 2026 Samarth Saraswat</string>
    <!-- Right-click → Services → Translate, on selected text in any app.
         Return type = macOS replaces the selection in place where editable. -->
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSMenuItem</key><dict><key>default</key><string>Translate to English (Desi Dictation)</string></dict>
            <key>NSMessage</key><string>translateToEnglish</string>
            <key>NSPortName</key><string>Desi Dictation</string>
            <key>NSSendTypes</key><array><string>NSStringPboardType</string></array>
            <key>NSReturnTypes</key><array><string>NSStringPboardType</string></array>
        </dict>
        <dict>
            <key>NSMenuItem</key><dict><key>default</key><string>Translate to हिन्दी (Desi Dictation)</string></dict>
            <key>NSMessage</key><string>translateToHindi</string>
            <key>NSPortName</key><string>Desi Dictation</string>
            <key>NSSendTypes</key><array><string>NSStringPboardType</string></array>
            <key>NSReturnTypes</key><array><string>NSStringPboardType</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST

# Prefer a stable identity so TCC grants survive rebuilds (make_dev_cert.sh);
# fall back to ad-hoc. Distribution builds use a Developer ID (LAUNCH.md).
# NOTE: no `-v` — the self-signed dev cert is untrusted (fine for signing/TCC)
# and `-v` would hide it, silently falling back to ad-hoc.
IDENTITY="-"
if security find-identity -p codesigning | grep -q "Desi Dictation Dev"; then
  IDENTITY="Desi Dictation Dev"
fi
echo "==> Codesigning with: $IDENTITY"
codesign --force --deep --sign "$IDENTITY" "$BUNDLE"

echo "==> Done:"
codesign -dv "$BUNDLE" 2>&1 | head -2
du -sh "$BUNDLE"
