#!/usr/bin/env bash
# TP12 — vérifie un déploiement Swarm RÉEL : un site Drupal répliqué 3x derrière
# Traefik, adossé à MariaDB. On installe le site (drush), puis on prouve :
# le routage par Host, la répartition sur plusieurs réplicas, et la base peuplée.
source "$(git rev-parse --show-toplevel)/scripts/lib.sh"
set +e  # les boucles d'attente gèrent leurs propres erreurs ; le verdict vient de summary

TARGET="${1:-solution}"
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/$TARGET" || exit 1
STACK="tp12"
IMG="tp12-telemach-drupal:1.0"
WE_INIT_SWARM=0

cleanup() {
  docker stack rm "$STACK" >/dev/null 2>&1 || true
  sleep 5
  # Les volumes survivent à 'stack rm' : on les supprime, sinon l'install échoue
  # « already installed » au run suivant (BDD déjà peuplée).
  docker volume rm "${STACK}_db-data" "${STACK}_drupal-files" >/dev/null 2>&1 || true
  [ "$WE_INIT_SWARM" = "1" ] && docker swarm leave --force >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup  # repartir propre

# curl bornés : --max-time empêche tout blocage.
cget()  { curl -fsS  --max-time 5 "$@"; }
ccode() { curl -sS -o /dev/null --max-time 5 -w '%{http_code}' "$@" 2>/dev/null; }
reps()  { docker service ls --filter "name=$1" --format '{{.Replicas}}' 2>/dev/null; }
cid_of(){ docker ps --filter "label=com.docker.swarm.service.name=${STACK}_$1" -q 2>/dev/null | head -1; }

dump() {
  echo "--- services ---"; docker stack services "$STACK" 2>&1
  echo "--- ps drupal ---"; docker service ps "${STACK}_drupal" --no-trunc 2>&1 | tail -8
  echo "--- ps db ---";     docker service ps "${STACK}_db"     --no-trunc 2>&1 | tail -5
  local dc; dc="$(cid_of drupal)"; [ -n "$dc" ] && { echo "--- logs drupal ---"; docker logs "$dc" 2>&1 | tail -20; }
}

step "1) S'assurer qu'un Swarm est actif (init si nécessaire)"
if ! docker node ls >/dev/null 2>&1; then
  ADV="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')"
  docker swarm init ${ADV:+--advertise-addr "$ADV"} >/dev/null 2>&1 \
    || docker swarm init >/dev/null 2>&1 \
    || docker swarm init --advertise-addr 127.0.0.1 >/dev/null
  WE_INIT_SWARM=1
  info "Swarm initialisé (advertise-addr=${ADV:-auto})"
fi
check "Le nœud courant est un manager Swarm" bash -c "docker node ls >/dev/null 2>&1"

step "2) Construire l'image applicative (Swarm ne build pas)"
docker build -t "$IMG" "$HERE/drupal" || { echo "build KO"; exit 1; }
check "Image $IMG construite" bash -c "docker image inspect '$IMG' >/dev/null 2>&1"

step "3) Déployer la stack"
# --resolve-image=never : l'image est locale (pas dans un registre) -> pas de lookup.
docker stack deploy --resolve-image=never -c stack.yml "$STACK"

step "4) Attendre les réplicas (db 1/1, drupal 3/3, traefik 1/1)"
wait_reps() { # $1=service  $2=cible  $3=timeout
  local i=0 r=""
  while [ "$i" -lt "$3" ]; do r="$(reps "${STACK}_$1")"; [ "$r" = "$2" ] && { echo "$r"; return 0; }; i=$((i+3)); sleep 3; done
  echo "$r"; return 1
}
DB="$(wait_reps db 1/1 180)";       info "db=$DB"
DR="$(wait_reps drupal 3/3 240)";   info "drupal=$DR"
TR="$(wait_reps traefik 1/1 120)";  info "traefik=$TR"
if [ "$DB" != "1/1" ] || [ "$DR" != "3/3" ] || [ "$TR" != "1/1" ]; then
  echo "services pas prêts"; dump; exit 1
fi
check "MariaDB en 1 réplica" bash -c "[ '$DB' = '1/1' ]"
check "Drupal en 3 réplicas (réplication)" bash -c "[ '$DR' = '3/3' ]"

step "5) Attendre que MariaDB soit healthy"
i=0; DBH=""
while [ "$i" -lt 150 ]; do
  DBCID="$(cid_of db)"
  [ -n "$DBCID" ] && DBH="$(docker inspect -f '{{.State.Health.Status}}' "$DBCID" 2>/dev/null)"
  [ "$DBH" = "healthy" ] && break
  i=$((i+3)); sleep 3
done
if [ "$DBH" != "healthy" ]; then echo "MariaDB pas healthy ($DBH)"; dump; exit 1; fi
info "MariaDB healthy"

step "6) Installer le site Drupal une seule fois (drush) -> crée les tables"
DRCID="$(cid_of drupal)"
if [ -z "$DRCID" ]; then echo "aucun conteneur drupal"; dump; exit 1; fi
INSTALL_OUT="$(docker exec "$DRCID" drush -y site:install standard \
  --site-name='Telemach Swarm' --account-name=admin --account-pass=admin 2>&1)"
echo "$INSTALL_OUT" | tail -3
assert_contains "drush site:install réussit (Drupal parle à MariaDB)" "Installation complete" "$INSTALL_OUT"

step "7) Traefik route Host(\`drupal.localhost\`) vers le site installé"
i=0; ROUTE=""; LAST=""
while [ "$i" -lt 90 ]; do
  LAST="$(ccode -H 'Host: drupal.localhost' http://localhost:8090/)"
  [ "$LAST" = "200" ] && { ROUTE=ok; break; }
  i=$((i+3)); sleep 3
done
if [ "$ROUTE" != ok ]; then echo "routage KO (dernier code: $LAST)"; dump; exit 1; fi
BODY="$(cget -H 'Host: drupal.localhost' http://localhost:8090/)"
assert_contains "La page d'accueil sert le vrai site (« Telemach »)" "Telemach" "$BODY"

step "8) Le routeur drupal est enregistré dans l'API Traefik"
assert_contains "Routeur drupal présent (provider swarm)" "drupal" \
  "$(cget http://localhost:8091/api/http/routers 2>/dev/null || echo '[]')"

step "9) Répartition de charge : plusieurs réplicas répondent"
DISTINCT="$(for _ in $(seq 1 15); do
  curl -fsS --max-time 5 -D - -o /dev/null -H 'Host: drupal.localhost' http://localhost:8090/ 2>/dev/null \
    | sed -n 's/^[Xx]-[Ss]erved-[Bb]y: //p' | tr -d '\r'
done | sort -u | grep -c .)"
info "réplicas distincts observés (X-Served-By) = $DISTINCT"
check "Au moins 2 réplicas distincts répondent" bash -c "[ '${DISTINCT:-0}' -ge 2 ]"

step "10) La base MariaDB contient bien les tables du site"
DBCID="$(cid_of db)"
TABLES="$(docker exec "$DBCID" mariadb -uroot -prootpass -N \
  -e "SELECT count(*) FROM information_schema.tables WHERE table_schema='drupal'" 2>/dev/null | tr -d '[:space:]')"
info "tables dans la base 'drupal' = ${TABLES:-0}"
check "La base 'drupal' est peuplée (> 20 tables)" bash -c "[ '${TABLES:-0}' -gt 20 ]"

summary
