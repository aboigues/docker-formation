#!/usr/bin/env bash
# Publie une image dans le registre privé : login -> tag -> push, puis vérifie le catalogue.
set -euo pipefail

REG="localhost:5000"
USER="${REG_USER:-telescope}"
PASS="${REG_PASS:-registry_secret}"
SRC="alpine:3.23"
DEST="$REG/demo/alpine:1.0"

echo "→ Connexion au registre $REG"
echo "$PASS" | docker login "$REG" -u "$USER" --password-stdin

echo "→ Récupération de l'image source puis ré-étiquetage vers le registre privé"
docker pull "$SRC"
docker tag "$SRC" "$DEST"

echo "→ Push"
docker push "$DEST"

echo "→ Contenu du registre :"
curl -fsS -u "$USER:$PASS" "http://$REG/v2/_catalog"
echo
