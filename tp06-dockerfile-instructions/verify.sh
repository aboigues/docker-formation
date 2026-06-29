#!/usr/bin/env bash
# TP6 — vérifie que le Dockerfile « complet » produit une image conforme :
#   appli qui répond, version injectée au build (ARG), conteneur non-root, HEALTHCHECK présent.
source "$(git rev-parse --show-toplevel)/scripts/lib.sh"

TARGET="${1:-solution}"
HERE="$(cd "$(dirname "$0")" && pwd)"
CTX="$HERE/$TARGET"

TP6_IMG="tp6-portail:verify"
TP6_NAME="tp6-portail"
TP6_PORT=8085
TP6_VERSION="1.4.2"   # version de test injectée via --build-arg

cleanup() {
  docker rm -f "$TP6_NAME" >/dev/null 2>&1 || true
  docker rmi -f "$TP6_IMG" >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup  # repartir propre

step "Construction de l'image ($TARGET) avec APP_VERSION=$TP6_VERSION"
docker build --build-arg "APP_VERSION=$TP6_VERSION" -t "$TP6_IMG" "$CTX"

step "Lancement du conteneur"
docker run -d --name "$TP6_NAME" -p "$TP6_PORT:3000" "$TP6_IMG" >/dev/null
wait_for_http "http://localhost:$TP6_PORT/healthz" 60 || { docker logs "$TP6_NAME" 2>&1 | tail -30; exit 1; }

step "Vérifications applicatives"
TP6_HOME="$(curl -fsSL "http://localhost:$TP6_PORT/")"
assert_contains "La page d'accueil affiche « Telemach Cloud »" "Telemach Cloud" "$TP6_HOME"

TP6_VER="$(curl -fsSL "http://localhost:$TP6_PORT/version")"
assert_contains "La version injectée au build est exposée sur /version" "$TP6_VERSION" "$TP6_VER"

step "Vérifications du Dockerfile (bonnes pratiques)"
# Non-root : l'utilisateur effectif dans le conteneur ne doit pas être 0 (root).
TP6_UID="$(docker exec "$TP6_NAME" id -u 2>/dev/null || echo 0)"
check "Le conteneur tourne en non-root (uid != 0)" test "$TP6_UID" != "0"

# HEALTHCHECK déclaré dans l'image.
TP6_HC="$(docker inspect -f '{{if .Config.Healthcheck}}yes{{end}}' "$TP6_IMG")"
check "L'image déclare un HEALTHCHECK" test "$TP6_HC" = "yes"

# EXPOSE déclaré.
TP6_PORTS="$(docker inspect -f '{{json .Config.ExposedPorts}}' "$TP6_IMG")"
assert_contains "L'image documente le port via EXPOSE 3000/tcp" "3000/tcp" "$TP6_PORTS"

summary
