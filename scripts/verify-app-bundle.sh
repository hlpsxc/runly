#!/usr/bin/env bash
# Fail the release if the app looks like a Debug dump or embeds builder home paths.
set -euo pipefail

APP="${1:?usage: verify-app-bundle.sh /path/to/Runly.app}"
test -d "$APP"
BIN="$APP/Contents/MacOS/Runly"
test -f "$BIN"

if [[ -e "$APP/Contents/MacOS/Runly.debug.dylib" ]]; then
  echo "error: Debug companion dylib present; refuse to package Debug builds" >&2
  exit 1
fi

# Absolute builder homes / CI checkouts must not ship in the binary.
if strings -a "$BIN" | grep -E '/Users/[^/]+/(pcode|work)/|/Users/runner/|/Users/skl/' >/dev/null; then
  echo "error: Mach-O embeds absolute builder paths:" >&2
  strings -a "$BIN" | grep -E '/Users/[^/]+/(pcode|work)/|/Users/runner/|/Users/skl/' | sort -u | head -40 >&2
  exit 1
fi

# Info.plist should identify the product; DT* keys from Xcode are OK but note them.
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist"

echo "OK: $APP looks like a Release app without builder home-path leakage"
