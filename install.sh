#!/bin/bash
# Přeloží aplikaci, nainstaluje ji do /Applications a spustí.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Claude Usage"
LABEL="com.liberafatum.claude-usage-widget"
IDENTITY="Claude Usage Local"

. ./Tools/preflight.sh

# Stálý podpis drží povolení přístupu ke Keychainu i po aktualizaci. Vytvoření
# identity umí vyvolat systémový dialog, proto se o něj pokoušíme jen když
# u toho někdo sedí. Neinteraktivní běh, třeba z AI agenta, by se na dialogu
# zasekl bez výstupu.
if ! security find-identity 2>/dev/null | grep -q "\"$IDENTITY\""; then
    if [ -t 0 ]; then
        ./Tools/create-signing-identity.sh || echo "Identita se nevytvořila, pokračuji ad-hoc podpisem."
    else
        echo "Přeskakuji vytvoření podpisové identity, běžím bez terminálu."
        echo "Až budeš u počítače, spusť jednou: ./Tools/create-signing-identity.sh"
    fi
fi

if ! ./build.sh; then
    echo >&2
    echo "Překlad selhal, nic se nenainstalovalo. Výpis výše říká proč." >&2
    exit 1
fi

echo "==> Instalace do /Applications"
pkill -f "/$APP_NAME.app/Contents/MacOS/ClaudeUsage" 2>/dev/null || true
rm -rf "/Applications/$APP_NAME.app"
cp -R "build/$APP_NAME.app" "/Applications/$APP_NAME.app"

echo "==> Spouštím"
if [ -f "$HOME/Library/LaunchAgents/$LABEL.plist" ]; then
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/$LABEL.plist"
else
    open "/Applications/$APP_NAME.app"
fi

# Instalace smí hlásit úspěch jen tehdy, když aplikace opravdu běží.
RUNNING=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
    if pgrep -f "/$APP_NAME.app/Contents/MacOS/ClaudeUsage" >/dev/null 2>&1; then
        RUNNING=1
        break
    fi
    sleep 1
done

echo
if [ "$RUNNING" -eq 1 ]; then
    cat <<'MSG'
Hotovo. V pravé části horní lišty přibyl oranžový panáček a vedle něj procenta,
například "12 % s | 34 % w".

Že widget běží, ověříš i z terminálu:
    pgrep -fl "Claude Usage.app"

Spouštění po restartu zapneš v jeho menu: Nastavení > Spouštět po přihlášení.
MSG
else
    cat >&2 <<'MSG'
Aplikace se nainstalovala do /Applications, ale nepodařilo se ji spustit.

Zkus ji otevřít ručně:
    open "/Applications/Claude Usage.app"

Pokud se ani tak neobjeví v liště, podívej se do logu:
    cat ~/Library/Logs/ClaudeUsage.log
MSG
    exit 1
fi
