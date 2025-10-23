#!/bin/bash

# App Icon Verification Script
# This script verifies that all required app icon files are present

echo "🔍 Verifying App Icon Configuration"
echo "===================================="

ICON_DIR="PhotoTidy-Toilet Buddy/Assets.xcassets/AppIcon.appiconset"
CONTENTS_FILE="$ICON_DIR/Contents.json"

# Check if Contents.json exists
if [ ! -f "$CONTENTS_FILE" ]; then
    echo "❌ Contents.json not found at $CONTENTS_FILE"
    exit 1
fi

echo "✅ Contents.json found"

# Extract expected filenames from Contents.json
EXPECTED_FILES=$(grep -o '"filename" : "[^"]*"' "$CONTENTS_FILE" | sed 's/"filename" : "//g' | sed 's/"//g')

echo ""
echo "📋 Expected icon files:"
echo "$EXPECTED_FILES" | while read -r filename; do
    if [ -n "$filename" ]; then
        filepath="$ICON_DIR/$filename"
        if [ -f "$filepath" ]; then
            echo "✅ $filename"
        else
            echo "❌ $filename (missing)"
        fi
    fi
done

echo ""
echo "📊 Summary:"

# Count total expected files
TOTAL_EXPECTED=$(echo "$EXPECTED_FILES" | grep -c .)
# Count existing files
EXISTING_COUNT=0
for filename in $EXPECTED_FILES; do
    if [ -n "$filename" ] && [ -f "$ICON_DIR/$filename" ]; then
        ((EXISTING_COUNT++))
    fi
done

echo "   Total expected: $TOTAL_EXPECTED"
echo "   Found: $EXISTING_COUNT"
echo "   Missing: $((TOTAL_EXPECTED - EXISTING_COUNT))"

if [ $EXISTING_COUNT -eq $TOTAL_EXPECTED ]; then
    echo ""
    echo "🎉 All app icons are present and ready!"
    echo ""
    echo "🚀 Next steps:"
    echo "   1. Open your project in Xcode"
    echo "   2. Build and run the app"
    echo "   3. Check the app icon on the home screen"
else
    echo ""
    echo "⚠️  Some icons are missing. Please run the generate_app_icons.sh script"
    echo "   with your source image to create the missing icons."
fi
