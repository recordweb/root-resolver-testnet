#!/usr/bin/env bash
# Schritt 1: Kryptomaterial generieren mit cryptogen
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_DIR="$SCRIPT_DIR/../network"

echo "==> Kryptomaterial generieren..."
docker run --rm \
  -v "$NETWORK_DIR/configtx:/config" \
  -v "$NETWORK_DIR/crypto-config:/output" \
  hyperledger/fabric-tools:2.5 \
  cryptogen generate --config=/config/crypto-config.yaml --output=/output

echo "✓ crypto-config/ befüllt"

echo "==> Admin-Zertifikate in msp/admincerts kopieren..."

docker run --rm \
  -v "$NETWORK_DIR/crypto-config:/crypto" \
  alpine:3.20 sh -c '
for ORG in recordweb.org swissgov.recordweb.dev; do
  mkdir -p /crypto/peerOrganizations/${ORG}/msp/admincerts
  cp /crypto/peerOrganizations/${ORG}/users/Admin@${ORG}/msp/signcerts/Admin@${ORG}-cert.pem \
     /crypto/peerOrganizations/${ORG}/msp/admincerts/
  echo "  ✓ ${ORG}: Admin-Cert nach msp/admincerts kopiert"
done
'

echo "✓ Admin-Zertifikate erfolgreich propagiert"

echo "==> Leserechte für nicht-root-Consumer (z.B. admin-app als UID 1000) setzen..."
# cryptogen läuft im obigen Container als root, alle Dateien landen daher mit
# 600/Owner-root auf dem Host. Andere Container, die crypto-config read-only
# mounten und selbst NICHT als root laufen (z.B. admin-app -> USER node),
# koennten sonst weder TLS-CA-Zertifikate noch private Keys lesen (EACCES).
# Fuer dieses Testnetz ist weltweit lesbares Kryptomaterial akzeptabel; in
# einer echten Produktionsumgebung waere stattdessen eine gezielte
# Gruppenzuordnung (gleiche GID wie die Consumer-Container) vorzuziehen.
docker run --rm -v "$NETWORK_DIR/crypto-config:/crypto" alpine:3.20 sh -c '
  find /crypto -type d -exec chmod 755 {} \;
  find /crypto -type f -exec chmod 644 {} \;
'

echo "✓ Leserechte gesetzt (Verzeichnisse 755, Dateien 644)"