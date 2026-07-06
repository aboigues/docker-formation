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

# Persistance RÉELLE : on écrit une donnée, on DÉTRUIT le conteneur MySQL (celui qui
# porte le volume wp-db) puis on le recrée. La donnée doit survivre — sinon le volume
# n'était pas monté au bon endroit. Supprimer WordPress ne prouverait rien : le volume
# est sur MySQL, pas sur WordPress.
step "Test de persistance (destruction/recréation de MySQL)"
docker exec wp-mysql mysql -uroot -prootsecret \
  -e "CREATE TABLE IF NOT EXISTS wordpress.persist_probe (id INT); \
      TRUNCATE wordpress.persist_probe; INSERT INTO wordpress.persist_probe VALUES (42);" >/dev/null
docker rm -f wp-mysql >/dev/null          # on tue la BASE ; le volume wp-db doit survivre
bash "$DEPLOY" up >/dev/null              # deploy.sh recrée MySQL sur le volume existant
# On attend que MySQL réponde de nouveau avant d'interroger la table
i=0
until docker exec wp-mysql mysqladmin ping -h localhost --silent >/dev/null 2>&1; do
  i=$((i+2)); sleep 2
  [ "$i" -ge 60 ] && { docker logs wp-mysql 2>&1 | tail -30; break; }
done
check "Le volume wp-db a survécu à la destruction de MySQL" \
  bash -c "docker volume ls --format '{{.Name}}' | grep -qx wp-db"
check "La donnée écrite avant la destruction est toujours là (persistance réelle)" \
  bash -c "docker exec wp-mysql mysql -uroot -prootsecret -N -e 'SELECT id FROM wordpress.persist_probe' 2>/dev/null | grep -qx 42"
# La stack complète doit répondre de nouveau après recréation de la base
wait_for_http "http://localhost:8083" 120 || { docker logs wp-app 2>&1 | tail -30; exit 1; }

summary
