#!/usr/bin/env bash
# sdk_env.sh — sourced by preflight/build_app/release. Picks a macOS SDK that
# can actually compile the app, so a Command Line Tools update can't silently
# break the build (BUILD_LOG FM#23).
#
# CLT 27.0 ships the macOS 27 SDK, whose SwiftUI `@State` is a macro — but the
# CLT has no SwiftUIMacros compiler plugin (only full Xcode does). Probe: type-
# check one `@State` line against the default SDK; if that fails, fall back to
# the newest installed macOS 26 SDK. The app's deployment target is macOS 14
# either way, so the SDK choice changes nothing about where the app runs.
# No-op when SDKROOT is already set or when Xcode is the active developer dir
# (CI runners, Macs with Xcode).
if [ -z "${SDKROOT:-}" ] && [[ "$(xcode-select -p 2>/dev/null)" != *Xcode* ]]; then
  _probe="$(mktemp -d)"
  printf 'import SwiftUI\nstruct P: View { @State var n = 0; var body: some View { Text("") } }\n' > "$_probe/p.swift"
  if ! xcrun swiftc -typecheck "$_probe/p.swift" >/dev/null 2>&1; then
    _sdk="$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.[0-9]*.sdk 2>/dev/null | sort -V | tail -1)"
    if [ -n "$_sdk" ]; then
      export SDKROOT="$_sdk"
      echo "   (default SDK can't compile SwiftUI with CLT — using $(basename "$_sdk"), FM#23)" >&2
    else
      echo "✗ default SDK can't compile SwiftUI and no macOS 26 SDK is installed (FM#23)" >&2
    fi
  fi
  rm -rf "$_probe"; unset _probe _sdk
fi
