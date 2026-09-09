#!/bin/bash
# Dvojklik v Finderu spustí instalaci. Okno zůstane otevřené, ať je vidět výsledek.
cd "$(dirname "$0")" || exit 1

./install.sh
STATUS=$?

echo
if [ "$STATUS" -eq 0 ]; then
    echo "Můžeš zavřít tohle okno."
else
    echo "Instalace skončila chybou $STATUS. Text výše říká, co dělat."
fi
echo "Stiskni Enter pro zavření."
read -r _
