#!/usr/bin/env bash
# install.sh — one-line installer for Desi Dictation (macOS, Apple Silicon).
#
#   curl -fsSL https://raw.githubusercontent.com/s-samarth/desi-dictation/main/install.sh | bash
#
# Always installs the newest GitHub Release. Re-run it to update: settings,
# history, dictionary and downloaded models live in ~/Library and are kept.
#
# Why no "Apple could not verify…" dialog: macOS only runs that Gatekeeper
# check on files carrying the com.apple.quarantine flag, which browsers set
# and curl does not. We verify the DMG's SHA-256 against the one published
# with the release instead, and clear any stray flag after copying.
#
# Env overrides (mostly for testing):
#   DESI_INSTALL_DIR  where the .app goes        (default /Applications)
#   DESI_DMG_URL      install this DMG instead of the latest release
#   DESI_NO_LAUNCH=1  don't open the app afterwards
#
# Everything runs inside main(), called on the last line, so a download cut
# off halfway through never executes a partial script.
set -euo pipefail

REPO="s-samarth/desi-dictation"
APP_NAME="Desi Dictation.app"
BUNDLE_ID="com.desi.dictation"
MIN_MACOS=14
LATEST="https://github.com/$REPO/releases/latest/download"

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*" >&2; }
die()  { printf '\033[1;31m✗\033[0m   %s\n' "$*" >&2; exit 1; }

check_platform() {
  [ "$(uname -s)" = "Darwin" ] || die "Desi Dictation is a macOS app."
  # uname -m says x86_64 under Rosetta; sysctl reports the real chip.
  [ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" = "1" ] \
    || die "Desi Dictation needs an Apple Silicon Mac (M1 or newer)."
  local major
  major="$(sw_vers -productVersion | cut -d. -f1)"
  [ "$major" -ge "$MIN_MACOS" ] \
    || die "Desi Dictation needs macOS $MIN_MACOS (Sonoma) or newer — you have $(sw_vers -productVersion)."
}

# Fallback when the release lacks the stable-named asset (pre-0.6.2 style):
# ask the GitHub API for the latest release's versioned .dmg.
latest_dmg_via_api() {
  curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | grep -o '"browser_download_url": *"[^"]*\.dmg"' \
    | head -n1 | sed 's/.*"\(https[^"]*\)"/\1/'
}

download() {
  local tmp="$1" url
  if [ -n "${DESI_DMG_URL:-}" ]; then
    url="$DESI_DMG_URL"
  else
    url="$LATEST/DesiDictation.dmg"
  fi
  say "Downloading $url"
  if ! curl -fL --progress-bar -o "$tmp/DesiDictation.dmg" "$url"; then
    [ -z "${DESI_DMG_URL:-}" ] || die "Download failed: $url"
    url="$(latest_dmg_via_api)"
    [ -n "$url" ] || die "Couldn't find a DMG in the latest release of $REPO."
    say "Downloading $url"
    curl -fL --progress-bar -o "$tmp/DesiDictation.dmg" "$url" || die "Download failed."
  fi
  DMG_URL="$url"
}

verify_checksum() {
  local tmp="$1" expected actual
  if ! expected="$(curl -fsSL "$DMG_URL.sha256" 2>/dev/null | awk '{print $1}')" \
     || [ -z "$expected" ]; then
    warn "No published checksum for this DMG — skipping SHA-256 check."
    return
  fi
  actual="$(shasum -a 256 "$tmp/DesiDictation.dmg" | awk '{print $1}')"
  [ "$expected" = "$actual" ] \
    || die "Checksum mismatch — the download is corrupt or tampered with. Nothing was installed."
  say "Checksum verified"
}

# Only the copy we're about to replace — matched by its executable's path.
quit_running_app() {
  local exe="$DEST_DIR/$APP_NAME/Contents/MacOS/"
  pgrep -f "$exe" >/dev/null || return 0
  say "Quitting the running Desi Dictation"
  osascript -e "quit app id \"$BUNDLE_ID\"" >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -f "$exe" >/dev/null || return 0
    sleep 0.5
  done
  pkill -f "$exe" || true
}

# Run a command, escalating with sudo only when the target isn't writable.
maybe_sudo() {
  if [ -w "$DEST_DIR" ]; then "$@"; else sudo "$@"; fi
}

install_app() {
  local tmp="$1" mnt src
  mnt="$tmp/mnt"
  mkdir -p "$mnt"
  hdiutil attach -nobrowse -readonly -quiet -mountpoint "$mnt" "$tmp/DesiDictation.dmg" \
    || die "Couldn't open the DMG."
  MOUNTED="$mnt"
  src="$mnt/$APP_NAME"
  [ -d "$src" ] || die "The DMG doesn't contain '$APP_NAME'."

  mkdir -p "$DEST_DIR" 2>/dev/null || sudo mkdir -p "$DEST_DIR"
  [ -w "$DEST_DIR" ] || say "$DEST_DIR needs admin rights — macOS may ask for your password."
  quit_running_app
  say "Installing to $DEST_DIR/$APP_NAME"
  # Replace, never merge: stale files from an old bundle break its code seal.
  maybe_sudo rm -rf "$DEST_DIR/$APP_NAME"
  maybe_sudo ditto "$src" "$DEST_DIR/$APP_NAME"
  maybe_sudo xattr -dr com.apple.quarantine "$DEST_DIR/$APP_NAME" 2>/dev/null || true

  hdiutil detach -quiet "$mnt" || true
  MOUNTED=""
  codesign --verify --deep --strict "$DEST_DIR/$APP_NAME" 2>/dev/null \
    || die "Installed app failed its code-signature check — please report this."
}

cleanup() {
  local rc=$?
  [ -z "${MOUNTED:-}" ] || hdiutil detach -quiet -force "$MOUNTED" 2>/dev/null || true
  [ -z "${TMP_DIR:-}" ] || rm -rf "$TMP_DIR"
  exit "$rc"
}

main() {
  DEST_DIR="${DESI_INSTALL_DIR:-/Applications}"
  MOUNTED=""
  check_platform
  TMP_DIR="$(mktemp -d)"
  trap cleanup EXIT

  download "$TMP_DIR"
  verify_checksum "$TMP_DIR"
  install_app "$TMP_DIR"

  local version
  version="$(defaults read "$DEST_DIR/$APP_NAME/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "?")"
  say "Installed Desi Dictation $version ✅"
  if [ "${DESI_NO_LAUNCH:-0}" != "1" ]; then
    open "$DEST_DIR/$APP_NAME"
    echo "    Look for the mic icon in your menu bar and follow the setup steps."
  fi
  echo "    Guide: https://github.com/$REPO/blob/main/docs/SETUP_GUIDE.md"
  echo "    Update later by running the same command again."
}

main "$@"
