#!/usr/bin/env bash
# Schritt 4: Channel erstellen und Peers joinen
# Verwendet osnadmin (Fabric 2.5 Channel Participation API)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_DIR="$SCRIPT_DIR/../network"
CHANNEL_NAME="root-resolver"

echo "==> Channel '$CHANNEL_NAME' via osnadmin erstellen..."
docker exec fabric-cli osnadmin channel join \
  --channelID $CHANNEL_NAME \
  --config-block /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/genesis.block \
  -o orderer.orderer.recordweb.dev:7053 \
  --ca-file     /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/orderer.recordweb.dev/tlsca/tlsca.orderer.recordweb.dev-cert.pem \
  --client-cert /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/orderer.recordweb.dev/users/Admin@orderer.recordweb.dev/tls/client.crt \
  --client-key  /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/orderer.recordweb.dev/users/Admin@orderer.recordweb.dev/tls/client.key

echo "✓ Orderer joint den Channel"

echo "==> peer0.org.recordweb.dev joint den Channel..."
docker exec fabric-cli peer channel join \
  -b /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/genesis.block

echo "==> peer0.swissgov.recordweb.dev joint den Channel..."
docker exec \
  -e CORE_PEER_ADDRESS=peer0.swissgov.recordweb.dev:9051 \
  -e CORE_PEER_LOCALMSPID=SwissGovOrgMSP \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/swissgov.recordweb.dev/peers/peer0.swissgov.recordweb.dev/tls/ca.crt \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/swissgov.recordweb.dev/users/Admin@swissgov.recordweb.dev/msp \
  fabric-cli peer channel join \
  -b /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/genesis.block

echo "✓ Alle Peers sind im Channel"