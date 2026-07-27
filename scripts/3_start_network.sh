#!/usr/bin/env bash
# Schritt 3: Fabric-Netzwerk starten
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_DIR="$SCRIPT_DIR/../network"

echo "==> Netzwerk starten..."
cd "$NETWORK_DIR"
docker compose up -d --build

echo "==> Warte 5 Sekunden auf Node-Startup..."
sleep 5
docker compose ps
echo "✓ Netzwerk läuft"