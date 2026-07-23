#!/usr/bin/env bash
# Netzwerk stoppen und aufräumen
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_DIR="$SCRIPT_DIR/../network"

echo "==> Netzwerk stoppen..."
cd "$NETWORK_DIR"
docker compose down -v

echo "==> Generierte Artefakte löschen (optional, auskommentieren zum Behalten)..."
# rm -rf "$NETWORK_DIR/crypto-config"
# rm -rf "$NETWORK_DIR/channel-artifacts"

echo "✓ Netzwerk gestoppt"