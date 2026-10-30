#!/usr/bin/env bash
# rehearse_update.sh — one real in-app update, end to end, without touching
# your app, keychain or settings (UPDATES.md). It uses a throwaway keychain
# with two throwaway certificates, a test bundle ID and a feed on localhost.
#   1. same certificate  → downloads, checks, swaps, relaunches the new app
#   2. other certificate → refused; the old app keeps running
#   3. wrong checksum    → refused
#   4. relaunch          → an update found before a relaunch isn't downloaded again
# The old app is the real debug binary (only its updater runs:
# DESI_UPDATE_REHEARSAL); the new one is a stub that notes it was opened.
#
# Usage: (cd app && swift build) && ./scripts/rehearse_update.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/app/.build/debug/desi-dictation"
[ -x "$BIN" ] || { echo "✗ build first: (cd app && swift build)"; exit 1; }
W="$(mktemp -d)"; KC="$W/test.keychain-db"; PORT=8765; APP_PID=""; SERVER=""
APP="Desi Dictation.app"

cleanup() {
  [ -z "$APP_PID" ] || kill "$APP_PID" 2>/dev/null || true
  [ -z "$SERVER" ] || kill "$SERVER" 2>/dev/null || true
  security delete-keychain "$KC" 2>/dev/null || true
  rm -rf "$W" "$HOME/Library/Caches/com.desi.dictation/Update"
}
trap cleanup EXIT

identity() {
  openssl req -x509 -newkey rsa:2048 -days 1 -nodes -keyout "$W/$1.key" -out "$W/$1.pem" \
    -subj "/CN=$1" -addext "keyUsage=digitalSignature" -addext "extendedKeyUsage=codeSigning" 2>/dev/null
  openssl pkcs12 -export -legacy -out "$W/$1.p12" -inkey "$W/$1.key" -in "$W/$1.pem" -passout pass:x 2>/dev/null \
    || openssl pkcs12 -export -out "$W/$1.p12" -inkey "$W/$1.key" -in "$W/$1.pem" -passout pass:x
  security import "$W/$1.p12" -k "$KC" -P x -T /usr/bin/codesign >/dev/null
}
security create-keychain -p x "$KC"
security unlock-keychain -p x "$KC"
security set-keychain-settings "$KC"            # no auto-lock mid-run
identity "Desi Update Test A"
identity "Desi Update Test B"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k x "$KC" >/dev/null

printf '#include <stdio.h>\nint main(void){FILE*f=fopen("%s","w");if(f){fputs("opened\\n",f);fclose(f);}return 0;}\n' \
  "$W/opened" > "$W/stub.c"
cc -o "$W/stub" "$W/stub.c"

# bundle <dir> <version> <executable> <certificate>
bundle() {
  local contents="$1/$APP/Contents"
  mkdir -p "$contents/MacOS"
  cp "$3" "$contents/MacOS/Desi Dictation"
  cat > "$contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.desi.dictation.updatetest</string>
  <key>CFBundleExecutable</key><string>Desi Dictation</string>
  <key>CFBundleShortVersionString</key><string>$2</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
  codesign --force --deep --keychain "$KC" --sign "$4" "$1/$APP" 2>/dev/null
}

mkdir -p "$W/feed"
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$W/feed" >"$W/server.log" 2>&1 &
SERVER=$!; disown
sleep 1

# pass <name> <new app's certificate> <tamper checksum: 0|1> <expect: updated|refused> [relaunch]
pass() {
  rm -rf "$W/installed" "$W/new" "$W/opened" "$W/feed/"*
  bundle "$W/installed" 0.7.1 "$BIN" "Desi Update Test A"
  bundle "$W/new" 0.7.2 "$W/stub" "$2"
  hdiutil create -quiet -volname "Desi Dictation" -srcfolder "$W/new" -format UDZO \
    "$W/feed/DesiDictation-update.dmg"
  (cd "$W/feed" && shasum -a 256 DesiDictation-update.dmg > DesiDictation-update.dmg.sha256)
  [ "$3" = 0 ] || printf '%064d  DesiDictation-update.dmg\n' 0 > "$W/feed/DesiDictation-update.dmg.sha256"
  local base="http://127.0.0.1:$PORT"
  printf '{"tag_name":"v0.7.2","assets":[{"name":"DesiDictation-update.dmg","browser_download_url":"%s/DesiDictation-update.dmg"},{"name":"DesiDictation-update.dmg.sha256","browser_download_url":"%s/DesiDictation-update.dmg.sha256"}]}' \
    "$base" "$base" > "$W/feed/latest.json"

  if [ "${5:-}" = relaunch ]; then   # find it, quit before installing, open again
    DESI_UPDATE_REHEARSAL=1 DESI_UPDATE_FEED="$base/latest.json" \
      "$W/installed/$APP/Contents/MacOS/Desi Dictation" > "$W/log" 2>&1 &
    APP_PID=$!; disown
    for _ in $(seq 1 120); do grep -q "\[update\] ready" "$W/log" && break; sleep 0.5; done
    kill "$APP_PID" 2>/dev/null || true; APP_PID=""; sleep 1
  fi
  : > "$W/server.log"
  DESI_UPDATE_REHEARSAL=1 DESI_UPDATE_INSTALL_NOW=1 DESI_UPDATE_FEED="$base/latest.json" \
    "$W/installed/$APP/Contents/MacOS/Desi Dictation" > "$W/log" 2>&1 &
  APP_PID=$!; disown
  local outcome="timeout"
  for _ in $(seq 1 120); do
    if ! kill -0 "$APP_PID" 2>/dev/null; then outcome="quit"; break; fi
    if grep -q "\[update\] failed" "$W/log"; then outcome="failed"; break; fi
    sleep 0.5
  done
  [ "$outcome" = quit ] && for _ in $(seq 1 20); do [ -f "$W/opened" ] && break; sleep 0.5; done
  kill "$APP_PID" 2>/dev/null || true; APP_PID=""
  local version
  version="$(defaults read "$W/installed/$APP/Contents/Info.plist" CFBundleShortVersionString)"
  if [ "${5:-}" = relaunch ] && grep -q "GET /DesiDictation-update.dmg " "$W/server.log"; then
    echo "  ✗ $1: downloaded again after the relaunch"; FAILED=1
  elif [ "$4" = updated ] && [ "$outcome" = quit ] && [ "$version" = 0.7.2 ] && [ -f "$W/opened" ] \
     && [ ! -e "$W/installed/.$APP.old" ] && codesign --verify --deep --strict "$W/installed/$APP" 2>/dev/null; then
    echo "  ✓ $1: swapped to v$version, signature intact, new app opened"
  elif [ "$4" = refused ] && [ "$outcome" = failed ] && [ "$version" = 0.7.1 ]; then
    echo "  ✓ $1: refused ($(grep -o 'failed(.*' "$W/log" | head -1 | sed 's/.*"\(.*\)")/\1/; s/\\//g')), v$version kept"
  else
    echo "  ✗ $1: outcome=$outcome version=$version opened=$([ -f "$W/opened" ] && echo yes || echo no)"
    grep "\[update\]" "$W/log" | tail -5
    FAILED=1
  fi
}

FAILED=0
echo "==> Rehearsing an in-app update (each pass waits ~20 s for the first check)"
pass "same certificate" "Desi Update Test A" 0 updated
pass "other certificate" "Desi Update Test B" 0 refused
pass "wrong checksum" "Desi Update Test A" 1 refused
pass "relaunch, not downloaded again" "Desi Update Test A" 0 updated relaunch
[ "$FAILED" = 0 ] && echo "✅ update rehearsal green" || { echo "✗ update rehearsal failed"; exit 1; }
