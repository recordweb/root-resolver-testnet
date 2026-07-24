#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
NETWORK_DIR="${ROOT_DIR}/network"
CRYPTO_DIR="${NETWORK_DIR}/crypto-config"

CC_SRC="${ROOT_DIR}/chaincode/namespace-registry"
CC_NAME="namespace-registry"
CC_VERSION="1.0"
CC_SEQUENCE=1
CHANNEL="root-resolver"

DOCKER_NETWORK="network_fabric_net"

ORDERER_ADDR="orderer.orderer.recordweb.dev:7050"
ORDERER_HOST_OVERRIDE="orderer.orderer.recordweb.dev"
ORDERER_CA="${CRYPTO_DIR}/ordererOrganizations/orderer.recordweb.dev/orderers/orderer.orderer.recordweb.dev/msp/tlscacerts/tlsca.orderer.recordweb.dev-cert.pem"

PEER0_RWORG_ADDR="peer0.recordweb.org:7051"
PEER0_RWORG_CA="${CRYPTO_DIR}/peerOrganizations/recordweb.org/peers/peer0.recordweb.org/tls/ca.crt"
PEER0_RWORG_ADMIN_MSP="${CRYPTO_DIR}/peerOrganizations/recordweb.org/users/Admin@recordweb.org/msp"

PEER0_SWGOV_ADDR="peer0.swissgov.recordweb.dev:9051"
PEER0_SWGOV_CA="${CRYPTO_DIR}/peerOrganizations/swissgov.recordweb.dev/peers/peer0.swissgov.recordweb.dev/tls/ca.crt"
PEER0_SWGOV_ADMIN_MSP="${CRYPTO_DIR}/peerOrganizations/swissgov.recordweb.dev/users/Admin@swissgov.recordweb.dev/msp"

export CORE_PEER_TLS_ENABLED=true
export FABRIC_CFG_PATH="${NETWORK_DIR}/config"

log() { echo -e "\033[1;34m[DEPLOY]\033[0m $*"; }

peer_env_rworg() {
  export CORE_PEER_LOCALMSPID="RecordWebOrgMSP"
  export CORE_PEER_ADDRESS="${PEER0_RWORG_ADDR}"
  export CORE_PEER_MSPCONFIGPATH="${PEER0_RWORG_ADMIN_MSP}"
  export CORE_PEER_TLS_ROOTCERT_FILE="${PEER0_RWORG_CA}"
}

peer_env_swgov() {
  export CORE_PEER_LOCALMSPID="SwissGovOrgMSP"
  export CORE_PEER_ADDRESS="${PEER0_SWGOV_ADDR}"
  export CORE_PEER_MSPCONFIGPATH="${PEER0_SWGOV_ADMIN_MSP}"
  export CORE_PEER_TLS_ROOTCERT_FILE="${PEER0_SWGOV_CA}"
}

fabric_cmd() {
  docker run --rm --network "${DOCKER_NETWORK}" \
    -v "${ROOT_DIR}":/opt/fabric \
    -e CORE_PEER_TLS_ENABLED=true \
    -e CORE_PEER_LOCALMSPID="${CORE_PEER_LOCALMSPID}" \
    -e CORE_PEER_ADDRESS="${CORE_PEER_ADDRESS}" \
    -e CORE_PEER_MSPCONFIGPATH="${CORE_PEER_MSPCONFIGPATH//${ROOT_DIR}//opt/fabric}" \
    -e CORE_PEER_TLS_ROOTCERT_FILE="${CORE_PEER_TLS_ROOTCERT_FILE//${ROOT_DIR}//opt/fabric}" \
    -e FABRIC_CFG_PATH=/opt/fabric/network/config \
    -e FABRIC_LOGGING_SPEC=INFO \
    hyperledger/fabric-tools:2.5 "$@"
}

log "Step 1/6  –  go mod vendor"
docker run --rm \
  -v "${CC_SRC}":/chaincode \
  -w /chaincode \
  golang:1.21-alpine \
  sh -c "go mod tidy && go mod vendor"

log "Step 2/6  –  peer lifecycle chaincode package"
docker run --rm \
  -v "${ROOT_DIR}":/opt/fabric \
  -w /opt/fabric \
  -e FABRIC_CFG_PATH=/opt/fabric/network/config \
  hyperledger/fabric-tools:2.5 \
  peer lifecycle chaincode package \
    /opt/fabric/${CC_NAME}.tar.gz \
    --path /opt/fabric/chaincode/namespace-registry \
    --lang golang \
    --label "${CC_NAME}_${CC_VERSION}"

log "Package created: ${ROOT_DIR}/${CC_NAME}.tar.gz"

log "Step 3/6  –  install on RecordWebOrgMSP peer"
peer_env_rworg
fabric_cmd peer lifecycle chaincode install /opt/fabric/${CC_NAME}.tar.gz || \
  log "  (already installed – continuing)"

log "Step 4/6  –  install on SwissGovOrgMSP peer"
peer_env_swgov
fabric_cmd peer lifecycle chaincode install /opt/fabric/${CC_NAME}.tar.gz || \
  log "  (already installed – continuing)"
  
log "Step 5/6  –  query installed → extract package ID"
peer_env_rworg
PKG_ID=$(fabric_cmd peer lifecycle chaincode queryinstalled --output json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print([x['package_id'] for x in d['installed_chaincodes'] if x['label']=='${CC_NAME}_${CC_VERSION}'][0])")
log "Package ID: ${PKG_ID}"

ENDORSEMENT_POLICY="OR('RecordWebOrgMSP.peer','SwissGovOrgMSP.peer')"

log "Step 6/6a – approveformyorg (RecordWebOrgMSP)"
peer_env_rworg
fabric_cmd peer lifecycle chaincode approveformyorg \
  -o "${ORDERER_ADDR}" \
  --ordererTLSHostnameOverride "${ORDERER_HOST_OVERRIDE}" \
  --tls --cafile "/opt/fabric/network/crypto-config/ordererOrganizations/orderer.recordweb.dev/orderers/orderer.orderer.recordweb.dev/msp/tlscacerts/tlsca.orderer.recordweb.dev-cert.pem" \
  --channelID "${CHANNEL}" \
  --name "${CC_NAME}" \
  --version "${CC_VERSION}" \
  --package-id "${PKG_ID}" \
  --sequence "${CC_SEQUENCE}" \
  --signature-policy "${ENDORSEMENT_POLICY}"

log "Step 6/6b – approveformyorg (SwissGovOrgMSP)"
peer_env_swgov
fabric_cmd peer lifecycle chaincode approveformyorg \
  -o "${ORDERER_ADDR}" \
  --ordererTLSHostnameOverride "${ORDERER_HOST_OVERRIDE}" \
  --tls --cafile "/opt/fabric/network/crypto-config/ordererOrganizations/orderer.recordweb.dev/orderers/orderer.orderer.recordweb.dev/msp/tlscacerts/tlsca.orderer.recordweb.dev-cert.pem" \
  --channelID "${CHANNEL}" \
  --name "${CC_NAME}" \
  --version "${CC_VERSION}" \
  --package-id "${PKG_ID}" \
  --sequence "${CC_SEQUENCE}" \
  --signature-policy "${ENDORSEMENT_POLICY}"

log "Step 6/6c – checkcommitreadiness"
peer_env_rworg
fabric_cmd peer lifecycle chaincode checkcommitreadiness \
  --channelID "${CHANNEL}" \
  --name "${CC_NAME}" \
  --version "${CC_VERSION}" \
  --sequence "${CC_SEQUENCE}" \
  --signature-policy "${ENDORSEMENT_POLICY}" \
  --output json

log "Step 6/6d – commit chaincode definition"
peer_env_rworg
fabric_cmd peer lifecycle chaincode commit \
  -o "${ORDERER_ADDR}" \
  --ordererTLSHostnameOverride "${ORDERER_HOST_OVERRIDE}" \
  --tls --cafile "/opt/fabric/network/crypto-config/ordererOrganizations/orderer.recordweb.dev/orderers/orderer.orderer.recordweb.dev/msp/tlscacerts/tlsca.orderer.recordweb.dev-cert.pem" \
  --channelID "${CHANNEL}" \
  --name "${CC_NAME}" \
  --version "${CC_VERSION}" \
  --sequence "${CC_SEQUENCE}" \
  --signature-policy "${ENDORSEMENT_POLICY}" \
  --peerAddresses "${PEER0_RWORG_ADDR}" \
  --tlsRootCertFiles "/opt/fabric/network/crypto-config/peerOrganizations/recordweb.org/peers/peer0.recordweb.org/tls/ca.crt" \
  --peerAddresses "${PEER0_SWGOV_ADDR}" \
  --tlsRootCertFiles "/opt/fabric/network/crypto-config/peerOrganizations/swissgov.recordweb.dev/peers/peer0.swissgov.recordweb.dev/tls/ca.crt"

log "✅ Chaincode ${CC_NAME} v${CC_VERSION} committed on channel ${CHANNEL}"