#!/bin/bash
# Script de validation de la configuration OpenTelemetry

set -e

echo "=== Validation de la configuration OpenTelemetry ==="
echo ""

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction de test
test_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1 existe"
        return 0
    else
        echo -e "${RED}✗${NC} $1 manquant"
        return 1
    fi
}

# 1. Vérifier les fichiers de configuration
echo "1. Vérification des fichiers de configuration..."
test_file "docker-compose.yml"
test_file "otel-collector-config.yaml"
test_file "prometheus.yml"
test_file "grafana-datasources.yml"
echo ""

# 2. Vérifier l'application Node.js
echo "2. Vérification de l'application Node.js..."
test_file "app-nodejs/package.json"
test_file "app-nodejs/tracing.js"
test_file "app-nodejs/server.js"
test_file "app-nodejs/Dockerfile"
echo ""

# 3. Vérifier l'application Python
echo "3. Vérification de l'application Python..."
test_file "app-python/requirements.txt"
test_file "app-python/app.py"
test_file "app-python/Dockerfile"
echo ""

# 4. Vérifier la syntaxe YAML
echo "4. Vérification de la syntaxe YAML..."
if command -v docker-compose &> /dev/null; then
    docker-compose config > /dev/null 2>&1 && echo -e "${GREEN}✓${NC} docker-compose.yml valide" || echo -e "${RED}✗${NC} docker-compose.yml invalide"
else
    echo -e "${YELLOW}⚠${NC} docker-compose non disponible, validation YAML ignorée"
fi
echo ""

echo "=== Configuration validée ==="
echo ""
echo "Pour démarrer la stack :"
echo "  docker compose up -d --build"
echo ""
echo "Pour vérifier les services :"
echo "  docker compose ps"
echo ""
echo "Interfaces web :"
echo "  - Grafana:    http://localhost:3000"
echo "  - Jaeger:     http://localhost:16686"
echo "  - Prometheus: http://localhost:9090"
echo "  - Demo App:   http://localhost:8080"
echo "  - Python API: http://localhost:5000"
