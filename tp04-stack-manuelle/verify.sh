#!/usr/bin/env bash
# TP3 — vérifie que la stack WordPress + MySQL fonctionne et persiste.
source "$(git rev-parse --show-toplevel)/scripts/lib.sh"

TARGET="${1:-solution}"
HERE="$(cd "$(dirname "$0")" && pwd)"
DEPLOY="$HERE/$TARGET/deploy.sh"

cleanup() {
  bash "$DEPLOY" down >/dev/null 2>&1 || true
  docker volume rm wp-db >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup  # repartir propre

step "Montage de la stack ($TARGET)"
bash "$DEPLOY" up >/dev/null

# WordPress met du temps à joindre MySQL au 1er démarrage → timeout généreux
wait_for_http "http://localhost:8083" 180 || { docker logs wp-app 2>&1 | tail -30; exit 1; }

BODY="$(curl -fsSL "http://localhost:8083")"
assert_contains "WordPress répond (page d'installation)" "WordPress" "$BODY"

step "Vérification de l'isolation et de la persistance"
check "Le réseau custom wp-net existe"     bash -c "docker network ls --format '{{.Name}}' | grep -qx wp-net"
check "Le volume wp-db existe"             bash -c "docker volume ls --format '{{.Name}}' | grep -qx wp-db"
check "MySQL n'est PAS exposé sur l'hôte"  bash -c "! docker port wp-mysql 2>/dev/null | grep -q 3306"

# Persistance : on supprime WordPress, on le recrée, le volume (donc la base) survit
step "Test de persistance (suppression/recréation de WordPress)"
docker rm -f wp-app >/dev/null
bash "$DEPLOY" up >/dev/null
wait_for_http "http://localhost:8083" 120 || { docker logs wp-app 2>&1 | tail -30; exit 1; }
check "Le volume wp-db a survécu à la recréation" bash -c "docker volume ls --format '{{.Name}}' | grep -qx wp-db"

summary
