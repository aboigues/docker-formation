# Test de la solution TP14b - OpenTelemetry

## 📁 Structure créée

```
opentelemetry/
├── docker-compose.yml               # Orchestration complète
├── otel-collector-config.yaml       # Configuration du Collector
├── prometheus.yml                   # Configuration Prometheus
├── grafana-datasources.yml          # Datasources Grafana
├── validate-setup.sh                # Script de validation
├── test-traces.sh                   # Script de test
├── app-nodejs/                      # Application Node.js instrumentée
│   ├── package.json
│   ├── tracing.js                   # Configuration OpenTelemetry
│   ├── server.js                    # Serveur Express
│   └── Dockerfile
└── app-python/                      # Application Python instrumentée
    ├── requirements.txt
    ├── app.py                       # Application Flask
    └── Dockerfile
```

## 🚀 Démarrage rapide

### 1. Validation de la configuration

```bash
cd ~/docker-tp/opentelemetry
chmod +x validate-setup.sh test-traces.sh
./validate-setup.sh
```

### 2. Démarrage de la stack

```bash
docker compose up -d --build
```

Attendez environ 30 secondes que tous les services démarrent.

### 3. Vérification des services

```bash
docker compose ps
```

Tous les services doivent être "Up":
- otel-collector
- jaeger
- prometheus
- grafana
- demo-app
- python-api

### 4. Vérification de la santé

```bash
# OpenTelemetry Collector
curl http://localhost:13133/

# Demo App
curl http://localhost:8080/health

# Python API
curl http://localhost:5000/health
```

## 🧪 Tests

### Test automatique

```bash
./test-traces.sh
```

Ce script va :
1. Vérifier que tous les services sont accessibles
2. Tester les endpoints des deux applications
3. Générer du trafic
4. Vérifier les traces dans Jaeger
5. Vérifier les métriques dans Prometheus

### Tests manuels

#### Test de l'application Node.js

```bash
# Page d'accueil
curl http://localhost:8080/

# Liste des utilisateurs
curl http://localhost:8080/api/users

# Utilisateur spécifique
curl http://localhost:8080/api/users/1
```

#### Test de l'application Python

```bash
# Page d'accueil
curl http://localhost:5000/

# Liste des produits
curl http://localhost:5000/api/products

# Produit avec appel distribué vers Node.js
curl http://localhost:5000/api/products/1
```

#### Génération de trafic

```bash
# Script de génération de trafic varié
for i in {1..50}; do
  curl -s http://localhost:8080/api/users > /dev/null
  curl -s http://localhost:8080/api/users/$((RANDOM % 10 + 1)) > /dev/null
  curl -s http://localhost:5000/api/products > /dev/null
  curl -s http://localhost:5000/api/products/$((RANDOM % 5 + 1)) > /dev/null
  echo "Batch $i envoyé"
  sleep 1
done
```

## 🔍 Visualisation

### Jaeger (Traces)

**URL**: http://localhost:16686

**Tests à faire**:
1. Sélectionner le service "demo-app"
2. Cliquer sur "Find Traces"
3. Observer les traces avec leurs spans
4. Sélectionner une trace pour voir les détails
5. Vérifier les attributs (db.system, user.id, etc.)

**Trace distribuée**:
1. Sélectionner le service "python-api"
2. Opération: "GET /api/products/<int:product_id>"
3. Observer la trace qui traverse Python → Node.js
4. Vérifier la propagation du contexte

### Prometheus (Métriques)

**URL**: http://localhost:9090

**Requêtes à tester**:

```promql
# Taux de requêtes total
rate(http_requests_total[5m])

# Taux par endpoint
sum by (route) (rate(http_requests_total[5m]))

# Latence P95
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Services UP
up

# Métriques du collector
rate(otelcol_receiver_accepted_spans[5m])
```

### Grafana (Visualisation)

**URL**: http://localhost:3000

**Connexion**: Pas de login requis (auth anonyme activée)

**Tests à faire**:
1. Vérifier que les datasources sont configurées:
   - Prometheus (par défaut)
   - Jaeger
2. Créer un nouveau dashboard
3. Ajouter des panels avec les requêtes PromQL ci-dessus
4. Tester la navigation Grafana → Jaeger

## ✅ Validation des résultats

### 1. Traces dans Jaeger

- [ ] Services "demo-app" et "python-api" visibles
- [ ] Traces avec plusieurs spans
- [ ] Attributs personnalisés présents
- [ ] Traces distribuées fonctionnelles
- [ ] Durées cohérentes
- [ ] Service map visible

### 2. Métriques dans Prometheus

- [ ] Targets "otel-collector" UP
- [ ] Métriques http_requests_total disponibles
- [ ] Métriques http_request_duration_seconds disponibles
- [ ] Métriques custom (python_api_*) visibles
- [ ] Valeurs cohérentes avec le trafic

### 3. OpenTelemetry Collector

```bash
# Voir les logs du collector
docker compose logs -f otel-collector

# Vérifier les métriques du collector
curl http://localhost:8888/metrics | grep otelcol

# Health check
curl http://localhost:13133/
```

### 4. Architecture distribuée

Pour vérifier que les traces distribuées fonctionnent:

```bash
# Faire un appel qui traverse les deux services
curl http://localhost:5000/api/products/1

# Dans Jaeger, chercher cette trace
# Vous devriez voir:
# python-api: GET /api/products/1
#   ├─ get-product-by-id
#   │  ├─ database.query
#   │  └─ call-user-service
#   │     └─ demo-app: GET /api/users/1
#   │        └─ get-user-by-id
```

## 🐛 Debugging

### Service ne démarre pas

```bash
# Voir les logs
docker compose logs <service-name>

# Redémarrer un service
docker compose restart <service-name>

# Rebuild complet
docker compose down -v
docker compose up -d --build
```

### Pas de traces dans Jaeger

1. Vérifier que le collector reçoit des spans:
   ```bash
   docker compose logs otel-collector | grep -i span
   ```

2. Vérifier que les applications envoient bien au collector:
   ```bash
   docker compose logs demo-app | grep -i otel
   docker compose logs python-api | grep -i otel
   ```

3. Vérifier la connexion collector → jaeger:
   ```bash
   docker compose logs otel-collector | grep -i jaeger
   ```

### Pas de métriques dans Prometheus

1. Vérifier les targets Prometheus:
   ```bash
   curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
   ```

2. Vérifier l'endpoint du collector:
   ```bash
   curl http://localhost:8889/metrics | head -20
   ```

## 📊 Résultats attendus

### Trafic généré

Après avoir exécuté `test-traces.sh` ou généré du trafic manuellement:

- **Jaeger**: 50+ traces visibles
- **Prometheus**: Métriques avec des valeurs > 0
- **Grafana**: Graphiques avec des données

### Performance

Les applications sont instrumentées avec un overhead minimal:
- Latence additionnelle: < 10ms
- Utilisation CPU du collector: < 5%
- Utilisation mémoire du collector: < 200MB

## 🧹 Nettoyage

```bash
# Arrêter tous les services
docker compose down

# Supprimer aussi les volumes (données persistantes)
docker compose down -v

# Supprimer les images
docker compose down --rmi all -v
```

## 📝 Notes

### Points clés de la solution

1. **Auto-instrumentation**: Node.js et Python utilisent l'auto-instrumentation pour capturer automatiquement les requêtes HTTP
2. **Instrumentation manuelle**: Spans custom ajoutés pour les opérations métier
3. **Context propagation**: Headers W3C Trace Context propagés automatiquement
4. **Métriques custom**: Compteurs et histogrammes pour les métriques métier
5. **Sampling**: Tous les spans sont collectés (100%) pour la démo

### Améliorations possibles

Pour un environnement de production:
- Activer le tail sampling (voir TP14b-Solution.md)
- Ajouter TLS pour les communications
- Configurer des alertes Prometheus
- Ajouter Loki pour les logs
- Mettre en place un stockage long terme (Cassandra pour Jaeger)

## 🎯 Prochaines étapes

Après avoir validé ce setup:

1. Explorer les **exercices 5-7 du TP14b**:
   - Alertes avancées
   - Optimisation du sampling
   - Logs avec Loki

2. Créer des **dashboards Grafana** personnalisés

3. Configurer des **alertes** basées sur les SLO

4. Tester en **charge** avec des outils comme k6 ou Apache Bench

## 📚 Ressources

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/naming/)
- [Grafana Tutorials](https://grafana.com/tutorials/)

---

**Bonne exploration de l'observabilité avec OpenTelemetry! 🔭**
