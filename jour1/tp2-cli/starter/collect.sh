#!/usr/bin/env bash
# TP2 — Script de diagnostic d'un conteneur.
# Usage : ./collect.sh <nom_conteneur>
# Doit afficher exactement 3 lignes : IP=... / LOGS=... / WEB_RUNNING=yes|no
set -euo pipefail

CONTAINER="${1:?Usage: ./collect.sh <nom_conteneur>}"

# TODO 1 : récupérer l'IP interne du conteneur sur son réseau.
#   Indice : docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER"
IP="______"

# TODO 2 : compter le nombre de lignes de logs.
#   Indice : docker logs "$CONTAINER" 2>&1 | wc -l   (pensez à enlever les espaces avec tr -d ' ')
LOGS="______"

# TODO 3 : déterminer si un process web (nginx) tourne dans le conteneur → "yes" ou "no".
#   Indice : docker top "$CONTAINER" | grep -q nginx
WEB_RUNNING="______"

echo "IP=${IP}"
echo "LOGS=${LOGS}"
echo "WEB_RUNNING=${WEB_RUNNING}"
