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

step "1) S'assurer qu'un Swarm est actif (init si nécessaire)"
if ! docker node ls >/dev/null 2>&1; then
  docker swarm init --advertise-addr 127.0.0.1 >/dev/null 2>&1 || docker swarm init >/dev/null
  WE_INIT_SWARM=1
  info "Swarm initialisé pour le TP"
fi
check "Le nœud courant est un manager Swarm" bash -c "docker node ls >/dev/null 2>&1"

step "2) Déployer la stack"
docker stack deploy -c stack.yml "$STACK"

step "3) Attendre que les 3 réplicas de whoami soient en service"
i=0
until [ "$(docker service ls --filter "name=${STACK}_whoami" --format '{{.Replicas}}')" = "3/3" ]; do
  i=$((i + 3)); sleep 3
  [ "$i" -ge 120 ] && { docker service ps "${STACK}_whoami" --no-trunc; exit 1; }
done
info "whoami = 3/3"

step "4) Traefik route par Host(\`whoami.localhost\`) vers le service"
i=0
until curl -fsS -H "Host: whoami.localhost" "http://localhost:8090/" >/dev/null 2>&1; do
  i=$((i + 3)); sleep 3
  [ "$i" -ge 90 ] && { docker service logs "${STACK}_traefik" --no-trunc 2>&1 | tail -20; exit 1; }
done
assert_contains "whoami répond à travers Traefik" "Hostname:" \
  "$(curl -fsS -H 'Host: whoami.localhost' "http://localhost:8090/")"

step "5) Répartition de charge sur plusieurs réplicas"
DISTINCT="$(for _ in $(seq 1 15); do
  curl -fsS -H 'Host: whoami.localhost' "http://localhost:8090/" 2>/dev/null | sed -n 's/^Hostname: //p'
done | sort -u | wc -l)"
info "réplicas distincts observés = $DISTINCT"
check "Au moins 2 réplicas distincts répondent" bash -c "[ '$DISTINCT' -ge 2 ]"

step "6) L'API Traefik connaît bien le routeur whoami"
i=0
until curl -fsS "http://localhost:8091/api/rawdata" >/dev/null 2>&1; do
  i=$((i + 2)); sleep 2
  [ "$i" -ge 30 ] && break
done
assert_contains "Le routeur whoami est enregistré dans Traefik" "whoami" \
  "$(curl -fsS "http://localhost:8091/api/rawdata" 2>/dev/null || echo '{}')"

summary
