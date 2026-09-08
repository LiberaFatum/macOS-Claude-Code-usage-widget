#!/bin/bash
# Přeloží aplikaci, nainstaluje ji do /Applications a spustí.
set -euo pipefail

cd "$(dirname "$0")"
APP_NAME="Claude Usage"

./build.sh

echo "==> Instalace do /Applications"
pkill -f "/Claude Usage.app/Contents/MacOS/ClaudeUsage" 2>/dev/null || true
rm -rf "/Applications/$APP_NAME.app"
cp -R "build/$APP_NAME.app" "/Applications/$APP_NAME.app"

echo "==> Spouštím"
open "/Applications/$APP_NAME.app"

echo
echo "Hotovo, widget je v liště."
echo "Spouštění po restartu zapneš v menu: Nastavení > Spouštět po přihlášení."
