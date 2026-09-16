#!/bin/bash
set -e

APP_NAME="IdleFaceLock"
BUILD_DIR=".build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

echo "==> Building $APP_NAME"

swift build -c release

BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"

if [ ! -f "$BINARY" ]; then
    echo "ERROR: binary not found:"
    echo "$BINARY"
    exit 1
fi

echo "==> Binary:"
echo "$BINARY"

echo "==> Creating app bundle"

rm -rf "$APP_DIR"

mkdir -p \
    "$APP_DIR/Contents/MacOS" \
    "$APP_DIR/Contents/Resources"

cp "$BINARY" \
    "$APP_DIR/Contents/MacOS/$APP_NAME"

cp Resources/Info.plist        "$APP_DIR/Contents/Info.plist"
cp Resources/IdleFaceLock.icns "$APP_DIR/Contents/Resources/IdleFaceLock.icns"

chmod +x     "$APP_DIR/Contents/MacOS/$APP_NAME"

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
