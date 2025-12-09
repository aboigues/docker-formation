# Exemples TP14b - OpenTelemetry

Ce dossier contient des exemples complets et prêts à l'emploi pour le TP14b sur OpenTelemetry.

## 📁 Contenu

```
opentelemetry/
├── docker-compose.yml              # Orchestration complète (7 services)
├── otel-collector-config.yaml      # Configuration OpenTelemetry Collector
├── prometheus.yml                  # Configuration Prometheus
├── grafana-datasources.yml         # Datasources Grafana (auto-provisioning)
│
├── app-nodejs/                     # Application Node.js instrumentée
│   ├── package.json
│   ├── tracing.js                  # Configuration OpenTelemetry
│   ├── server.js                   # API Express avec traces
│   └── Dockerfile
│
├── app-python/                     # Application Python instrumentée
│   ├── requirements.txt
│   ├── app.py                      # Flask avec traces distribuées
│   └── Dockerfile
│
├── validate-setup.sh               # Script de validation de la config
├── test-traces.sh                  # Script de test automatique
├── QUICK-START.md                  # Guide de démarrage rapide
└── README-TEST.md                  # Documentation complète de test
```

## 🚀 Utilisation rapide

### 1. Copier les fichiers dans votre répertoire de travail

```bash
# Depuis la racine du repository
cp -r module-07-production/exemples/opentelemetry ~/docker-tp/
cd ~/docker-tp/opentelemetry
```

### 2. Valider la configuration

```bash
chmod +x validate-setup.sh test-traces.sh
./validate-setup.sh
```

### 3. Démarrer la stack

```bash
docker compose up -d --build
```

**Note**: Le premier démarrage peut prendre 1-2 minutes pour télécharger les images et construire les applications.

### 4. Attendre que tout soit prêt

```bash
# Vérifier le statut
docker compose ps

# Tous les services doivent être "Up"
```

### 5. Lancer les tests

```bash
# Attendre environ 30 secondes après le démarrage, puis:
./test-traces.sh
```

## 🌐 Accès aux interfaces

Une fois la stack démarrée, accédez aux interfaces web:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Grafana** | http://localhost:3000 | Auto-login (pas de credentials) |
| **Jaeger** | http://localhost:16686 | Pas de login |
| **Prometheus** | http://localhost:9090 | Pas de login |
| **Demo App (Node.js)** | http://localhost:8080 | - |
| **Python API** | http://localhost:5000 | - |

## 🧪 Tests rapides

### Test des applications

```bash
# Application Node.js
curl http://localhost:8080/
curl http://localhost:8080/api/users
curl http://localhost:8080/api/users/1

# Application Python
curl http://localhost:5000/
curl http://localhost:5000/api/products
curl http://localhost:5000/api/products/1  # ← Trace distribuée!
```

### Générer du trafic

```bash
for i in {1..20}; do
  curl -s http://localhost:8080/api/users > /dev/null
  curl -s http://localhost:5000/api/products/$i > /dev/null
  echo "Batch $i envoyé"
  sleep 1
done
```

## 📊 Visualiser les résultats

### Dans Jaeger (Traces)

1. Ouvrir http://localhost:16686
2. **Service** → Sélectionner `python-api`
3. **Operation** → Sélectionner `GET /api/products/<int:product_id>`
4. Cliquer sur **Find Traces**
5. Sélectionner une trace pour voir le détail

**Ce que vous verrez** :
- Une trace qui commence dans `python-api`
- Un span qui appelle `demo-app` (Node.js)
- La propagation du contexte entre les deux services
- Les attributs détaillés (db.system, http.status_code, etc.)

### Dans Prometheus (Métriques)

1. Ouvrir http://localhost:9090
2. Dans la barre de requête, essayer:

```promql
# Taux de requêtes
rate(http_requests_total[5m])

# Latence P95
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Services UP
up
```

### Dans Grafana (Dashboards)

1. Ouvrir http://localhost:3000
2. **Menu** → **Dashboards** → **New Dashboard**
3. **Add visualization**
4. **Data source** → Prometheus
5. Ajouter une requête PromQL (exemples ci-dessus)

## 🎯 Ce que démontre cet exemple

### Architecture
- ✅ OpenTelemetry Collector comme point central
- ✅ Exportation vers multiples backends (Jaeger, Prometheus)
- ✅ Auto-provisioning Grafana avec datasources

### Applications
- ✅ Node.js avec auto-instrumentation HTTP
- ✅ Python Flask avec auto-instrumentation
- ✅ Spans personnalisés pour les opérations métier
- ✅ Métriques custom (compteurs et histogrammes)

### Traces distribuées
- ✅ Context propagation automatique (W3C Trace Context)
- ✅ Appels inter-services tracés
- ✅ Corrélation des spans entre microservices

### Production-ready
- ✅ Batch processing pour optimiser l'export
- ✅ Memory limiter pour éviter les OOM
- ✅ Health checks sur tous les services
- ✅ Resource attributes pour le contexte

## 🛠️ Commandes utiles

```bash
# Voir les logs du collector
docker compose logs -f otel-collector

# Voir les logs d'une application
docker compose logs -f demo-app
docker compose logs -f python-api

# Redémarrer un service
docker compose restart demo-app

# Arrêter la stack
docker compose down

# Nettoyer complètement (avec volumes)
docker compose down -v

# Rebuild et redémarrer
docker compose down
docker compose up -d --build
```

## 🐛 Dépannage

### Les services ne démarrent pas

```bash
# Vérifier les logs
docker compose logs

# Vérifier les erreurs spécifiques
docker compose logs otel-collector
docker compose logs demo-app
```

### Pas de traces dans Jaeger

1. Vérifier que les applications envoient bien des traces:
   ```bash
   docker compose logs demo-app | grep -i otel
   ```

2. Vérifier que le collector reçoit des spans:
   ```bash
   docker compose logs otel-collector | grep -i span
   ```

3. Générer du trafic et attendre 10-15 secondes

### Ports déjà utilisés

Si un port est déjà utilisé, modifiez `docker-compose.yml`:

```yaml
ports:
  - "3001:3000"  # Au lieu de 3000:3000
```

## 📚 Documentation complète

- **QUICK-START.md** : Guide de démarrage en 3 minutes
- **README-TEST.md** : Documentation détaillée avec tous les tests possibles
- **[TP14b](../tp/TP14b-OpenTelemetry-Centralisation.md)** : Énoncé complet du TP
- **[Solution TP14b](../solutions/TP14b-Solution.md)** : Solution détaillée avec explications

## 🎓 Pour aller plus loin

Après avoir testé cet exemple, explorez les exercices avancés du TP14b:

1. **Exercice 5** : Alertes avec Prometheus et Alertmanager
2. **Exercice 6** : Optimisation avec tail sampling
3. **Exercice 7** : Centralisation des logs avec Loki

## 💡 Conseils

- **Premier test** : Utilisez `./test-traces.sh` pour tout valider automatiquement
- **Exploration** : Prenez le temps d'explorer Jaeger et les traces distribuées
- **Expérimentation** : Modifiez le code des applications pour ajouter vos propres spans
- **Production** : Étudiez la configuration du collector pour comprendre les best practices

## 📝 Notes

- Les applications sont volontairement simples pour se concentrer sur l'observabilité
- Le sampling est à 100% pour la démo (à ajuster en production)
- Les données sont en mémoire (non persistées après redémarrage)
- La configuration est optimisée pour l'apprentissage, pas pour la production à grande échelle

---

**Besoin d'aide ?** Consultez les fichiers README-TEST.md et la solution complète du TP14b.

**Prêt à explorer l'observabilité avec OpenTelemetry ? 🔭**
