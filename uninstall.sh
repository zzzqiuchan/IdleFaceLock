#!/bin/bash
set -e

APP_NAME="IdleFaceLock"
BUNDLE_ID="com.zzzqiuchan.idlefacelock"
PLIST_PATH="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"

UID_VALUE="$(id -u)"

echo "==> Stopping LaunchAgent"

launchctl bootout     "gui/$UID_VALUE/$BUNDLE_ID"     2>/dev/null || true

echo "==> Removing LaunchAgent"

rm -f "$PLIST_PATH"

echo "==> Removing application"

# Cover both install locations: install.sh uses /Applications, while the
# one-line installer in the README installs to ~/Applications.
rm -rf "/Applications/$APP_NAME.app"
rm -rf "$HOME/Applications/$APP_NAME.app"

echo "==> Resetting camera permission and preferences"

tccutil reset Camera "$BUNDLE_ID" 2>/dev/null || true
defaults delete "$BUNDLE_ID" 2>/dev/null || true

echo
echo "IdleFaceLock uninstalled."
echo "Logs kept at ~/Library/Logs/IdleFaceLock/ (remove manually if you want)."
