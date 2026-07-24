// =============================================================================
// contract.js  –  Typisierte Wrapper um die Chaincode-Funktionen
// -----------------------------------------------------------------------------
// Bildet die realen Go-Signaturen des Chaincodes "namespace-registry" 1:1 ab:
//
//   RegisterNamespace(namespace, resolverEndpoint, registeredBy, endorsedByJSON)
//   ResolveNamespace(namespace)                      -> NamespaceRecord
//   UpdateResolverEndpoint(namespace, newEndpoint, callerMSP)
//   GetNamespaceHistory(namespace)                   -> []HistoryEntry
//   GetAllNamespaces()                               -> []NamespaceRecord
//
// Regel: Lesen = evaluateTransaction (nur lokaler Query am Gateway-Peer, kein
// Ledger-Write), Schreiben = submitTransaction (Endorsement + Ordering +
// Commit). Rückgaben kommen als Bytes (Uint8Array) und werden zu JS-Objekten
// geparst.
// =============================================================================

import { getContract } from './gatewayClient.js';

const utf8 = new TextDecoder('utf-8');

// Bytes -> JS-Objekt. Leere Antworten (typisch bei Schreibfunktionen, deren
// Go-Signatur nur "error" zurückgibt) ergeben null.
function parseJson(bytes) {
  const text = utf8.decode(bytes).trim();
  if (text.length === 0) {
    return null;
  }
  return JSON.parse(text);
}

// ── Lesen ────────────────────────────────────────────────────────────────────

// GetAllNamespaces() -> Array aller NamespaceRecords.
export async function listNamespaces() {
  const bytes = await getContract().evaluateTransaction('GetAllNamespaces');
  return parseJson(bytes) ?? [];
}

// ResolveNamespace(namespace) -> einzelner NamespaceRecord.
export async function resolveNamespace(namespace) {
  const bytes = await getContract().evaluateTransaction('ResolveNamespace', namespace);
  return parseJson(bytes);
}

// GetNamespaceHistory(namespace) -> Array von HistoryEntry.
export async function getNamespaceHistory(namespace) {
  const bytes = await getContract().evaluateTransaction('GetNamespaceHistory', namespace);
  return parseJson(bytes) ?? [];
}

// ── Schreiben ──────────────────────────────────────────────────────────────

// RegisterNamespace(namespace, resolverEndpoint, registeredBy, endorsedByJSON).
// endorsedByArray (JS-Array) wird zum JSON-Array-String serialisiert, weil der
// Chaincode einen JSON-String erwartet, z.B. ["CH","RecordWeb.org"].
export async function registerNamespace(namespace, resolverEndpoint, registeredBy, endorsedByArray) {
  const endorsedByJson = JSON.stringify(endorsedByArray ?? []);
  await getContract().submitTransaction(
    'RegisterNamespace',
    namespace,
    resolverEndpoint,
    registeredBy,
    endorsedByJson,
  );
}

// UpdateResolverEndpoint(namespace, newEndpoint, callerMSP).
// callerMSP muss dem registeredBy des bestehenden Records entsprechen, sonst
// lehnt der Chaincode die Transaktion ab.
export async function updateResolverEndpoint(namespace, newEndpoint, callerMSP) {
  await getContract().submitTransaction(
    'UpdateResolverEndpoint',
    namespace,
    newEndpoint,
    callerMSP,
  );
}
