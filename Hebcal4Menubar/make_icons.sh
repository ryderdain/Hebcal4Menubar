#!/bin/bash
#
# make_icons.sh — generate macOS icon assets from a source icon.png
#
# Produces:
#   1. AppIcon.icns          — the app bundle icon (full color), for Finder,
#                              Login Items, the app switcher, etc.
#   2. MenubarIcon.png +@2x  — small versions for the status-bar item.
#
# Run this on macOS from the folder containing icon.png:
#     chmod +x make_icons.sh && ./make_icons.sh
#
# Requires: sips and iconutil (both ship with macOS — nothing to install).

set -euo pipefail

SRC="icon.png"
if [[ ! -f "$SRC" ]]; then
    echo "error: $SRC not found in $(pwd)" >&2
    echo "Place your downloaded icon.png here and re-run." >&2
    exit 1
fi

echo "Source: $SRC"
sips -g pixelWidth -g pixelHeight "$SRC" | sed 's/^/  /'

# --- 1. App icon (.icns) ----------------------------------------------------
# macOS .icns expects a specific set of sizes inside a .iconset folder.
ICONSET="AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

# size:filename pairs required by iconutil
declare -a SIZES=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
)

for pair in "${SIZES[@]}"; do
    px="${pair%%:*}"
    name="${pair##*:}"
    sips -z "$px" "$px" "$SRC" --out "$ICONSET/$name" >/dev/null
done

iconutil -c icns "$ICONSET" -o AppIcon.icns
echo "Wrote AppIcon.icns"

# --- 2. Menubar icon --------------------------------------------------------
# The status bar is ~18pt tall. We emit 1x (18px) and 2x (36px) so it stays
# crisp on Retina. NOTE: for proper light/dark tinting this should ideally be
# a monochrome *template* image; see ICON_NOTES.md for how to flag it.
sips -z 18 18 "$SRC" --out "MenubarIcon.png"    >/dev/null
sips -z 36 36 "$SRC" --out "MenubarIcon@2x.png" >/dev/null
echo "Wrote MenubarIcon.png and MenubarIcon@2x.png"

echo "Done."
