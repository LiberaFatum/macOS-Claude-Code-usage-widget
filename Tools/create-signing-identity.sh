#!/bin/bash
# Vytvoří lokální podpisovou identitu, aby měla aplikace stálý otisk.
#
# Bez ní se podepisuje ad-hoc a otisk se mění při každém překladu. Povolení
# "Povolit vždy" v Keychainu je na otisk navázané, takže by po každé aktualizaci
# propadlo a systém by si znovu řekl o heslo.
#
# Certifikát je jen tvůj a jen na tomhle stroji, nikam se neposílá.
# Odstranění: security delete-identity -c "Claude Usage Local"
set -euo pipefail

NAME="Claude Usage Local"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning | grep -q "$NAME"; then
    echo "Identita \"$NAME\" už existuje."
    exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "==> Generuji certifikát"
openssl req -x509 -newkey rsa:2048 -nodes -days 7300 \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
    -subj "/CN=$NAME" \
    -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null

openssl pkcs12 -export -out "$TMP/id.p12" \
    -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -passout pass: -name "$NAME" 2>/dev/null

echo "==> Vkládám do svazku klíčů \"přihlášení\""
security import "$TMP/id.p12" -k "$KEYCHAIN" -P "" -A -T /usr/bin/codesign

echo "==> Označuji jako důvěryhodný pro podepisování kódu"
echo "    (systém si teď řekne o heslo, je to jednorázové)"
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem"

if security find-identity -v -p codesigning | grep -q "$NAME"; then
    echo "Hotovo, identita \"$NAME\" je připravená."
else
    echo "Identita se nevytvořila, aplikace zůstane u ad-hoc podpisu." >&2
    exit 1
fi
