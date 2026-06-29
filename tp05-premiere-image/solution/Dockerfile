# TP5 — Solution de référence
FROM nginx:1.30-alpine

LABEL maintainer="formation@telemach-learning.fr"

# Copie la landing page dans le répertoire servi par nginx
COPY site/ /usr/share/nginx/html/

# Documentation du port d'écoute
EXPOSE 80

# Bonus : vérification de santé intégrée à l'image
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost/ >/dev/null 2>&1 || exit 1
