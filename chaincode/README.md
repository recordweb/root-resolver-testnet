# Chaincode — Namespace-Registrierung

> **Platzhalter** — wird im nächsten Chat entwickelt.

## Zukünftiger Inhalt

Der Chaincode implementiert die Namespace-Registry gemäss RWP-Konzept Abschnitt 5.

### Erwartete Verzeichnisstruktur
chaincode/
namespace-registry/
go.mod
go.sum
chaincode.go # SmartContract-Struct + Init
namespace.go # Datenstruktur NamespaceEntry
register.go # RegisterNamespace()
resolve.go # ResolveNamespace()
history.go # GetNamespaceHistory()


### Datenstruktur (aus Konzept Abschnitt 5)

```json
{
  "namespace": "a3f9e21c",
  "resolverEndpoint": "https://vps.recordweb.dev/resolver/parlament/1.0/identifiers",
  "registeredBy": "CH",
  "registeredAt": "2026-07-23T15:10:50Z",
  "txId": "a1b2c3d4...",
  "endorsedBy": ["CH", "RecordWeb.org"]
}
```

### Seed-Daten

Die bestehenden Namespaces aus dem PoC (`namespaces.json`) werden als erste
Transaktionen eingespielt. Seed-Script kommt unter `scripts/seed_namespaces.sh`.

### Endorsement Policy (Testnetz)

```
OR('RecordWebOrgMSP.peer', 'SwissGovOrgMSP.peer')
```

Im Produktivbetrieb: `MAJORITY Endorsement` über alle aktiven Organisationen.

```
docs/architecture.md
```

# Architektur: RWP Root-Resolver Testnetz

Bezug: RWP v0.1 Kapitel 12.2 | Konzept: `docs/root-resolver-fabric-concept.md`

## Übersicht

┌─────────────────────────────────────────────────────┐
│ Hyperledger Fabric Testnetz (Spur A)                │
│                                                     │
│ ┌──────────────┐ ┌──────────────┐                   │
│ │RecordWebOrg  │ │SwissGovOrg   │                   │
│ │peer0:7051    │ │peer0:9051    │                   │
│ └──────────────┘ └──────────────┘                   │
│                                                     │
│ ┌──────────────────────────────┐                    │
│ │ Orderer (Single-Node Raft)   │                    │
│ │ :7050 (gRPC) | :7053 (admin) │                    │
│ └──────────────────────────────┘                    │
│                                                     │
│ Channel: root-resolver                              │
│ Chaincode: namespace-registry (→ nächster Chat)     │
└─────────────────────────────────────────────────────┘


## Komponenten

| Komponente | Image | Port | Zweck |
|---|---|---|---|
| orderer.orderer.recordweb.dev | fabric-orderer:2.5 | 7050, 7053 | Blockproduktion (Raft) |
| peer0.recordweb.org | fabric-peer:2.5 | 7051 | RecordWeb.org Peer |
| peer0.swissgov.recordweb.dev | fabric-peer:2.5 | 9051 | SwissGov Peer |
| fabric-cli | fabric-tools:2.5 | — | Admin-CLI |

## Spur A vs. Spur B

- **Spur A (dieses Repo):** Lokales/VPS-Testnetz, `cryptogen`, Single-Orderer, Lernumgebung
- **Spur B (Folge-Schritt):** Produktiv, eigene MSP pro Org, verteilter Raft-Orderer,
  Beitrittsprozess für neue Organisationen

## Chaincode

→ Wird in separatem Chat entwickelt. Platzhalter: `chaincode/README.md`