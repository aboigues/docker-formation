#!/usr/bin/env bash
# Chaîne de livraison du TP14 : BUILD -> SCAN -> PUSH.
# Une image refusée au scan n'est JAMAIS poussée dans le registre.
#
# Usage : ./ship.sh <shop-api|loadgen> <version>      ex. ./ship.sh shop-api 1.0.0
set -euo pipefail

COMP="${1:?usage : ./ship.sh <shop-api|loadgen> <version>}"
VERSION="${2:?usage : ./ship.sh <shop-api|loadgen> <version>}"
REGISTRY="${REGISTRY:-localhost:5000}"
TRIVY_IMAGE="aquasec/trivy:0.75.0"
HERE="$(cd "$(dirname "$0")" && pwd)"

case "$COMP" in
  shop-api) DOCKERFILE="$HERE/Dockerfile";         CONTEXT="$HERE/../app" ;;
  loadgen)  DOCKERFILE="$HERE/../loadgen/Dockerfile"; CONTEXT="$HERE/../loadgen" ;;
  *) echo "composant inconnu : $COMP (shop-api ou loadgen)"; exit 2 ;;
esac
if [ "$VERSION" = "latest" ]; then
  echo "❌ « latest » n'est pas une version : donnez un numéro (ex. 1.0.0)."; exit 2
fi
REF="$REGISTRY/telemach/$COMP:$VERSION"

echo "▶ BUILD  $REF"
docker build --build-arg VERSION="$VERSION" -f "$DOCKERFILE" -t "$REF" "$CONTEXT"
docker image ls "$REF" --format '  taille : {{.Size}}'

echo "▶ SCAN   (Trivy : on refuse toute faille HIGH ou CRITICAL)"
# Trivy tourne en conteneur et lit l'image via le socket Docker (cf. TP13).
# Le volume « tp14-trivy-cache » évite de retélécharger la base de failles à chaque scan.
if ! docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v tp14-trivy-cache:/root/.cache/ \
      "$TRIVY_IMAGE" image --quiet --no-progress \
      --severity HIGH,CRITICAL --exit-code 1 "$REF"; then
  echo "❌ Image REFUSÉE par le scan : rien n'a été poussé."
  exit 1
fi
echo "  ✓ aucune faille HIGH/CRITICAL"

echo "▶ PUSH   $REF"
docker push "$REF"
echo "✅ $REF est disponible dans le registre."
