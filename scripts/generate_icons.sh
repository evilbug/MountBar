#!/bin/bash
# Generate macOS AppIcon.appiconset from source icon using sips (built-in macOS tool)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_ICON="$SCRIPT_DIR/icon/app_icon.png"
APPICONSET_DIR="$SCRIPT_DIR/src/MountBar/Assets.xcassets/AppIcon.appiconset"

if [ ! -f "$SOURCE_ICON" ]; then
    echo "Error: Source icon not found at $SOURCE_ICON"
    exit 1
fi

mkdir -p "$APPICONSET_DIR"

# Remove old icons (preserve Contents.json)
find "$APPICONSET_DIR" -name "*.png" -type f -delete

# Generate all macOS app icon sizes
# Format: display_size:output_size:filename

sizes=(
    "16:16:icon_16x16.png"
    "16:32:icon_32x32.png"
    "32:32:icon_32x32.png"
    "32:64:icon_32x32@2x.png"
    "128:128:icon_128x128.png"
    "128:256:icon_256x256.png"
    "256:256:icon_256x256.png"
    "256:512:icon_256x256@2x.png"
    "512:512:icon_512x512.png"
    "512:1024:icon_512x512@2x.png"
)

for entry in "${sizes[@]}"; do
    IFS=':' read -r display_size output_size filename <<< "$entry"
    echo "Generating $filename (${output_size}x${output_size})"
    sips -z "$output_size" "$output_size" "$SOURCE_ICON" --out "$APPICONSET_DIR/$filename" > /dev/null 2>&1
done

echo "✓ App icons generated successfully in $APPICONSET_DIR"
ls -la "$APPICONSET_DIR"
