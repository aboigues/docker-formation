#!/usr/bin/env bash
# TP5 — vérifie que le Dockerfile « complet » produit une image conforme :
#   appli qui répond, version injectée au build (ARG), conteneur non-root, HEALTHCHECK présent.
source "$(git rev-parse --show-toplevel)/scripts/lib.sh"

TARGET="${1:-starter}"
HERE="$(cd "$(dirname "$0")" && pwd)"
CTX="$HERE/$TARGET"

TP5_IMG="tp05-portail:verify"
TP5_NAME="tp05-portail"
TP5_PORT=8085
TP5_VERSION="1.4.2"   # version de test injectée via --build-arg

cleanup() {
  docker rm -f "$TP5_NAME" >/dev/null 2>&1 || true
  docker rmi -f "$TP5_IMG" >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup  # repartir propre

step "Construction de l'image ($TARGET) avec APP_VERSION=$TP5_VERSION"
docker build --build-arg "APP_VERSION=$TP5_VERSION" -t "$TP5_IMG" "$CTX"

step "Lancement du conteneur"
docker run -d --name "$TP5_NAME" -p "$TP5_PORT:3000" "$TP5_IMG" >/dev/null
wait_for_http "http://localhost:$TP5_PORT/healthz" 60 || { docker logs "$TP5_NAME" 2>&1 | tail -30; exit 1; }

step "Vérifications applicatives"
TP5_HOME="$(curl -fsSL "http://localhost:$TP5_PORT/")"
assert_contains "La page d'accueil affiche « Telemach Cloud »" "Telemach Cloud" "$TP5_HOME"

TP5_VER="$(curl -fsSL "http://localhost:$TP5_PORT/version")"
assert_contains "La version injectée au build est exposée sur /version" "$TP5_VERSION" "$TP5_VER"

step "Vérifications du Dockerfile (bonnes pratiques)"
# Non-root : l'utilisateur effectif dans le conteneur ne doit pas être 0 (root).
TP5_UID="$(docker exec "$TP5_NAME" id -u 2>/dev/null || echo 0)"
check "Le conteneur tourne en non-root (uid != 0)" test "$TP5_UID" != "0"

# HEALTHCHECK déclaré dans l'image.
TP5_HC="$(docker inspect -f '{{if .Config.Healthcheck}}yes{{end}}' "$TP5_IMG")"
check "L'image déclare un HEALTHCHECK" test "$TP5_HC" = "yes"

# EXPOSE déclaré.
TP5_PORTS="$(docker inspect -f '{{json .Config.ExposedPorts}}' "$TP5_IMG")"
assert_contains "L'image documente le port via EXPOSE 3000/tcp" "3000/tcp" "$TP5_PORTS"

summary
