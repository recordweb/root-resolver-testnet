#!/usr/bin/env bash
# Schritt 2: Genesis Block und Channel-Artefakte erzeugen
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_DIR="$SCRIPT_DIR/../network"
CHANNEL_NAME="root-resolver"

echo "==> Genesis Block erzeugen..."
docker run --rm \
  -e FABRIC_CFG_PATH=/config \
  -v "$NETWORK_DIR/configtx:/config" \
  -v "$NETWORK_DIR/crypto-config:/crypto-config" \
  -v "$NETWORK_DIR/channel-artifacts:/output" \
  hyperledger/fabric-tools:2.5 \
  configtxgen -profile RootResolverGenesis -channelID $CHANNEL_NAME -outputBlock /output/genesis.block

echo "✓ channel-artifacts/genesis.block erzeugt"