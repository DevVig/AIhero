#!/usr/bin/env bash
# Assembles a runnable AIhero.app bundle from the SwiftPM build.
# Usage: Scripts/make_app.sh [debug|release]
#
# If Scripts/AppIcon.icns exists (produced by make_icon.sh) it's embedded and
# referenced from the Info.plist; otherwise the bundle builds icon-less with a
# warning. Signing/notarization is a separate step — see Scripts/sign_app.sh.
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/AIhero.app"
BIN_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"
ICON_SRC="$ROOT/Scripts/AppIcon.icns"

echo "▶ Building ($CONFIG)…"
swift build -c "$CONFIG" --package-path "$ROOT" >/dev/null

BIN_PATH="$(swift build -c "$CONFIG" --package-path "$ROOT" --show-bin-path)/AIhero"

echo "▶ Assembling bundle…"
rm -rf "$APP"
mkdir -p "$BIN_DIR" "$RES_DIR"
cp "$BIN_PATH" "$BIN_DIR/AIhero"

# Icon (optional but expected for release).
ICON_KEY=""
if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$RES_DIR/AppIcon.icns"
    ICON_KEY='    <key>CFBundleIconFile</key>        <string>AppIcon</string>'
    echo "  • embedded AppIcon.icns"
else
    echo "  ⚠ no Scripts/AppIcon.icns — bundle will be icon-less (run make_icon.sh first)"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>AIhero</string>
    <key>CFBundleDisplayName</key>     <string>AIhero</string>
    <key>CFBundleIdentifier</key>      <string>ai.aihero.companion</string>
    <key>CFBundleVersion</key>         <string>0.1.0</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleExecutable</key>      <string>AIhero</string>
$ICON_KEY
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSHighResolutionCapable</key> <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
    <key>NSHumanReadableCopyright</key><string>On-device superhero companion. Nothing leaves your Mac.</string>
</dict>
</plist>
PLIST

echo "✓ Built $APP"
