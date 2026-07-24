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
DOCKER_NETWORK="network_default"

ORDERER_CA_CTR="/opt/fabric/network/crypto-config/ordererOrganizations/recordweb.example.com/orderers/orderer.recordweb.example.com/msp/tlscacerts/tlsca.recordweb.example.com-cert.pem"
PEER0_RWORG_CA_CTR="/opt/fabric/network/crypto-config/peerOrganizations/recordweborg.example.com/peers/peer0.recordweborg.example.com/tls/ca.crt"

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="RecordWebOrgMSP"
export CORE_PEER_ADDRESS="peer0.recordweborg.example.com:7051"
export CORE_PEER_MSPCONFIGPATH="${CRYPTO_DIR}/peerOrganizations/recordweborg.example.com/users/Admin@recordweborg.example.com/msp"
export CORE_PEER_TLS_ROOTCERT_FILE="${CRYPTO_DIR}/peerOrganizations/recordweborg.example.com/peers/peer0.recordweborg.example.com/tls/ca.crt"

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
      -o orderer.recordweb.example.com:7050 \
      --ordererTLSHostnameOverride orderer.recordweb.example.com \
      --tls --cafile "${ORDERER_CA_CTR}" \
      -C "${CHANNEL}" -n "${CC_NAME}" \
      --peerAddresses peer0.recordweborg.example.com:7051 \
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
    hyperledger/fabric-tools:2.5 \
    peer chaincode query \
      -C "${CHANNEL}" -n "${CC_NAME}" \
      "$@"
}

# ── Seed: vier PoC-Namespaces ─────────────────────────────────────────────────────
log "=== SEED: Registering four PoC namespaces ==="
ENDORSED='["CH","RecordWeb.org"]'

declare -A NAMESPACES
NAMESPACES["a3f9e21c"]="https://resolver.bundesarchiv.admin.ch/rwp/v1"
NAMESPACES["b7d4c810"]="https://resolver.parlament.ch/rwp/v1"
NAMESPACES["f2c81e05"]="https://resolver.recordweb.org/rwp/v1"
NAMESPACES["c6cdee0b"]="https://resolver.staatsarchiv.ch/rwp/v1"

for NS in "${!NAMESPACES[@]}"; do
  ENDPOINT="${NAMESPACES[$NS]}"
  log "  RegisterNamespace: ${NS}  →  ${ENDPOINT}"
  fabric_invoke \
    -c "{\"function\":\"RegisterNamespace\",\"Args\":[\"${NS}\",\"${ENDPOINT}\",\"CH\",${ENDORSED}]}"
  sleep 2
done

# ── Resolve ──────────────────────────────────────────────────────────────────────
log ""
log "=== RESOLVE: querying each namespace ==="
for NS in "${!NAMESPACES[@]}"; do
  log "  ResolveNamespace: ${NS}"
  RESULT=$(fabric_query -c "{\"function\":\"ResolveNamespace\",\"Args\":[\"${NS}\"]}")
  info "${RESULT}"
done

# ── Update ───────────────────────────────────────────────────────────────────────
log ""
log "=== UPDATE: change endpoint of a3f9e21c ==="
fabric_invoke \
  -c '{"function":"UpdateResolverEndpoint","Args":["a3f9e21c","https://resolver.v2.bundesarchiv.admin.ch/rwp/v2","CH"]}'
sleep 2

# ── History ─────────────────────────────────────────────────────────────────────
log ""
log "=== HISTORY: GetNamespaceHistory for a3f9e21c (original + update) ==="
RESULT=$(fabric_query -c '{"function":"GetNamespaceHistory","Args":["a3f9e21c"]}')
info "${RESULT}"

log ""
log "✅  All tests passed."
