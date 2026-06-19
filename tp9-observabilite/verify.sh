#!/usr/bin/env bash
# TP9 — vérifie une stack d'observabilité : Prometheus scrape l'appli + cAdvisor,
# Grafana est provisionné (Prometheus + Loki), et les logs arrivent dans Loki via Alloy.
source "$(git rev-parse --show-toplevel)/scripts/lib.sh"

TARGET="${1:-solution}"
cd "$TARGET"

cleanup() { docker compose down -v --remove-orphans >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup  # repartir propre

# Attend qu'une requête PromQL renvoie une série de valeur 1 (cible « up »).
wait_metric() {
  local q="$1" t="${2:-90}" i=0
  until curl -fsS -G "http://localhost:9090/api/v1/query" --data-urlencode "query=$q" 2>/dev/null | grep -q ',"1"]'; do
    i=$((i + 3)); sleep 3
    [ "$i" -ge "$t" ] && return 1
  done
}

step "1) Démarrage de la stack d'observabilité (6 services)"
docker compose up -d --build

step "2) Grafana répond"
wait_for_http "http://localhost:3000/api/health" 90 || { docker compose logs grafana; exit 1; }

step "3) Prometheus est prêt"
i=0
until curl -fsS "http://localhost:9090/-/ready" >/dev/null 2>&1; do
  i=$((i + 3)); sleep 3
  [ "$i" -ge 60 ] && { docker compose logs prometheus; exit 1; }
done
info "prometheus prêt"

step "4) Générer un peu de trafic applicatif (métriques + logs)"
for _ in $(seq 1 8); do curl -fsS "http://localhost:8088/" >/dev/null 2>&1 || true; done

step "5) Les cibles Prometheus sont UP"
wait_metric 'up{job="telescope-app"}' 90
assert_contains "telescope-app : up == 1" ',"1"]' \
  "$(curl -fsS -G "http://localhost:9090/api/v1/query" --data-urlencode 'query=up{job="telescope-app"}')"
wait_metric 'up{job="cadvisor"}' 90
assert_contains "cadvisor : up == 1" ',"1"]' \
  "$(curl -fsS -G "http://localhost:9090/api/v1/query" --data-urlencode 'query=up{job="cadvisor"}')"

step "6) Une métrique APPLICATIVE est bien collectée"
check "telescope_requests_total est présent dans Prometheus" \
  bash -c "curl -fsS -G 'http://localhost:9090/api/v1/query' --data-urlencode 'query=telescope_requests_total' | grep -q '\"result\":\[{'"

step "7) Grafana : sources de données provisionnées (Prometheus + Loki)"
DS="$(curl -fsS -u admin:admin "http://localhost:3000/api/datasources")"
assert_contains "Source Prometheus provisionnée" '"type":"prometheus"' "$DS"
assert_contains "Source Loki provisionnée" '"type":"loki"' "$DS"

step "8) Loki est prêt"
i=0
until curl -fsS "http://localhost:3100/ready" 2>/dev/null | grep -q "ready"; do
  i=$((i + 3)); sleep 3
  [ "$i" -ge 90 ] && break
done
assert_contains "Loki répond 'ready'" "ready" \
  "$(curl -fsS "http://localhost:3100/ready" 2>/dev/null || echo indisponible)"

step "9) Les logs des conteneurs arrivent dans Loki (via Alloy)"
i=0
until curl -fsS "http://localhost:3100/loki/api/v1/labels" 2>/dev/null | grep -q '"data":\["'; do
  curl -fsS "http://localhost:8088/" >/dev/null 2>&1 || true   # produire des logs
  i=$((i + 5)); sleep 5
  [ "$i" -ge 150 ] && break
done
assert_contains "Loki a indexé des logs (labels présents)" '"data":["' \
  "$(curl -fsS "http://localhost:3100/loki/api/v1/labels" 2>/dev/null || echo '{}')"

summary
