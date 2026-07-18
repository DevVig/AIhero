#!/usr/bin/env bash
# Builds AIhero's app icon (.icns) from a single square source PNG.
#
# Point it at the exported MagicPath hero/mark artwork — ideally 1024×1024 with a
# transparent or solid background. It renders every size macOS wants and packs
# them into an .icns that Scripts/make_app.sh will drop into the bundle.
#
# Usage: Scripts/make_icon.sh <source.png> [out.icns]
#   default out: Scripts/AppIcon.icns
set -euo pipefail

SRC="${1:?usage: make_icon.sh <source-square-png> [out.icns]}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${2:-$ROOT/Scripts/AppIcon.icns}"

[ -f "$SRC" ] || { echo "✗ source not found: $SRC" >&2; exit 1; }

WORK="$(mktemp -d)/AIhero.iconset"
mkdir -p "$WORK"

# name → pixel size (retina variants included)
emit() { sips -z "$1" "$1" "$SRC" --out "$WORK/$2" >/dev/null; }
echo "▶ Rendering icon sizes from $SRC…"
emit 16   icon_16x16.png
emit 32   icon_16x16@2x.png
emit 32   icon_32x32.png
emit 64   icon_32x32@2x.png
emit 128  icon_128x128.png
emit 256  icon_128x128@2x.png
emit 256  icon_256x256.png
emit 512  icon_256x256@2x.png
emit 512  icon_512x512.png
emit 1024 icon_512x512@2x.png

echo "▶ Packing .icns…"
iconutil -c icns "$WORK" -o "$OUT"
rm -rf "$(dirname "$WORK")"
echo "✓ Wrote $OUT"
