#!/bin/bash
# Odstraní aplikaci, login item i uložené předvolby.
set -euo pipefail

APP_NAME="Claude Usage"
LABEL="com.liberafatum.claude-usage-widget"

pkill -f "/Claude Usage.app/Contents/MacOS/ClaudeUsage" 2>/dev/null || true
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "/Applications/$APP_NAME.app"
defaults delete "$LABEL" 2>/dev/null || true

security delete-identity -c "Claude Usage Local" 2>/dev/null || true

echo "$APP_NAME odstraněna."
