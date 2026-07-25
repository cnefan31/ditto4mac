#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Ditto4Mac"
BUILD_MODE="${1:-debug}"

if [ "$BUILD_MODE" = "release" ]; then
    BUILD_DIR="$PROJECT_ROOT/.build/release"
    echo "Building $APP_NAME (release)..."
    cd "$PROJECT_ROOT" && swift build -c release 2>&1
else
    BUILD_DIR="$PROJECT_ROOT/.build/debug"
    echo "Building $APP_NAME (debug)..."
    cd "$PROJECT_ROOT" && swift build 2>&1
fi

APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

# Create .app bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/"

# Copy icon
cp "$PROJECT_ROOT/scripts/AppIcon.icns" "$RESOURCES_DIR/"

# Generate Info.plist
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>Ditto4Mac</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.ditto4mac.app</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Ditto4Mac</string>
	<key>CFBundleDisplayName</key>
	<string>Ditto4Mac</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSSupportsAutomaticGraphicsSwitching</key>
	<true/>
</dict>
</plist>
PLIST

echo "✓ App bundle created: $APP_BUNDLE ($BUILD_MODE)"
echo "  Run: open $APP_BUNDLE"
