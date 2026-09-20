#!/bin/bash
set -e

APP_NAME="IdleFaceLock"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SOURCE="$PROJECT_DIR/.build/$APP_NAME.app"
APP_DEST="/Applications/$APP_NAME.app"

echo "==> Building $APP_NAME"
"$PROJECT_DIR/build-app.sh"

echo
echo "==> Installing application"

rm -rf "$APP_DEST"
cp -R "$APP_SOURCE" "$APP_DEST"

echo
echo "========================================"
echo "IdleFaceLock 0.5.6 installed."
echo
echo "Application:"
echo "$APP_DEST"
echo
echo "Login at startup:"
echo "OFF by default"
echo
echo "Use the menu bar item '登录时启动' to enable it."
echo
echo "Logs:"
echo "~/Library/Logs/IdleFaceLock/current.log"
echo
echo "========================================"
