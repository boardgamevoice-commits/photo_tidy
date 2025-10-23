#!/bin/bash

# App Icon Generator Script for PhotoTidy-Toilet Buddy
# This script helps generate all required app icon sizes from a source image

echo "🚽 PhotoTidy-Toilet Buddy App Icon Generator"
echo "============================================="

# Check if ImageMagick is installed
if ! command -v magick &> /dev/null; then
    echo "❌ ImageMagick is not installed. Please install it first:"
    echo "   brew install imagemagick"
    exit 1
fi

# Check if source image is provided
if [ $# -eq 0 ]; then
    echo "📝 Usage: $0 <source_image_path>"
    echo ""
    echo "📋 Required icon sizes:"
    echo "   iPhone: 20x20, 29x29, 40x40, 60x60 (with @2x and @3x variants)"
    echo "   iPad: 20x20, 29x29, 40x40, 76x76, 83.5x83.5 (with @1x and @2x variants)"
    echo "   App Store: 1024x1024"
    echo ""
    echo "💡 Examples:"
    echo "   $0 assets/source_images/app_icon.png"
    echo "   $0 toilet_icon.png"
    echo ""
    echo "🔍 Looking for source images in assets/source_images/..."
    if [ -d "assets/source_images" ]; then
        SOURCE_FILES=$(find assets/source_images -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" | head -5)
        if [ -n "$SOURCE_FILES" ]; then
            echo "📸 Found source images:"
            echo "$SOURCE_FILES" | while read -r file; do
                echo "   - $file"
            done
            echo ""
            echo "💡 You can use any of these files as the source image."
        else
            echo "   No source images found. Please add your app_icon.png to assets/source_images/"
        fi
    else
        echo "   assets/source_images/ directory not found."
    fi
    exit 1
fi

SOURCE_IMAGE="$1"
ICON_DIR="PhotoTidy-Toilet Buddy/Assets.xcassets/AppIcon.appiconset"

# Check if source image exists
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "❌ Source image '$SOURCE_IMAGE' not found!"
    exit 1
fi

# Check if icon directory exists
if [ ! -d "$ICON_DIR" ]; then
    echo "❌ Icon directory '$ICON_DIR' not found!"
    exit 1
fi

echo "📸 Source image: $SOURCE_IMAGE"
echo "📁 Target directory: $ICON_DIR"
echo ""

# Create icons with proper naming
echo "🎨 Generating app icons..."

# iPhone icons
magick "$SOURCE_IMAGE" -resize 40x40 "$ICON_DIR/icon-20@2x.png"
magick "$SOURCE_IMAGE" -resize 60x60 "$ICON_DIR/icon-20@3x.png"
magick "$SOURCE_IMAGE" -resize 58x58 "$ICON_DIR/icon-29@2x.png"
magick "$SOURCE_IMAGE" -resize 87x87 "$ICON_DIR/icon-29@3x.png"
magick "$SOURCE_IMAGE" -resize 80x80 "$ICON_DIR/icon-40@2x.png"
magick "$SOURCE_IMAGE" -resize 120x120 "$ICON_DIR/icon-40@3x.png"
magick "$SOURCE_IMAGE" -resize 120x120 "$ICON_DIR/icon-60@2x.png"
magick "$SOURCE_IMAGE" -resize 180x180 "$ICON_DIR/icon-60@3x.png"

# iPad icons
magick "$SOURCE_IMAGE" -resize 20x20 "$ICON_DIR/icon-20.png"
magick "$SOURCE_IMAGE" -resize 40x40 "$ICON_DIR/icon-20@2x.png"
magick "$SOURCE_IMAGE" -resize 29x29 "$ICON_DIR/icon-29.png"
magick "$SOURCE_IMAGE" -resize 58x58 "$ICON_DIR/icon-29@2x.png"
magick "$SOURCE_IMAGE" -resize 40x40 "$ICON_DIR/icon-40.png"
magick "$SOURCE_IMAGE" -resize 80x80 "$ICON_DIR/icon-40@2x.png"
magick "$SOURCE_IMAGE" -resize 76x76 "$ICON_DIR/icon-76.png"
magick "$SOURCE_IMAGE" -resize 152x152 "$ICON_DIR/icon-76@2x.png"
magick "$SOURCE_IMAGE" -resize 167x167 "$ICON_DIR/icon-83.5@2x.png"

# App Store icon
magick "$SOURCE_IMAGE" -resize 1024x1024 "$ICON_DIR/icon-1024.png"

echo "✅ All app icons generated successfully!"
echo ""
echo "📋 Generated icons:"
echo "   iPhone: 20x20, 29x29, 40x40, 60x60 (with @2x and @3x variants)"
echo "   iPad: 20x20, 29x29, 40x40, 76x76, 83.5x83.5 (with @1x and @2x variants)"
echo "   App Store: 1024x1024"
echo ""
echo "🎯 Next steps:"
echo "   1. Open your project in Xcode"
echo "   2. Build and run to see the new icons"
echo "   3. Test on different devices to ensure quality"
echo ""
echo "💡 Tip: For best results, use a high-resolution source image (at least 1024x1024)"
