// =============================================================================
// gatewayClient.js  –  Aufbau & Caching der Fabric-Gateway-Verbindung
// -----------------------------------------------------------------------------
// Fabric-Konzepte in Kürze (für DevOps-Leser, denen Docker/Node vertraut ist,
// Fabric aber neu):
//
//  • Peer        = ein Netzwerkknoten einer Organisation. Er hält eine Kopie
//                  des Ledgers und führt Chaincode (= Smart Contract) aus.
//  • Gateway     = ab Fabric 2.4 der empfohlene Client-Einstiegspunkt. Statt
//                  dass der Client selbst mit Ordering-Service und mehreren
//                  Peers spricht, redet er nur mit EINEM Gateway-Peer; dieser
//                  übernimmt Endorsement-Sammlung und Submit an den Orderer.
//  • Identity    = X.509-Zertifikat (wer bin ich) + MSP-ID (zu welcher Org).
//  • Signer      = der zugehörige private Schlüssel; signiert jede Transaktion
//                  lokal. Der Schlüssel verlässt diesen Prozess nie.
//  • mTLS        = die gRPC-Verbindung zum Peer ist TLS-gesichert; wir brauchen
//                  das TLS-CA-Zertifikat des Peers, um ihm zu vertrauen.
//
// Ablauf hier: gRPC-Kanal (TLS) -> Identity aus Zertifikat -> Signer aus
// Private Key -> connect() ergibt eine Gateway-Instanz. Die halten wir als
// Singleton, weil der TLS-Handshake + gRPC-Kanalaufbau teuer ist und über
// viele HTTP-Requests wiederverwendet werden soll.
// =============================================================================

import { readFileSync, statSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { connect, hash, signers } from '@hyperledger/fabric-gateway';
import * as grpc from '@grpc/grpc-js';
import { credentials } from '@grpc/grpc-js';
import * as crypto from 'node:crypto';
import { config } from '../config.js';

// Singleton-Handles, damit connect() nur einmal pro Prozess läuft.
let gateway;
let grpcClient;

// -----------------------------------------------------------------------------
// Hilfsfunktion: privaten Schlüssel laden.
// cryptogen legt den Key als einzelne Datei "priv_sk" in einem keystore-
// Verzeichnis ab. Wir erlauben sowohl einen direkten Dateipfad als auch ein
// Verzeichnis (dann: erste Datei darin).
// -----------------------------------------------------------------------------
function readPrivateKeyPem(keyPath) {
  const stat = statSync(keyPath);
  if (stat.isDirectory()) {
    const files = readdirSync(keyPath);
    if (files.length === 0) {
      throw new Error(`Keystore-Verzeichnis ist leer: ${keyPath}`);
    }
    return readFileSync(path.join(keyPath, files[0]));
  }
  return readFileSync(keyPath);
}

// -----------------------------------------------------------------------------
// Schritt 1: gRPC-Kanal zum Peer aufbauen (TLS).
// Wir laden das TLS-CA-Zertifikat des Peers und erzeugen daraus
// ChannelCredentials. Der "ssl_target_name_override" ist wichtig, wenn der
// tatsächliche Endpoint (z.B. localhost:7051 via Portmapping) nicht mit dem
// CN/SAN im Peer-Zertifikat (peer0.recordweb.org) übereinstimmt.
// -----------------------------------------------------------------------------
function newGrpcConnection() {
  const tlsRootCert = readFileSync(config.peerTlsCaPath);
  const tlsCredentials = credentials.createSsl(tlsRootCert);

  return new grpc.Client(config.peerEndpoint, tlsCredentials, {
    'grpc.ssl_target_name_override': config.peerHostAlias,
  });
}

// -----------------------------------------------------------------------------
// Schritt 2: Identity bauen (Zertifikat + MSP-ID).
// Die Identity sagt dem Peer, WER die Transaktion einreicht und zu welcher
// Organisation (MSP) diese Person gehört.
// -----------------------------------------------------------------------------
function newIdentity() {
  const credentialsPem = readFileSync(config.certPath);
  return { mspId: config.mspId, credentials: credentialsPem };
}

// -----------------------------------------------------------------------------
// Schritt 3: Signer bauen (privater Schlüssel).
// Der Signer signiert Transaktions-Payloads lokal per ECDSA. Der Schlüssel
// wird nur in den Speicher geladen und nie über das Netz gesendet.
// -----------------------------------------------------------------------------
function newSigner() {
  const privateKeyPem = readPrivateKeyPem(config.keyPath);
  const privateKey = crypto.createPrivateKey(privateKeyPem);
  return signers.newPrivateKeySigner(privateKey);
}

// -----------------------------------------------------------------------------
// Schritt 4: Gateway verbinden (einmalig) und cachen.
// connect() verknüpft gRPC-Kanal, Identity und Signer. Die Timeout-Defaults
// setzen wir konservativ, damit hängende Requests nicht ewig blockieren.
// -----------------------------------------------------------------------------
export function getGateway() {
  if (gateway) {
    return gateway;
  }

  grpcClient = newGrpcConnection();

  gateway = connect({
    client: grpcClient,
    identity: newIdentity(),
    signer: newSigner(),
    hash: hash.sha256,
    // Zeitlimits pro Interaktionstyp (in Millisekunden).
    evaluateOptions: () => ({ deadline: Date.now() + 5000 }),
    endorseOptions: () => ({ deadline: Date.now() + 15000 }),
    submitOptions: () => ({ deadline: Date.now() + 5000 }),
    commitStatusOptions: () => ({ deadline: Date.now() + 60000 }),
  });

  return gateway;
}

// -----------------------------------------------------------------------------
// Bequemer Zugriff auf den Chaincode:
// Gateway -> Network (= Channel) -> Contract (= Chaincode).
// -----------------------------------------------------------------------------
export function getContract() {
  const network = getGateway().getNetwork(config.channelName);
  return network.getContract(config.chaincodeName);
}

// -----------------------------------------------------------------------------
// Sauberes Herunterfahren: Gateway + gRPC-Kanal schliessen.
// -----------------------------------------------------------------------------
export function closeGateway() {
  gateway?.close();
  grpcClient?.close();
  gateway = undefined;
  grpcClient = undefined;
}
