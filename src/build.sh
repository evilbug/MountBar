#!/bin/bash

echo "🔨 Building MountBar..."

# Navigate to project directory
cd "$(dirname "$0")"

# Clean and build release version
echo "📦 Building release version..."
xcodebuild -project MountBar.xcodeproj -scheme MountBar -configuration Release clean build

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build successful!"

# Copy app to Desktop
echo "📋 Copying app to Desktop..."
cp -R "/Users/iago/Library/Developer/Xcode/DerivedData/MountBar-"*"/Build/Products/Release/MountBar.app" "release/MountBar.app"

if [ $? -ne 0 ]; then
    echo "❌ Failed to copy app!"
    exit 1
fi

echo "✅ App copied to Desktop!"

# Create DMG
echo "💿 Creating DMG installer..."
hdiutil create -volname "MountBar" -srcfolder release/MountBar.app -ov -format UDZO release/MountBar.dmg

if [ $? -ne 0 ]; then
    echo "❌ Failed to create DMG!"
    exit 1
fi

echo "✅ DMG created!"

# Get file sizes
APP_SIZE=$(du -h "/Users/iago/Desktop/MountBar.app" | cut -f1)
DMG_SIZE=$(du -h "/Users/iago/Desktop/MountBar.dmg" | cut -f1)

echo ""
echo "🎉 Build completed successfully!"
echo "📁 Check your Desktop for:"
echo "   • MountBar.app ($APP_SIZE)"
echo "   • MountBar.dmg ($DMG_SIZE)"
echo ""
echo "🚀 Ready for distribution!"
