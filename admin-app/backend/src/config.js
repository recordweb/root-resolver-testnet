// =============================================================================
// config.js  –  Zentrale Konfiguration des Admin-Backends
// -----------------------------------------------------------------------------
// Alle Werte kommen aus Umgebungsvariablen (12-Factor-Style). Die Defaults sind
// exakt auf das Testnetz in diesem Repo abgestimmt (network/docker-compose.yml
// + scripts/7_deploy_chaincode.sh), damit das Backend ohne .env lokal gegen den
// RecordWebOrg-Peer läuft. Im Docker-Betrieb (späterer Schritt) werden die
// Pfade/Endpoints per Environment überschrieben.
// =============================================================================

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';

dotenv.config();

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Repo-Root relativ zu dieser Datei: admin-app/backend/src -> ../../../
const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');

// Basisverzeichnis des von cryptogen erzeugten Kryptomaterials.
// (network/crypto-config/ ist .gitignore't und wird lokal/auf dem VPS erzeugt.)
const CRYPTO_ROOT = path.join(REPO_ROOT, 'network', 'crypto-config');

// Admin-Identity + Peer-TLS von RecordWebOrg (peer0.recordweb.org).
const RWORG = path.join(CRYPTO_ROOT, 'peerOrganizations', 'recordweb.org');

const env = (key, fallback) => process.env[key] ?? fallback;

export const config = {
  // ── Fabric-Netzwerk-Koordinaten ──────────────────────────────────────────
  channelName: env('CHANNEL_NAME', 'root-resolver'),
  chaincodeName: env('CHAINCODE_NAME', 'namespace-registry'),

  // gRPC-Endpoint des Peers. Im fabric_net-Docker-Netz ist der Container-Name
  // (peer0.recordweb.org) auflösbar; für lokalen Zugriff via Portmapping ggf.
  // auf localhost:7051 setzen (dann PEER_HOST_ALIAS beibehalten!).
  peerEndpoint: env('PEER_ENDPOINT', 'peer0.recordweb.org:7051'),

  // TLS-Servername, gegen den das Peer-Zertifikat validiert wird. Muss dem
  // CN/SAN im Peer-Zertifikat entsprechen (hier der Container-Hostname),
  // auch wenn peerEndpoint auf localhost zeigt (SSH-Tunnel/Portmapping).
  peerHostAlias: env('PEER_HOST_ALIAS', 'peer0.recordweb.org'),

  // MSP-ID der Organisation, in deren Namen wir signieren.
  mspId: env('MSP_ID', 'RecordWebOrgMSP'),

  // ── Pfade zum Kryptomaterial ─────────────────────────────────────────────
  // TLS-CA-Zertifikat des Peers (zum Aufbau der TLS-Verbindung).
  peerTlsCaPath: env(
    'PEER_TLS_CA_PATH',
    path.join(RWORG, 'peers', 'peer0.recordweb.org', 'tls', 'ca.crt'),
  ),

  // X.509-Zertifikat der Admin-Identity (signcert).
  certPath: env(
    'CERT_PATH',
    path.join(
      RWORG,
      'users',
      'Admin@recordweb.org',
      'msp',
      'signcerts',
      'Admin@recordweb.org-cert.pem',
    ),
  ),

  // Privater Schlüssel der Admin-Identity. Default zeigt auf das keystore-
  // Verzeichnis; gatewayClient nimmt bei einem Verzeichnis die erste Datei
  // (cryptogen legt den Key als "priv_sk" ab). Ein direkter Dateipfad wird
  // ebenfalls akzeptiert.
  keyPath: env(
    'KEY_PATH',
    path.join(RWORG, 'users', 'Admin@recordweb.org', 'msp', 'keystore'),
  ),

  // ── HTTP-Server ────────────────────────────────────────────────────────────
  port: Number(env('PORT', '3000')),

  // Statisch ausgeliefertes Frontend-Verzeichnis (Platzhalter für jetzt).
  frontendDir: path.join(REPO_ROOT, 'admin-app', 'frontend'),
};
