#!/usr/bin/env bash
# Schritt 5: Netzwerk-Status prüfen
set -euo pipefail

CHANNEL_NAME="root-resolver"

echo "==> Laufende Container:"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo ""
echo "==> Channel-Info (peer0.org.recordweb.dev):"
docker exec fabric-cli peer channel getinfo -c $CHANNEL_NAME

echo ""
echo "==> Channel-Liste (peer0.org.recordweb.dev):"
docker exec fabric-cli peer channel list

echo ""
echo "==> Channel-Info (peer0.swissgov.recordweb.dev):"
docker exec \
  -e CORE_PEER_ADDRESS=peer0.swissgov.recordweb.dev:9051 \
  -e CORE_PEER_LOCALMSPID=SwissGovOrgMSP \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/swissgov.recordweb.dev/peers/peer0.swissgov.recordweb.dev/tls/ca.crt \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/swissgov.recordweb.dev/users/Admin@swissgov.recordweb.dev/msp \
  fabric-cli peer channel list

echo "✓ Netzwerk-Status geprüft"