#!/usr/bin/env bash
# make_dev_cert.sh — one-time: create a self-signed code-signing identity
# "Desi Dictation Dev" in the login keychain.
#
# WHY: ad-hoc signatures change every build, so macOS TCC treats each rebuild
# as a new app and silently invalidates Accessibility/Input Monitoring grants
# (grants show ON but are denied — BUILD_LOG failure mode #8). A stable
# identity gives a stable code requirement → grants survive rebuilds.
# The proper launch-time replacement is a $99 Apple Developer ID (LAUNCH.md).
set -euo pipefail

NAME="Desi Dictation Dev"
if security find-identity -v -p codesigning | grep -q "$NAME"; then
  echo "==> Identity '$NAME' already exists"; exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Use the system LibreSSL: OpenSSL 3.x emits modern PKCS12 (AES/SHA2 MAC)
# that `security import` rejects with "MAC verification failed".
OPENSSL=/usr/bin/openssl

$OPENSSL req -x509 -newkey rsa:2048 -days 3650 -nodes \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
  -subj "/CN=$NAME" \
  -addext "keyUsage=digitalSignature" \
  -addext "extendedKeyUsage=codeSigning" 2>/dev/null

$OPENSSL pkcs12 -export -legacy -out "$TMP/dev.p12" \
  -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -passout pass:desi 2>/dev/null \
|| $OPENSSL pkcs12 -export -out "$TMP/dev.p12" \
  -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -passout pass:desi

security import "$TMP/dev.p12" \
  -k "$HOME/Library/Keychains/login.keychain-db" -P desi \
  -T /usr/bin/codesign

echo "==> Imported. First codesign use may show an 'Allow' dialog — click Always Allow."
security find-identity -v -p codesigning | grep "$NAME" || true
