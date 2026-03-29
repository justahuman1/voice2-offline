#!/bin/bash
# Build and run Speak2 as a proper .app bundle so macOS shows the menu bar icon.
# A bare executable from `swift build` doesn't register with the window server
# properly — wrapping it in a minimal .app bundle fixes this.

set -euo pipefail

APP_NAME="Speak2"
APP_DIR=".build/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
MACOS="${CONTENTS}/MacOS"

# Build
echo "Building ${APP_NAME}..."
swift build

# Create minimal .app bundle
rm -rf "${APP_DIR}"
mkdir -p "${MACOS}"

# Copy binary
cp ".build/debug/${APP_NAME}" "${MACOS}/${APP_NAME}"

# Write minimal Info.plist
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
</dict>
</plist>
PLIST

echo "Running ${APP_NAME}.app..."
open "${APP_DIR}"
