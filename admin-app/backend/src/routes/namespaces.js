// =============================================================================
// routes/namespaces.js  –  REST-Endpunkte für die Namespace-Registry
// -----------------------------------------------------------------------------
//   GET    /api/namespaces                       -> alle Namespaces
//   GET    /api/namespaces/:namespace            -> ein Namespace
//   GET    /api/namespaces/:namespace/history    -> Änderungshistorie
//   POST   /api/namespaces                       -> neuen Namespace registrieren
//   PUT    /api/namespaces/:namespace            -> resolverEndpoint aktualisieren
// =============================================================================

import { Router } from 'express';
import {
  listNamespaces,
  resolveNamespace,
  getNamespaceHistory,
  registerNamespace,
  updateResolverEndpoint,
} from '../fabric/contract.js';

export const namespacesRouter = Router();

// Chaincode-Fehler (kommen als gRPC-Fehler mit Go-Fehlertext) auf HTTP-Codes
// abbilden. Der aussagekräftige Text steckt je nach Fehlerart in message oder
// in den gRPC-details.
function mapChaincodeError(err) {
  const parts = [err?.message ?? ''];
  for (const d of err?.details ?? []) {
    if (d?.message) parts.push(d.message);
  }
  const text = parts.join(' ').toLowerCase();

  if (text.includes('not found')) return 404;
  if (text.includes('already exists')) return 409;
  if (text.includes('is not the registrar')) return 403;
  return 500;
}

function sendError(res, err) {
  const status = mapChaincodeError(err);
  res.status(status).json({ error: err?.message ?? 'internal error' });
}

// GET /api/namespaces  – Liste aller Namespaces.
namespacesRouter.get('/', async (_req, res) => {
  try {
    res.json(await listNamespaces());
  } catch (err) {
    sendError(res, err);
  }
});

// GET /api/namespaces/:namespace  – einzelner Record.
namespacesRouter.get('/:namespace', async (req, res) => {
  try {
    res.json(await resolveNamespace(req.params.namespace));
  } catch (err) {
    sendError(res, err);
  }
});

// GET /api/namespaces/:namespace/history  – Versionshistorie.
namespacesRouter.get('/:namespace/history', async (req, res) => {
  try {
    res.json(await getNamespaceHistory(req.params.namespace));
  } catch (err) {
    sendError(res, err);
  }
});

// POST /api/namespaces  – neuen Namespace registrieren.
// Body: { namespace, resolverEndpoint, registeredBy, endorsedBy[] }
namespacesRouter.post('/', async (req, res) => {
  const { namespace, resolverEndpoint, registeredBy, endorsedBy } = req.body ?? {};

  if (!namespace || !resolverEndpoint || !registeredBy) {
    return res.status(400).json({
      error: 'namespace, resolverEndpoint und registeredBy sind erforderlich',
    });
  }
  if (endorsedBy !== undefined && !Array.isArray(endorsedBy)) {
    return res.status(400).json({ error: 'endorsedBy muss ein Array sein' });
  }

  try {
    await registerNamespace(namespace, resolverEndpoint, registeredBy, endorsedBy ?? []);
    res.status(201).json(await resolveNamespace(namespace));
  } catch (err) {
    sendError(res, err);
  }
});

// PUT /api/namespaces/:namespace  – resolverEndpoint aktualisieren.
// Body: { resolverEndpoint, callerMSP }
namespacesRouter.put('/:namespace', async (req, res) => {
  const { resolverEndpoint, callerMSP } = req.body ?? {};

  if (!resolverEndpoint || !callerMSP) {
    return res.status(400).json({
      error: 'resolverEndpoint und callerMSP sind erforderlich',
    });
  }

  try {
    await updateResolverEndpoint(req.params.namespace, resolverEndpoint, callerMSP);
    res.json(await resolveNamespace(req.params.namespace));
  } catch (err) {
    sendError(res, err);
  }
});
