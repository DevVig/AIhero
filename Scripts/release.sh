#!/usr/bin/env bash
# One-shot release: icon → bundle → sign → notarize → DMG.
#
# Usage:
#   DEVELOPER_ID_APP="Developer ID Application: … (TEAMID)" \
#     Scripts/release.sh [path/to/magicpath-icon.png]
#
# If an icon PNG is passed (or Scripts/AppIcon.icns already exists) the bundle is
# iconed. Requires the one-time notarytool setup described in sign_app.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICON_PNG="${1:-}"

if [ -n "$ICON_PNG" ]; then
    "$ROOT/Scripts/make_icon.sh" "$ICON_PNG"
elif [ ! -f "$ROOT/Scripts/AppIcon.icns" ]; then
    echo "⚠ no icon: pass a source PNG or run make_icon.sh first (continuing icon-less)"
fi

"$ROOT/Scripts/make_app.sh" release
"$ROOT/Scripts/sign_app.sh"

echo "✓ Release ready → dist/AIhero.dmg"
