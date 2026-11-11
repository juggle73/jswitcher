#!/usr/bin/env bash
# Builds, notarizes and packages a release: build/jswitcher-<version>.zip plus its SHA-256.
#
# One-time setup (stores notary credentials in the login keychain):
#   xcrun notarytool store-credentials jswitcher-notary --apple-id <apple-id> --team-id <team-id>
# Override the profile name with $JSWITCHER_NOTARY_PROFILE.
set -euo pipefail
cd "$(dirname "$0")/.."

PROFILE="${JSWITCHER_NOTARY_PROFILE:-jswitcher-notary}"
APP=build/jswitcher.app
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
ZIP="build/jswitcher-$VERSION.zip"

scripts/build.sh --release

echo "==> notarize ($PROFILE)"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait

echo "==> staple"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose "$APP"

echo "==> package"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
shasum -a 256 "$ZIP" | tee "$ZIP.sha256"
echo "OK: $ZIP"
