#!/bin/bash
# Script pour tester les traces distribuées

set -e

echo "=== Test de génération de traces OpenTelemetry ==="
echo ""

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Attendre que les services soient prêts
echo "Vérification de la disponibilité des services..."
sleep 5

# Vérifier les services
services=("demo-app:8080" "python-api:5000" "jaeger:16686" "prometheus:9090" "grafana:3000")
for service in "${services[@]}"; do
    host=$(echo $service | cut -d: -f1)
    port=$(echo $service | cut -d: -f2)
    if curl -s http://localhost:$port > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $host accessible sur port $port"
    else
        echo -e "${YELLOW}⚠${NC} $host non accessible sur port $port"
    fi
done
echo ""

# Test 1: Application Node.js
echo "1. Test de l'application Node.js..."
echo -n "  GET / : "
curl -s http://localhost:8080/ | jq -r '.message' || echo "Erreur"

echo -n "  GET /api/users : "
curl -s http://localhost:8080/api/users | jq -r 'length' | xargs echo "utilisateurs"

echo -n "  GET /api/users/1 : "
curl -s http://localhost:8080/api/users/1 | jq -r '.name' || echo "Erreur"
echo ""

# Test 2: Application Python
echo "2. Test de l'application Python..."
echo -n "  GET / : "
curl -s http://localhost:5000/ | jq -r '.message' || echo "Erreur"

echo -n "  GET /api/products : "
curl -s http://localhost:5000/api/products | jq -r 'length' | xargs echo "produits"

echo -n "  GET /api/products/1 (trace distribuée) : "
curl -s http://localhost:5000/api/products/1 | jq -r '.name' || echo "Erreur"
echo ""

# Test 3: Génération de trafic
echo "3. Génération de trafic pour les traces..."
for i in {1..10}; do
    curl -s http://localhost:8080/api/users > /dev/null
    curl -s http://localhost:8080/api/users/$i > /dev/null
    curl -s http://localhost:5000/api/products > /dev/null
    curl -s http://localhost:5000/api/products/$((i % 5 + 1)) > /dev/null
    echo -n "."
done
echo " ${GREEN}✓${NC}"
echo ""

# Test 4: Vérifier les traces dans Jaeger
echo "4. Vérification des traces dans Jaeger..."
sleep 2
TRACES=$(curl -s "http://localhost:16686/api/services" | jq -r '.data | length')
if [ "$TRACES" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Services détectés dans Jaeger:"
    curl -s "http://localhost:16686/api/services" | jq -r '.data[]' | sed 's/^/  - /'
else
    echo -e "${YELLOW}⚠${NC} Aucun service détecté dans Jaeger (attendre quelques secondes)"
fi
echo ""

# Test 5: Vérifier les métriques dans Prometheus
echo "5. Vérification des métriques dans Prometheus..."
TARGETS=$(curl -s 'http://localhost:9090/api/v1/targets' | jq -r '.data.activeTargets | length')
echo "  Targets actives: $TARGETS"

METRICS=$(curl -s 'http://localhost:9090/api/v1/query?query=up' | jq -r '.data.result | length')
echo "  Services UP: $METRICS"
echo ""

echo "=== Tests terminés ==="
echo ""
echo "Accédez aux interfaces :"
echo "  - Jaeger UI:     http://localhost:16686"
echo "    → Sélectionnez 'demo-app' ou 'python-api' dans 'Service'"
echo "    → Cliquez sur 'Find Traces'"
echo ""
echo "  - Prometheus:    http://localhost:9090"
echo "    → Requête: rate(http_requests_total[5m])"
echo ""
echo "  - Grafana:       http://localhost:3000"
echo "    → Créez un dashboard avec les datasources Prometheus et Jaeger"
