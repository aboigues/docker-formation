#!/usr/bin/env bash
# TP5 — vérifie que la stack Compose lève WordPress + MySQL.
source "$(git rev-parse --show-toplevel)/scripts/lib.sh"

TARGET="${1:-solution}"
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/$TARGET"
PROJECT="tp5verify"

compose() { docker compose -p "$PROJECT" -f "$DIR/docker-compose.yml" "$@"; }

cleanup() { compose down -v >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup  # repartir propre

step "Validation de la syntaxe du fichier Compose"
check "docker compose config est valide" \
  docker compose -p "$PROJECT" -f "$DIR/docker-compose.yml" config

step "Lancement de la stack ($TARGET)"
compose up -d >/dev/null

wait_for_http "http://localhost:8083" 180 || { compose logs wordpress 2>&1 | tail -30; exit 1; }

BODY="$(curl -fsSL "http://localhost:8083")"
assert_contains "WordPress répond" "WordPress" "$BODY"

step "Vérification des ressources créées par Compose"
RUNNING="$(compose ps --status running -q | wc -l | tr -d ' ')"
check "Un réseau du projet a été créé"  bash -c "docker network ls --format '{{.Name}}' | grep -q '^${PROJECT}'"
check "Un volume du projet a été créé"   bash -c "docker volume ls --format '{{.Name}}' | grep -q '^${PROJECT}'"
check "Deux services tournent"           bash -c "[ '${RUNNING}' -ge 2 ]"

summary
