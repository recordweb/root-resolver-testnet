#!/usr/bin/env bash
# =============================================================================
# 0_full_reset.sh – Kompletter, konsistenter Reset + Deploy + optional Test
#
# Verwendung:
#   bash scripts/0_full_reset.sh          → Reset + Deploy
#   bash scripts/0_full_reset.sh --test   → Reset + Deploy + Test
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
NETWORK_DIR="${ROOT_DIR}/network"

RUN_TEST=false
if [[ "${1:-}" == "--test" ]]; then
  RUN_TEST=true
fi

log() { echo -e "\033[1;35m[RESET]\033[0m $*"; }

log "Step 0/8 – Netzwerk stoppen und Volumes entfernen"
docker compose -f "${NETWORK_DIR}/docker-compose.yml" down -v || true

log "Step 1/8 – Alte crypto-config & channel-artifacts entfernen (als root)"
docker run --rm -v "${ROOT_DIR}":/workspace alpine:3.20 \
  sh -c "rm -rf /workspace/network/crypto-config /workspace/network/channel-artifacts"

log "Step 2/8 – Kryptomaterial neu generieren"
bash "${SCRIPT_DIR}/1_generate_crypto.sh"

log "Step 3/8 – Admin-Zertifikate propagieren (als root, im selben Reset-Lauf)"
docker run --rm -v "${NETWORK_DIR}/crypto-config":/crypto alpine:3.20 sh -c '
for ORG in org.recordweb.dev swissgov.recordweb.dev; do
  mkdir -p /crypto/peerOrganizations/${ORG}/msp/admincerts
  cp /crypto/peerOrganizations/${ORG}/users/Admin@${ORG}/msp/signcerts/Admin@${ORG}-cert.pem \
     /crypto/peerOrganizations/${ORG}/msp/admincerts/
  echo "  ✓ ${ORG}: Admin-Cert propagiert"
done
'

log "Step 4/8 – Channel-Artefakte (Genesis Block) neu erzeugen"
bash "${SCRIPT_DIR}/2_generate_channel_artifacts.sh"

log "Step 5/8 – Netzwerk mit frischen Zertifikaten starten"
bash "${SCRIPT_DIR}/3_start_network.sh"

log "Step 6/8 – Channel erzeugen & Peers beitreten lassen"
bash "${SCRIPT_DIR}/4_create_channel.sh"

log "Step 7/8 – Netzwerk-Status verifizieren"
bash "${SCRIPT_DIR}/5_verify_network.sh"

log "Step 8/8 – Chaincode deployen"
bash "${SCRIPT_DIR}/7_deploy_chaincode.sh"

if [[ "${RUN_TEST}" == "true" ]]; then
  log "Zusatz – Funktionale Tests ausführen"
  bash "${SCRIPT_DIR}/8_test_chaincode.sh"
fi

log "✅ Kompletter Reset + Deploy${RUN_TEST:+ + Test} erfolgreich abgeschlossen"