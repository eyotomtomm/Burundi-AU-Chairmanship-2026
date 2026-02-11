#!/bin/bash

echo "🎨 Updating Burundi AU Chairmanship App Icon"
echo "============================================="
echo ""

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "❌ ImageMagick not found."
    echo ""
    echo "Install with:"
    echo "  macOS: brew install imagemagick"
    echo "  Ubuntu: sudo apt-get install imagemagick"
    echo "  Windows: https://imagemagick.org/script/download.php"
    echo ""
    exit 1
fi

# Navigate to project root
cd "$(dirname "$0")"

# Check if SVG exists
if [ ! -f "burundi_au_chairmanship/assets/icons/karyenda_drum.svg" ]; then
    echo "❌ SVG file not found: burundi_au_chairmanship/assets/icons/karyenda_drum.svg"
    exit 1
fi

cd "burundi_au_chairmanship/assets/icons"

echo "📐 Generating iOS icons..."

# iOS Icons - All required sizes
convert karyenda_drum.svg -resize 20x20 -background white -alpha remove icon-20.png
convert karyenda_drum.svg -resize 29x29 -background white -alpha remove icon-29.png
convert karyenda_drum.svg -resize 40x40 -background white -alpha remove icon-40.png
convert karyenda_drum.svg -resize 58x58 -background white -alpha remove icon-58.png
convert karyenda_drum.svg -resize 60x60 -background white -alpha remove icon-60.png
convert karyenda_drum.svg -resize 76x76 -background white -alpha remove icon-76.png
convert karyenda_drum.svg -resize 80x80 -background white -alpha remove icon-80.png
convert karyenda_drum.svg -resize 87x87 -background white -alpha remove icon-87.png
convert karyenda_drum.svg -resize 120x120 -background white -alpha remove icon-120.png
convert karyenda_drum.svg -resize 152x152 -background white -alpha remove icon-152.png
convert karyenda_drum.svg -resize 167x167 -background white -alpha remove icon-167.png
convert karyenda_drum.svg -resize 180x180 -background white -alpha remove icon-180.png
convert karyenda_drum.svg -resize 1024x1024 -background white -alpha remove icon-1024.png

echo "✅ iOS icons generated (13 sizes)"
echo ""

echo "🤖 Generating Android icons..."

# Create directories if they don't exist
mkdir -p ../../android/app/src/main/res/mipmap-mdpi
mkdir -p ../../android/app/src/main/res/mipmap-hdpi
mkdir -p ../../android/app/src/main/res/mipmap-xhdpi
mkdir -p ../../android/app/src/main/res/mipmap-xxhdpi
mkdir -p ../../android/app/src/main/res/mipmap-xxxhdpi

# Android Icons - All densities
convert karyenda_drum.svg -resize 48x48 -background white -alpha remove ../../android/app/src/main/res/mipmap-mdpi/ic_launcher.png
convert karyenda_drum.svg -resize 72x72 -background white -alpha remove ../../android/app/src/main/res/mipmap-hdpi/ic_launcher.png
convert karyenda_drum.svg -resize 96x96 -background white -alpha remove ../../android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
convert karyenda_drum.svg -resize 144x144 -background white -alpha remove ../../android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
convert karyenda_drum.svg -resize 192x192 -background white -alpha remove ../../android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png

echo "✅ Android icons generated (5 densities)"
echo ""

echo "📊 Icon Summary:"
echo "  iOS icons:     13 sizes (20px to 1024px)"
echo "  Android icons: 5 densities (mdpi to xxxhdpi)"
echo "  Total files:   18 PNG files"
echo ""

echo "📱 Next Steps:"
echo ""
echo "  iOS (Xcode):"
echo "    1. Open: open burundi_au_chairmanship/ios/Runner.xcworkspace"
echo "    2. Navigate to: Runner > Assets.xcassets > AppIcon"
echo "    3. Drag icon-*.png files to corresponding slots"
echo ""
echo "  Android:"
echo "    ✅ Icons already placed in mipmap folders!"
echo ""
echo "  Test:"
echo "    flutter clean"
echo "    flutter pub get"
echo "    flutter run"
echo ""

echo "🎉 App icon update complete!"
