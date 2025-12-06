# TP14 : Docker en production - Best practices

## Objectif

Préparer et sécuriser des applications Docker pour la production.

## Durée estimée

120 minutes

---

## Exercice 1 : Healthchecks avancés

### 1.1 - Healthcheck multi-niveau

```yaml
version: '3.8'

services:
  api:
    build: ./api
    # Note: curl doit être installé dans le Dockerfile de l'API
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3

  db:
    image: postgres:15-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d myapp"]
      interval: 10s
      timeout: 5s
      retries: 5
    volumes:
      - db_data:/var/lib/postgresql/data

  redis:
    image: redis:alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 3

volumes:
  db_data:
```

### 1.2 - Endpoint de health personnalisé

```javascript
// healthcheck.js
const http = require('http');

const options = {
  host: 'localhost',
  port: 3000,
  path: '/health',
  timeout: 2000
};

const healthCheck = http.request(options, (res) => {
  console.log(`STATUS: ${res.statusCode}`);
  if (res.statusCode == 200) {
    process.exit(0);
  } else {
    process.exit(1);
  }
});

healthCheck.on('error', (err) => {
  console.error('ERROR:', err);
  process.exit(1);
});

healthCheck.end();
```

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY . .
HEALTHCHECK --interval=30s CMD node healthcheck.js
CMD ["node", "server.js"]
```

---

## Exercice 2 : Logging en production

### 2.1 - Configuration des logs

```yaml
version: '3.8'

services:
  app:
    image: myapp:latest
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        labels: "app,environment"
        tag: "{{.Name}}/{{.ID}}"

  nginx:
    image: nginx:alpine
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://logstash:5000"
        tag: "nginx"
```

### 2.2 - Centralized logging avec ELK

```bash
mkdir -p ~/docker-tp/production-logging
cd ~/docker-tp/production-logging

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
      - xpack.security.enabled=false
    volumes:
      - es_data:/usr/share/elasticsearch/data
    networks:
      - logging

  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline
    ports:
      - "5000:5000"
    environment:
      LS_JAVA_OPTS: "-Xmx256m -Xms256m"
    networks:
      - logging
    depends_on:
      - elasticsearch

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    ports:
      - "5601:5601"
    environment:
      ELASTICSEARCH_HOSTS: http://elasticsearch:9200
    networks:
      - logging
    depends_on:
      - elasticsearch

  # Application qui envoie des logs
  app:
    image: nginx:alpine
    logging:
      driver: syslog
      options:
        syslog-address: "tcp://127.0.0.1:5000"
        tag: "nginx"
    ports:
      - "8080:80"
    networks:
      - logging

volumes:
  es_data:

networks:
  logging:
EOF
```

---

## Exercice 3 : Sécurité

### 3.1 - Dockerfile sécurisé

```dockerfile
# Multi-stage build pour minimiser l'image
FROM node:18-alpine AS builder
WORKDIR /build
COPY package*.json ./
RUN npm ci --only=production && \
    npm cache clean --force
COPY . .
RUN npm run build

# Runtime image
FROM node:18-alpine

# Installer dumb-init pour proper signal handling
RUN apk add --no-cache dumb-init

# Créer utilisateur non-root
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Créer répertoires avec bonnes permissions
WORKDIR /app
RUN chown -R nodejs:nodejs /app

# Copier artifacts
COPY --from=builder --chown=nodejs:nodejs /build/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /build/node_modules ./node_modules
COPY --chown=nodejs:nodejs package*.json ./

# Passer à utilisateur non-root
USER nodejs

# Security headers
ENV NODE_ENV=production

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node healthcheck.js || exit 1

# Exposer port
EXPOSE 3000

# Utiliser dumb-init comme PID 1
ENTRYPOINT ["dumb-init", "--"]

# Commande
CMD ["node", "dist/server.js"]
```

### 3.2 - Docker Compose sécurisé

```yaml
version: '3.8'

services:
  app:
    build: .
    read_only: true
    tmpfs:
      - /tmp
      - /var/run
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    security_opt:
      - no-new-privileges:true
    pids_limit: 100
    deploy:
      resources:
        limits:
          cpus: '0.50'
          memory: 512M
        reservations:
          memory: 256M
    environment:
      NODE_ENV: production
    secrets:
      - db_password
      - api_key
    networks:
      - frontend
      - backend

  db:
    image: postgres:15-alpine
    read_only: true
    tmpfs:
      - /tmp
      - /var/run/postgresql
    volumes:
      - db_data:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
    networks:
      - backend

secrets:
  db_password:
    file: ./secrets/db_password.txt
  api_key:
    file: ./secrets/api_key.txt

volumes:
  db_data:

networks:
  frontend:
    driver: bridge
  backend:
    internal: true
```

---

## Exercice 4 : Secrets management

### 4.1 - Docker secrets (Swarm)

```bash
# Initialiser Swarm mode
docker swarm init

# Créer des secrets
echo "supersecretpassword" | docker secret create db_password -
echo "api-key-12345" | docker secret create api_key -

# Lister les secrets
docker secret ls

# Utiliser dans un service
docker service create \
  --name myapp \
  --secret db_password \
  --secret api_key \
  myapp:latest

# Les secrets sont disponibles dans /run/secrets/
```

### 4.2 - Alternative : Vault

```yaml
version: '3.8'

services:
  vault:
    image: vault:latest
    ports:
      - "8200:8200"
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: myroot
      VAULT_DEV_LISTEN_ADDRESS: 0.0.0.0:8200
    cap_add:
      - IPC_LOCK

  app:
    image: myapp:latest
    environment:
      VAULT_ADDR: http://vault:8200
      VAULT_TOKEN: myroot
    depends_on:
      - vault
```

---

## Exercice 5 : Resource limits et QoS

### 5.1 - Limites de ressources

```yaml
version: '3.8'

services:
  web:
    image: nginx:alpine
    deploy:
      resources:
        limits:
          cpus: '0.50'      # Max 50% d'un CPU
          memory: 512M      # Max 512MB RAM
        reservations:
          cpus: '0.25'      # Minimum 25% CPU
          memory: 256M      # Minimum 256MB RAM
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
        window: 120s

  db:
    image: postgres:15-alpine
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 1G
    # Prioriser la base de données
    mem_swappiness: 0
    oom_score_adj: -500
```

### 5.2 - Monitoring des ressources

```bash
# Voir l'utilisation en temps réel
docker stats

# Limites au runtime
docker run -d \
  --name limited-app \
  --cpus="0.5" \
  --memory="512m" \
  --memory-swap="1g" \
  --pids-limit=100 \
  myapp:latest
```

---

## Exercice 6 : Backup et disaster recovery

### 6.1 - Script de backup

```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Backup volumes
for volume in $(docker volume ls -q); do
  echo "Backing up volume: $volume"
  docker run --rm \
    -v $volume:/source:ro \
    -v $BACKUP_DIR:/backup \
    alpine \
    tar czf /backup/${volume}_${DATE}.tar.gz -C /source .
done

# Backup images
echo "Backing up images..."
docker save $(docker images -q) | gzip > $BACKUP_DIR/images_${DATE}.tar.gz

# Backup configs
cp docker-compose.yml $BACKUP_DIR/docker-compose_${DATE}.yml
cp .env $BACKUP_DIR/env_${DATE}

# Cleanup old backups (keep 7 days)
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR"
```

### 6.2 - Restauration

```bash
#!/bin/bash
# restore.sh

BACKUP_FILE=$1

# Créer le volume si nécessaire
VOLUME_NAME=$(basename $BACKUP_FILE | sed 's/_.*//g')
docker volume create $VOLUME_NAME

# Restaurer
docker run --rm \
  -v $VOLUME_NAME:/target \
  -v $(pwd):/backup \
  alpine \
  sh -c "cd /target && tar xzf /backup/$BACKUP_FILE"

echo "Restored $BACKUP_FILE to volume $VOLUME_NAME"
```

---

## Exercice 7 : Blue-Green Deployment

### 7.1 - Pattern Blue-Green

```yaml
version: '3.8'

services:
  # Version Blue (actuelle)
  app-blue:
    image: myapp:1.0
    environment:
      VERSION: blue
    networks:
      - app-net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app.rule=Host(`app.example.com`)"
      - "traefik.http.services.app.loadbalancer.server.port=3000"

  # Version Green (nouvelle)
  app-green:
    image: myapp:2.0
    environment:
      VERSION: green
    networks:
      - app-net
    labels:
      - "traefik.enable=false"  # Désactivée initialement

  # Load balancer
  traefik:
    image: traefik:v2.10
    command:
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
    ports:
      - "80:80"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - app-net

networks:
  app-net:
```

**Procédure de basculement**:
```bash
# 1. Déployer green
docker compose up -d app-green

# 2. Tester green
curl -H "Host: app-green.example.com" http://localhost

# 3. Basculer le trafic
docker compose exec traefik sh
# Mettre à jour les labels...

# 4. Arrêter blue
docker compose stop app-blue
```

---

## Exercice 8 : Checklist de production

### 8.1 - Validation avant déploiement

```bash
#!/bin/bash
# production-checklist.sh

IMAGE=$1

echo "=== Production Readiness Check ==="
echo ""

# 1. Taille
SIZE=$(docker images $IMAGE --format '{{.Size}}')
echo "1. Image Size: $SIZE"
[[ "$SIZE" == *GB* ]] && echo "   ⚠️  WARNING: Large image"

# 2. Scan de sécurité
echo "2. Security Scan:"
docker scout cves $IMAGE --only-severity critical,high 2>/dev/null || echo "   ⚠️  Scanner not available"

# 3. Healthcheck
HC=$(docker inspect $IMAGE --format '{{.Config.Healthcheck}}')
[[ "$HC" == "<nil>" ]] && echo "3. Healthcheck: ✗ MISSING" || echo "3. Healthcheck: ✓ Present"

# 4. User
USER=$(docker inspect $IMAGE --format '{{.Config.User}}')
[[ -z "$USER" || "$USER" == "root" ]] && echo "4. User: ✗ ROOT" || echo "4. User: ✓ $USER"

# 5. Secrets
SECRETS=$(docker inspect $IMAGE --format '{{.Config.Env}}' | grep -i "password\|secret\|key")
[[ -n "$SECRETS" ]] && echo "5. Secrets: ⚠️  Found in ENV" || echo "5. Secrets: ✓ Not in ENV"

# 6. Versioning
VERSION=$(docker inspect $IMAGE --format '{{index .Config.Labels "org.opencontainers.image.version"}}')
echo "6. Version: ${VERSION:-⚠️  Not labeled}"

# 7. Resources
echo "7. Resource Limits:"
docker run --rm $IMAGE sh -c "ulimit -a" 2>/dev/null | grep -E "cpu|memory" || echo "   ⚠️  Check Docker Compose"

echo ""
echo "=== Summary ==="
```

---

## 🏆 Validation

- [ ] Configuré des healthchecks robustes
- [ ] Mis en place un logging centralisé
- [ ] Sécurisé les images et conteneurs
- [ ] Géré les secrets correctement
- [ ] Configuré les resource limits
- [ ] Créé des scripts de backup
- [ ] Implémenté un pattern de déploiement
- [ ] Validé avec la checklist production

---

## 📊 Checklist finale de production

```markdown
Sécurité:
- [ ] Images scannées (pas de CVE critical/high)
- [ ] Utilisateur non-root
- [ ] Secrets dans vault/secrets, pas dans ENV
- [ ] Read-only filesystem quand possible
- [ ] Capabilities minimales (cap_drop: ALL)
- [ ] no-new-privileges activé
- [ ] Network isolation (backend internal)

Performance:
- [ ] Resource limits définis
- [ ] Images multi-stage (< 100MB si possible)
- [ ] Health checks configurés
- [ ] PID limits définis

Fiabilité:
- [ ] Restart policy configurée
- [ ] Depends_on avec conditions
- [ ] Backups automatisés
- [ ] Monitoring en place
- [ ] Logs centralisés

Opérations:
- [ ] Labels OCI complets
- [ ] Documentation à jour
- [ ] Runbook de déploiement
- [ ] Procédure de rollback
- [ ] Alertes configurées
```

---

**[→ Voir les solutions](../solutions/TP14-Solution.md)**

**[← Retour au README du module](../README.md)**
