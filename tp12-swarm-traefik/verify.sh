#!/usr/bin/env bash
# TP12 — vérifie un déploiement Swarm : service whoami répliqué 3x, exposé par
# Traefik (routage par Host), avec répartition de charge sur les réplicas.
source "$(git rev-parse --show-toplevel)/scripts/lib.sh"
set +e  # les boucles d'attente gèrent elles-mêmes leurs erreurs ; le verdict vient de summary

TARGET="${1:-solution}"
cd "$TARGET" || exit 1
STACK="tp10"
WE_INIT_SWARM=0

cleanup() {
  docker stack rm "$STACK" >/dev/null 2>&1 || true
  sleep 4
  [ "$WE_INIT_SWARM" = "1" ] && docker swarm leave --force >/dev/null 2>&1 || true
}
trap cleanup EXIT

# curl bornés : --max-time empêche tout blocage (le maillage Swarm peut accepter
# la connexion sans répondre tant qu'aucune tâche n'est prête).
cget()  { curl -fsS  --max-time 5 "$@"; }                       # échoue si code != 2xx/3xx
ccode() { curl -sS -o /dev/null --max-time 5 -w '%{http_code}' "$@" 2>/dev/null; }
reps()  { docker service ls --filter "name=$1" --format '{{.Replicas}}' 2>/dev/null; }

dump_traefik() {
  echo "--- service ps traefik ---"; docker service ps "${STACK}_traefik" --no-trunc 2>&1 | tail -8
  echo "--- service ps whoami ---";  docker service ps "${STACK}_whoami"  --no-trunc 2>&1 | tail -8
  echo "--- service logs traefik ---"; docker service logs "${STACK}_traefik" 2>&1 | tail -30
  local cid
  cid="$(docker ps --filter "label=com.docker.swarm.service.name=${STACK}_traefik" -q 2>/dev/null | head -1)"
  if [ -n "$cid" ]; then
    echo "--- docker logs (conteneur $cid) ---"; docker logs "$cid" 2>&1 | tail -30
    echo "--- ports publiés ---"; docker port "$cid" 2>&1
  fi
  echo "--- routers (API) ---"; cget "http://localhost:8091/api/http/routers" 2>/dev/null || echo "(API injoignable)"
}

step "1) S'assurer qu'un Swarm est actif (init si nécessaire)"
if ! docker node ls >/dev/null 2>&1; then
  # On annonce une VRAIE IP (pas 127.0.0.1, qui casse le maillage overlay/ingress).
  ADV="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')"
  docker swarm init ${ADV:+--advertise-addr "$ADV"} >/dev/null 2>&1 \
    || docker swarm init >/dev/null 2>&1 \
    || docker swarm init --advertise-addr 127.0.0.1 >/dev/null
  WE_INIT_SWARM=1
  info "Swarm initialisé (advertise-addr=${ADV:-auto})"
fi
check "Le nœud courant est un manager Swarm" bash -c "docker node ls >/dev/null 2>&1"

step "2) Déployer la stack"
docker stack deploy -c stack.yml "$STACK"

step "3) Attendre que les services soient en place (traefik 1/1, whoami 3/3)"
i=0; TR=""
while [ "$i" -lt 180 ]; do
  TR="$(reps "${STACK}_traefik")"; [ "$TR" = "1/1" ] && break
  i=$((i + 3)); sleep 3
done
i=0; WH=""
while [ "$i" -lt 180 ]; do
  WH="$(reps "${STACK}_whoami")"; [ "$WH" = "3/3" ] && break
  i=$((i + 3)); sleep 3
done
info "réplicas : traefik=$TR · whoami=$WH"
if [ "$TR" != "1/1" ] || [ "$WH" != "3/3" ]; then
  echo "services pas prêts"; dump_traefik; exit 1
fi

step "4) L'API Traefik est joignable (ingress -> Traefik)"
i=0; API_OK=0
while [ "$i" -lt 60 ]; do
  cget "http://localhost:8091/api/rawdata" >/dev/null 2>&1 && { API_OK=1; break; }
  i=$((i + 3)); sleep 3
done
if [ "$API_OK" != 1 ]; then echo "API Traefik injoignable"; dump_traefik; exit 1; fi
info "API Traefik OK"

step "5) Traefik route par Host(\`whoami.localhost\`) vers whoami"
i=0; ROUTE_OK=0; LAST=""
while [ "$i" -lt 60 ]; do
  LAST="$(ccode -H 'Host: whoami.localhost' http://localhost:8090/)"
  [ "$LAST" = "200" ] && { ROUTE_OK=1; break; }
  i=$((i + 3)); sleep 3
done
if [ "$ROUTE_OK" != 1 ]; then
  echo "--- routage KO (dernier code HTTP : $LAST) ---"; dump_traefik; exit 1
fi
assert_contains "whoami répond à travers Traefik" "Hostname:" \
  "$(cget -H 'Host: whoami.localhost' "http://localhost:8090/")"

step "6) Le routeur whoami est enregistré dans l'API Traefik"
assert_contains "Routeur whoami présent (provider swarm)" "whoami" \
  "$(cget "http://localhost:8091/api/http/routers" 2>/dev/null || echo '[]')"

step "7) Répartition de charge sur plusieurs réplicas"
DISTINCT="$(for _ in $(seq 1 12); do
  cget -H 'Host: whoami.localhost' "http://localhost:8090/" 2>/dev/null | sed -n 's/^Hostname: //p'
done | sort -u | wc -l)"
info "réplicas distincts observés = $DISTINCT"
check "Au moins 2 réplicas distincts répondent" bash -c "[ '$DISTINCT' -ge 2 ]"

summary
