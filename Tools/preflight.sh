#!/bin/bash
# Předletová kontrola. Načítá se přes ". Tools/preflight.sh" z build.sh i install.sh.
# Cílem je, aby uživatel místo pádu uprostřed překladu dostal větu, co má udělat.

preflight_fail() {
    printf '\n%s\n\n' "$1" >&2
    exit 1
}

# 1. Verze macOS. MenuBarExtra a SwiftUI Canvas potřebují Ventura a novější.
MACOS_MAJOR=$(sw_vers -productVersion 2>/dev/null | cut -d. -f1)
if [ -n "${MACOS_MAJOR:-}" ] && [ "$MACOS_MAJOR" -lt 13 ] 2>/dev/null; then
    preflight_fail "Potřeba macOS 13 (Ventura) nebo novější, tenhle Mac má $(sw_vers -productVersion)."
fi

# 2. Command Line Tools. Testuje se existence swiftc v aktivním developer adresáři.
#    Ne "command -v swift", ten je na systému vždy jako stub, který si o CLT teprve řekne.
#    Ne "xcrun --find", ten na stroji bez CLT sám otevře systémový dialog.
DEV_DIR=$(xcode-select -p 2>/dev/null || true)
if [ -z "${DEV_DIR:-}" ] || [ ! -x "$DEV_DIR/usr/bin/swiftc" ]; then
    preflight_fail "Chybí Xcode Command Line Tools, bez nich se projekt nedá přeložit.

Spusť:

    xcode-select --install

Otevře se systémové okno, klikni na Instalovat a počkej, než se stahování dokončí.
Je to jednorázový krok a musí ho odklikat člověk, AI agent to za tebe neudělá.

Hotovo poznáš takto:

    xcode-select -p        # vypíše /Library/Developer/CommandLineTools
    swiftc --version       # vypíše verzi Swiftu

Potom spusť instalaci znovu.

Pokud hlásí, že jsou nástroje už nainstalované, ale tahle kontrola padá,
rozbil je upgrade systému. Pomůže:

    sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install"
fi

# 3. Verze Swiftu. Package.swift má swift-tools-version 5.9.
SWIFT_VERSION=$("$DEV_DIR/usr/bin/swiftc" --version 2>/dev/null | sed -n 's/.*Swift version \([0-9][0-9.]*\).*/\1/p' | head -1)
if [ -n "${SWIFT_VERSION:-}" ]; then
    OLDEST=$(printf '%s\n5.9\n' "$SWIFT_VERSION" | sort -V | head -1)
    if [ "$OLDEST" != "5.9" ] && [ "$SWIFT_VERSION" != "5.9" ]; then
        preflight_fail "Nainstalovaný Swift $SWIFT_VERSION je starší než 5.9, který projekt potřebuje.
Aktualizuj Command Line Tools v Nastavení systému > Obecné > Aktualizace softwaru."
    fi
fi

# 4. Zápis do /Applications. Bez něj by instalace spadla až na konci.
if [ ! -w /Applications ]; then
    preflight_fail "Do /Applications se nedá zapisovat, instalace by na konci selhala.
Zkontroluj práva, nebo aplikaci nainstaluj ručně přetažením z adresáře build/."
fi

# 5. Claude Code. Chybějící data nejsou důvod instalaci zastavit, jen o tom říct.
if [ ! -e "$HOME/.claude.json" ] && [ ! -d "$HOME/.claude" ]; then
    echo "Poznámka: nenašel jsem ~/.claude.json ani ~/.claude, takže Claude Code na tomhle" >&2
    echo "         stroji nejspíš ještě neběžel. Widget se nainstaluje, ale data ukáže až" >&2
    echo "         po prvním spuštění Claude Code." >&2
fi
