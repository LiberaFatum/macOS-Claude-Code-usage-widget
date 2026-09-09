#!/bin/bash
# Sestaví "Claude Usage.app" do ./build. Xcode není potřeba, stačí Command Line Tools.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Claude Usage"
BUNDLE_ID="com.liberafatum.claude-usage-widget"
VERSION="1.0.0"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"

echo "==> Překlad (release)"
swift build -c release

echo "==> Sestavení bundlu"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/ClaudeUsage" "$APP/Contents/MacOS/ClaudeUsage"

echo "==> Vykreslení ikony"
ICONSET="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET"
if swiftc -O Tools/make-icon.swift Sources/ClaudeUsage/Mascot.swift -o "$BUILD_DIR/mkicon" >/dev/null 2>&1 \
   && "$BUILD_DIR/mkicon" "$ICONSET" >/dev/null 2>&1; then
    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns" || echo "    (převod na icns přeskočen)"
    rm -rf "$ICONSET" "$BUILD_DIR/mkicon"
else
    echo "    (vykreslení ikony přeskočeno)"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleExecutable</key><string>ClaudeUsage</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>MIT licensed</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

# Stálá identita drží otisk aplikace mezi překlady, takže povolení přístupu
# k tokenu v Keychainu nepropadne. Bez ní se podepisuje ad-hoc.
IDENTITY="Claude Usage Local"
# Identita je self-signed, takže ji "find-identity -p codesigning" nevypíše.
# Otisk se proto hledá v úplném seznamu a codesign se volá přes něj.
FINGERPRINT=$(security find-identity 2>/dev/null | grep "\"$IDENTITY\"" | head -1 | awk '{print $2}')
if [ -n "$FINGERPRINT" ]; then
    echo "==> Podpis identitou \"$IDENTITY\""
    codesign --force --deep --sign "$FINGERPRINT" "$APP"
else
    echo "==> Ad-hoc podpis"
    echo "    Pro stálý otisk spusť Tools/create-signing-identity.sh, jinak si systém"
    echo "    po každé aktualizaci znovu řekne o heslo ke svazku klíčů."
    codesign --force --deep --sign - "$APP" 2>/dev/null || echo "    (podpis přeskočen)"
fi

echo "==> Hotovo: $APP"
