#!/usr/bin/env bash
# TP14 — vérifie la reprise COMPLÈTE de Telemach Shop, de la livraison à l'incident :
#   phase 1  registre + chaîne build -> scan -> push (image durcie, versionnée)
#   phase 2  déploiement Swarm depuis le registre, routage Traefik
#   phase 3  observabilité : une cible Prometheus PAR réplica, Grafana, Loki
#   INC-101  la recherche par catégorie utilise un index
#   INC-102  le cache est borné, aucun réplica tué pour manque de mémoire
#   INC-103  6 réplicas sous forte charge sans erreur (pool de connexions)
#   INC-104  mise à jour 1.0.0 -> 1.1.0 SOUS CHARGE, sans aucune erreur
source "$(git rev-parse --show-toplevel)/scripts/lib.sh"
set +e  # les boucles d'attente gèrent leurs propres erreurs ; le verdict vient de summary

TARGET="${1:-starter}"
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/$TARGET" || exit 1
STACK="tp14"
INFRA="tp14-infra"
REG="localhost:5000"
API="${STACK}_shop-api"
WE_INIT_SWARM=0
WORK="$(mktemp -d)"

cleanup() {
  touch "$WORK/stop"
  docker stack rm "$STACK" "$INFRA" >/dev/null 2>&1 || true
  # Attendre la disparition des réseaux de la stack, sinon un redéploiement échoue.
  for _ in $(seq 1 30); do
    [ -z "$(docker network ls -q --filter "label=com.docker.stack.namespace=$STACK")" ] && break
    sleep 2
  done
  # Les volumes survivent à « stack rm » : la base serait déjà initialisée au run suivant.
  for _ in $(seq 1 10); do
    docker volume rm "${STACK}_db-data" "${INFRA}_registry-data" >/dev/null 2>&1 && break
    sleep 2
  done
  docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null \
    | grep "^$REG/telemach/" | xargs -r docker rmi -f >/dev/null 2>&1 || true
  [ "$WE_INIT_SWARM" = "1" ] && docker swarm leave --force >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT
cleanup; WORK="$(mktemp -d)"  # repartir propre

# --- petits outils -----------------------------------------------------------
ccode() { curl -sS -o /dev/null --max-time 5 -w '%{http_code}' "$@" 2>/dev/null; }
shop()  { curl -fsS --max-time 5 -H 'Host: shop.localhost' "http://localhost:8090$1" 2>/dev/null; }
reps()  { docker service ls --filter "name=$1" --format '{{.Name}} {{.Replicas}}' 2>/dev/null \
            | awk -v n="$1" '$1==n {print $2}'; }
cid_of(){ docker ps --filter "label=com.docker.swarm.service.name=${STACK}_$1" -q 2>/dev/null | head -1; }
# Valeur scalaire d'une requête PromQL (vide si aucun résultat).
promq() {
  curl -fsS --max-time 5 -G http://localhost:9091/api/v1/query --data-urlencode "query=$1" 2>/dev/null \
    | python3 -c 'import json,sys
r=json.load(sys.stdin)["data"]["result"]
print(r[0]["value"][1] if r else "")' 2>/dev/null
}
wait_reps() { # $1=service $2=cible $3=timeout
  local i=0 r=""
  while [ "$i" -lt "$3" ]; do r="$(reps "$1")"; [ "$r" = "$2" ] && { echo "$r"; return 0; }; i=$((i+3)); sleep 3; done
  echo "${r:-absent}"; return 1
}
dump() {
  echo "--- services ---"; docker stack services "$STACK" 2>&1
  echo "--- ps shop-api ---"; docker service ps "$API" --no-trunc 2>&1 | tail -10
  local c; c="$(cid_of shop-api)"; [ -n "$c" ] && { echo "--- logs shop-api ---"; docker logs "$c" 2>&1 | tail -15; }
}
fatal() { printf "  ${RED}✗ %s${NC}\n" "$*"; FAIL=$((FAIL+1)); dump; summary; exit 1; }

# =============================================================================
step "0) Un Swarm actif (init si nécessaire)"
if ! docker node ls >/dev/null 2>&1; then
  ADV="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')"
  docker swarm init ${ADV:+--advertise-addr "$ADV"} >/dev/null 2>&1 \
    || docker swarm init >/dev/null 2>&1 \
    || docker swarm init --advertise-addr 127.0.0.1 >/dev/null
  WE_INIT_SWARM=1
  info "Swarm initialisé (advertise-addr=${ADV:-auto})"
fi
check "Le nœud courant est un manager Swarm" bash -c "docker node ls >/dev/null 2>&1"

# =============================================================================
step "1) Phase 1 — Registre privé"
docker stack deploy -c registry.yml "$INFRA" >/dev/null
i=0; until [ "$(ccode http://$REG/v2/)" = "200" ] || [ "$i" -ge 90 ]; do i=$((i+3)); sleep 3; done
check "Le registre répond sur $REG" bash -c "[ \"\$(curl -s -o /dev/null -w '%{http_code}' http://$REG/v2/)\" = 200 ]"

step "2) Phase 1 — Livraison : build -> scan -> push"
./ship.sh loadgen 1.0.0 > "$WORK/ship-loadgen.log" 2>&1
LG_RC=$?
check "loadgen 1.0.0 livré (build, scan, push)" bash -c "[ $LG_RC -eq 0 ]"
./ship.sh shop-api 1.0.0 > "$WORK/ship-api.log" 2>&1
SHIP_RC=$?
tail -4 "$WORK/ship-api.log" | sed 's/^/  │ /'
check "shop-api 1.0.0 passe le scan Trivy (0 HIGH/CRITICAL) et est poussé" bash -c "[ $SHIP_RC -eq 0 ]"
[ "$SHIP_RC" -eq 0 ] || fatal "Image refusée : impossible de déployer (voir ship.sh)"

IMG="$REG/telemach/shop-api:1.0.0"
SIZE="$(docker image inspect -f '{{.Size}}' "$IMG" 2>/dev/null)"
info "taille de l'image : $(( ${SIZE:-0} / 1000000 )) Mo"
check "Image shop-api < 30 Mo (multi-stage, base minimale)" bash -c "[ '${SIZE:-999999999}' -lt 30000000 ]"
USR="$(docker image inspect -f '{{.Config.User}}' "$IMG" 2>/dev/null)"
info "utilisateur de l'image : ${USR:-<root par défaut>}"
check "L'image tourne en utilisateur non-root" \
  bash -c "case '$USR' in ''|root|0|0:*|root:*) exit 1;; esac"
TAGS="$(curl -fsS http://$REG/v2/telemach/shop-api/tags/list 2>/dev/null)"
info "tags publiés : ${TAGS:-<aucun>}"
assert_contains "Le tag 1.0.0 est dans le registre" '"1.0.0"' "$TAGS"
check "Aucun tag « latest » publié" bash -c "! grep -q latest <<<'$TAGS'"

# =============================================================================
step "3) Phase 2 — Déploiement de la stack depuis le registre"
SHOP_VERSION=1.0.0 docker stack deploy -c stack.yml "$STACK" >/dev/null
for s in db:1/1 shop-api:3/3 traefik:1/1 loadgen:1/1 prometheus:1/1 loki:1/1 grafana:1/1 cadvisor:1/1 alloy:1/1; do
  R="$(wait_reps "${STACK}_${s%%:*}" "${s#*:}" 240)"
  info "${s%%:*} = $R"
done
check "shop-api en 3 réplicas" bash -c "[ '$(reps "$API")' = '3/3' ]"
check "Toute la stack est en place (db, traefik, loadgen, observabilité)" bash -c \
  "[ -z \"\$(docker stack services $STACK --format '{{.Replicas}}' | awk -F/ '\$1!=\$2')\" ]"
SPEC_IMG="$(docker service inspect -f '{{.Spec.TaskTemplate.ContainerSpec.Image}}' "$API" 2>/dev/null)"
info "image du service : $SPEC_IMG"
assert_contains "Swarm tire shop-api depuis le registre, en version 1.0.0" "^$REG/telemach/shop-api:1.0.0" "$SPEC_IMG"

step "4) Phase 2 — Traefik route shop.localhost vers l'API"
i=0; until [ "$(ccode -H 'Host: shop.localhost' 'http://localhost:8090/products?category=cat-07')" = 200 ] || [ "$i" -ge 120 ]; do
  i=$((i+3)); sleep 3
done
[ "$i" -ge 120 ] && fatal "L'API ne répond pas via Traefik"
assert_contains "GET /products?category=cat-07 renvoie des produits" '"category":"cat-07"' \
  "$(shop '/products?category=cat-07')"

# =============================================================================
step "5) Phase 3 — Prometheus voit CHAQUE réplica (et pas la VIP)"
i=0; UP=""
while [ "$i" -lt 90 ]; do
  UP="$(promq 'count(up{job="shop-api"} == 1)')"; [ "$UP" = 3 ] && break; i=$((i+5)); sleep 5
done
info "cibles shop-api UP = ${UP:-0}"
check "3 cibles shop-api distinctes dans Prometheus" bash -c "[ '${UP:-0}' = 3 ]"
check "cAdvisor est scrapé" bash -c "[ \"\$(curl -fsS -G http://localhost:9091/api/v1/query --data-urlencode 'query=up{job=\"cadvisor\"}' | grep -c '\"1\"\]')\" -ge 1 ]"

# =============================================================================
step "6) INC-101 — La recherche par catégorie utilise un index"
DBC="$(cid_of db)"
PLAN="$(docker exec "$DBC" psql -U shop -d shop -tAc \
  "EXPLAIN SELECT id FROM products WHERE category = 'cat-07' ORDER BY price DESC LIMIT 100" 2>&1)"
echo "$PLAN" | head -3 | sed 's/^/  │ /'
assert_contains "Le plan d'exécution passe par un index (plus de Seq Scan)" "Index" "$PLAN"
check "Le correctif est pérenne : l'index est créé par db/init.sql" grep -qi "create index" db/init.sql

# =============================================================================
step "7) INC-102 — Sous charge, le cache reste borné et aucun réplica n'est tué"
info "boutique ouverte : 70 s de trafic (loadgen)..."
sleep 70
CACHE="$(promq 'max(shop_cache_entries)')"
info "entrées max dans un cache = ${CACHE:-?}"
check "Cache borné (≤ 500 entrées par réplica)" bash -c "[ -n '$CACHE' ] && [ '${CACHE%.*}' -le 500 ]"
DEAD="$(docker service ps "$API" --filter desired-state=shutdown -q 2>/dev/null | grep -c .)"
info "réplicas remplacés depuis le déploiement = $DEAD"
check "Aucun réplica tué/redémarré (pas d'OOM kill)" bash -c "[ '$DEAD' -eq 0 ]"

# =============================================================================
step "8) INC-103 — Pic de trafic : 6 réplicas, 60 clients sans pause"
docker service update --detach --env-add WORKERS=60 --env-add THINK_MS=0 "${STACK}_loadgen" >/dev/null
docker service scale --detach "$API=6" >/dev/null
R="$(wait_reps "$API" 6/6 120)"; info "shop-api = $R"
sleep 45
ERR="$(promq 'sum(increase(shop_http_requests_total{code=~"5.."}[40s])) or vector(0)')"
CONNS="$(promq 'max_over_time(sum(shop_db_pool_total_conns)[40s:5s])')"
REQS="$(promq 'sum(increase(shop_http_requests_total[40s]))')"
info "requêtes servies (40 s) = ${REQS%.*} · erreurs 5xx = ${ERR%.*} · connexions PG max = ${CONNS%.*} / 40"
check "La charge est réelle (> 1000 requêtes en 40 s)" bash -c "[ '${REQS%.*}' -gt 1000 ]"
check "Aucune erreur 5xx avec 6 réplicas sous charge" bash -c "[ -n '$ERR' ] && [ '${ERR%.*}' -eq 0 ]"
check "Connexions ouvertes ≤ 30 (sous max_connections=40, avec marge)" bash -c "[ -n '$CONNS' ] && [ '${CONNS%.*}' -le 30 ]"

# =============================================================================
step "9) INC-104 — Déploiement sans coupure : la configuration"
HC="$(docker service inspect -f '{{json .Spec.TaskTemplate.ContainerSpec.Healthcheck}}' "$API" 2>/dev/null)"
UPD="$(docker service inspect -f '{{.Spec.UpdateConfig.Order}} {{.Spec.UpdateConfig.FailureAction}}' "$API" 2>/dev/null)"
info "healthcheck = $HC"; info "update_config = $UPD"
check "shop-api a un healthcheck" bash -c "[ -n '$HC' ] && [ '$HC' != null ]"
assert_contains "Mise à jour en « start-first »" "start-first" "$UPD"
assert_contains "Retour arrière automatique en cas d'échec" "rollback" "$UPD"

step "10) INC-104 — Livrer 1.1.0 et la déployer SOUS CHARGE"
./ship.sh shop-api 1.1.0 > "$WORK/ship-api-2.log" 2>&1
SHIP2_RC=$?
check "shop-api 1.1.0 livré (build, scan, push)" bash -c "[ $SHIP2_RC -eq 0 ]"

# Sonde « client » : une requête toutes les 100 ms pendant toute la mise à jour.
PROBE="$WORK/probe.txt"; : > "$PROBE"
( end=$((SECONDS+400))
  while [ ! -f "$WORK/stop" ] && [ "$SECONDS" -lt "$end" ]; do
    curl -s -o /dev/null --max-time 5 -w '%{http_code}\n' -H 'Host: shop.localhost' \
      http://localhost:8090/products/42 >> "$PROBE" 2>/dev/null
    sleep 0.1
  done ) &
PROBE_PID=$!
sleep 3
# Redéploiement déclaratif : nouvelle version, et retour à la config nominale (3 réplicas, trafic normal).
upd() { docker service inspect -f "{{if .UpdateStatus}}{{.UpdateStatus.$1}}{{end}}" "$API" 2>/dev/null; }
BEFORE="$(upd StartedAt)"
SHOP_VERSION=1.1.0 docker stack deploy -c stack.yml "$STACK" >/dev/null
i=0; ST=""
while [ "$i" -lt 300 ]; do
  ST="$(upd State)"
  # On attend la fin de CETTE mise à jour (et non un statut « completed » laissé par une précédente).
  if [ "$(upd StartedAt)" != "$BEFORE" ]; then
    case "$ST" in completed|rollback_completed|paused|rollback_paused) break ;; esac
  fi
  i=$((i+3)); sleep 3
done
R="$(wait_reps "$API" 3/3 60)"
sleep 8
touch "$WORK/stop"; wait "$PROBE_PID" 2>/dev/null
TOTAL="$(grep -c . "$PROBE")"; KO="$(grep -vc '^200$' "$PROBE")"
info "mise à jour : $ST (${i}s) · shop-api = $R · sonde : $TOTAL requêtes, $KO en échec"
grep -v '^200$' "$PROBE" | sort | uniq -c | sed 's/^/  │ codes en échec : /'
assert_contains "La mise à jour s'est terminée normalement" "^completed$" "$ST"
VERS="$(for _ in 1 2 3 4 5 6; do shop /version; done)"
assert_contains "La version 1.1.0 est servie" '"version":"1.1.0"' "$VERS"
check "Aucune version 1.0.0 ne répond encore" bash -c "! grep -q '\"1.0.0\"' <<<'$VERS'"
check "La sonde a tourné pendant toute la mise à jour (> 150 requêtes)" bash -c "[ '$TOTAL' -gt 150 ]"
check "ZÉRO requête en échec pendant la mise à jour" bash -c "[ '$KO' -eq 0 ]"

# =============================================================================
step "11) Phase 3 — Grafana et Loki"
i=0; until [ "$(ccode http://localhost:3000/api/health)" = 200 ] || [ "$i" -ge 60 ]; do i=$((i+3)); sleep 3; done
assert_contains "Le dashboard « Telemach Shop — production » est provisionné" "telemach-shop" \
  "$(curl -fsS -u admin:admin 'http://localhost:3000/api/search?query=Telemach' 2>/dev/null)"
LOKI=""
for _ in $(seq 1 20); do
  LOKI="$(curl -fsS -u admin:admin \
    'http://localhost:3000/api/datasources/proxy/uid/loki/loki/api/v1/label/service/values' 2>/dev/null)"
  grep -q "$API" <<<"$LOKI" && break; sleep 3
done
assert_contains "Les logs de shop-api arrivent dans Loki (label service)" "$API" "$LOKI"

summary
