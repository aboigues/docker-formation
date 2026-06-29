#!/usr/bin/env bash
# Publiez une image dans le registre privé. Complétez les « TODO ».
set -euo pipefail

REG="localhost:5000"
USER="${REG_USER:-telescope}"
PASS="${REG_PASS:-registry_secret}"
SRC="alpine:3.23"
DEST="$REG/demo/alpine:1.0"

# TODO 1 : connectez-vous au registre (docker login) en lisant le mot de passe
#          sur l'entrée standard (--password-stdin), c'est la bonne pratique.
______

# TODO 2 : récupérez l'image source ($SRC), puis ré-étiquetez-la en $DEST.
______
______

# TODO 3 : poussez $DEST vers le registre.
______

echo "→ Contenu du registre :"
curl -fsS -u "$USER:$PASS" "http://$REG/v2/_catalog"; echo
