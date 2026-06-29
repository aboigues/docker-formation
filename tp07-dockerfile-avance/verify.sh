#!/usr/bin/env bash
# TP7 — vérifie l'image multi-stage : l'API répond ET l'image est légère.
# Lancé localement par le participant ET par la CI (sur solution/).
source "$(git rev-parse --show-toplevel)/scripts/lib.sh"

# Par défaut on teste la solution ; passez "starter" pour tester le vôtre :
#   ./verify.sh starter
TARGET="${1:-solution}"
IMAGE="tp07-api-${TARGET}:test"
NAME="tp07-verify-${TARGET}"
PORT=8088
VERSION="tp07-1.0"
HERE="$(cd "$(dirname "$0")" && pwd)"

# Au-dessus de ce seuil, c'est que la toolchain de build a fui dans l'image
# finale (multi-stage raté). Une image scratch + binaire Go tient sous ~20 Mo.
MAX_BYTES=$((25 * 1000 * 1000))   # 25 Mo

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; docker rmi "$IMAGE" >/dev/null 2>&1 || true; }
trap cleanup EXIT

step "Construction de l'image ($TARGET)"
docker build -q --build-arg VERSION="$VERSION" -t "$IMAGE" "$HERE/$TARGET" >/dev/null

step "Lancement du conteneur sur le port $PORT"
docker run -d --name "$NAME" -p "$PORT:8080" "$IMAGE" >/dev/null

wait_for_http "http://localhost:$PORT/healthz" 30 || { docker logs "$NAME"; exit 1; }

BODY="$(curl -fsS "http://localhost:$PORT/")"
assert_contains "La page d'accueil contient le nom du produit" "Telemach Cloud" "$BODY"

VER="$(curl -fsS "http://localhost:$PORT/version")"
assert_contains "La version injectée au build est présente dans le binaire" "$VERSION" "$VER"

check "Le conteneur est bien en cours d'exécution" \
  bash -c "docker ps --filter name=$NAME --filter status=running -q | grep -q ."

SIZE="$(docker image inspect "$IMAGE" -f '{{.Size}}')"
step "Taille de l'image : $((SIZE / 1000 / 1000)) Mo (multi-stage réussi si < $((MAX_BYTES / 1000 / 1000)) Mo)"
check "L'image finale est légère (multi-stage : la toolchain n'a pas fui)" \
  bash -c "[ \"$SIZE\" -lt \"$MAX_BYTES\" ]"

summary
