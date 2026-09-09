#!/bin/bash
# Vytvoří lokální podpisovou identitu, aby měla aplikace stálý otisk.
#
# Bez ní se podepisuje ad-hoc a otisk se počítá z obsahu binárky, takže se mění
# při každém překladu. Povolení "Povolit vždy" v Keychainu je na otisk navázané,
# propadlo by tedy po každé aktualizaci a systém by si znovu řekl o heslo.
#
# S podepsanou aplikací se povolení váže na certifikát, který zůstává stejný.
# Certifikát je jen tvůj a jen na tomhle stroji, nikam se neposílá.
# Odstranění: security delete-identity -c "Claude Usage Local"
set -euo pipefail

NAME="Claude Usage Local"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity | grep -q "\"$NAME\""; then
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

# Prázdné heslo ani moderní šifry "security import" nepřijme, proto jednorázové
# náhodné heslo a staré algoritmy, kterým rozumí.
PW=$(openssl rand -hex 16)
openssl pkcs12 -export -out "$TMP/id.p12" \
    -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -passout "pass:$PW" -name "$NAME" \
    -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1

echo "==> Vkládám do svazku klíčů \"přihlášení\""
security import "$TMP/id.p12" -k "$KEYCHAIN" -P "$PW" -A -T /usr/bin/codesign

# Certifikát zůstává nedůvěryhodný pro systém, na podepisování to stačí a ušetří
# to jedno zadávání hesla. Gatekeeper stejně lokálně přeloženou aplikaci neřeší.
if security find-identity | grep -q "\"$NAME\""; then
    echo "Hotovo, identita \"$NAME\" je připravená."
else
    echo "Identita se nevytvořila, aplikace zůstane u ad-hoc podpisu." >&2
    exit 1
fi
