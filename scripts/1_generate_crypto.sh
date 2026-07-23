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