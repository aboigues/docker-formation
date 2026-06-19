#!/usr/bin/env bash
# TP10 — vérifie un déploiement Swarm : service whoami répliqué 3x, exposé par
# Traefik (routage par Host), avec répartition de charge sur les réplicas.
source "$(git rev-parse --show-toplevel)/scripts/lib.sh"

TARGET="${1:-solution}"
cd "$TARGET"
STACK="tp10"
WE_INIT_SWARM=0

cleanup() {
  docker stack rm "$STACK" >/dev/null 2>&1 || true
  sleep 4
  [ "$WE_INIT_SWARM" = "1" ] && docker swarm leave --force >/dev/null 2>&1 || true
}
trap cleanup EXIT

# curl borné : --max-time empêche tout blocage (le maillage Swarm peut accepter
# la connexion sans répondre tant qu'aucune tâche n'est prête -> sinon hang infini).
cget()  { curl -fsS  --max-time 5 "$@"; }                 # échoue sur code != 2xx/3xx
ccode() { curl -sS -o /dev/null --max-time 5 -w '%{http_code}' "$@" 2>/dev/null; }

dump_traefik() {
  echo "--- service ps traefik ---"; docker service ps "${STACK}_traefik" --no-trunc 2>&1 | tail -8
  echo "--- service ps whoami ---";  docker service ps "${STACK}_whoami"  --no-trunc 2>&1 | tail -8
  echo "--- logs traefik ---";       docker service logs "${STACK}_traefik" 2>&1 | tail -30
  echo "--- routers (API) ---";      cget "http://localhost:8091/api/http/routers" 2>/dev/null || echo "(API injoignable)"
}

# Attend qu'un service atteigne l'état de réplicas voulu (ex. "3/3").
wait_replicas() {
  local svc="$1" want="$2" t="${3:-180}" i=0
  until [ "$(docker service ls --filter "name=$svc" --format '{{.Replicas}}')" = "$want" ]; do
    i=$((i + 3)); sleep 3
    [ "$i" -ge "$t" ] && { docker service ps "$svc" --no-trunc 2>&1 | tail -10; return 1; }
  done
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
wait_replicas "${STACK}_traefik" "1/1" 180 || { echo "traefik pas prêt"; dump_traefik; exit 1; }
wait_replicas "${STACK}_whoami"  "3/3" 180 || { echo "whoami pas prêt"; exit 1; }
info "traefik = 1/1, whoami = 3/3"

step "4) L'API Traefik est joignable (ingress -> Traefik)"
i=0
until cget "http://localhost:8091/api/rawdata" >/dev/null 2>&1; do
  i=$((i + 3)); sleep 3
  [ "$i" -ge 60 ] && { echo "API Traefik injoignable"; dump_traefik; exit 1; }
done
info "API Traefik OK"

step "5) Traefik route par Host(\`whoami.localhost\`) vers whoami"
i=0
until [ "$(ccode -H 'Host: whoami.localhost' http://localhost:8090/)" = "200" ]; do
  i=$((i + 3)); sleep 3
  if [ "$i" -ge 60 ]; then
    echo "--- routage KO (dernier code HTTP : $(ccode -H 'Host: whoami.localhost' http://localhost:8090/)) ---"
    dump_traefik
    exit 1
  fi
done
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
