#!/usr/bin/env bash
# Signs, notarizes, staples, and packages dist/AIhero.app into a distributable
# DMG. Run Scripts/make_app.sh release first.
#
# One-time setup (per machine):
#   1. Enroll in the Apple Developer Program; install your
#      "Developer ID Application" certificate into the login keychain.
#   2. Store a notarytool credential profile:
#        xcrun notarytool store-credentials AIhero \
#          --apple-id "<you@example.com>" --team-id "<TEAMID>" \
#          --password "<app-specific-password>"
#
# Then set, per run:
#   DEVELOPER_ID_APP  e.g. "Developer ID Application: Jane Doe (TEAMID)"
#   AC_PROFILE        notarytool keychain profile name (default: AIhero)
#
# Usage: DEVELOPER_ID_APP="Developer ID Application: … (TEAMID)" Scripts/sign_app.sh
#
# Design note: the app is signed with the hardened runtime and NO entitlements —
# the most restrictive posture. AIhero itself opens no network connections; art
# generation is delegated to the user's own `codex` binary, a separate process
# with its own signature and auth. There is nothing to grant.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/AIhero.app"
DMG="$ROOT/dist/AIhero.dmg"
AC_PROFILE="${AC_PROFILE:-AIhero}"

[ -d "$APP" ] || { echo "✗ $APP not found — run Scripts/make_app.sh release first" >&2; exit 1; }
: "${DEVELOPER_ID_APP:?set DEVELOPER_ID_APP to your \"Developer ID Application: … (TEAMID)\" identity}"

echo "▶ Signing (hardened runtime, no entitlements)…"
# Inner executable first, then the bundle — no --deep (deprecated/unsafe).
codesign --force --options runtime --timestamp \
    --sign "$DEVELOPER_ID_APP" "$APP/Contents/MacOS/AIhero"
codesign --force --options runtime --timestamp \
    --sign "$DEVELOPER_ID_APP" "$APP"

echo "▶ Verifying signature…"
codesign --verify --strict --verbose=2 "$APP"

echo "▶ Building DMG…"
rm -f "$DMG"
hdiutil create -volname "AIhero" -srcfolder "$APP" -ov -format UDZO "$DMG" >/dev/null

echo "▶ Notarizing (this can take a few minutes)…"
xcrun notarytool submit "$DMG" --keychain-profile "$AC_PROFILE" --wait

echo "▶ Stapling…"
xcrun stapler staple "$DMG"
xcrun stapler staple "$APP"

echo "▶ Gatekeeper assessment…"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG" || true

echo "✓ Signed + notarized: $DMG"
