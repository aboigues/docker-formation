#!/usr/bin/env bash
# TP6 — vérifie une stack Compose avancée : santé-gating (depends_on), cache Redis,
# isolation réseau, profiles et surcouches dev/prod.
source "$(git rev-parse --show-toplevel)/scripts/lib.sh"

TARGET="${1:-solution}"
cd "$TARGET"
API="http://localhost:8085"

cleanup() { docker compose down -v --remove-orphans >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup  # repartir propre

step "1) Démarrage de la stack (API gardée par depends_on: service_healthy)"
docker compose up -d --build
wait_for_http "$API/health" 150 || { docker compose ps; docker compose logs api; exit 1; }
assert_contains "L'API se déclare en bonne santé" '"status":"ok"' "$(curl -fsS "$API/health")"

step "2) Raccourcir une URL (POST /shorten -> écriture Postgres)"
CREATE="$(curl -fsS -X POST -H 'Content-Type: application/json' \
  -d '{"url":"https://docs.docker.com"}' "$API/shorten")"
assert_contains "La création renvoie un code" '"code"' "$CREATE"
CODE="$(printf '%s' "$CREATE" | sed -n 's/.*"code":"\([^"]*\)".*/\1/p')"
info "code généré = $CODE"

step "3) 1re résolution -> X-Cache: MISS (lecture Postgres puis mise en cache)"
H1="$(curl -fsS -D - -o /dev/null "$API/r/$CODE")"
assert_contains "Redirection 302" " 302" "$H1"
assert_contains "Cache MISS la 1re fois" "X-Cache: MISS" "$H1"
assert_contains "Location pointe vers l'URL d'origine" "docs.docker.com" "$H1"

step "4) 2de résolution -> X-Cache: HIT (servie par Redis, sans toucher Postgres)"
H2="$(curl -fsS -D - -o /dev/null "$API/r/$CODE")"
assert_contains "Cache HIT la 2de fois" "X-Cache: HIT" "$H2"

step "5) La clé est bien présente dans Redis"
check "Redis contient link:$CODE" \
  bash -c "docker compose exec -T cache redis-cli exists 'link:$CODE' | tr -d '\r' | grep -qx 1"

step "5b) Persistance : le volume nommé est monté au bon endroit (Postgres 18)"
DBID="$(docker compose ps -q db)"
MNT="$(docker inspect "$DBID" --format '{{range .Mounts}}{{.Destination}}={{.Name}};{{end}}')"
info "montages db = $MNT"
assert_contains "db-data monté sur /var/lib/postgresql" "/var/lib/postgresql=" "$MNT"

step "6) Isolation : Postgres n'est PAS exposé sur l'hôte"
check "Le port 5432 est fermé côté hôte" \
  bash -c "! timeout 2 bash -c 'exec 3<>/dev/tcp/127.0.0.1/5432' 2>/dev/null"

step "7) Profil 'debug' : adminer ne démarre QUE sur demande"
check "adminer absent du profil par défaut" \
  bash -c "! docker compose config --services | grep -qx adminer"
assert_contains "adminer présent avec --profile debug" "adminer" \
  "$(docker compose --profile debug config --services)"

step "8) Surcouche prod : image immuable (pas de code monté), pas de mode dev"
PROD="$(mktemp)"
docker compose -f compose.yaml -f compose.prod.yaml config > "$PROD"
check "Aucun bind mount du code en prod" bash -c "! grep -q 'type: bind' '$PROD'"
check "NODE_ENV development absent en prod" bash -c "! grep -q development '$PROD'"
assert_contains "Politique restart définie en prod" "restart: always" "$(cat "$PROD")"

step "9) En dev (override auto) : code monté + NODE_ENV development"
DEV="$(docker compose config)"
assert_contains "Bind mount du code en dev" "type: bind" "$DEV"
assert_contains "NODE_ENV development en dev" "development" "$DEV"

rm -f "$PROD"
summary
