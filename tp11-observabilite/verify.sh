#!/usr/bin/env bash
# TP11 — vérifie une stack d'observabilité : Prometheus scrape l'appli + cAdvisor,
# Grafana est provisionné (Prometheus + Loki), et les logs arrivent dans Loki via Alloy.
source "$(git rev-parse --show-toplevel)/scripts/lib.sh"

TARGET="${1:-starter}"
cd "$TARGET"

cleanup() { docker compose down -v --remove-orphans >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup  # repartir propre

# Attend qu'une requête PromQL renvoie une série de valeur 1 (cible « up »).
wait_metric() {
  local q="$1" t="${2:-90}" i=0
  until curl -fsS -G "http://localhost:9091/api/v1/query" --data-urlencode "query=$q" 2>/dev/null | grep -q ',"1"]'; do
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
until curl -fsS "http://localhost:9091/-/ready" >/dev/null 2>&1; do
  i=$((i + 3)); sleep 3
  [ "$i" -ge 60 ] && { docker compose logs prometheus; exit 1; }
done
info "prometheus prêt"

step "4) Générer un peu de trafic applicatif (métriques + logs)"
for _ in $(seq 1 8); do curl -fsS "http://localhost:8088/" >/dev/null 2>&1 || true; done

step "5) L'appli expose bien ses métriques (vérification directe)"
assert_contains "telescope_requests_total exposé sur /metrics" "telescope_requests_total" \
  "$(curl -fsS "http://localhost:8088/metrics")"

step "6) Les cibles Prometheus sont UP (app + cAdvisor)"
if ! wait_metric 'up{job="telescope-app"}' 120; then
  echo "--- diagnostic : cibles Prometheus ---"
  curl -fsS "http://localhost:9091/api/v1/targets" 2>/dev/null | sed 's/},{/},\n{/g' \
    | grep -Ei '"job"|"health"|"lastError"|"scrapeUrl"' | head -40
  echo "--- logs app ---"; docker compose logs app 2>&1 | tail -15
fi
assert_contains "telescope-app : up == 1" ',"1"]' \
  "$(curl -fsS -G "http://localhost:9091/api/v1/query" --data-urlencode 'query=up{job="telescope-app"}')"
wait_metric 'up{job="cadvisor"}' 120 || true
assert_contains "cadvisor : up == 1" ',"1"]' \
  "$(curl -fsS -G "http://localhost:9091/api/v1/query" --data-urlencode 'query=up{job="cadvisor"}')"

step "7) Une métrique APPLICATIVE est bien collectée"
check "telescope_requests_total est présent dans Prometheus" \
  bash -c "curl -fsS -G 'http://localhost:9091/api/v1/query' --data-urlencode 'query=telescope_requests_total' | grep -q '\"result\":\[{'"

step "8) Grafana : sources de données provisionnées (Prometheus + Loki)"
DS="$(curl -fsS -u admin:admin "http://localhost:3000/api/datasources")"
assert_contains "Source Prometheus provisionnée" '"type":"prometheus"' "$DS"
assert_contains "Source Loki provisionnée" '"type":"loki"' "$DS"

step "9) Loki est prêt"
i=0
until curl -fsS "http://localhost:3100/ready" 2>/dev/null | grep -q "ready"; do
  i=$((i + 3)); sleep 3
  [ "$i" -ge 90 ] && break
done
assert_contains "Loki répond 'ready'" "ready" \
  "$(curl -fsS "http://localhost:3100/ready" 2>/dev/null || echo indisponible)"

step "10) Les logs des conteneurs arrivent dans Loki (via Alloy)"
# Un flux Loki non vide renvoie un tableau "data" peuplé : ["container",...].
# grep -F (chaîne littérale) car le motif contient un « [ ».
i=0; LOGS_OK=0
while [ "$i" -lt 150 ]; do
  curl -fsS "http://localhost:8088/" >/dev/null 2>&1 || true   # produire des logs
  if curl -fsS "http://localhost:3100/loki/api/v1/labels" 2>/dev/null | grep -qF '"data":["'; then
    LOGS_OK=1; break
  fi
  i=$((i + 5)); sleep 5
done
check "Loki a indexé des logs (au moins un label présent)" bash -c "[ '$LOGS_OK' = '1' ]"
[ "$LOGS_OK" = "1" ] || { echo "--- logs alloy ---"; docker compose logs alloy 2>&1 | tail -30; }

summary
