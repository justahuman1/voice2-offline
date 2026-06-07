#!/bin/bash
# Build and run Speak2 as a proper .app bundle so macOS shows the menu bar icon.
# The .app bundle is created once and reused so macOS permission grants persist.

set -euo pipefail

APP_NAME="Speak2"
APP_DIR=".build/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
MACOS="${CONTENTS}/MacOS"

# Build
echo "Building ${APP_NAME}..."
swift build

# Create .app bundle only if it doesn't exist
if [ ! -f "${CONTENTS}/Info.plist" ]; then
    echo "Creating ${APP_NAME}.app bundle..."
    mkdir -p "${MACOS}"

    cat > "${CONTENTS}/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.speak2.app</string>
    <key>CFBundleName</key>
    <string>Speak2</string>
    <key>CFBundleExecutable</key>
    <string>Speak2</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Speak2 needs microphone access to record speech for transcription.</string>
</dict>
</plist>
PLIST
fi

# Always update the binary
cp ".build/debug/${APP_NAME}" "${MACOS}/${APP_NAME}"

echo "Running ${APP_NAME}.app..."
open "${APP_DIR}"
