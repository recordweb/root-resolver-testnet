# Root-Resolver Admin-App

Eigenständige Admin-Webseite für die `namespace-registry`. Sie spricht den
Fabric-Peer **nicht** über die peer-CLI, sondern über das
`@hyperledger/fabric-gateway` Node.js SDK, und liefert ein schlankes Vanilla-
Frontend (Login + Dashboard) aus.

```
admin-app/
├── backend/            # Express-Server + Fabric-Gateway-Anbindung + REST-API
│   ├── Dockerfile      # eigenständiges Image (node:20-slim)
│   └── src/
└── frontend/           # statisches UI (HTML/CSS/JS, kein Build-Step)
```

Der Service ist bewusst **eigenständig** (eigenes Image/eigener Container),
kein Teil eines Fabric-Peer-Containers.

## Mit Docker Compose (empfohlen)

Der Service `admin-app` ist in `network/docker-compose.yml` definiert und tritt
demselben Docker-Netz `fabric_net` bei wie die Fabric-Container, damit der
Peer-Hostname `peer0.recordweb.org` per Docker-DNS auflösbar ist. Das
cryptogen-Material (`network/crypto-config`) wird read-only nach `/app/crypto`
gemountet.

```bash
cd network

# Nur die Admin-App bauen und starten (Fabric-Netz muss bereits laufen):
docker compose build admin-app
docker compose up -d admin-app

# Logs / Stop
docker compose logs -f admin-app
docker compose stop admin-app
```

Danach ist die UI unter <http://localhost:3000/> erreichbar
(Health-Check: <http://localhost:3000/api/health>).

> Hinweis: Der Build-Context ist `admin-app/` (nicht `admin-app/backend/`),
> damit `frontend/` mit ins Image kommt. Das Dockerfile liegt unter
> `backend/Dockerfile`.

## Lokal ohne Docker (Entwicklung)

Voraussetzung: Node ≥ 18. Das Fabric-Netz muss laufen und das Krypto-Material
unter `network/crypto-config/` erzeugt sein (siehe Repo-Root-README).

```bash
cd admin-app/backend
npm install
npm run start        # oder: npm run dev  (node --watch)
```

Die Defaults in `src/config.js` zeigen bereits auf das lokale Repo-Layout
(`network/crypto-config/...`, `peer0.recordweb.org:7051`). Für abweichende
Setups eine `.env` anlegen (Vorlage: `backend/.env.example`).

## Wichtige Umgebungsvariablen

| Variable | Zweck | Default (lokal) / Compose-Wert |
|---|---|---|
| `PORT` | HTTP-Port des Servers | `3000` |
| `PEER_ENDPOINT` | gRPC-Adresse des Peers | `peer0.recordweb.org:7051` |
| `PEER_HOST_ALIAS` | TLS-Servername (Zertifikats-CN) | `peer0.recordweb.org` |
| `MSP_ID` | MSP der signierenden Org | `RecordWebOrgMSP` |
| `PEER_TLS_CA_PATH` | TLS-CA des Peers | Compose: `/app/crypto/.../tls/ca.crt` |
| `CERT_PATH` | Admin-Zertifikat (signcert) | Compose: `/app/crypto/.../signcerts/Admin@recordweb.org-cert.pem` |
| `KEY_PATH` | Admin-Key (Datei oder keystore-Verzeichnis) | Compose: `/app/crypto/.../msp/keystore` |
| `CHANNEL_NAME` | Fabric-Channel | `root-resolver` |
| `CHAINCODE_NAME` | Chaincode-Name | `namespace-registry` |
| `FRONTEND_DIR` | Verzeichnis der statischen Assets | Compose: `/app/frontend` |
