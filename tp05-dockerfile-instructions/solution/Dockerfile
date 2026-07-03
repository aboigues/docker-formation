# TP6 — Solution de référence.
# Objectif : un Dockerfile « complet » qui exerce les instructions courantes.
# syntax=docker/dockerfile:1
FROM node:24-alpine

# --- LABEL : métadonnées de l'image (qui maintient, version, provenance) ---
LABEL org.opencontainers.image.title="Telemach Cloud — portail interne" \
      org.opencontainers.image.authors="formation@telemach-learning.fr" \
      org.opencontainers.image.source="https://github.com/aboigues/docker-formation"

# --- ARG : variable disponible UNIQUEMENT pendant le build
#     (ex. numéro de version fourni par la CI). Valeur par défaut si non fournie. ---
ARG APP_VERSION=0.0.0-dev

# --- ENV : variables disponibles AU RUNTIME, dans le conteneur.
#     On « fige » la version du build dans une variable d'environnement. ---
ENV NODE_ENV=production \
    PORT=3000 \
    APP_VERSION=$APP_VERSION

# --- WORKDIR : crée /app et s'y place. Toutes les instructions suivantes
#     (COPY, RUN, CMD…) partent de ce répertoire. ---
WORKDIR /app

# --- Ordre des couches = cache. Les dépendances changent rarement → on les
#     installe AVANT de copier le code. Tant que package.json est identique,
#     Docker réutilise ce layer (le plus lent) au lieu de tout réinstaller. ---
COPY package.json ./
RUN npm install --omit=dev && npm cache clean --force

# --- Le code applicatif change souvent → copié APRÈS les dépendances. ---
COPY server.js ./

# --- EXPOSE : documente le port d'écoute. Purement déclaratif
#     (ne publie rien : la publication se fait au `docker run -p`). ---
EXPOSE 3000

# --- USER : on abandonne root. L'image node fournit déjà un utilisateur
#     non privilégié nommé « node ». Principe du moindre privilège. ---
USER node

# --- HEALTHCHECK : Docker sonde lui-même la santé du conteneur.
#     L'état (healthy/unhealthy) devient visible dans `docker ps`. ---
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/healthz >/dev/null 2>&1 || exit 1

# --- ENTRYPOINT + CMD : l'exécutable fixe (`node`) et son argument par défaut
#     (`server.js`). On peut surcharger l'argument au `docker run` sans réécrire
#     la commande complète (ex. `docker run … --version`). ---
ENTRYPOINT ["node"]
CMD ["server.js"]
