#!/bin/bash
# Instalace jedním příkazem. Naklonuje nebo aktualizuje repozitář a spustí install.sh.
#
#   curl -fsSL https://raw.githubusercontent.com/LiberaFatum/macOS-Claude-Code-usage-widget/main/Tools/bootstrap.sh | bash
set -euo pipefail

REPO="https://github.com/LiberaFatum/macOS-Claude-Code-usage-widget.git"
DEST="${CLAUDE_USAGE_DIR:-$HOME/.local/share/claude-usage-widget}"

if ! command -v git >/dev/null 2>&1; then
    echo "Chybí git. Nainstaluješ ho spolu s vývojářskými nástroji: xcode-select --install" >&2
    exit 1
fi

if [ -d "$DEST/.git" ]; then
    echo "==> Aktualizuji $DEST"
    git -C "$DEST" pull --ff-only --quiet
else
    echo "==> Stahuji do $DEST"
    mkdir -p "$(dirname "$DEST")"
    git clone --quiet "$REPO" "$DEST"
fi

cd "$DEST"

# Skript typicky běží přes rouru z curl, takže stdin není terminál a install.sh
# by přeskočil krok, který potřebuje potvrzení dialogu. Když je terminál po ruce,
# připojíme ho zpět.
if [ ! -t 0 ] && [ -r /dev/tty ]; then
    exec ./install.sh < /dev/tty
fi
exec ./install.sh
