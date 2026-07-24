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