# Solution TP14b : Centralisation avec OpenTelemetry

## Vue d'ensemble de la solution

Cette solution met en place une infrastructure complète d'observabilité basée sur OpenTelemetry, avec :
- **OpenTelemetry Collector** : collecte et traitement des signaux
- **Jaeger** : visualisation des traces distribuées
- **Prometheus** : stockage des métriques
- **Grafana** : dashboards et visualisation
- **Loki** : centralisation des logs
- Applications instrumentées (Node.js et Python)

---

## Exercice 1 : Infrastructure complète

### Structure des fichiers

```
opentelemetry/
├── docker-compose.yml
├── otel-collector-config.yaml
├── prometheus.yml
├── prometheus-rules.yml
├── grafana-datasources.yml
├── alertmanager.yml
├── promtail-config.yml
├── app-nodejs/
│   ├── package.json
│   ├── tracing.js
│   ├── server.js
│   └── Dockerfile
└── app-python/
    ├── requirements.txt
    ├── app.py
    └── Dockerfile
```

### Commandes de déploiement

```bash
# Créer la structure
mkdir -p ~/docker-tp/opentelemetry/{app-nodejs,app-python,grafana-dashboards}
cd ~/docker-tp/opentelemetry

# Copier tous les fichiers de configuration (voir TP)

# Démarrer la stack
docker compose up -d

# Vérifier la santé
docker compose ps
docker compose logs otel-collector | tail -20

# Test du collector
curl http://localhost:13133/
```

### Vérification des services

```bash
# Prometheus targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Jaeger health
curl http://localhost:16686/

# Grafana health
curl http://localhost:3000/api/health
```

---

## Exercice 2 : Application Node.js

### Installation et build

```bash
cd ~/docker-tp/opentelemetry/app-nodejs

# Créer package.json, tracing.js, server.js, Dockerfile
# (voir fichiers du TP)

# Build et démarrage
cd ~/docker-tp/opentelemetry
docker compose up -d --build demo-app

# Vérifier les logs
docker compose logs -f demo-app
```

### Tests et validation

```bash
# Test basique
curl http://localhost:8080/
# Réponse : {"message":"Hello OpenTelemetry!"}

curl http://localhost:8080/api/users
# Réponse : [{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]

# Générer du trafic varié
for i in {1..50}; do
  curl -s http://localhost:8080/ > /dev/null
  curl -s http://localhost:8080/api/users > /dev/null
  curl -s http://localhost:8080/api/users/$((RANDOM % 10 + 1)) > /dev/null
  echo "Request batch $i sent"
  sleep 0.5
done
```

### Analyse dans Jaeger

1. Ouvrir http://localhost:16686
2. Service : "demo-app"
3. Operation : "GET /api/users/:id"
4. Find Traces

**Points à observer** :
- Span principal avec la requête HTTP
- Span enfant "database.query"
- Span enfant "http.request" (appel externe)
- Durées de chaque opération
- Attributs personnalisés (user.id, db.system, etc.)

### Analyse dans Prometheus

```bash
# Requêtes PromQL utiles

# Taux de requêtes total
rate(http_requests_total[5m])

# Taux par endpoint
sum by (route) (rate(http_requests_total[5m]))

# P50, P95, P99 latency
histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))

# Taux d'erreurs (5xx)
rate(http_requests_total{status=~"5.."}[5m])
```

---

## Exercice 3 : Application Python avec traces distribuées

### Déploiement

```bash
cd ~/docker-tp/opentelemetry/app-python

# Créer requirements.txt, app.py, Dockerfile
# (voir fichiers du TP)

# Build et démarrage
cd ~/docker-tp/opentelemetry
docker compose up -d --build python-api

# Vérifier les logs
docker compose logs -f python-api
```

### Tests des traces distribuées

```bash
# Test qui traverse les deux services
curl http://localhost:5000/api/products/1

# Réponse attendue :
# {
#   "id": 1,
#   "name": "Product 1",
#   "price": 100,
#   "owner": {
#     "id": "1",
#     "name": "User 1"
#   }
# }

# Générer du trafic
for i in {1..30}; do
  curl -s http://localhost:5000/api/products > /dev/null
  curl -s http://localhost:5000/api/products/$((RANDOM % 5 + 1)) > /dev/null
  echo "Python API request $i"
  sleep 1
done
```

### Analyse des traces distribuées

**Dans Jaeger** :
1. Service : "python-api"
2. Operation : "GET /api/products/<int:product_id>"
3. Find Traces
4. Sélectionner une trace

**Structure de la trace** :
```
python-api: GET /api/products/1 (150ms)
  ├─ get-product-by-id (145ms)
  │  ├─ database.query (50ms)
  │  └─ call-user-service (80ms)
  │     └─ demo-app: GET /api/users/1 (75ms)
  │        ├─ get-user-by-id (70ms)
  │        │  ├─ database.query (30ms)
  │        │  └─ fetch-user-permissions (35ms)
```

**Points à observer** :
- Propagation automatique du context entre services
- Headers W3C Trace Context
- Durée totale de la transaction
- Cascades et dépendances
- Service Map dans Jaeger

### Debugging avec les traces

**Identifier les goulots d'étranglement** :
1. Trier les traces par durée (descendant)
2. Analyser les spans les plus lents
3. Vérifier les appels séquentiels vs parallèles

**Exemples de problèmes détectables** :
- N+1 queries (multiples appels DB séquentiels)
- Timeout sur services externes
- Retry loops
- Opérations bloquantes

---

## Exercice 4 : Dashboards Grafana

### Dashboard "Application Overview"

**Création** :
1. Grafana → Dashboards → New Dashboard
2. Add visualization

**Panel 1 : Request Rate**
```
Title: Requests per Second
Query: rate(http_requests_total[5m])
Legend: {{service}} - {{route}}
Type: Time series
```

**Panel 2 : Latency Percentiles**
```
Title: Response Time (Percentiles)
Queries:
  - histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))
  - histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
  - histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
Legend: P50, P95, P99
Type: Time series
```

**Panel 3 : Error Rate**
```
Title: Error Rate (5xx)
Query: rate(http_requests_total{status=~"5.."}[5m])
Type: Time series
Alert: > 0.05 for 5m
```

**Panel 4 : Request Distribution**
```
Title: Requests by Endpoint
Query: sum by (route) (rate(http_requests_total[5m]))
Type: Bar chart
```

**Panel 5 : Service Health**
```
Title: Services Up
Query: up
Type: Stat
Thresholds: 0 (red), 1 (green)
```

### Dashboard "Distributed Tracing"

**Panel 1 : Trace Duration Distribution**
```
Title: Trace Duration Distribution
Query: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))
Type: Heatmap
```

**Panel 2 : Service Dependencies**
```
Title: Service Call Graph
Type: Node Graph
Source: Jaeger datasource
```

**Panel 3 : Recent Traces Table**
```
Title: Recent Traces
Datasource: Jaeger
Type: Table
Filters: duration > 1s OR has error
```

### Variables de dashboard

Ajoutez des variables pour filtrer :

```
Variable: service
Query: label_values(http_requests_total, service)

Variable: environment
Query: label_values(http_requests_total, environment)

Variable: time_range
Type: Interval
Values: 5m,15m,1h,6h,24h
```

### Export du dashboard

```bash
# Depuis Grafana UI
Settings → JSON Model → Copy to clipboard

# Sauvegarder
cat > ~/docker-tp/opentelemetry/grafana-dashboards/application-overview.json <<'EOF'
{
  "dashboard": {
    "title": "Application Overview",
    // ... JSON complet ...
  }
}
EOF
```

### Import automatique au démarrage

```yaml
# docker-compose.yml - mise à jour du service grafana
  grafana:
    # ... config existante ...
    volumes:
      - ./grafana-datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml
      - ./grafana-dashboards:/etc/grafana/provisioning/dashboards
      - ./grafana-dashboard-provider.yml:/etc/grafana/provisioning/dashboards/provider.yml
```

```yaml
# grafana-dashboard-provider.yml
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
```

---

## Exercice 5 : Alertes

### Configuration complète

```yaml
# prometheus.yml (version complète)
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'production'
    environment: 'prod'

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

rule_files:
  - /etc/prometheus/prometheus-rules.yml

scrape_configs:
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['otel-collector:8888', 'otel-collector:8889']

  - job_name: 'demo-app'
    static_configs:
      - targets: ['demo-app:8080']
    scrape_interval: 10s

  - job_name: 'python-api'
    static_configs:
      - targets: ['python-api:5000']
    scrape_interval: 10s

  - job_name: 'jaeger'
    static_configs:
      - targets: ['jaeger:14269']

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
```

### Règles d'alerte avancées

```yaml
# prometheus-rules.yml (version complète)
groups:
  - name: application_alerts
    interval: 30s
    rules:
      # Taux d'erreurs élevé
      - alert: HighErrorRate
        expr: |
          (
            sum(rate(http_requests_total{status=~"5.."}[5m]))
            /
            sum(rate(http_requests_total[5m]))
          ) > 0.05
        for: 5m
        labels:
          severity: critical
          team: backend
        annotations:
          summary: "High error rate on {{ $labels.service }}"
          description: "Error rate is {{ $value | humanizePercentage }} on {{ $labels.service }}"
          runbook: "https://wiki.example.com/runbooks/high-error-rate"

      # Latence élevée (P95)
      - alert: HighLatencyP95
        expr: |
          histogram_quantile(0.95,
            sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service)
          ) > 1
        for: 5m
        labels:
          severity: warning
          team: backend
        annotations:
          summary: "High P95 latency on {{ $labels.service }}"
          description: "P95 latency is {{ $value }}s on {{ $labels.service }}"

      # Latence très élevée (P99)
      - alert: VeryHighLatencyP99
        expr: |
          histogram_quantile(0.99,
            sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service)
          ) > 3
        for: 5m
        labels:
          severity: critical
          team: backend
        annotations:
          summary: "Very high P99 latency on {{ $labels.service }}"
          description: "P99 latency is {{ $value }}s on {{ $labels.service }}"

      # Service down
      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
          team: ops
        annotations:
          summary: "Service {{ $labels.job }} is down"
          description: "{{ $labels.job }} on {{ $labels.instance }} has been down for more than 1 minute"

      # Trafic anormal
      - alert: TrafficDrop
        expr: |
          (
            sum(rate(http_requests_total[5m]))
            /
            sum(rate(http_requests_total[5m] offset 1h))
          ) < 0.5
        for: 10m
        labels:
          severity: warning
          team: ops
        annotations:
          summary: "Traffic drop detected"
          description: "Traffic has dropped by {{ $value | humanizePercentage }} compared to 1 hour ago"

      # OpenTelemetry Collector issues
      - alert: OtelCollectorHighMemory
        expr: |
          process_memory_rss{job="otel-collector"} > 1073741824
        for: 5m
        labels:
          severity: warning
          team: ops
        annotations:
          summary: "OTel Collector high memory usage"
          description: "Collector is using {{ $value | humanize1024 }}B of memory"

      - alert: OtelCollectorDroppedSpans
        expr: |
          rate(otelcol_processor_dropped_spans[5m]) > 10
        for: 5m
        labels:
          severity: warning
          team: ops
        annotations:
          summary: "OTel Collector dropping spans"
          description: "Collector is dropping {{ $value }} spans/s"

  - name: business_alerts
    interval: 1m
    rules:
      # Exemple d'alerte métier
      - alert: LowUserActivity
        expr: |
          sum(rate(http_requests_total{route="/api/users"}[5m])) < 1
        for: 15m
        labels:
          severity: info
          team: product
        annotations:
          summary: "Low user API activity"
          description: "User API has less than 1 req/s for 15 minutes"
```

### Configuration Alertmanager

```yaml
# alertmanager.yml (version complète)
global:
  resolve_timeout: 5m
  slack_api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'

templates:
  - '/etc/alertmanager/templates/*.tmpl'

route:
  # Route principale
  receiver: 'default'
  group_by: ['alertname', 'service', 'severity']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h

  # Routes spécifiques
  routes:
    # Alertes critiques → Slack + PagerDuty
    - match:
        severity: critical
      receiver: critical-alerts
      continue: false

    # Alertes warning → Slack
    - match:
        severity: warning
      receiver: warning-alerts
      continue: false

    # Alertes info → Email
    - match:
        severity: info
      receiver: info-alerts
      continue: false

receivers:
  - name: 'default'
    webhook_configs:
      - url: 'http://localhost:5001/webhook'
        send_resolved: true

  - name: 'critical-alerts'
    slack_configs:
      - channel: '#alerts-critical'
        title: '🚨 Critical Alert'
        text: |
          {{ range .Alerts }}
          *Alert:* {{ .Labels.alertname }}
          *Service:* {{ .Labels.service }}
          *Description:* {{ .Annotations.description }}
          *Runbook:* {{ .Annotations.runbook }}
          {{ end }}
        send_resolved: true
    # pagerduty_configs:
    #   - service_key: 'YOUR_PAGERDUTY_KEY'

  - name: 'warning-alerts'
    slack_configs:
      - channel: '#alerts-warning'
        title: '⚠️ Warning Alert'
        text: |
          {{ range .Alerts }}
          *Alert:* {{ .Labels.alertname }}
          *Service:* {{ .Labels.service }}
          *Description:* {{ .Annotations.description }}
          {{ end }}
        send_resolved: true

  - name: 'info-alerts'
    email_configs:
      - to: 'team@example.com'
        from: 'alertmanager@example.com'
        smarthost: 'smtp.example.com:587'
        auth_username: 'alertmanager'
        auth_password: 'password'
        headers:
          Subject: 'Info: {{ .GroupLabels.alertname }}'

inhibit_rules:
  # Inhiber les alertes warning si critical existe
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'service']

  # Inhiber toutes les alertes si service down
  - source_match:
      alertname: 'ServiceDown'
    target_match_re:
      alertname: '.*'
    equal: ['service']
```

### Test des alertes

```bash
# Générer une erreur pour tester l'alerte
for i in {1..100}; do
  # Appeler un endpoint qui n'existe pas (génère des 404)
  curl http://localhost:8080/api/nonexistent
  sleep 0.1
done

# Vérifier les alertes dans Prometheus
curl http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | {alert: .labels.alertname, state: .state}'

# Vérifier Alertmanager
curl http://localhost:9093/api/v1/alerts | jq '.data[] | {alert: .labels.alertname, status: .status.state}'
```

---

## Exercice 6 : Optimisation

### Configuration optimisée du Collector

```yaml
# otel-collector-config.yaml (version optimisée production)
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
        max_recv_msg_size_mib: 16
        max_concurrent_streams: 100
        read_buffer_size: 524288
        write_buffer_size: 524288
      http:
        endpoint: 0.0.0.0:4318
        max_request_body_size: 10485760

  prometheus:
    config:
      scrape_configs:
        - job_name: 'otel-collector'
          scrape_interval: 10s
          static_configs:
            - targets: ['localhost:8888']

processors:
  # Limite de mémoire
  memory_limiter:
    check_interval: 1s
    limit_mib: 512
    spike_limit_mib: 128

  # Batch pour optimiser l'export
  batch:
    timeout: 10s
    send_batch_size: 1024
    send_batch_max_size: 2048

  # Tail sampling intelligent
  tail_sampling:
    decision_wait: 10s
    num_traces: 100000
    expected_new_traces_per_sec: 1000
    policies:
      # Toujours garder les erreurs
      - name: error-traces
        type: status_code
        status_code:
          status_codes: [ERROR]

      # Garder les traces lentes
      - name: slow-traces
        type: latency
        latency:
          threshold_ms: 1000

      # Garder certains endpoints importants
      - name: critical-endpoints
        type: string_attribute
        string_attribute:
          key: http.route
          values: ["/api/payment", "/api/checkout"]

      # Sampling probabiliste pour le reste
      - name: probabilistic-policy
        type: probabilistic
        probabilistic:
          sampling_percentage: 10

  # Filtrer les attributs sensibles
  attributes:
    actions:
      - key: password
        action: delete
      - key: api_key
        action: delete
      - key: authorization
        action: delete
      - key: credit_card
        action: delete

  # Ajouter des métadonnées
  resource:
    attributes:
      - key: environment
        value: production
        action: upsert
      - key: cluster
        value: eu-west-1
        action: upsert

  # Déduplication
  resource/deduplicate:
    attributes:
      - key: duplicate_attribute
        action: delete

exporters:
  # Jaeger avec retry
  otlp/jaeger:
    endpoint: jaeger:4317
    tls:
      insecure: true
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
      max_elapsed_time: 300s
    sending_queue:
      enabled: true
      num_consumers: 10
      queue_size: 1000

  # Prometheus
  prometheus:
    endpoint: "0.0.0.0:8889"
    namespace: "otel"
    const_labels:
      environment: "production"

  # Logging pour debug (désactiver en prod)
  logging:
    loglevel: warn
    sampling_initial: 5
    sampling_thereafter: 200

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, tail_sampling, attributes, batch, resource]
      exporters: [otlp/jaeger]

    metrics:
      receivers: [otlp, prometheus]
      processors: [memory_limiter, batch, resource]
      exporters: [prometheus]

    logs:
      receivers: [otlp]
      processors: [memory_limiter, attributes, batch, resource]
      exporters: [logging]

  telemetry:
    logs:
      level: info
    metrics:
      level: detailed
      address: 0.0.0.0:8888

  extensions: [health_check, zpages]

extensions:
  health_check:
    endpoint: 0.0.0.0:13133

  zpages:
    endpoint: 0.0.0.0:55679
```

### Monitoring du Collector lui-même

```bash
# Métriques du collector
curl http://localhost:8888/metrics

# ZPages pour debug
curl http://localhost:55679/debug/tracez
curl http://localhost:55679/debug/pipelinez
```

**Dashboard Grafana pour le Collector** :
```promql
# Spans reçus
rate(otelcol_receiver_accepted_spans[5m])

# Spans droppés
rate(otelcol_processor_dropped_spans[5m])

# Utilisation mémoire
process_memory_rss{job="otel-collector"}

# Queue length
otelcol_exporter_queue_size
```

---

## Exercice 7 : Logs avec Loki

### Déploiement complet

```bash
# Ajouter au docker-compose.yml
docker compose up -d loki promtail

# Vérifier
docker compose logs loki | tail
docker compose logs promtail | tail
```

### Requêtes LogQL

**Dans Grafana → Explore → Loki** :

```logql
# Tous les logs de demo-app
{container="demo-app"}

# Logs d'erreur
{container="demo-app"} |= "error" or "ERROR"

# Logs avec trace ID
{container="demo-app"} | json | traceId != ""

# Taux d'erreurs
rate({container="demo-app"} |= "error" [5m])

# Top 10 des messages
topk(10, sum by (message) (rate({container="demo-app"} [5m])))
```

### Corrélation Traces-Logs

**Dans Grafana** :
1. Dashboard → Add panel
2. Data source: Loki
3. Query: `{container="demo-app"} | json`
4. Transform → Extract fields: traceId
5. Data links → Add link:
   - Title: "View trace"
   - URL: `http://localhost:16686/trace/${__value.raw}`

**Résultat** : Cliquer sur un log ouvre la trace correspondante dans Jaeger.

### Dashboard "Logs & Traces"

```
Panel 1: Log volume by container
Query: sum by (container) (rate({job="docker"}[5m]))

Panel 2: Error logs
Query: {job="docker"} |= "error"
Type: Logs

Panel 3: Trace correlation
Query: {container="demo-app"} | json | traceId != ""
Type: Table with trace links
```

---

## Validation finale

### Script de validation

```bash
#!/bin/bash
# validate-otel-setup.sh

echo "=== OpenTelemetry Setup Validation ==="
echo ""

# 1. Services health
echo "1. Checking services..."
for service in otel-collector jaeger prometheus grafana demo-app python-api; do
  status=$(docker compose ps $service --format json | jq -r '.[0].Health // .[0].State')
  echo "  $service: $status"
done
echo ""

# 2. Collector health
echo "2. Collector health..."
curl -s http://localhost:13133/ | jq '.'
echo ""

# 3. Generate test traffic
echo "3. Generating test traffic..."
for i in {1..5}; do
  curl -s http://localhost:8080/api/users > /dev/null
  curl -s http://localhost:5000/api/products/1 > /dev/null
done
echo "  Test traffic sent"
echo ""

# 4. Check traces in Jaeger
echo "4. Checking traces in Jaeger..."
TRACES=$(curl -s "http://localhost:16686/api/traces?service=demo-app&limit=5" | jq '.data | length')
echo "  Found $TRACES traces in demo-app"
echo ""

# 5. Check metrics in Prometheus
echo "5. Checking metrics in Prometheus..."
METRICS=$(curl -s 'http://localhost:9090/api/v1/query?query=up' | jq '.data.result | length')
echo "  Found $METRICS targets UP"
echo ""

# 6. Check Grafana datasources
echo "6. Checking Grafana datasources..."
curl -s http://localhost:3000/api/datasources | jq '.[] | {name: .name, type: .type}'
echo ""

echo "=== Validation Complete ==="
```

```bash
chmod +x validate-otel-setup.sh
./validate-otel-setup.sh
```

### Checklist finale

```markdown
Infrastructure:
✓ OpenTelemetry Collector démarré et healthy
✓ Jaeger accessible sur port 16686
✓ Prometheus accessible sur port 9090
✓ Grafana accessible sur port 3000
✓ Loki et Promtail démarrés

Applications:
✓ demo-app (Node.js) instrumenté et fonctionnel
✓ python-api instrumenté et fonctionnel
✓ Traces visibles dans Jaeger
✓ Métriques visibles dans Prometheus

Traces:
✓ Spans avec attributs corrects
✓ Traces distribuées entre services
✓ Context propagation fonctionnel
✓ Error tracking actif

Métriques:
✓ Métriques HTTP collectées
✓ Métriques custom visibles
✓ Histogrammes configurés
✓ Targets Prometheus UP

Visualisation:
✓ Dashboards Grafana créés
✓ Panels avec queries PromQL
✓ Service map visible
✓ Corrélation traces-logs

Alertes:
✓ Règles d'alerte configurées
✓ Alertmanager fonctionnel
✓ Test d'alerte réussi

Optimisation:
✓ Sampling configuré
✓ Batch processor actif
✓ Memory limiter configuré
✓ Resource limits définis

Production:
✓ Attributs sensibles filtrés
✓ Retention configurée
✓ Monitoring du collector
✓ Documentation à jour
```

---

## Commandes utiles

### Debug

```bash
# Voir les logs du collector en temps réel
docker compose logs -f otel-collector

# Voir les spans reçus
docker compose logs otel-collector | grep "Span"

# Vérifier la configuration
docker compose exec otel-collector cat /etc/otel-collector-config.yaml

# Restart un service
docker compose restart demo-app

# Stats en temps réel
docker stats
```

### Cleanup

```bash
# Arrêter tout
docker compose down

# Supprimer les volumes
docker compose down -v

# Rebuild from scratch
docker compose down -v
docker compose build --no-cache
docker compose up -d
```

### Export des données

```bash
# Export Prometheus snapshot
curl -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot

# Export traces Jaeger (exemple)
curl "http://localhost:16686/api/traces?service=demo-app&start=$(date -d '1 hour ago' +%s)000000&end=$(date +%s)000000" | jq '.' > traces-export.json
```

---

## Points clés de la solution

### Architecture

1. **OpenTelemetry Collector** = point central de collecte
   - Reçoit les données des applications (OTLP)
   - Traite (batch, sampling, enrichment)
   - Exporte vers les backends

2. **Multi-backend** = flexibilité
   - Jaeger pour les traces (visualisation)
   - Prometheus pour les métriques (stockage TSDB)
   - Grafana pour la visualisation unifiée
   - Loki pour les logs

3. **Instrumentation** = observabilité native
   - Auto-instrumentation quand possible
   - Instrumentation manuelle pour le business context
   - Propagation automatique du context

### Best practices appliquées

1. **Tail sampling** = intelligence + économie
   - Garder 100% des erreurs
   - Garder 100% des traces lentes
   - Sampling 10% du reste

2. **Attributs sémantiques** = standardisation
   - Utiliser les conventions OpenTelemetry
   - Ajouter du contexte métier
   - Faciliter les requêtes cross-service

3. **Resource limits** = stabilité
   - Limiter la mémoire du collector
   - Configurer les queues
   - Activer les retry policies

4. **Sécurité** = protection
   - Filtrer les données sensibles
   - TLS en production
   - RBAC dans Grafana

---

## Aller plus loin

### Améliorations possibles

1. **HA et scalabilité**
   ```yaml
   # Plusieurs collectors
   otel-collector-1:
     # ... config ...
   otel-collector-2:
     # ... config ...

   # Load balancer
   nginx:
     # ... route vers collectors ...
   ```

2. **Stockage long terme**
   - Thanos pour Prometheus
   - Cassandra pour Jaeger
   - S3 pour Loki

3. **Sécurité avancée**
   - TLS mutual authentication
   - OAuth pour Grafana
   - Vault pour les secrets

4. **CI/CD integration**
   ```yaml
   # .github/workflows/deploy.yml
   - name: Check traces after deploy
     run: |
       ./scripts/check-traces.sh
       ./scripts/validate-metrics.sh
   ```

---

**Félicitations !** Vous avez mis en place une infrastructure d'observabilité complète avec OpenTelemetry.

**[← Retour au TP14b](../tp/TP14b-OpenTelemetry-Centralisation.md)**

**[← Retour au README du module](../README.md)**
