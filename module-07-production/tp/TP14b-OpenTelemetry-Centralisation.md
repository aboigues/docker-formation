# TP14b : Centralisation avec OpenTelemetry

## Objectif

Mettre en place un système de centralisation et d'observabilité avec OpenTelemetry pour collecter et analyser les traces, métriques et logs de vos applications Docker.

## Durée estimée

120 minutes

---

## Introduction à OpenTelemetry

**OpenTelemetry** (OTel) est un standard open-source pour l'observabilité des applications. Il fournit une instrumentation unifiée pour collecter :
- **Traces** : suivi des requêtes à travers les services
- **Métriques** : données quantitatives sur les performances
- **Logs** : événements détaillés de l'application

### Architecture

```
Application → OpenTelemetry SDK → OpenTelemetry Collector → Backends
                                                             ├─ Jaeger (traces)
                                                             ├─ Prometheus (métriques)
                                                             └─ Loki (logs)
```

---

## Exercice 1 : Déploiement de l'infrastructure OpenTelemetry

### 1.1 - Stack complète d'observabilité

Créez un environnement avec OpenTelemetry Collector, Jaeger, Prometheus et Grafana.

```bash
mkdir -p ~/docker-tp/opentelemetry
cd ~/docker-tp/opentelemetry
```

```yaml
# docker-compose.yml
version: '3.8'

services:
  # OpenTelemetry Collector
  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.91.0
    command: ["--config=/etc/otel-collector-config.yaml"]
    volumes:
      - ./otel-collector-config.yaml:/etc/otel-collector-config.yaml
    ports:
      - "4317:4317"   # OTLP gRPC receiver
      - "4318:4318"   # OTLP HTTP receiver
      - "8888:8888"   # Prometheus metrics exposed by the collector
      - "8889:8889"   # Prometheus exporter metrics
      - "13133:13133" # health_check extension
    networks:
      - observability

  # Jaeger - Pour les traces
  jaeger:
    image: jaegertracing/all-in-one:1.52
    environment:
      - COLLECTOR_OTLP_ENABLED=true
    ports:
      - "16686:16686" # Jaeger UI
      - "14268:14268" # Jaeger collector
    networks:
      - observability

  # Prometheus - Pour les métriques
  prometheus:
    image: prom/prometheus:v2.48.0
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.enable-lifecycle'
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    networks:
      - observability

  # Grafana - Pour la visualisation
  grafana:
    image: grafana/grafana:10.2.2
    environment:
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
      - GF_AUTH_DISABLE_LOGIN_FORM=true
    volumes:
      - ./grafana-datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml
      - grafana_data:/var/lib/grafana
    ports:
      - "3000:3000"
    networks:
      - observability
    depends_on:
      - prometheus
      - jaeger

volumes:
  prometheus_data:
  grafana_data:

networks:
  observability:
    driver: bridge
```

### 1.2 - Configuration OpenTelemetry Collector

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

  # Recevoir les métriques Prometheus
  prometheus:
    config:
      scrape_configs:
        - job_name: 'otel-collector'
          scrape_interval: 10s
          static_configs:
            - targets: ['localhost:8888']

processors:
  batch:
    timeout: 10s
    send_batch_size: 1024

  memory_limiter:
    check_interval: 1s
    limit_mib: 512

  # Ajouter des attributs de ressource
  resource:
    attributes:
      - key: environment
        value: production
        action: upsert

exporters:
  # Export vers Jaeger pour les traces
  otlp/jaeger:
    endpoint: jaeger:4317
    tls:
      insecure: true

  # Export vers Prometheus pour les métriques
  prometheus:
    endpoint: "0.0.0.0:8889"
    namespace: "otel"

  # Export vers stdout pour debug
  logging:
    loglevel: info

  # Export métriques vers Prometheus
  prometheusremotewrite:
    endpoint: http://prometheus:9090/api/v1/write

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch, resource]
      exporters: [otlp/jaeger, logging]

    metrics:
      receivers: [otlp, prometheus]
      processors: [memory_limiter, batch, resource]
      exporters: [prometheus, logging]

    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch, resource]
      exporters: [logging]

  extensions: [health_check]

extensions:
  health_check:
    endpoint: 0.0.0.0:13133
```

### 1.3 - Configuration Prometheus

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['otel-collector:8888']
      - targets: ['otel-collector:8889']
```

### 1.4 - Configuration Grafana

```yaml
# grafana-datasources.yml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true

  - name: Jaeger
    type: jaeger
    access: proxy
    url: http://jaeger:16686
    editable: true
```

### 1.5 - Démarrage de la stack

```bash
cd ~/docker-tp/opentelemetry
docker compose up -d

# Vérifier que tous les services sont up
docker compose ps

# Vérifier les logs du collector
docker compose logs -f otel-collector
```

**Accès aux interfaces** :
- Grafana : http://localhost:3000
- Jaeger : http://localhost:16686
- Prometheus : http://localhost:9090

---

## Exercice 2 : Instrumentation d'une application Node.js

### 2.1 - Application exemple

```bash
mkdir -p ~/docker-tp/opentelemetry/app-nodejs
cd ~/docker-tp/opentelemetry/app-nodejs
```

```json
// package.json
{
  "name": "otel-demo-app",
  "version": "1.0.0",
  "type": "module",
  "dependencies": {
    "express": "^4.18.2",
    "@opentelemetry/api": "^1.7.0",
    "@opentelemetry/sdk-node": "^0.45.1",
    "@opentelemetry/auto-instrumentations-node": "^0.40.3",
    "@opentelemetry/exporter-trace-otlp-grpc": "^0.45.1",
    "@opentelemetry/exporter-metrics-otlp-grpc": "^0.45.1",
    "@opentelemetry/resources": "^1.19.0",
    "@opentelemetry/semantic-conventions": "^1.19.0"
  }
}
```

### 2.2 - Configuration OpenTelemetry

```javascript
// tracing.js
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-grpc';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-grpc';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';

const resource = new Resource({
  [SemanticResourceAttributes.SERVICE_NAME]: 'demo-app',
  [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
  [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: 'production',
});

const traceExporter = new OTLPTraceExporter({
  url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://otel-collector:4317',
});

const metricExporter = new OTLPMetricExporter({
  url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://otel-collector:4317',
});

const sdk = new NodeSDK({
  resource: resource,
  traceExporter: traceExporter,
  metricReader: new PeriodicExportingMetricReader({
    exporter: metricExporter,
    exportIntervalMillis: 10000,
  }),
  instrumentations: [
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-fs': {
        enabled: false,
      },
    }),
  ],
});

sdk.start();

process.on('SIGTERM', () => {
  sdk.shutdown()
    .then(() => console.log('Tracing terminated'))
    .catch((error) => console.log('Error terminating tracing', error))
    .finally(() => process.exit(0));
});

export default sdk;
```

### 2.3 - Application Express

```javascript
// server.js
import './tracing.js';
import express from 'express';
import { trace, metrics, SpanStatusCode } from '@opentelemetry/api';

const app = express();
const PORT = process.env.PORT || 8080;

// Obtenir le tracer et le meter
const tracer = trace.getTracer('demo-app');
const meter = metrics.getMeter('demo-app');

// Créer des métriques personnalisées
const requestCounter = meter.createCounter('http_requests_total', {
  description: 'Total number of HTTP requests',
});

const requestDuration = meter.createHistogram('http_request_duration_seconds', {
  description: 'HTTP request duration in seconds',
});

// Middleware pour mesurer la durée des requêtes
app.use((req, res, next) => {
  const startTime = Date.now();

  res.on('finish', () => {
    const duration = (Date.now() - startTime) / 1000;

    requestCounter.add(1, {
      method: req.method,
      route: req.route?.path || req.path,
      status: res.statusCode,
    });

    requestDuration.record(duration, {
      method: req.method,
      route: req.route?.path || req.path,
      status: res.statusCode,
    });
  });

  next();
});

// Routes
app.get('/', (req, res) => {
  res.json({ message: 'Hello OpenTelemetry!' });
});

app.get('/api/users', async (req, res) => {
  const span = tracer.startSpan('get-users');

  try {
    // Simuler un appel à une base de données
    await simulateDbQuery('SELECT * FROM users', 100);

    const users = [
      { id: 1, name: 'Alice' },
      { id: 2, name: 'Bob' },
    ];

    span.setAttributes({
      'db.system': 'postgresql',
      'db.operation': 'SELECT',
      'user.count': users.length,
    });

    span.setStatus({ code: SpanStatusCode.OK });
    res.json(users);
  } catch (error) {
    span.setStatus({
      code: SpanStatusCode.ERROR,
      message: error.message,
    });
    span.recordException(error);
    res.status(500).json({ error: 'Internal Server Error' });
  } finally {
    span.end();
  }
});

app.get('/api/users/:id', async (req, res) => {
  const span = tracer.startSpan('get-user-by-id');
  const userId = req.params.id;

  try {
    span.setAttribute('user.id', userId);

    // Simuler un appel à une base de données
    await simulateDbQuery(`SELECT * FROM users WHERE id = ${userId}`, 50);

    // Simuler un appel à un service externe
    const childSpan = tracer.startSpan('fetch-user-permissions', {
      parent: span,
    });

    await simulateExternalCall('permissions-service', 30);
    childSpan.end();

    const user = { id: userId, name: 'User ' + userId };

    span.setStatus({ code: SpanStatusCode.OK });
    res.json(user);
  } catch (error) {
    span.setStatus({
      code: SpanStatusCode.ERROR,
      message: error.message,
    });
    span.recordException(error);
    res.status(500).json({ error: 'Internal Server Error' });
  } finally {
    span.end();
  }
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

// Fonctions utilitaires pour simuler des opérations
async function simulateDbQuery(query, delay) {
  const span = tracer.startSpan('database.query');
  span.setAttributes({
    'db.statement': query,
    'db.system': 'postgresql',
  });

  await new Promise(resolve => setTimeout(resolve, delay));
  span.end();
}

async function simulateExternalCall(service, delay) {
  const span = tracer.startSpan('http.request');
  span.setAttributes({
    'http.method': 'GET',
    'http.url': `http://${service}/api`,
  });

  await new Promise(resolve => setTimeout(resolve, delay));
  span.end();
}

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

### 2.4 - Dockerfile

```dockerfile
# Dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 8080

CMD ["node", "server.js"]
```

### 2.5 - Ajout au docker-compose

Ajoutez ce service au `docker-compose.yml` principal :

```yaml
  # Application Node.js instrumentée
  demo-app:
    build: ./app-nodejs
    ports:
      - "8080:8080"
    environment:
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
      - OTEL_SERVICE_NAME=demo-app
      - OTEL_RESOURCE_ATTRIBUTES=environment=production
    networks:
      - observability
    depends_on:
      - otel-collector
```

### 2.6 - Test de l'instrumentation

```bash
# Redémarrer la stack
cd ~/docker-tp/opentelemetry
docker compose up -d --build

# Générer du trafic
curl http://localhost:8080/
curl http://localhost:8080/api/users
curl http://localhost:8080/api/users/1
curl http://localhost:8080/api/users/2

# Générer plusieurs requêtes pour voir les patterns
for i in {1..20}; do
  curl http://localhost:8080/api/users
  curl http://localhost:8080/api/users/$((RANDOM % 5 + 1))
  sleep 1
done
```

**Visualiser les résultats** :
- Ouvrez Jaeger : http://localhost:16686
- Sélectionnez le service "demo-app"
- Explorez les traces et leurs spans

---

## Exercice 3 : Application Python avec OpenTelemetry

### 3.1 - Application Flask

```bash
mkdir -p ~/docker-tp/opentelemetry/app-python
cd ~/docker-tp/opentelemetry/app-python
```

```python
# requirements.txt
flask==3.0.0
opentelemetry-api==1.21.0
opentelemetry-sdk==1.21.0
opentelemetry-instrumentation-flask==0.42b0
opentelemetry-instrumentation-requests==0.42b0
opentelemetry-exporter-otlp-proto-grpc==1.21.0
requests==2.31.0
```

```python
# app.py
from flask import Flask, jsonify
import requests
import time
import os

from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.semconv.resource import ResourceAttributes
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor

# Configuration du Resource
resource = Resource.create({
    ResourceAttributes.SERVICE_NAME: "python-api",
    ResourceAttributes.SERVICE_VERSION: "1.0.0",
    ResourceAttributes.DEPLOYMENT_ENVIRONMENT: "production",
})

# Configuration du Tracer
trace_provider = TracerProvider(resource=resource)
otlp_endpoint = os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT', 'otel-collector:4317')
trace_exporter = OTLPSpanExporter(endpoint=otlp_endpoint, insecure=True)
trace_provider.add_span_processor(BatchSpanProcessor(trace_exporter))
trace.set_tracer_provider(trace_provider)

# Configuration des Métriques
metric_reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(endpoint=otlp_endpoint, insecure=True)
)
meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
metrics.set_meter_provider(meter_provider)

# Créer l'application Flask
app = Flask(__name__)

# Instrumenter Flask automatiquement
FlaskInstrumentor().instrument_app(app)
RequestsInstrumentor().instrument()

# Obtenir tracer et meter
tracer = trace.get_tracer(__name__)
meter = metrics.get_meter(__name__)

# Créer des métriques personnalisées
request_counter = meter.create_counter(
    "python_api_requests_total",
    description="Total number of requests"
)

processing_time = meter.create_histogram(
    "python_api_processing_seconds",
    description="Processing time in seconds"
)

@app.route('/')
def home():
    request_counter.add(1, {"endpoint": "/", "method": "GET"})
    return jsonify({"message": "Python API with OpenTelemetry"})

@app.route('/api/products')
def get_products():
    with tracer.start_as_current_span("get-products") as span:
        start_time = time.time()

        span.set_attribute("db.system", "mongodb")
        span.set_attribute("product.count", 3)

        # Simuler une requête DB
        time.sleep(0.1)

        products = [
            {"id": 1, "name": "Laptop", "price": 999},
            {"id": 2, "name": "Mouse", "price": 25},
            {"id": 3, "name": "Keyboard", "price": 75},
        ]

        duration = time.time() - start_time
        processing_time.record(duration, {"endpoint": "/api/products"})
        request_counter.add(1, {"endpoint": "/api/products", "method": "GET"})

        return jsonify(products)

@app.route('/api/products/<int:product_id>')
def get_product(product_id):
    with tracer.start_as_current_span("get-product-by-id") as span:
        start_time = time.time()

        span.set_attribute("product.id", product_id)

        # Simuler une requête DB
        time.sleep(0.05)

        # Appeler l'API Node.js (service externe)
        with tracer.start_as_current_span("call-user-service") as child_span:
            try:
                # Appeler le service demo-app
                response = requests.get(
                    f"http://demo-app:8080/api/users/{product_id}",
                    timeout=2
                )
                child_span.set_attribute("http.status_code", response.status_code)
                user_data = response.json()
            except Exception as e:
                child_span.record_exception(e)
                user_data = None

        product = {
            "id": product_id,
            "name": f"Product {product_id}",
            "price": 100 * product_id,
            "owner": user_data
        }

        duration = time.time() - start_time
        processing_time.record(duration, {"endpoint": "/api/products/:id"})
        request_counter.add(1, {"endpoint": "/api/products/:id", "method": "GET"})

        return jsonify(product)

@app.route('/health')
def health():
    return jsonify({"status": "healthy"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
```

### 3.2 - Dockerfile Python

```dockerfile
# Dockerfile (dans app-python/)
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["python", "app.py"]
```

### 3.3 - Ajout au docker-compose

```yaml
  # Application Python instrumentée
  python-api:
    build: ./app-python
    ports:
      - "5000:5000"
    environment:
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
      - OTEL_SERVICE_NAME=python-api
    networks:
      - observability
    depends_on:
      - otel-collector
      - demo-app
```

### 3.4 - Test des traces distribuées

```bash
# Rebuild et redémarrer
docker compose up -d --build

# Tester l'appel qui traverse les deux services
curl http://localhost:5000/api/products/1

# Générer du trafic
for i in {1..10}; do
  curl http://localhost:5000/api/products
  curl http://localhost:5000/api/products/$((RANDOM % 5 + 1))
  sleep 1
done
```

**Vérification dans Jaeger** :
1. Ouvrez http://localhost:16686
2. Sélectionnez "python-api"
3. Recherchez une trace pour `/api/products/:id`
4. Vous devriez voir une trace qui traverse `python-api` → `demo-app`

---

## Exercice 4 : Dashboards Grafana

### 4.1 - Dashboard pour les métriques

1. Accédez à Grafana : http://localhost:3000
2. Créez un nouveau dashboard
3. Ajoutez les panels suivants :

**Panel 1 : Taux de requêtes HTTP**
```promql
rate(http_requests_total[5m])
```

**Panel 2 : Durée des requêtes (p95)**
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

**Panel 3 : Taux d'erreurs**
```promql
rate(http_requests_total{status=~"5.."}[5m])
```

**Panel 4 : Requêtes par endpoint**
```promql
sum by (route) (rate(http_requests_total[5m]))
```

### 4.2 - Dashboard avec Jaeger datasource

1. Ajoutez un panel de type "Traces"
2. Configurez pour afficher les dernières traces
3. Ajoutez des filtres par service et durée

### 4.3 - Export du dashboard

```bash
# Créer un fichier de dashboard
mkdir -p ~/docker-tp/opentelemetry/grafana-dashboards
```

Créez un fichier `dashboard.json` avec votre configuration.

---

## Exercice 5 : Monitoring avancé et alertes

### 5.1 - Ajout de règles d'alerte Prometheus

```yaml
# prometheus-rules.yml
groups:
  - name: application_alerts
    interval: 30s
    rules:
      - alert: HighErrorRate
        expr: |
          rate(http_requests_total{status=~"5.."}[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} req/s"

      - alert: HighLatency
        expr: |
          histogram_quantile(0.95,
            rate(http_request_duration_seconds_bucket[5m])
          ) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High latency detected"
          description: "P95 latency is {{ $value }}s"

      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service is down"
          description: "{{ $labels.job }} is down"
```

Mettez à jour `prometheus.yml` :

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - /etc/prometheus/prometheus-rules.yml

scrape_configs:
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['otel-collector:8888']
      - targets: ['otel-collector:8889']

  - job_name: 'demo-app'
    static_configs:
      - targets: ['demo-app:8080']

  - job_name: 'python-api'
    static_configs:
      - targets: ['python-api:5000']
```

### 5.2 - Ajout d'Alertmanager

```yaml
# Ajout au docker-compose.yml
  alertmanager:
    image: prom/alertmanager:v0.26.0
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml
    networks:
      - observability
```

```yaml
# alertmanager.yml
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'severity']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'default'

receivers:
  - name: 'default'
    webhook_configs:
      - url: 'http://localhost:5001/webhook'
        send_resolved: true
```

---

## Exercice 6 : Optimisation et best practices

### 6.1 - Sampling des traces

Modifiez `otel-collector-config.yaml` pour ajouter du sampling :

```yaml
processors:
  # ... autres processeurs ...

  # Probabilistic sampling - garde 10% des traces
  probabilistic_sampler:
    sampling_percentage: 10

  # Tail sampling - décisions intelligentes
  tail_sampling:
    policies:
      # Garder toutes les traces avec erreurs
      - name: error-policy
        type: status_code
        status_code:
          status_codes: [ERROR]

      # Garder les traces lentes
      - name: latency-policy
        type: latency
        latency:
          threshold_ms: 1000

      # Sampling probabiliste pour le reste
      - name: probabilistic-policy
        type: probabilistic
        probabilistic:
          sampling_percentage: 10

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, tail_sampling, batch, resource]
      exporters: [otlp/jaeger, logging]
```

### 6.2 - Configuration des resource limits

```yaml
# docker-compose.yml - Mise à jour des services
  otel-collector:
    # ... configuration existante ...
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
```

### 6.3 - Best practices OpenTelemetry

**Attributs de span recommandés** :
```javascript
span.setAttributes({
  // HTTP
  'http.method': 'GET',
  'http.url': '/api/users',
  'http.status_code': 200,

  // Database
  'db.system': 'postgresql',
  'db.statement': 'SELECT * FROM users',
  'db.operation': 'SELECT',

  // Service
  'service.version': '1.0.0',
  'deployment.environment': 'production',

  // Custom
  'user.id': 'user123',
  'business.transaction_id': 'tx456',
});
```

**Gestion des erreurs** :
```javascript
try {
  // ... opération ...
  span.setStatus({ code: SpanStatusCode.OK });
} catch (error) {
  span.setStatus({
    code: SpanStatusCode.ERROR,
    message: error.message,
  });
  span.recordException(error);
  throw error;
} finally {
  span.end();
}
```

---

## Exercice 7 : Logs avec OpenTelemetry

### 7.1 - Configuration de Loki

Ajoutez Loki pour la gestion des logs :

```yaml
# docker-compose.yml
  loki:
    image: grafana/loki:2.9.3
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    networks:
      - observability

  promtail:
    image: grafana/promtail:2.9.3
    volumes:
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock
      - ./promtail-config.yml:/etc/promtail/config.yml
    command: -config.file=/etc/promtail/config.yml
    networks:
      - observability
    depends_on:
      - loki
```

```yaml
# promtail-config.yml
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        target_label: 'container'
      - source_labels: ['__meta_docker_container_log_stream']
        target_label: 'stream'
```

### 7.2 - Mise à jour Grafana datasources

```yaml
# grafana-datasources.yml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true

  - name: Jaeger
    type: jaeger
    access: proxy
    url: http://jaeger:16686
    editable: true

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: true
```

### 7.3 - Corrélation Traces-Logs

Modifiez vos applications pour ajouter le trace ID dans les logs :

```javascript
// Node.js
import { trace } from '@opentelemetry/api';

app.use((req, res, next) => {
  const span = trace.getActiveSpan();
  if (span) {
    const traceId = span.spanContext().traceId;
    req.traceId = traceId;
  }
  next();
});

app.get('/api/users', (req, res) => {
  console.log(JSON.stringify({
    message: 'Fetching users',
    traceId: req.traceId,
    level: 'info'
  }));
  // ...
});
```

---

## 🏆 Validation

- [ ] Stack OpenTelemetry déployée (Collector, Jaeger, Prometheus, Grafana)
- [ ] Application Node.js instrumentée avec traces et métriques
- [ ] Application Python instrumentée avec traces distribuées
- [ ] Traces visibles dans Jaeger avec spans détaillés
- [ ] Métriques collectées dans Prometheus
- [ ] Dashboard Grafana créé avec visualisations
- [ ] Sampling configuré pour optimiser les performances
- [ ] Logs centralisés avec Loki
- [ ] Corrélation traces-logs fonctionnelle

---

## 📊 Checklist de production OpenTelemetry

```markdown
Configuration:
- [ ] Sampling approprié configuré (tail sampling recommandé)
- [ ] Resource limits définis pour le Collector
- [ ] Batch processor configuré (10s timeout recommandé)
- [ ] Memory limiter activé

Instrumentation:
- [ ] Auto-instrumentation activée quand possible
- [ ] Attributs sémantiques corrects (semantic conventions)
- [ ] Gestion des erreurs avec recordException
- [ ] Context propagation entre services

Sécurité:
- [ ] TLS activé en production
- [ ] Authentification configurée
- [ ] Données sensibles filtrées (PII)
- [ ] RBAC configuré dans Grafana

Performance:
- [ ] Sampling rate adapté au volume
- [ ] Exports asynchrones (batch mode)
- [ ] Retention configurée (Prometheus, Jaeger)
- [ ] Indexes optimisés (Jaeger)

Monitoring:
- [ ] Métriques du Collector surveillées
- [ ] Alertes configurées
- [ ] SLO/SLI définis
- [ ] Dashboards pour chaque service
```

---

## 📚 Ressources supplémentaires

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/naming/)

---

**[→ Voir les solutions](../solutions/TP14b-Solution.md)**

**[← Retour au TP14](./TP14-Production-Best-Practices.md)**

**[← Retour au README du module](../README.md)**
