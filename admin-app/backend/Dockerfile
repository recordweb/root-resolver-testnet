# Admin-App Backend – eigenständiges Image (Express + Fabric Gateway).
# WICHTIG: Der Build-Context ist admin-app/ (nicht admin-app/backend/), damit
# sowohl backend/ als auch das Sibling-Verzeichnis frontend/ ins Image kopiert
# werden können. In docker-compose entsprechend:
#   build: { context: ../admin-app, dockerfile: backend/Dockerfile }
#
# Kein Build-Step nötig (reines JS), daher Single-Stage. node:20-slim passt zur
# engines-Angabe (>=18) in backend/package.json.
FROM node:20-slim

ENV NODE_ENV=production
WORKDIR /app

# Nur Manifeste zuerst kopieren -> Layer-Cache für npm ci bleibt erhalten,
# solange sich package*.json nicht ändert.
COPY backend/package*.json ./
RUN npm ci --omit=dev

# Backend-Quellcode und Frontend (statische Assets) ins Image.
COPY backend/src ./src
COPY frontend ./frontend

# Nicht als root laufen (der node-User existiert im offiziellen Image).
USER node

EXPOSE 3000

CMD ["node", "src/server.js"]
