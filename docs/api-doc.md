# API-Dokumentation: namespace-registry Chaincode

Chaincode wird nicht über eine klassische REST-API, sondern über den `peer chaincode invoke/query`-Mechanismus von Hyperledger Fabric angesprochen. Für eine spätere Web-Anwendung braucht es daher eine dünne API-Schicht (Node.js mit dem Fabric Gateway SDK), die diese Aufrufe kapselt.

## Funktionen (basierend auf Tests)

| Funktion | Typ | Parameter | Rückgabe |
|---|---|---|---|
| RegisterNamespace | Invoke (schreibend) | namespace, resolverEndpoint | Transaktions-Bestätigung |
| ResolveNamespace | Query (lesend) | namespace | JSON-Record (namespace, resolverEndpoint, registeredBy, registeredAt, txId, endorsedBy) |
| UpdateNamespace (vermutlich, da Update in Test genutzt) | Invoke (schreibend) | namespace, neuer resolverEndpoint | Transaktions-Bestätigung |
| GetNamespaceHistory | Query (lesend) | namespace | Array aller Versionen (chronologisch, inkl. txId, timestamp, isDelete) |

## Beispiel-Record-Struktur

```json
{
  "namespace": "a3f9e21c",
  "resolverEndpoint": "https://resolver.bundesarchiv.admin.ch/rwp/v1",
  "registeredBy": "CH",
  "registeredAt": "2026-07-24T18:14:19Z",
  "txId": "6a4232b91e...",
  "endorsedBy": ["CH", "RecordWeb.org"]
}
```

## Zugriffsweg für eine spätere Anwendung

Die gängige, empfohlene Methode ist das **Fabric Gateway Node.js SDK** (`@hyperledger/fabric-gateway`), das eine einfache API zum Submitten von Transaktionen und Abfragen des Ledgers bereitstellt, ohne dass die `peer`-CLI direkt aufgerufen werden muss.

