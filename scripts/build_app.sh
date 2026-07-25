#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Ditto4Mac"
BUILD_MODE="${1:-debug}"
UNIVERSAL=0
if [ "$2" = "--universal" ]; then
    UNIVERSAL=1
fi

ARCH_FLAGS=""
if [ "$UNIVERSAL" = "1" ]; then
    ARCH_FLAGS="--arch arm64 --arch x86_64"
    echo "Building universal binary (arm64 + x86_64)..."
fi

if [ "$BUILD_MODE" = "release" ]; then
    echo "Building $APP_NAME (release)..."
    cd "$PROJECT_ROOT" && swift build -c release $ARCH_FLAGS 2>&1
    BUILD_DIR="$PROJECT_ROOT/.build/release"
else
    echo "Building $APP_NAME (debug)..."
    cd "$PROJECT_ROOT" && swift build $ARCH_FLAGS 2>&1
    BUILD_DIR="$PROJECT_ROOT/.build/debug"
fi

# Universal binary 走 xcbuild，输出路径可能与默认不同，动态获取
if [ "$UNIVERSAL" = "1" ]; then
    BIN_PATH=$(cd "$PROJECT_ROOT" && swift build -c ${BUILD_MODE} $ARCH_FLAGS --show-bin-path 2>/dev/null) || true
    if [ -n "$BIN_PATH" ]; then
        BUILD_DIR="$BIN_PATH"
    fi
fi

# .app bundle 统一放在默认构建目录，与二进制实际输出路径解耦
OUTPUT_DIR="$PROJECT_ROOT/.build/${BUILD_MODE}"
APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
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

ARCH_INFO=""
if [ "$UNIVERSAL" = "1" ]; then
    ARCH_INFO=" universal"
fi

echo "✓ App bundle created:$ARCH_INFO $APP_BUNDLE ($BUILD_MODE)"
echo "  Run: open $APP_BUNDLE"
