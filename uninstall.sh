#!/bin/bash
set -e

APP_NAME="IdleFaceLock"
APP_DEST="/Applications/$APP_NAME.app"
PLIST_PATH="$HOME/Library/LaunchAgents/com.zzzqiuchan.idlefacelock.plist"

UID_VALUE="$(id -u)"

echo "==> Stopping LaunchAgent"

launchctl bootout     "gui/$UID_VALUE/com.zzzqiuchan.idlefacelock"     2>/dev/null || true

echo "==> Removing LaunchAgent"

rm -f "$PLIST_PATH"

echo "==> Removing application"

rm -rf "$APP_DEST"

echo
echo "IdleFaceLock uninstalled."
