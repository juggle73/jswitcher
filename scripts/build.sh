#!/usr/bin/env bash
# Builds a universal (arm64 + x86_64) build/jswitcher.app, signs and audits it.
# Fails on any network symbol or entitlement.
#   scripts/build.sh            local build: Developer ID if present, else ad-hoc; no timestamp
#   scripts/build.sh --release  Developer ID required, secure timestamp (needed for notarization)
set -euo pipefail
cd "$(dirname "$0")/.."

RELEASE=0
[ "${1:-}" = "--release" ] && RELEASE=1

APP=build/jswitcher.app

echo "==> swift test"
swift test

echo "==> swift build (release, universal)"
ARCHS=(--arch arm64 --arch x86_64)
swift build -c release --product jswitcher "${ARCHS[@]}"
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)/jswitcher"

echo "==> bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/jswitcher"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/dict_en.bin Resources/dict_ru.bin Resources/dict_en_top.bin Resources/dict_ru_top.bin Resources/dict_tech.bin Resources/ngram_en.bin Resources/ngram_ru.bin Resources/AppIcon.icns LICENSE THIRD_PARTY_NOTICES.txt "$APP/Contents/Resources/"

# Signing identity: $JSWITCHER_SIGN_IDENTITY, else the first "Developer ID Application" in the
# keychain, else ad-hoc. A real certificate keeps macOS permissions across rebuilds; ad-hoc doesn't.
IDENTITY="${JSWITCHER_SIGN_IDENTITY:-$(security find-identity -v -p codesigning \
    | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)}"
if [ "$RELEASE" = 1 ] && [ -z "$IDENTITY" ]; then
    echo "FAIL: --release needs a Developer ID Application certificate" >&2
    exit 1
fi
IDENTITY="${IDENTITY:--}"
# Local builds skip the timestamp (no request to Apple's server); notarization requires one.
if [ "$RELEASE" = 1 ]; then TS=(--timestamp); else TS=(--timestamp=none); fi
echo "==> codesign ($IDENTITY, hardened runtime, ${TS[*]})"
codesign --force --sign "$IDENTITY" --options runtime "${TS[@]}" "$APP"
codesign --verify --strict "$APP"

echo "==> network audit"
EXE="$APP/Contents/MacOS/jswitcher"
if otool -L "$EXE" | grep -E 'Network\.framework|CFNetwork\.framework'; then
    echo "FAIL: binary links a network framework" >&2
    exit 1
fi
BAD='URLSession|NSURLConnection|NSURLSession|CFSocket|CFStream|SCNetworkReachability|_nw_|^_socket$|^_connect$|^_getaddrinfo$|^_sendto$|^_recvfrom$'
if nm -u "$EXE" | grep -E "$BAD"; then
    echo "FAIL: binary references network symbols (listed above)" >&2
    exit 1
fi

echo "==> entitlements audit"
ENT="$(codesign -d --entitlements - "$APP" 2>/dev/null || true)"
if [ -n "$ENT" ]; then
    echo "FAIL: unexpected entitlements:" >&2
    echo "$ENT" >&2
    exit 1
fi

echo "OK: $APP"
