# Solutions - Module 5 : Docker Compose

## Structure docker-compose.yml

```yaml
version: '3.8'  # Version du format Compose

services:        # Définition des conteneurs
  nom-service:
    image: ou build:
    ports:       # Mapping de ports
    volumes:     # Montage de volumes
    environment: # Variables d'environnement
    networks:    # Réseaux
    depends_on:  # Dépendances
    restart:     # Politique de redémarrage

volumes:         # Volumes nommés
networks:        # Réseaux personnalisés
```

## TP11 - Solutions

### Exercice WordPress - Points clés

**depends_on vs condition**:
```yaml
# Simple: attend que le conteneur démarre
depends_on:
  - db

# Avancé: attend que le service soit healthy
depends_on:
  db:
    condition: service_healthy
```

**Restart policies**:
- `no`: Ne jamais redémarrer (défaut)
- `always`: Toujours redémarrer
- `on-failure`: Redémarrer seulement en cas d'erreur
- `unless-stopped`: Toujours sauf si arrêté manuellement

### Variables d'environnement - Ordre de priorité

```bash
# 1. Variables d'environnement du shell
export DB_PASSWORD=shell_value

# 2. Fichier .env
# DB_PASSWORD=env_file_value

# 3. environment dans docker-compose.yml
# DB_PASSWORD=compose_value

# 4. ARG dans Dockerfile

# Priorité: shell > .env > compose > dockerfile
```

### Scaling - Explications

```bash
# Scale manuel
docker compose up -d --scale api=3

# Pour le load balancing, Docker utilise le DNS round-robin
# Chaque requête vers "api" est distribuée entre les 3 instances
```

**Limitations du scaling**:
- Ne fonctionne pas avec des ports publiés
- Nécessite un load balancer (nginx, traefik, etc.)

### Healthchecks - Exemples complets

```yaml
services:
  db:
    image: postgres:15
    healthcheck:
      # Commande à exécuter
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      # Temps d'attente avant la première vérification
      start_period: 30s
      # Intervalle entre les vérifications
      interval: 10s
      # Timeout pour la commande
      timeout: 5s
      # Nombre d'échecs avant de considérer unhealthy
      retries: 3

  api:
    depends_on:
      db:
        condition: service_healthy
```

---

## TP12 - Solutions

### Stack MERN - Explications

**Architecture**:
```
┌─────────────────────────────────────┐
│          Nginx (Frontend)           │  Port 8080
└────────────┬────────────────────────┘
             │ Frontend Network
┌────────────▼────────────────────────┐
│         Express (Backend)           │  Port 5000
└────────────┬────────────────────────┘
             │ Backend Network
┌────────────▼────────────────────────┐
│           MongoDB                   │  Port 27017
└─────────────────────────────────────┘
```

**Isolation réseau**:
- Frontend: Nginx accessible de l'extérieur
- Backend: API accessible uniquement depuis frontend
- Database: MongoDB accessible uniquement depuis backend

### Monitoring Stack - Configuration Prometheus

```yaml
# prometheus.yml complet
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'my-cluster'
    environment: 'production'

scrape_configs:
  # Prometheus lui-même
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Métriques système
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  # Métriques Docker
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  # Application custom
  - job_name: 'app'
    static_configs:
      - targets: ['app:3000']
    metrics_path: '/metrics'

alerting:
  alertmanagers:
    - static_configs:
      - targets: ['alertmanager:9093']
```

### E-commerce Stack - Patterns avancés

**Pattern: Init containers**:
```yaml
services:
  db:
    image: postgres:15
    # ...

  db-init:
    image: postgres:15
    depends_on:
      db:
        condition: service_healthy
    command: >
      sh -c "
        psql -h db -U postgres -c 'CREATE DATABASE IF NOT EXISTS ecommerce';
        psql -h db -U postgres ecommerce -f /docker-entrypoint-initdb.d/schema.sql;
      "
    volumes:
      - ./init-scripts:/docker-entrypoint-initdb.d
    restart: "no"

  api:
    depends_on:
      db-init:
        condition: service_completed_successfully
```

**Pattern: Secrets management**:
```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  api:
    secrets:
      - db_password
      - api_key

secrets:
  db_password:
    file: ./secrets/db_password.txt
  api_key:
    external: true

# Accessible dans /run/secrets/db_password
```

---

## Patterns et astuces

### 1. Override intelligent

```yaml
# docker-compose.yml - Base commune
version: '3.8'
services:
  app:
    image: myapp:latest

# docker-compose.dev.yml - Dev overrides
services:
  app:
    build: .  # Override image avec build
    volumes:
      - ./src:/app/src
    command: npm run dev

# docker-compose.prod.yml - Prod overrides
services:
  app:
    deploy:
      replicas: 3
    logging:
      driver: syslog
```

Usage:
```bash
# Dev
docker compose -f docker-compose.yml -f docker-compose.dev.yml up

# Prod
docker compose -f docker-compose.yml -f docker-compose.prod.yml up
```

### 2. Wait-for-it pattern

```yaml
services:
  app:
    depends_on:
      db:
        condition: service_healthy
    # Alternative: script wait-for-it
    command: >
      sh -c "
        ./wait-for-it.sh db:5432 --timeout=30 --strict --
        npm start
      "
```

### 3. Configuration centralisée

```yaml
# Utiliser des configs (v3.3+)
configs:
  nginx_config:
    file: ./nginx.conf
  app_config:
    external: true

services:
  nginx:
    configs:
      - source: nginx_config
        target: /etc/nginx/nginx.conf
```

### 4. Extension fields (réutilisation)

```yaml
x-logging: &default-logging
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"

x-healthcheck: &default-healthcheck
  interval: 30s
  timeout: 10s
  retries: 3

services:
  app1:
    logging: *default-logging
    healthcheck: *default-healthcheck

  app2:
    logging: *default-logging
    healthcheck: *default-healthcheck
```

### 5. Build optimization

```yaml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.prod
      args:
        BUILD_DATE: ${BUILD_DATE}
        VERSION: ${VERSION}
      cache_from:
        - myapp:latest
      target: production
    image: myapp:${VERSION}
```

---

## Troubleshooting

### Problème: Services ne communiquent pas

**Solution**:
```bash
# Vérifier les réseaux
docker compose ps
docker network inspect <project>_<network>

# Vérifier le DNS
docker compose exec app1 ping app2
docker compose exec app1 nslookup app2

# Vérifier les logs
docker compose logs app1 app2
```

### Problème: Volumes non persistants

**Solution**:
```yaml
# ✗ MAL: Volume anonyme
services:
  db:
    volumes:
      - /var/lib/postgresql/data

# ✓ BIEN: Volume nommé
services:
  db:
    volumes:
      - db_data:/var/lib/postgresql/data

volumes:
  db_data:  # Déclaration nécessaire
```

### Problème: Variables d'environnement non reconnues

**Solution**:
```bash
# Vérifier les variables chargées
docker compose config

# Vérifier dans le conteneur
docker compose exec app env

# Forcer un fichier .env
docker compose --env-file prod.env up
```

---

## Commandes avancées

```bash
# Valider la configuration
docker compose config

# Voir seulement les changements
docker compose config --resolve-image-digests

# Exécuter une commande sur tous les services
docker compose ps -q | xargs docker inspect

# Nettoyer tout (conteneurs, volumes, réseaux)
docker compose down -v --remove-orphans

# Recréer seulement un service
docker compose up -d --force-recreate --no-deps app

# Voir les logs en direct avec timestamp
docker compose logs -f -t

# Lister les ports utilisés
docker compose ps --format json | jq '.[].Publishers'

# Scale multiple services
docker compose up -d --scale api=3 --scale worker=2
```

---

## Checklist Production

```markdown
Sécurité:
- [ ] Pas de secrets dans le docker-compose.yml
- [ ] Utiliser des secrets Docker ou .env
- [ ] Images à jour et scannées
- [ ] Utilisateurs non-root

Performance:
- [ ] Resource limits définis
- [ ] Healthchecks configurés
- [ ] Logging avec rotation
- [ ] Réseaux isolés

Fiabilité:
- [ ] Restart policy appropriée
- [ ] Depends_on avec healthcheck
- [ ] Volumes pour la persistance
- [ ] Backups configurés

Monitoring:
- [ ] Logs centralisés
- [ ] Métriques exposées
- [ ] Alertes configurées
- [ ] Dashboards prêts
```

---

**[← Retour aux TPs](../tp/)**
