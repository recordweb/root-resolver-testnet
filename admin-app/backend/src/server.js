// =============================================================================
// server.js  –  Express-Einstiegspunkt des Admin-Backends
// -----------------------------------------------------------------------------
// Stellt die REST-API bereit, liefert das (vorerst Platzhalter-) Frontend
// statisch aus und bietet unter /api/health einen einfachen Verbindungstest
// zum Fabric-Gateway.
// =============================================================================

import express from 'express';
import cors from 'cors';
import { config } from './config.js';
import { namespacesRouter } from './routes/namespaces.js';
import { listNamespaces } from './fabric/contract.js';
import { closeGateway } from './fabric/gatewayClient.js';

const app = express();

app.use(cors());
app.use(express.json());

// Namespace-REST-API.
app.use('/api/namespaces', namespacesRouter);

// Health-Check: versucht eine leichte Read-Transaktion (GetAllNamespaces).
// Gelingt sie, steht die Gateway-Verbindung zum Peer. Schlägt sie fehl,
// liefern wir 503 mit der Fehlerursache.
app.get('/api/health', async (_req, res) => {
  try {
    const namespaces = await listNamespaces();
    res.json({ status: 'ok', gateway: 'connected', namespaceCount: namespaces.length });
  } catch (err) {
    res.status(503).json({ status: 'error', gateway: 'unavailable', error: err?.message });
  }
});

// Statisches Frontend (Platzhalter – echtes UI folgt in späterem Schritt).
app.use(express.static(config.frontendDir));

const server = app.listen(config.port, () => {
  console.log(`Admin-Backend läuft auf http://localhost:${config.port}`);
  console.log(`  Channel:   ${config.channelName}`);
  console.log(`  Chaincode: ${config.chaincodeName}`);
  console.log(`  Peer:      ${config.peerEndpoint} (MSP ${config.mspId})`);
});

// Gateway-Verbindung bei Prozessende sauber schliessen.
function shutdown() {
  console.log('\nBeende Admin-Backend …');
  server.close(() => {
    closeGateway();
    process.exit(0);
  });
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
