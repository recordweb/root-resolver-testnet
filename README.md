# RWP Root-Resolver — Fabric Testnetz (Spur A)

Hyperledger Fabric 2.5 Testnetz für die `did:rwp` Namespace-Registry.
Kontext: RWP Kapitel 12.2 | Konzept: `docs/root-resolver-fabric-concept.md`

> **Zweck:** Lernumgebung und Entwicklungsplattform für den Namespace-Registry-Chaincode.
> Kein Produktivbetrieb.

## Struktur
fabric-root-resolver/
├── network/
│ ├── configtx/
│ │ ├── crypto-config.yaml # Org-/Node-Definitionen für cryptogen
│ │ └── configtx.yaml # Channel- und Policy-Konfiguration
│ ├── docker-compose.yml # Fabric-Netzwerk (Orderer, Peers, CLI)
│ ├── crypto-config/ # generiert, nicht eingecheckt (.gitignore)
│ └── channel-artifacts/ # generiert, nicht eingecheckt (.gitignore)
├── scripts/
│ ├── 1_generate_crypto.sh # Kryptomaterial erzeugen
│ ├── 2_generate_channel_artifacts.sh # Genesis Block erzeugen
│ ├── 3_start_network.sh # Netzwerk starten
│ ├── 4_create_channel.sh # Channel erstellen + Peers joinen
│ ├── 5_verify_network.sh # Status prüfen
│ └── 6_stop_network.sh # Netzwerk stoppen
├── chaincode/
│ └── README.md # Platzhalter → nächster Chat
├── docs/
│ └── architecture.md
└── .github/workflows/deploy.yml


## Voraussetzungen

- Docker Engine ≥ 24 und Docker Compose Plugin
- Kein lokales `fabric-tools`-Binary nötig — alle Befehle laufen im
  `hyperledger/fabric-tools:2.5` Container

```bash
docker pull hyperledger/fabric-peer:2.5
docker pull hyperledger/fabric-orderer:2.5
docker pull hyperledger/fabric-tools:2.5
```

## Netzwerk von Null aufbauen

### Schritt 1 — Kryptomaterial generieren

```bash
bash scripts/1_generate_crypto.sh
```

Erzeugt `network/crypto-config/` mit MSPs und TLS-Zertifikaten für:
- `OrdererOrg` (orderer.orderer.recordweb.dev)
- `RecordWebOrg` (peer0.recordweb.org)
- `SwissGovOrg` (peer0.swissgov.recordweb.dev)

### Schritt 2 — Channel-Artefakte generieren

```bash
bash scripts/2_generate_channel_artifacts.sh
```

Erzeugt `network/channel-artifacts/genesis.block` für den Channel `root-resolver`.

### Schritt 3 — Netzwerk starten

```bash
bash scripts/3_start_network.sh
```

Startet Orderer, beide Peers und die CLI via Docker Compose.

### Schritt 4 — Channel erstellen und Peers joinen

```bash
bash scripts/4_create_channel.sh
```

Erstellt den Channel `root-resolver` via Channel Participation API (`osnadmin`)
und lässt beide Peers joinen.

### Schritt 5 — Status prüfen

```bash
bash scripts/5_verify_network.sh
```

Erwartete Ausgabe:
- Alle 4 Container laufen
- Beide Peers listen den Channel `root-resolver`
- Block Height: 1 (Genesis Block)

## Netzwerk stoppen

```bash
bash scripts/6_stop_network.sh
```

Löscht alle Container und Volumes. `crypto-config/` und `channel-artifacts/`
bleiben erhalten (Kommentar im Script entfernen zum Löschen).

## Orgs im Testnetz

| Org | MSP-ID | Peer | Port |
|---|---|---|---|
| RecordWebOrg | RecordWebOrgMSP | peer0.recordweb.org | 7051 |
| SwissGovOrg | SwissGovOrgMSP | peer0.swissgov.recordweb.dev | 9051 |
| OrdererOrg | OrdererMSP | orderer.orderer.recordweb.dev | 7050 |

## Nächster Schritt: Chaincode

→ Chaincode-Entwicklung, -Deploy und Namespace-Seed in separatem Chat.
Platzhalter und Datenstruktur: `chaincode/README.md`

## VPS-Deployment

GitHub Actions (`.github/workflows/deploy.yml`) deployed automatisch bei Push auf `main`.
Voraussetzung: Secrets `VPS_HOST`, `VPS_USER`, `VPS_SSH_KEY` in GitHub-Repository-Settings.
Repo-Pfad auf VPS: `/opt/fabric-root-resolver`

Beim ersten Deployment werden Kryptomaterial und Genesis Block automatisch erzeugt,
falls `network/crypto-config/` noch nicht existiert.
