#!/usr/bin/env bash
# =============================================================================
# 7_deploy_chaincode.sh  –  Namespace-Registry Chaincode Lifecycle (Fabric 2.5)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CC_SRC="${ROOT_DIR}/chaincode/namespace-registry"
CC_NAME="namespace-registry"
CC_VERSION="1.0"
CC_SEQUENCE=1
CHANNEL="root-resolver"
ORDERER_CA="${ROOT_DIR}/crypto-config/ordererOrganizations/recordweb.example.com/orderers/orderer.recordweb.example.com/msp/tlscacerts/tlsca.recordweb.example.com-cert.pem"
PEER0_RWORG_CA="${ROOT_DIR}/crypto-config/peerOrganizations/recordweborg.example.com/peers/peer0.recordweborg.example.com/tls/ca.crt"
PEER0_SWGOV_CA="${ROOT_DIR}/crypto-config/peerOrganizations/swissgovorg.example.com/peers/peer0.swissgovorg.example.com/tls/ca.crt"

export FABRIC_CFG_PATH="${ROOT_DIR}/config"
export CORE_PEER_TLS_ENABLED=true

log() { echo -e "\033[1;34m[DEPLOY]\033[0m $*"; }

# ── 1. Build Go vendor cache ──────────────────────────────────────────────────
log "Step 1/6  –  go mod vendor"
docker run --rm \
  -v "${CC_SRC}":/chaincode \
  -w /chaincode \
  golang:1.21-alpine \
  sh -c "go mod tidy && go mod vendor"

# ── 2. Package ────────────────────────────────────────────────────────────────
log "Step 2/6  –  peer lifecycle chaincode package"
docker run --rm \
  -v "${ROOT_DIR}":/opt/fabric \
  -w /opt/fabric \
  -e FABRIC_CFG_PATH=/opt/fabric/config \
  hyperledger/fabric-tools:2.5 \
  peer lifecycle chaincode package \
    /opt/fabric/"${CC_NAME}.tar.gz" \
    --path /opt/fabric/chaincode/namespace-registry \
    --lang golang \
    --label "${CC_NAME}_${CC_VERSION}"

# ── Helper: set peer env per org ──────────────────────────────────────────────
peer_env_rworg() {
  export CORE_PEER_LOCALMSPID="RecordWebOrgMSP"
  export CORE_PEER_ADDRESS="peer0.recordweborg.example.com:7051"
  export CORE_PEER_MSPCONFIGPATH="${ROOT_DIR}/crypto-config/peerOrganizations/recordweborg.example.com/users/Admin@recordweborg.example.com/msp"
  export CORE_PEER_TLS_ROOTCERT_FILE="${PEER0_RWORG_CA}"
}
peer_env_swgov() {
  export CORE_PEER_LOCALMSPID="SwissGovOrgMSP"
  export CORE_PEER_ADDRESS="peer0.swissgovorg.example.com:9051"
  export CORE_PEER_MSPCONFIGPATH="${ROOT_DIR}/crypto-config/peerOrganizations/swissgovorg.example.com/users/Admin@swissgovorg.example.com/msp"
  export CORE_PEER_TLS_ROOTCERT_FILE="${PEER0_SWGOV_CA}"
}

fabric_cmd() {
  # Pfade anpassen: Host-Pfad → Container-Pfad
  docker run --rm --network fabric_test \
    -v "${ROOT_DIR}":/opt/fabric \
    -e CORE_PEER_TLS_ENABLED=true \
    -e CORE_PEER_LOCALMSPID="${CORE_PEER_LOCALMSPID}" \
    -e CORE_PEER_ADDRESS="${CORE_PEER_ADDRESS}" \
    -e CORE_PEER_MSPCONFIGPATH="${CORE_PEER_MSPCONFIGPATH//${ROOT_DIR}//opt/fabric}" \
    -e CORE_PEER_TLS_ROOTCERT_FILE="${CORE_PEER_TLS_ROOTCERT_FILE//${ROOT_DIR}//opt/fabric}" \
    -e FABRIC_CFG_PATH=/opt/fabric/config \
    hyperledger/fabric-tools:2.5 "$@"
}

# ── 3. Install on RecordWebOrg ────────────────────────────────────────────────
log "Step 3/6  –  install on RecordWebOrgMSP peer"
peer_env_rworg
fabric_cmd peer lifecycle chaincode install /opt/fabric/"${CC_NAME}.tar.gz"

# ── 4. Install on SwissGovOrg ─────────────────────────────────────────────────
log "Step 4/6  –  install on SwissGovOrgMSP peer"
peer_env_swgov
fabric_cmd peer lifecycle chaincode install /opt/fabric/"${CC_NAME}.tar.gz"

# ── 5. Get Package ID ─────────────────────────────────────────────────────────
log "Step 5/6  –  query installed → extract package ID"
peer_env_rworg
PKG_ID=$(fabric_cmd peer lifecycle chaincode queryinstalled \
  --output json 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); \
      print([x['package_id'] for x in d['installed_chaincodes'] \
             if x['label']=='${CC_NAME}_${CC_VERSION}'][0])")
log "Package ID: ${PKG_ID}"

ENDORSEMENT_POLICY="OR('RecordWebOrgMSP.peer','SwissGovOrgMSP.peer')"

# ── 6a. approveformyorg – RecordWebOrg ───────────────────────────────────────
log "Step 6/6a –  approveformyorg (RecordWebOrgMSP)"
peer_env_rworg
fabric_cmd peer lifecycle chaincode approveformyorg \
  -o orderer.recordweb.example.com:7050 \
  --ordererTLSHostnameOverride orderer.recordweb.example.com \
  --tls --cafile /opt/fabric/crypto-config/ordererOrganizations/recordweb.example.com/orderers/orderer.recordweb.example.com/msp/tlscacerts/tlsca.recordweb.example.com-cert.pem \
  --channelID "${CHANNEL}" \
  --name "${CC_NAME}" \
  --version "${CC_VERSION}" \
  --package-id "${PKG_ID}" \
  --sequence "${CC_SEQUENCE}" \
  --signature-policy "${ENDORSEMENT_POLICY}"

# ── 6b. approveformyorg – SwissGovOrg ────────────────────────────────────────
log "Step 6/6b –  approveformyorg (SwissGovOrgMSP)"
peer_env_swgov
fabric_cmd peer lifecycle chaincode approveformyorg \
  -o orderer.recordweb.example.com:7050 \
  --ordererTLSHostnameOverride orderer.recordweb.example.com \
  --tls --cafile /opt/fabric/crypto-config/ordererOrganizations/recordweb.example.com/orderers/orderer.recordweb.example.com/msp/tlscacerts/tlsca.recordweb.example.com-cert.pem \
  --channelID "${CHANNEL}" \
  --name "${CC_NAME}" \
  --version "${CC_VERSION}" \
  --package-id "${PKG_ID}" \
  --sequence "${CC_SEQUENCE}" \
  --signature-policy "${ENDORSEMENT_POLICY}"

# ── 6c. checkcommitreadiness ──────────────────────────────────────────────────
log "Step 6/6c –  checkcommitreadiness"
peer_env_rworg
fabric_cmd peer lifecycle chaincode checkcommitreadiness \
  --channelID "${CHANNEL}" \
  --name "${CC_NAME}" \
  --version "${CC_VERSION}" \
  --sequence "${CC_SEQUENCE}" \
  --signature-policy "${ENDORSEMENT_POLICY}" \
  --output json

# ── 6d. commit ────────────────────────────────────────────────────────────────
log "Step 6/6d –  commit chaincode definition"
peer_env_rworg
fabric_cmd peer lifecycle chaincode commit \
  -o orderer.recordweb.example.com:7050 \
  --ordererTLSHostnameOverride orderer.recordweb.example.com \
  --tls --cafile /opt/fabric/crypto-config/ordererOrganizations/recordweb.example.com/orderers/orderer.recordweb.example.com/msp/tlscacerts/tlsca.recordweb.example.com-cert.pem \
  --channelID "${CHANNEL}" \
  --name "${CC_NAME}" \
  --version "${CC_VERSION}" \
  --sequence "${CC_SEQUENCE}" \
  --signature-policy "${ENDORSEMENT_POLICY}" \
  --peerAddresses peer0.recordweborg.example.com:7051 \
  --tlsRootCertFiles /opt/fabric/crypto-config/peerOrganizations/recordweborg.example.com/peers/peer0.recordweborg.example.com/tls/ca.crt \
  --peerAddresses peer0.swissgovorg.example.com:9051 \
  --tlsRootCertFiles /opt/fabric/crypto-config/peerOrganizations/swissgovorg.example.com/peers/peer0.swissgovorg.example.com/tls/ca.crt

log "✅  Chaincode ${CC_NAME} v${CC_VERSION} committed on channel ${CHANNEL}"