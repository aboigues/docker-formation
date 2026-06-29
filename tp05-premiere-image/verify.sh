#!/usr/bin/env bash
# TP5 — vérifie que l'image construite sert bien la landing page.
# Lancé localement par le participant ET par la CI (sur solution/).
source "$(git rev-parse --show-toplevel)/scripts/lib.sh"

# Par défaut on teste la solution ; passez "starter" en argument pour tester le vôtre :
#   ./verify.sh starter
TARGET="${1:-solution}"
IMAGE="tp05-landing-${TARGET}:test"
NAME="tp05-verify-${TARGET}"
PORT=8081
HERE="$(cd "$(dirname "$0")" && pwd)"

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; docker rmi "$IMAGE" >/dev/null 2>&1 || true; }
trap cleanup EXIT

step "Construction de l'image ($TARGET)"
docker build -q -t "$IMAGE" "$HERE/$TARGET" >/dev/null

step "Lancement du conteneur sur le port $PORT"
docker run -d --name "$NAME" -p "$PORT:80" "$IMAGE" >/dev/null

wait_for_http "http://localhost:$PORT" 30 || { docker logs "$NAME"; exit 1; }

BODY="$(curl -fsS "http://localhost:$PORT")"
assert_contains "La page contient le nom du produit"      "Telemach Cloud" "$BODY"
assert_contains "La page contient l'argument 'Portable'"  "Portable"       "$BODY"
check          "Le conteneur est bien en cours d'exécution" \
  bash -c "docker ps --filter name=$NAME --filter status=running -q | grep -q ."

summary
