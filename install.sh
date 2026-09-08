#!/bin/bash
# Builds the app, installs it into /Applications and launches it.
set -euo pipefail

cd "$(dirname "$0")"
APP_NAME="Claude Usage"

./build.sh

echo "==> Installing to /Applications"
pkill -f "/Claude Usage.app/Contents/MacOS/ClaudeUsage" 2>/dev/null || true
rm -rf "/Applications/$APP_NAME.app"
cp -R "build/$APP_NAME.app" "/Applications/$APP_NAME.app"

echo "==> Launching"
open "/Applications/$APP_NAME.app"

echo
echo "Installed. The widget now sits in your menu bar."
echo "Enable autostart from its Preferences submenu -> \"Start at login\"."
