#!/usr/bin/env bash
# TP2 — Solution de référence : diagnostic d'un conteneur.
# Usage : ./collect.sh <nom_conteneur>
set -euo pipefail

CONTAINER="${1:?Usage: ./collect.sh <nom_conteneur>}"

IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER")"

LOGS="$(docker logs "$CONTAINER" 2>&1 | wc -l | tr -d ' ')"

if docker top "$CONTAINER" 2>/dev/null | grep -q nginx; then
  WEB_RUNNING="yes"
else
  WEB_RUNNING="no"
fi

echo "IP=${IP}"
echo "LOGS=${LOGS}"
echo "WEB_RUNNING=${WEB_RUNNING}"
