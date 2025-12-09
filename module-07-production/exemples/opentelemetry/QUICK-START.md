# 🚀 Quick Start - TP14b OpenTelemetry

## Démarrage en 3 minutes

### 1️⃣ Validation
```bash
cd ~/docker-tp/opentelemetry
./validate-setup.sh
```

### 2️⃣ Démarrage
```bash
docker compose up -d --build
```

### 3️⃣ Test
```bash
# Attendre 30 secondes, puis:
./test-traces.sh
```

## 🌐 Interfaces Web

| Service | URL | Description |
|---------|-----|-------------|
| **Grafana** | http://localhost:3000 | Dashboards et visualisation |
| **Jaeger** | http://localhost:16686 | Exploration des traces |
| **Prometheus** | http://localhost:9090 | Métriques et alertes |
| **Demo App** | http://localhost:8080 | Application Node.js |
| **Python API** | http://localhost:5000 | Application Python |

## 🧪 Tests rapides

```bash
# Test Node.js
curl http://localhost:8080/api/users

# Test Python (trace distribuée!)
curl http://localhost:5000/api/products/1

# Générer du trafic
for i in {1..20}; do
  curl -s http://localhost:8080/api/users > /dev/null
  curl -s http://localhost:5000/api/products/$i > /dev/null
done
```

## 📊 Voir les résultats

### Dans Jaeger (http://localhost:16686)
1. Service → Sélectionner "python-api"
2. Operation → "GET /api/products/<int:product_id>"
3. Click "Find Traces"
4. Sélectionner une trace pour voir le détail

**Vous verrez**: La trace qui traverse Python → Node.js ! 🎉

### Dans Prometheus (http://localhost:9090)
```promql
rate(http_requests_total[5m])
```

### Dans Grafana (http://localhost:3000)
1. Create → Dashboard
2. Add panel
3. Data source: Prometheus
4. Query: `rate(http_requests_total[5m])`

## 🛠️ Commandes utiles

```bash
# Status
docker compose ps

# Logs
docker compose logs -f otel-collector

# Redémarrer
docker compose restart

# Arrêter
docker compose down

# Cleanup complet
docker compose down -v
```

## 📖 Documentation complète

Voir `README-TEST.md` pour:
- Tests détaillés
- Debugging
- Validation complète
- Exemples de requêtes

---

**Prêt? Let's go! 🚀**
