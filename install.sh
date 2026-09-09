#!/bin/bash
# Přeloží aplikaci, nainstaluje ji do /Applications a spustí.
set -euo pipefail

cd "$(dirname "$0")"
APP_NAME="Claude Usage"

if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "Claude Usage Local"; then
    ./Tools/create-signing-identity.sh || echo "Pokračuji s ad-hoc podpisem."
fi

./build.sh

echo "==> Instalace do /Applications"
pkill -f "/Claude Usage.app/Contents/MacOS/ClaudeUsage" 2>/dev/null || true
rm -rf "/Applications/$APP_NAME.app"
cp -R "build/$APP_NAME.app" "/Applications/$APP_NAME.app"

echo "==> Spouštím"
LABEL="com.liberafatum.claude-usage-widget"
if [ -f "$HOME/Library/LaunchAgents/$LABEL.plist" ]; then
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/$LABEL.plist"
else
    open "/Applications/$APP_NAME.app"
fi

echo
echo "Hotovo, widget je v liště."
echo "Spouštění po restartu zapneš v menu: Nastavení > Spouštět po přihlášení."
