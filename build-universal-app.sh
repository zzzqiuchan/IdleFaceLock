#!/bin/bash

set -e

APP_NAME="IdleFaceLock"

BUILD_DIR=".build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

echo "==> Building $APP_NAME"

echo "==> Building arm64"
swift build -c release --arch arm64

ARM_BINARY="$(swift build -c release --arch arm64 --show-bin-path)/$APP_NAME"

if [ ! -f "$ARM_BINARY" ]; then
    echo "ERROR: arm64 binary not found:"
    echo "$ARM_BINARY"
    exit 1
fi

echo "==> Building x86_64"
swift build -c release --arch x86_64

INTEL_BINARY="$(swift build -c release --arch x86_64 --show-bin-path)/$APP_NAME"

if [ ! -f "$INTEL_BINARY" ]; then
    echo "ERROR: x86_64 binary not found:"
    echo "$INTEL_BINARY"
    exit 1
fi

echo "==> Creating app bundle"

rm -rf "$APP_DIR"

mkdir -p \
    "$APP_DIR/Contents/MacOS" \
    "$APP_DIR/Contents/Resources"

echo "==> Creating Universal binary"

lipo -create \
    "$ARM_BINARY" \
    "$INTEL_BINARY" \
    -output "$APP_DIR/Contents/MacOS/$APP_NAME"

cp Resources/Info.plist        "$APP_DIR/Contents/Info.plist"
cp Resources/IdleFaceLock.icns "$APP_DIR/Contents/Resources/IdleFaceLock.icns"

chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

# Ad-hoc sign the app. `lipo -create` drops the per-slice signatures that
# `swift build` produced, leaving the universal binary unsigned. macOS ties
# camera/TCC grants to a valid code signature, so an unsigned app fails to get
# camera permission. A stable ad-hoc signature is enough to make TCC work
# (full Gatekeeper "just double-click" still needs Developer ID + notarization).
echo "==> Ad-hoc signing"
codesign --force --sign - "$APP_DIR"

echo
echo "========================================"
echo "App created:"
echo "$APP_DIR"
echo
echo "Architecture:"
file "$APP_DIR/Contents/MacOS/$APP_NAME"
echo
echo "Run:"
echo "open \"$APP_DIR\""
echo "========================================"
