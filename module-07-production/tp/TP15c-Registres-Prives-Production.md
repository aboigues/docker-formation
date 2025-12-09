# TP15c : Registres privés Docker - Production et haute disponibilité

## Objectif

Déployer et gérer un registre Docker en production avec haute disponibilité, monitoring, backup, et optimisations avancées.

## Durée estimée

120 minutes

## Prérequis

- TP15a et TP15b complétés
- Compréhension des concepts de haute disponibilité
- Docker Compose installé
- Connaissance de base en monitoring (Prometheus, Grafana)

## Concepts clés

```
┌──────────────────────────────────────────────────────────────┐
│    Architecture registre en production avec HA               │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│                    Load Balancer (nginx/HAProxy)             │
│                    ┌──────────────────┐                      │
│    Clients ──────▶ │   Port 443/5000  │                      │
│                    └────────┬─────────┘                      │
│                             │                                 │
│           ┌─────────────────┼─────────────────┐              │
│           ▼                 ▼                 ▼              │
│     ┌──────────┐      ┌──────────┐      ┌──────────┐        │
│     │Registry 1│      │Registry 2│      │Registry 3│        │
│     └────┬─────┘      └────┬─────┘      └────┬─────┘        │
│          │                 │                 │               │
│          └─────────────────┼─────────────────┘               │
│                            ▼                                  │
│                  Shared Storage Backend                       │
│                  ┌────────────────────┐                      │
│                  │  S3 / NFS / GCS    │                      │
│                  │  /var/lib/registry │                      │
│                  └────────────────────┘                      │
│                                                               │
│              Monitoring & Observability                       │
│     ┌──────────┐  ┌──────────┐  ┌───────────┐              │
│     │Prometheus│  │ Grafana  │  │   Logs    │              │
│     └──────────┘  └──────────┘  └───────────┘              │
│                                                               │
│  Caractéristiques production :                               │
│  • Haute disponibilité (multi-instances)                     │
│  • Stockage partagé (S3, NFS)                                │
│  • Load balancing                                             │
│  • Monitoring et alerting                                     │
│  • Backup automatique                                         │
│  • Garbage collection                                         │
│  • Cache et performance                                       │
│  • Disaster recovery                                          │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

---

## Exercice 1 : Storage backend - S3

### 1.1 - Setup MinIO (S3-compatible)

```bash
# Créer le répertoire du projet
mkdir -p ~/docker-registry-production
cd ~/docker-registry-production

# Créer docker-compose pour MinIO
cat > docker-compose-minio.yml << 'EOF'
version: '3.8'

services:
  minio:
    image: minio/minio:latest
    container_name: minio
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin123
    command: server /data --console-address ":9001"
    volumes:
      - minio-data:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3
    networks:
      - registry-network

volumes:
  minio-data:

networks:
  registry-network:
    driver: bridge
EOF

# Démarrer MinIO
docker-compose -f docker-compose-minio.yml up -d

# Attendre que MinIO soit prêt
sleep 5
echo "MinIO Console: http://localhost:9001 (minioadmin / minioadmin123)"
```

### 1.2 - Créer un bucket pour le registre

```bash
# Installer le client MinIO
docker run --rm --network registry-network \
  --entrypoint sh minio/mc -c "\
    mc alias set myminio http://minio:9000 minioadmin minioadmin123 && \
    mc mb myminio/registry-storage && \
    mc policy set download myminio/registry-storage && \
    mc ls myminio"

# Vérifier via l'interface web
echo "Vérifiez le bucket 'registry-storage' sur http://localhost:9001"
```

### 1.3 - Configurer le registre avec S3

```bash
mkdir -p ~/docker-registry-production/config

cat > config/registry-s3.yml << 'EOF'
version: 0.1

log:
  level: info
  formatter: json

storage:
  s3:
    accesskey: minioadmin
    secretkey: minioadmin123
    region: us-east-1
    regionendpoint: http://minio:9000
    bucket: registry-storage
    secure: false
    v4auth: true
    chunksize: 5242880
    rootdirectory: /
  cache:
    blobdescriptor: redis
  delete:
    enabled: true
  redirect:
    disable: true

http:
  addr: :5000
  secret: my-secret-change-this
  headers:
    X-Content-Type-Options: [nosniff]

health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3

redis:
  addr: redis:6379
  password: ""
  db: 0
  dialtimeout: 10ms
  readtimeout: 10ms
  writetimeout: 10ms
  pool:
    maxidle: 16
    maxactive: 64
    idletimeout: 300s
EOF

# Ajouter Redis et Registry au docker-compose
cat > docker-compose-registry-ha.yml << 'EOF'
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    container_name: registry-cache
    networks:
      - registry-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  registry-1:
    image: registry:2
    container_name: registry-1
    ports:
      - "5001:5000"
    volumes:
      - ./config/registry-s3.yml:/etc/docker/registry/config.yml
    environment:
      REGISTRY_HTTP_SECRET: my-secret-change-this
    depends_on:
      - redis
    networks:
      - registry-network
    restart: unless-stopped

  registry-2:
    image: registry:2
    container_name: registry-2
    ports:
      - "5002:5000"
    volumes:
      - ./config/registry-s3.yml:/etc/docker/registry/config.yml
    environment:
      REGISTRY_HTTP_SECRET: my-secret-change-this
    depends_on:
      - redis
    networks:
      - registry-network
    restart: unless-stopped

networks:
  registry-network:
    external: true
EOF

# Créer le réseau s'il n'existe pas
docker network create registry-network 2>/dev/null || true

# Démarrer les registres
docker-compose -f docker-compose-registry-ha.yml up -d

# Vérifier
sleep 5
curl http://localhost:5001/v2/
curl http://localhost:5002/v2/
```

### 1.4 - Tester le stockage partagé

```bash
# Push sur le premier registre
docker pull alpine:latest
docker tag alpine:latest localhost:5001/alpine:test
docker push localhost:5001/alpine:test

# Pull depuis le second registre (même storage S3)
docker rmi localhost:5001/alpine:test
docker pull localhost:5002/alpine:test

echo "✓ Le stockage est partagé entre les instances !"

# Vérifier dans MinIO
docker run --rm --network registry-network \
  --entrypoint sh minio/mc -c "\
    mc alias set myminio http://minio:9000 minioadmin minioadmin123 && \
    mc ls -r myminio/registry-storage"
```

---

## Exercice 2 : Load Balancing avec nginx

### 2.1 - Configuration nginx

```bash
mkdir -p ~/docker-registry-production/nginx

cat > nginx/nginx.conf << 'EOF'
upstream docker-registry {
    least_conn;
    server registry-1:5000 max_fails=3 fail_timeout=30s;
    server registry-2:5000 max_fails=3 fail_timeout=30s;
}

server {
    listen 5000;
    server_name localhost;

    # Disable any limits to avoid HTTP 413
    client_max_body_size 0;

    # Required to avoid HTTP 411
    chunked_transfer_encoding on;

    # Logging
    access_log /var/log/nginx/registry-access.log;
    error_log /var/log/nginx/registry-error.log;

    location / {
        proxy_pass http://docker-registry;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 900;

        # Health check
        proxy_next_upstream error timeout http_502 http_503 http_504;
    }

    # Health check endpoint
    location /nginx-health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

cat > nginx/Dockerfile << 'EOF'
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
EOF

# Build l'image nginx
cd nginx
docker build -t registry-nginx-lb .
cd ..

# Ajouter nginx au docker-compose
cat > docker-compose-full.yml << 'EOF'
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    container_name: registry-cache
    networks:
      - registry-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s

  registry-1:
    image: registry:2
    container_name: registry-1
    volumes:
      - ./config/registry-s3.yml:/etc/docker/registry/config.yml
    environment:
      REGISTRY_HTTP_SECRET: my-secret-change-this
    depends_on:
      - redis
    networks:
      - registry-network
    restart: unless-stopped

  registry-2:
    image: registry:2
    container_name: registry-2
    volumes:
      - ./config/registry-s3.yml:/etc/docker/registry/config.yml
    environment:
      REGISTRY_HTTP_SECRET: my-secret-change-this
    depends_on:
      - redis
    networks:
      - registry-network
    restart: unless-stopped

  nginx:
    image: registry-nginx-lb
    container_name: registry-lb
    ports:
      - "5000:5000"
    depends_on:
      - registry-1
      - registry-2
    networks:
      - registry-network
    restart: unless-stopped

networks:
  registry-network:
    external: true
EOF

# Redémarrer avec load balancer
docker-compose -f docker-compose-registry-ha.yml down
docker-compose -f docker-compose-full.yml up -d

# Tester le load balancer
sleep 5
curl http://localhost:5000/v2/
```

### 2.2 - Tester le load balancing

```bash
# Script pour tester la distribution de charge
cat > test-load-balancing.sh << 'EOF'
#!/bin/bash

echo "=== Test de Load Balancing ==="

for i in {1..10}; do
    echo "Requête $i:"
    curl -s http://localhost:5000/v2/ | jq .
    sleep 0.5
done

echo ""
echo "Vérification des logs nginx:"
docker logs registry-lb 2>&1 | tail -20
EOF

chmod +x test-load-balancing.sh
./test-load-balancing.sh

# Tester la haute disponibilité
echo "Test HA: Arrêt du registry-1"
docker stop registry-1

# Faire des requêtes (devraient fonctionner via registry-2)
for i in {1..5}; do
    curl -s http://localhost:5000/v2/ && echo " - OK"
    sleep 1
done

# Redémarrer registry-1
docker start registry-1
echo "✓ Haute disponibilité validée"
```

---

## Exercice 3 : Monitoring avec Prometheus et Grafana

### 3.1 - Configuration Prometheus

```bash
mkdir -p ~/docker-registry-production/{prometheus,grafana}

# Configuration Prometheus
cat > prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'docker-registry'
    static_configs:
      - targets: ['registry-1:5000', 'registry-2:5000']
    metrics_path: /metrics

  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx-exporter:9113']

  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']

  - job_name: 'minio'
    static_configs:
      - targets: ['minio:9000']
    metrics_path: /minio/v2/metrics/cluster
EOF

# Ajouter monitoring au docker-compose
cat > docker-compose-monitoring.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
    networks:
      - registry-network
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: admin123
      GF_USERS_ALLOW_SIGN_UP: "false"
    volumes:
      - grafana-data:/var/lib/grafana
    networks:
      - registry-network
    restart: unless-stopped

  redis-exporter:
    image: oliver006/redis_exporter:latest
    container_name: redis-exporter
    environment:
      REDIS_ADDR: redis:6379
    networks:
      - registry-network

  nginx-exporter:
    image: nginx/nginx-prometheus-exporter:latest
    container_name: nginx-exporter
    command:
      - '-nginx.scrape-uri=http://nginx:5000/nginx-health'
    networks:
      - registry-network

volumes:
  prometheus-data:
  grafana-data:

networks:
  registry-network:
    external: true
EOF

# Démarrer le monitoring
docker-compose -f docker-compose-monitoring.yml up -d

echo "Prometheus: http://localhost:9090"
echo "Grafana: http://localhost:3000 (admin/admin123)"
```

### 3.2 - Dashboard Grafana pour registre

```bash
# Créer un dashboard JSON pour Grafana
cat > grafana/registry-dashboard.json << 'EOF'
{
  "dashboard": {
    "title": "Docker Registry Monitoring",
    "tags": ["docker", "registry"],
    "timezone": "browser",
    "panels": [
      {
        "title": "Registry Requests Rate",
        "type": "graph",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{job}} - {{instance}}"
          }
        ]
      },
      {
        "title": "Storage Usage",
        "type": "graph",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      }
    ]
  }
}
EOF

echo "Dashboard créé dans grafana/registry-dashboard.json"
echo "Importez-le manuellement dans Grafana via UI"
```

### 3.3 - Alerting

```bash
# Configuration des alertes Prometheus
cat > prometheus/alerts.yml << 'EOF'
groups:
  - name: registry_alerts
    interval: 30s
    rules:
      - alert: RegistryDown
        expr: up{job="docker-registry"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Registry instance down"
          description: "Registry {{ $labels.instance }} is down for more than 1 minute"

      - alert: HighErrorRate
        expr: rate(http_requests_total{code=~"5.."}[5m]) > 0.05
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate on registry"
          description: "Error rate is {{ $value }} on {{ $labels.instance }}"

      - alert: HighStorageUsage
        expr: (registry_storage_used_bytes / registry_storage_total_bytes) > 0.85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High storage usage"
          description: "Storage usage is above 85%"
EOF

# Mettre à jour prometheus.yml pour inclure les alertes
cat >> prometheus/prometheus.yml << 'EOF'

rule_files:
  - 'alerts.yml'

alerting:
  alertmanagers:
    - static_configs:
        - targets: []
EOF
```

---

## Exercice 4 : Garbage Collection automatique

### 4.1 - Script de garbage collection

```bash
cat > ~/docker-registry-production/gc-script.sh << 'EOF'
#!/bin/bash

# Garbage Collection pour Docker Registry
# Ce script doit être exécuté régulièrement (cron)

REGISTRY_CONTAINER="registry-1"
LOG_FILE="/var/log/registry-gc.log"

echo "=== Garbage Collection - $(date) ===" | tee -a $LOG_FILE

# 1. Marquer les blobs à supprimer
echo "Phase 1: Marking blobs for deletion..." | tee -a $LOG_FILE
docker exec $REGISTRY_CONTAINER \
  bin/registry garbage-collect --dry-run \
  /etc/docker/registry/config.yml | tee -a $LOG_FILE

# 2. Exécuter le GC
echo "Phase 2: Running garbage collection..." | tee -a $LOG_FILE
docker exec $REGISTRY_CONTAINER \
  bin/registry garbage-collect \
  /etc/docker/registry/config.yml | tee -a $LOG_FILE

# 3. Vérifier l'espace libéré
echo "Phase 3: Checking freed space..." | tee -a $LOG_FILE
docker run --rm --network registry-network \
  --entrypoint sh minio/mc -c "\
    mc alias set myminio http://minio:9000 minioadmin minioadmin123 && \
    mc du myminio/registry-storage" | tee -a $LOG_FILE

echo "=== GC Complete - $(date) ===" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
EOF

chmod +x ~/docker-registry-production/gc-script.sh

# Tester le script
~/docker-registry-production/gc-script.sh
```

### 4.2 - Automatiser avec cron (dans un conteneur)

```bash
# Créer un conteneur cron pour le GC automatique
cat > ~/docker-registry-production/Dockerfile.cron << 'EOF'
FROM alpine:latest

RUN apk add --no-cache docker-cli dcron

COPY gc-script.sh /scripts/gc-script.sh
RUN chmod +x /scripts/gc-script.sh

# Cron job: chaque jour à 2h du matin
RUN echo "0 2 * * * /scripts/gc-script.sh" > /etc/crontabs/root

CMD ["crond", "-f", "-l", "2"]
EOF

# Build
cd ~/docker-registry-production
docker build -f Dockerfile.cron -t registry-gc-cron .

# Ajouter au docker-compose
cat >> docker-compose-full.yml << 'EOF'

  gc-cron:
    image: registry-gc-cron
    container_name: registry-gc
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./gc-script.sh:/scripts/gc-script.sh
    networks:
      - registry-network
    restart: unless-stopped
EOF

# Redémarrer
docker-compose -f docker-compose-full.yml up -d
```

---

## Exercice 5 : Backup et Disaster Recovery

### 5.1 - Backup automatique du registre

```bash
mkdir -p ~/docker-registry-production/backups

cat > ~/docker-registry-production/backup-registry.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="registry-backup-$TIMESTAMP"

echo "=== Starting Registry Backup - $TIMESTAMP ==="

# 1. Backup MinIO (S3) data
echo "Backing up S3 storage..."
docker run --rm --network registry-network \
  -v $(pwd)/backups:/backups \
  --entrypoint sh minio/mc -c "\
    mc alias set myminio http://minio:9000 minioadmin minioadmin123 && \
    mc mirror myminio/registry-storage /backups/$BACKUP_NAME"

# 2. Backup Redis cache (optionnel mais utile)
echo "Backing up Redis cache..."
docker exec registry-cache redis-cli SAVE
docker cp registry-cache:/data/dump.rdb backups/$BACKUP_NAME/redis-dump.rdb

# 3. Backup configurations
echo "Backing up configurations..."
tar czf backups/$BACKUP_NAME/configs.tar.gz \
  config/ nginx/ prometheus/ 2>/dev/null || true

# 4. Créer un manifest du backup
cat > backups/$BACKUP_NAME/manifest.txt << MANIFEST
Backup Date: $(date)
Backup Name: $BACKUP_NAME
Contents:
  - S3 Storage (images and layers)
  - Redis cache
  - Configuration files
MANIFEST

echo "Backup completed: $BACKUP_NAME"
ls -lh backups/$BACKUP_NAME/

# 5. Compresser le backup complet
cd backups
tar czf $BACKUP_NAME.tar.gz $BACKUP_NAME/
rm -rf $BACKUP_NAME/
cd ..

echo "=== Backup Complete: backups/$BACKUP_NAME.tar.gz ==="
EOF

chmod +x ~/docker-registry-production/backup-registry.sh

# Exécuter un backup
~/docker-registry-production/backup-registry.sh
```

### 5.2 - Restauration depuis backup

```bash
cat > ~/docker-registry-production/restore-registry.sh << 'EOF'
#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <backup-file.tar.gz>"
    echo "Available backups:"
    ls -lh backups/*.tar.gz 2>/dev/null || echo "No backups found"
    exit 1
fi

BACKUP_FILE="$1"
TEMP_DIR="/tmp/registry-restore"

echo "=== Restoring Registry from $BACKUP_FILE ==="

# 1. Extraire le backup
echo "Extracting backup..."
mkdir -p $TEMP_DIR
tar xzf $BACKUP_FILE -C $TEMP_DIR

# 2. Arrêter les services
echo "Stopping services..."
docker-compose -f docker-compose-full.yml down

# 3. Restaurer le storage S3
echo "Restoring S3 storage..."
# (Nécessite de vider le bucket d'abord)
docker run --rm --network registry-network \
  -v $TEMP_DIR:/restore \
  --entrypoint sh minio/mc -c "\
    mc alias set myminio http://minio:9000 minioadmin minioadmin123 && \
    mc rm -r --force myminio/registry-storage && \
    mc mb myminio/registry-storage && \
    mc mirror /restore/registry-storage myminio/registry-storage"

# 4. Restaurer les configs (si nécessaire)
echo "Restoring configurations..."
tar xzf $TEMP_DIR/configs.tar.gz -C ./ 2>/dev/null || true

# 5. Redémarrer les services
echo "Restarting services..."
docker-compose -f docker-compose-full.yml up -d

echo "=== Restore Complete ==="

# Cleanup
rm -rf $TEMP_DIR
EOF

chmod +x ~/docker-registry-production/restore-registry.sh

echo "Pour restaurer: ./restore-registry.sh backups/registry-backup-XXX.tar.gz"
```

### 5.3 - Backup vers un storage externe (exemple AWS S3)

```bash
cat > ~/docker-registry-production/backup-to-s3.sh << 'EOF'
#!/bin/bash

# Configuration AWS (à adapter)
AWS_BUCKET="my-registry-backups"
AWS_REGION="eu-west-1"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="registry-backup-$TIMESTAMP.tar.gz"

# Créer le backup local
./backup-registry.sh

# Upload vers S3 avec aws-cli
docker run --rm \
  -v $(pwd)/backups:/backups \
  -e AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY \
  amazon/aws-cli \
  s3 cp /backups/$BACKUP_NAME s3://$AWS_BUCKET/ --region $AWS_REGION

echo "Backup uploaded to S3: s3://$AWS_BUCKET/$BACKUP_NAME"

# Nettoyer les vieux backups locaux (garder 7 jours)
find backups/ -name "*.tar.gz" -mtime +7 -delete
EOF

chmod +x ~/docker-registry-production/backup-to-s3.sh
```

---

## Exercice 6 : Réplication entre registres

### 6.1 - Setup registre secondaire (DR site)

```bash
# Créer un second environnement de registre
mkdir -p ~/docker-registry-dr
cd ~/docker-registry-dr

# Copier les configs du registre principal
cp -r ~/docker-registry-production/config .
cp -r ~/docker-registry-production/nginx .

# Modifier la config pour le DR
sed -i 's/5000/6000/g' docker-compose-full.yml 2>/dev/null || true

# Pour une vraie réplication, utilisez Harbor ou configurez
# la réplication S3 entre buckets
```

### 6.2 - Synchronisation avec MinIO

```bash
# Configuration de réplication MinIO
cat > ~/docker-registry-production/setup-replication.sh << 'EOF'
#!/bin/bash

# Configurer la réplication entre deux sites MinIO
# Source: registre principal
# Target: registre DR

docker run --rm --network registry-network \
  --entrypoint sh minio/mc -c "\
    mc alias set source http://minio:9000 minioadmin minioadmin123 && \
    mc alias set target http://minio-dr:9000 minioadmin minioadmin123 && \
    mc replicate add source/registry-storage \
      --remote-bucket registry-storage \
      --priority 1 \
      --replicate 'existing-objects'"
EOF

chmod +x ~/docker-registry-production/setup-replication.sh
```

---

## Exercice 7 : Optimisation des performances

### 7.1 - Cache Redis avancé

```bash
# Configuration Redis optimisée
cat > redis/redis.conf << 'EOF'
# Memory
maxmemory 256mb
maxmemory-policy allkeys-lru

# Persistence (désactivée pour cache pur)
save ""
appendonly no

# Performance
tcp-backlog 511
timeout 0
tcp-keepalive 300

# Tuning
maxclients 10000
EOF

# Mettre à jour docker-compose
cat > docker-compose-redis-optimized.yml << 'EOF'
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    container_name: registry-cache
    command: redis-server /usr/local/etc/redis/redis.conf
    volumes:
      - ./redis/redis.conf:/usr/local/etc/redis/redis.conf
    networks:
      - registry-network
    restart: unless-stopped

networks:
  registry-network:
    external: true
EOF
```

### 7.2 - Configuration registry pour performance

```bash
cat > config/registry-optimized.yml << 'EOF'
version: 0.1

log:
  level: warn  # Réduit l'overhead des logs

storage:
  s3:
    accesskey: minioadmin
    secretkey: minioadmin123
    region: us-east-1
    regionendpoint: http://minio:9000
    bucket: registry-storage
    secure: false
    v4auth: true
    # Chunks plus petits pour uploads parallèles
    chunksize: 5242880
    # Multi-part upload
    multipartcopychunksize: 33554432
    multipartcopymaxconcurrency: 100
    multipartcopythresholdsize: 33554432

  cache:
    blobdescriptor: redis

  maintenance:
    # Nettoyage automatique des uploads incomplets
    uploadpurging:
      enabled: true
      age: 168h
      interval: 24h
      dryrun: false
    # Read-only mode pour maintenance
    readonly:
      enabled: false

http:
  addr: :5000
  # Secret pour session cookies
  secret: change-this-secret-key-please
  # Headers de sécurité
  headers:
    X-Content-Type-Options: [nosniff]
    X-Frame-Options: [deny]
  # HTTP/2 pour meilleures performances
  http2:
    disabled: false
  # Tuning
  debug:
    addr: :5001
    prometheus:
      enabled: true
      path: /metrics

# Cache Redis
redis:
  addr: redis:6379
  db: 0
  dialtimeout: 10ms
  readtimeout: 10ms
  writetimeout: 10ms
  pool:
    maxidle: 16
    maxactive: 64
    idletimeout: 300s

# Health checks
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
EOF
```

### 7.3 - Benchmarking

```bash
cat > ~/docker-registry-production/benchmark-registry.sh << 'EOF'
#!/bin/bash

echo "=== Registry Performance Benchmark ==="

# 1. Test de push
echo "Test 1: Push performance"
time for i in {1..10}; do
    docker tag alpine:latest localhost:5000/benchmark/alpine:$i
    docker push localhost:5000/benchmark/alpine:$i > /dev/null 2>&1
done

# 2. Test de pull
echo "Test 2: Pull performance"
docker rmi $(docker images -q localhost:5000/benchmark/*) 2>/dev/null
time for i in {1..10}; do
    docker pull localhost:5000/benchmark/alpine:$i > /dev/null 2>&1
done

# 3. Test API
echo "Test 3: API response time"
for i in {1..100}; do
    curl -s -o /dev/null -w "%{time_total}\n" http://localhost:5000/v2/_catalog
done | awk '{sum+=$1; count++} END {print "Average: " sum/count "s"}'

# 4. Test concurrent
echo "Test 4: Concurrent pulls"
time for i in {1..5}; do
    docker pull localhost:5000/benchmark/alpine:$i > /dev/null 2>&1 &
done
wait

echo "=== Benchmark Complete ==="
EOF

chmod +x ~/docker-registry-production/benchmark-registry.sh
```

---

## Exercice 8 : Sécurité avancée - Vulnerability Scanning

### 8.1 - Intégration Trivy pour scan de vulnérabilités

```bash
cat > ~/docker-registry-production/scan-registry-images.sh << 'EOF'
#!/bin/bash

REGISTRY="localhost:5000"

echo "=== Scanning all images in registry ==="

# Obtenir toutes les images
REPOS=$(curl -s http://$REGISTRY/v2/_catalog | jq -r '.repositories[]')

for repo in $REPOS; do
    TAGS=$(curl -s http://$REGISTRY/v2/$repo/tags/list | jq -r '.tags[]')

    for tag in $TAGS; do
        IMAGE="$REGISTRY/$repo:$tag"
        echo ""
        echo "Scanning: $IMAGE"

        # Scan avec Trivy
        docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy:latest image \
            --severity HIGH,CRITICAL \
            --no-progress \
            $IMAGE
    done
done

echo ""
echo "=== Scan Complete ==="
EOF

chmod +x ~/docker-registry-production/scan-registry-images.sh

# Exemple d'exécution
# ~/docker-registry-production/scan-registry-images.sh
```

### 8.2 - Webhook pour scan automatique

```bash
# Webhook listener qui scanne chaque nouvelle image
cat > ~/docker-registry-production/webhook-scanner.py << 'EOF'
from flask import Flask, request
import subprocess
import json

app = Flask(__name__)

@app.route('/webhook', methods=['POST'])
def webhook():
    data = request.json

    # Extraire info de l'image
    if data.get('events'):
        for event in data['events']:
            if event['action'] == 'push':
                repo = event['target']['repository']
                tag = event['target'].get('tag', 'latest')
                image = f"localhost:5000/{repo}:{tag}"

                print(f"New image pushed: {image}")

                # Lancer le scan
                subprocess.Popen([
                    'docker', 'run', '--rm',
                    '-v', '/var/run/docker.sock:/var/run/docker.sock',
                    'aquasec/trivy:latest', 'image',
                    '--severity', 'HIGH,CRITICAL',
                    image
                ])

    return {'status': 'ok'}, 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5002)
EOF

# Configuration registry pour webhooks
cat >> config/registry-optimized.yml << 'EOF'

notifications:
  endpoints:
    - name: webhook-scanner
      url: http://webhook-scanner:5002/webhook
      headers:
        Authorization: [Bearer <token>]
      timeout: 1s
      threshold: 5
      backoff: 1s
EOF
```

---

## Exercice 9 : Stack complète de production

### 9.1 - Docker Compose final

```bash
cd ~/docker-registry-production

cat > docker-compose-production.yml << 'EOF'
version: '3.8'

services:
  # Storage backend
  minio:
    image: minio/minio:latest
    container_name: minio
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: ${MINIO_PASSWORD:-minioadmin123}
    command: server /data --console-address ":9001"
    volumes:
      - minio-data:/data
    networks:
      - registry-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3
    restart: unless-stopped

  # Cache
  redis:
    image: redis:7-alpine
    container_name: registry-cache
    command: redis-server /usr/local/etc/redis/redis.conf
    volumes:
      - ./redis/redis.conf:/usr/local/etc/redis/redis.conf
    networks:
      - registry-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  # Registry instances
  registry-1:
    image: registry:2
    container_name: registry-1
    volumes:
      - ./config/registry-optimized.yml:/etc/docker/registry/config.yml
    environment:
      REGISTRY_HTTP_SECRET: ${REGISTRY_SECRET:-change-this-secret}
    depends_on:
      - redis
      - minio
    networks:
      - registry-network
    restart: unless-stopped
    labels:
      - "com.docker.registry.instance=1"

  registry-2:
    image: registry:2
    container_name: registry-2
    volumes:
      - ./config/registry-optimized.yml:/etc/docker/registry/config.yml
    environment:
      REGISTRY_HTTP_SECRET: ${REGISTRY_SECRET:-change-this-secret}
    depends_on:
      - redis
      - minio
    networks:
      - registry-network
    restart: unless-stopped
    labels:
      - "com.docker.registry.instance=2"

  # Load Balancer
  nginx:
    image: registry-nginx-lb
    container_name: registry-lb
    ports:
      - "5000:5000"
    depends_on:
      - registry-1
      - registry-2
    networks:
      - registry-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/nginx-health"]
      interval: 10s
      timeout: 5s
      retries: 3

  # Monitoring
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./prometheus/alerts.yml:/etc/prometheus/alerts.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
    networks:
      - registry-network
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD:-admin123}
      GF_USERS_ALLOW_SIGN_UP: "false"
    volumes:
      - grafana-data:/var/lib/grafana
    networks:
      - registry-network
    restart: unless-stopped

  # Exporters
  redis-exporter:
    image: oliver006/redis_exporter:latest
    container_name: redis-exporter
    environment:
      REDIS_ADDR: redis:6379
    networks:
      - registry-network
    restart: unless-stopped

  nginx-exporter:
    image: nginx/nginx-prometheus-exporter:latest
    container_name: nginx-exporter
    command:
      - '-nginx.scrape-uri=http://nginx:5000/nginx-health'
    networks:
      - registry-network
    restart: unless-stopped

volumes:
  minio-data:
  prometheus-data:
  grafana-data:

networks:
  registry-network:
    driver: bridge
EOF

# Fichier .env pour les secrets
cat > .env << 'EOF'
MINIO_PASSWORD=SuperSecureMinioPass123
REGISTRY_SECRET=registry-secret-key-change-this
GRAFANA_PASSWORD=GrafanaSecurePass456
EOF

chmod 600 .env

echo "Stack de production complète créée !"
echo "Démarrer avec: docker-compose -f docker-compose-production.yml up -d"
```

### 9.2 - Scripts d'administration

```bash
cat > ~/docker-registry-production/admin-tools.sh << 'EOF'
#!/bin/bash

# Toolkit d'administration du registre

case "$1" in
    status)
        echo "=== Registry Status ==="
        docker-compose -f docker-compose-production.yml ps
        ;;

    health)
        echo "=== Health Checks ==="
        curl -s http://localhost:5000/v2/ | jq .
        curl -s http://localhost:9090/-/healthy
        curl -s http://localhost:3000/api/health | jq .
        ;;

    stats)
        echo "=== Registry Statistics ==="
        echo "Total images:"
        curl -s http://localhost:5000/v2/_catalog | jq '.repositories | length'
        echo ""
        echo "Storage usage:"
        docker exec minio du -sh /data
        ;;

    backup)
        echo "=== Creating Backup ==="
        ./backup-registry.sh
        ;;

    gc)
        echo "=== Running Garbage Collection ==="
        ./gc-script.sh
        ;;

    logs)
        docker-compose -f docker-compose-production.yml logs -f --tail=100 $2
        ;;

    restart)
        echo "=== Restarting Registry ==="
        docker-compose -f docker-compose-production.yml restart registry-1 registry-2
        ;;

    *)
        echo "Usage: $0 {status|health|stats|backup|gc|logs|restart}"
        echo ""
        echo "Commands:"
        echo "  status  - Show all services status"
        echo "  health  - Check health of all services"
        echo "  stats   - Show registry statistics"
        echo "  backup  - Create a backup"
        echo "  gc      - Run garbage collection"
        echo "  logs    - Show logs (optionally specify service)"
        echo "  restart - Restart registry instances"
        exit 1
        ;;
esac
EOF

chmod +x ~/docker-registry-production/admin-tools.sh

echo "Admin tools disponibles via: ./admin-tools.sh"
```

---

## 🏆 Validation

À l'issue de ce TP, vous devez savoir :

- [ ] Configurer un registre avec storage S3/MinIO
- [ ] Mettre en place la haute disponibilité avec load balancing
- [ ] Implémenter le monitoring avec Prometheus et Grafana
- [ ] Configurer le garbage collection automatique
- [ ] Mettre en place des backups automatiques
- [ ] Optimiser les performances du registre
- [ ] Implémenter le scanning de vulnérabilités
- [ ] Déployer une stack complète de production

---

## 📊 Checklist Production

- [ ] Haute disponibilité (minimum 2 instances)
- [ ] Storage partagé (S3/NFS)
- [ ] Load balancer configuré
- [ ] HTTPS avec certificats valides
- [ ] Authentification activée
- [ ] Monitoring en place
- [ ] Alerting configuré
- [ ] Backups automatiques
- [ ] Garbage collection planifié
- [ ] Logs centralisés
- [ ] Documentation à jour
- [ ] Plan de disaster recovery testé

---

## 🚀 Aller plus loin

### Harbor - Solution entreprise complète

```bash
# Harbor est une solution clé en main qui inclut:
# - Registre Docker
# - UI web complète
# - RBAC avancé
# - Scanning de vulnérabilités
# - Réplication
# - Garbage collection
# - Notary (signature d'images)

wget https://github.com/goharbor/harbor/releases/download/v2.10.0/harbor-offline-installer-v2.10.0.tgz
tar xvf harbor-offline-installer-v2.10.0.tgz
cd harbor
./install.sh --with-trivy --with-chartmuseum
```

### Kubernetes deployment

Pour déployer le registre sur Kubernetes:
- Utilisez des StatefulSets
- Configurez des PersistentVolumeClaims
- Utilisez un Ingress pour le routing
- Implémentez HorizontalPodAutoscaler

---

## 🧹 Nettoyage

```bash
# Arrêter tous les services
cd ~/docker-registry-production
docker-compose -f docker-compose-production.yml down

# Supprimer les volumes
docker volume rm minio-data prometheus-data grafana-data registry-data

# Nettoyer les backups
rm -rf backups/

# Supprimer le répertoire
cd ~
rm -rf ~/docker-registry-production
```

---

**[← Retour : TP15b - Sécurité et authentification](TP15b-Registres-Prives-Securite.md)**

**[← Retour : TP15a - Fondamentaux](TP15a-Registres-Prives-Fondamentaux.md)**

**[→ Voir les solutions](../solutions/TP15c-Solution.md)**

**[← Retour au README du module](../README.md)**
