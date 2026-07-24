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

for ORG in recordweb.org swissgov.recordweb.dev; do
  ADMIN_SIGNCERT="${NETWORK_DIR}/crypto-config/peerOrganizations/${ORG}/users/Admin@${ORG}/msp/signcerts/Admin@${ORG}-cert.pem"
  ADMINCERTS_DIR="${NETWORK_DIR}/crypto-config/peerOrganizations/${ORG}/msp/admincerts"

  mkdir -p "${ADMINCERTS_DIR}"
  cp "${ADMIN_SIGNCERT}" "${ADMINCERTS_DIR}/"
  echo "  ✓ ${ORG}: Admin-Cert nach msp/admincerts kopiert"
done

echo "✓ Admin-Zertifikate erfolgreich propagiert"