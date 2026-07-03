# TP6 — À COMPLÉTER. Remplacez chaque ______ (les # TODO).
# But : un Dockerfile complet pour l'appli Node « Telemach Cloud ».
# syntax=docker/dockerfile:1
FROM node:24-alpine

# TODO 1 — LABEL : ajoutez au moins le titre et le mainteneur de l'image.
#   Indice : LABEL org.opencontainers.image.title="..." org.opencontainers.image.authors="..."
______

# TODO 2 — ARG : déclarez APP_VERSION (variable de BUILD) avec une valeur par défaut.
______

# TODO 3 — ENV : exposez au RUNTIME NODE_ENV=production, PORT=3000,
#   et APP_VERSION reprenant la valeur de l'ARG ci-dessus.
______

# TODO 4 — WORKDIR : placez-vous dans /app.
______

# TODO 5 — Dépendances AVANT le code (pour le cache) :
#   copiez package.json, puis installez les dépendances de prod.
#   Indice : COPY package.json ./   puis   RUN npm install --omit=dev && npm cache clean --force
______
______

# TODO 6 — Copiez le code applicatif (server.js).
______

# TODO 7 — EXPOSE : documentez le port d'écoute (3000).
______

# TODO 8 — USER : passez sur l'utilisateur non-root fourni par l'image node.
______

# TODO 9 — HEALTHCHECK : interrogez http://localhost:3000/healthz.
#   Indice : HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
#              CMD wget -qO- http://localhost:3000/healthz >/dev/null 2>&1 || exit 1
______

# TODO 10 — ENTRYPOINT + CMD : exécutable « node », argument par défaut « server.js ».
______
______
