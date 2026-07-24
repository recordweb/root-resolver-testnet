# Track B – Produktivbetrieb: Hinweise & Checkliste

> Dieses Dokument beschreibt **keine** Code-Änderungen, sondern skizziert, was
> vor einem Produktivbetrieb des RWP Namespace-Registry Chaincodes zu erledigen ist.

## 1  Echte MSP-Identitäten

| Schritt | Massnahme |
|---------|-----------|
| CA-Infrastruktur | Jede Organisation betreibt eine eigene Fabric CA (oder nutzt ein HSM-gestütztes Root-CA-Zertifikat). `cryptogen` ist **nur** für Testnetze geeignet. |
| Admin-Zertifikate | Admins erhalten Zertifikate via `fabric-ca-client enroll`, nicht aus dem `crypto-config`-Ordner. |
| MSP-Konfigurationsdatei | `config.yaml` mit `NodeOUs` für feingranulare Attribut-basierte Policies. |
| Zertifikatserneuerung | Ablaufdaten planen; CRL-Distribution-Points dokumentieren. |

## 2  Verteilter Raft-Orderer

- Mindestens **3 Orderer-Nodes** (toleriert 1 Ausfall), empfohlen 5.
- Jeder Orderer in separater Availability-Zone / RZ.
- `configtx.yaml`: `Orderer.EtcdRaft.Consenters` Liste mit allen TLS-Zertifikaten befüllen.
- Snapshots und Block-Retention dimensionieren.

## 3  Channel-Konfiguration & Policies

- OR → **MAJORITY** sobald mehr als zwei Orgs teilnehmen.
- Lifecycle-Policy: `MAJORITY` empfohlen.

## 4  Beitrittsprozess neue Organisationen

1. Neue Org erstellt MSP-Materialien (CA-Cert, TLS-Cert).
2. Channel-Update-Transaktion via `configtxlator`, Mehrheits-Signatur bestehender Orgs.
3. Endorsement-Policy updaten: `approveformyorg` + `commit` mit erhöhter `--sequence`.
4. Neuer Peer: `peer channel fetch oldest` → `peer channel join`.
5. Governance-Dokument (`docs/governance.md`) führen.

## 5  Security-Härtung

- `UpdateResolverEndpoint`: `callerMSP`-Parameter durch `ctx.GetClientIdentity().GetMSPID()` ersetzen.
- **State-based Endorsement** pro Key für Schreibrechte nur beim Registrar.
- Private Data Collections für vertrauliche Endpunkte prüfen.
- Chaincode-Docker-Images auf SHA256 pinnen.

## 6  Monitoring

| Tool | Verwendung |
|------|-----------|
| Prometheus + Grafana | `endorser_proposals_received`, `ledger_transaction_count` |
| Hyperledger Explorer | Block- und Transaction-Browser |
| Alertmanager | Alarm bei Orderer-Leader-Wechsel |

## 7  Disaster Recovery

- Regelmässige Snapshots: CouchDB State-DB + `blockfiles`-Verzeichnis.
- `peer node reset` / `peer node rollback` dokumentieren.