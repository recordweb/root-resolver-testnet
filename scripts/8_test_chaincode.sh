#!/usr/bin/env bash
# =============================================================================
# 8_test_chaincode.sh  –  Seed + functional test for namespace-registry
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
NETWORK_DIR="${ROOT_DIR}/network"
CRYPTO_DIR="${NETWORK_DIR}/crypto-config"

CC_NAME="namespace-registry"
CHANNEL="root-resolver"
DOCKER_NETWORK="fabric_net"

ORDERER_ADDR="orderer.orderer.recordweb.dev:7050"
ORDERER_HOST_OVERRIDE="orderer.orderer.recordweb.dev"
ORDERER_CA_CTR="/opt/fabric/network/crypto-config/ordererOrganizations/orderer.recordweb.dev/orderers/orderer.orderer.recordweb.dev/msp/tlscacerts/tlsca.orderer.recordweb.dev-cert.pem"

PEER0_RWORG_ADDR="peer0.recordweb.org:7051"
PEER0_RWORG_CA_CTR="/opt/fabric/network/crypto-config/peerOrganizations/recordweb.org/peers/peer0.recordweb.org/tls/ca.crt"
PEER0_RWORG_ADMIN_MSP="${CRYPTO_DIR}/peerOrganizations/recordweb.org/users/Admin@recordweb.org/msp"
PEER0_RWORG_CA_HOST="${CRYPTO_DIR}/peerOrganizations/recordweb.org/peers/peer0.recordweb.org/tls/ca.crt"

export FABRIC_CFG_PATH="${NETWORK_DIR}/config"
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="RecordWebOrgMSP"
export CORE_PEER_ADDRESS="${PEER0_RWORG_ADDR}"
export CORE_PEER_MSPCONFIGPATH="${PEER0_RWORG_ADMIN_MSP}"
export CORE_PEER_TLS_ROOTCERT_FILE="${PEER0_RWORG_CA_HOST}"

log()  { echo -e "\033[1;32m[TEST]\033[0m $*"; }
info() { echo -e "\033[0;36m      $*\033[0m"; }

fabric_invoke() {
  docker run --rm --network "${DOCKER_NETWORK}" \
    -v "${ROOT_DIR}":/opt/fabric \
    -e CORE_PEER_TLS_ENABLED=true \
    -e CORE_PEER_LOCALMSPID="${CORE_PEER_LOCALMSPID}" \
    -e CORE_PEER_ADDRESS="${CORE_PEER_ADDRESS}" \
    -e CORE_PEER_MSPCONFIGPATH="${CORE_PEER_MSPCONFIGPATH//${ROOT_DIR}//opt/fabric}" \
    -e CORE_PEER_TLS_ROOTCERT_FILE="${CORE_PEER_TLS_ROOTCERT_FILE//${ROOT_DIR}//opt/fabric}" \
    -e FABRIC_CFG_PATH=/opt/fabric/network/config \
    hyperledger/fabric-tools:2.5 \
    peer chaincode invoke \
      -o "${ORDERER_ADDR}" \
      --ordererTLSHostnameOverride "${ORDERER_HOST_OVERRIDE}" \
      --tls --cafile "${ORDERER_CA_CTR}" \
      -C "${CHANNEL}" -n "${CC_NAME}" \
      --peerAddresses "${PEER0_RWORG_ADDR}" \
      --tlsRootCertFiles "${PEER0_RWORG_CA_CTR}" \
      "$@"
}

fabric_query() {
  docker run --rm --network "${DOCKER_NETWORK}" \
    -v "${ROOT_DIR}":/opt/fabric \
    -e CORE_PEER_TLS_ENABLED=true \
    -e CORE_PEER_LOCALMSPID="${CORE_PEER_LOCALMSPID}" \
    -e CORE_PEER_ADDRESS="${CORE_PEER_ADDRESS}" \
    -e CORE_PEER_MSPCONFIGPATH="${CORE_PEER_MSPCONFIGPATH//${ROOT_DIR}//opt/fabric}" \
    -e CORE_PEER_TLS_ROOTCERT_FILE="${CORE_PEER_TLS_ROOTCERT_FILE//${ROOT_DIR}//opt/fabric}" \
    -e FABRIC_CFG_PATH=/opt/fabric/network/config \
    -e FABRIC_LOGGING_SPEC=INFO \
    hyperledger/fabric-tools:2.5 \
    peer chaincode query \
      -C "${CHANNEL}" -n "${CC_NAME}" \
      "$@"
}

# ── Seed: vier PoC-Namespaces ──────────────────────────────────────────────────
log "=== SEED: Registering four PoC namespaces ==="

declare -A NAMESPACES
NAMESPACES["a3f9e21c"]="https://vps.recordweb.dev/fragenmanagement/did"
NAMESPACES["b7d4c810"]="https://vps.recordweb.dev/antwortmanagement/did"
NAMESPACES["s73f42a3"]="https://vps.recordweb.dev/sox/did"
NAMESPACES["f2c81e05"]="https://resolver.recordweb.org/rwp/v1"
NAMESPACES["c6cdee0b"]="https://resolver.staatsarchiv.ch/rwp/v1"

for NS in "${!NAMESPACES[@]}"; do
  ENDPOINT="${NAMESPACES[$NS]}"
  log "  RegisterNamespace: ${NS}  →  ${ENDPOINT}"
  CTOR=$(python3 -c "
import json
endorsed = json.dumps(['CH','RecordWeb.org'])
args = ['RegisterNamespace', '${NS}', '${ENDPOINT}', 'CH', endorsed]
print(json.dumps({'function': args[0], 'Args': args[1:]}))
")
  fabric_invoke -c "${CTOR}"
  sleep 2
done

# ── Resolve ────────────────────────────────────────────────────────────────────
log ""
log "=== RESOLVE: querying each namespace ==="
for NS in "${!NAMESPACES[@]}"; do
  log "  ResolveNamespace: ${NS}"
  RESULT=$(fabric_query -c "{\"function\":\"ResolveNamespace\",\"Args\":[\"${NS}\"]}")
  info "${RESULT}"
done

# ── History ────────────────────────────────────────────────────────────────────
log ""
log "=== HISTORY: GetNamespaceHistory for a3f9e21c (original + update) ==="
RESULT=$(fabric_query -c '{"function":"GetNamespaceHistory","Args":["a3f9e21c"]}')
info "${RESULT}"

log ""
log "✅  All tests passed."