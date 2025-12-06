# TP13 : Portainer et interfaces d'administration

## Objectif

Mettre en place et utiliser des interfaces graphiques pour administrer Docker.

## Durée estimée

90 minutes

---

## Exercice 1 : Portainer

### 1.1 - Installation de Portainer

```bash
# Créer un volume pour Portainer
docker volume create portainer_data

# Démarrer Portainer
docker run -d \
  -p 9000:9000 \
  -p 9443:9443 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

# Accéder à https://localhost:9443
# Créer un compte admin
```

### 1.2 - Configuration initiale

**Étapes dans Portainer UI**:
1. Créer un utilisateur admin
2. Sélectionner "Local" environment
3. Explorer le dashboard

**Fonctionnalités principales**:
- Dashboard : Vue d'ensemble
- Containers : Gestion des conteneurs
- Images : Gestion des images
- Networks : Gestion des réseaux
- Volumes : Gestion des volumes
- Stacks : Docker Compose via UI

### 1.3 - Déployer une stack depuis Portainer

```yaml
# Dans Portainer > Stacks > Add stack
version: '3.8'

services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - web_data:/usr/share/nginx/html

  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_PASSWORD: password
    volumes:
      - db_data:/var/lib/postgresql/data

volumes:
  web_data:
  db_data:
```

---

## Exercice 2 : Monitoring avec cAdvisor et Prometheus

### 2.1 - Stack de monitoring complète

```bash
mkdir -p ~/docker-tp/monitoring
cd ~/docker-tp/monitoring

# Prometheus config
mkdir -p prometheus
cat > prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
EOF

# Docker Compose
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus:/etc/prometheus
      - prometheus_data:/prometheus
    restart: always

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana
    depends_on:
      - prometheus
    restart: always

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    privileged: true
    restart: always

  node-exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    restart: always

volumes:
  prometheus_data:
  grafana_data:
EOF

docker compose up -d

# Accès:
# Prometheus: http://localhost:9090
# Grafana: http://localhost:3000 (admin/admin)
# cAdvisor: http://localhost:8080
```

### 2.2 - Configurer Grafana

**Étapes**:

1. **Ajouter Prometheus comme source de données**:
   - Configuration > Data Sources > Add data source
   - Sélectionner Prometheus
   - URL: `http://prometheus:9090`
   - Save & Test

2. **Importer un dashboard**:
   - Dashboards > Import
   - ID: 193 (Docker dashboard)
   - Sélectionner Prometheus data source
   - Import

3. **Créer un dashboard personnalisé**:
   - Dashboards > New Dashboard
   - Add visualization
   - Query: `container_memory_usage_bytes`

---

## Exercice 3 : Lazy Docker (TUI)

### 3.1 - Installation et utilisation

```bash
# Installation (Linux)
curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

# Ou avec Docker
docker run --rm -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ~/.config/lazydocker:/.config/jesseduffield/lazydocker \
  lazyteam/lazydocker

# Navigation:
# x - Menu
# Tab - Changer de panneau
# Enter - Détails
# l - Logs
# s - Shell
# r - Restart
# d - Delete
# e - Exec shell
```

---

## Exercice 4 : Dozzle (Log viewer)

### 4.1 - Installation de Dozzle

```bash
docker run -d \
  --name dozzle \
  --restart always \
  -p 8888:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  amir20/dozzle:latest

# Accéder à http://localhost:8888
```

**Fonctionnalités**:
- Vue temps réel des logs de tous les conteneurs
- Recherche dans les logs
- Multi-host support
- Pas de configuration nécessaire

---

## Exercice 5 : Docker Dashboard (Docker Desktop alternative)

### 5.1 - Stack complète d'administration

```yaml
version: '3.8'

services:
  # Portainer - Admin UI
  portainer:
    image: portainer/portainer-ce:latest
    ports:
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    restart: always

  # Dozzle - Log viewer
  dozzle:
    image: amir20/dozzle:latest
    ports:
      - "8888:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: always

  # Traefik - Reverse proxy with dashboard
  traefik:
    image: traefik:v2.10
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
    ports:
      - "80:80"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: always

  # Watchtower - Auto-update containers
  watchtower:
    image: containrrr/watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --interval 30
    restart: always

  # Diun - Docker image update notifier
  diun:
    image: crazymax/diun:latest
    environment:
      - TZ=Europe/Paris
      - LOG_LEVEL=info
    volumes:
      - ./diun/config.yml:/config.yml:ro
      - /var/run/docker.sock:/var/run/docker.sock
    restart: always

volumes:
  portainer_data:
```

---

## Exercice 6 : Monitoring avancé avec Netdata

### 6.1 - Installation Netdata

```bash
docker run -d \
  --name netdata \
  --restart always \
  -p 19999:19999 \
  -v netdataconfig:/etc/netdata \
  -v netdatalib:/var/lib/netdata \
  -v netdatacache:/var/cache/netdata \
  -v /etc/passwd:/host/etc/passwd:ro \
  -v /etc/group:/host/etc/group:ro \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  --cap-add SYS_PTRACE \
  --security-opt apparmor=unconfined \
  netdata/netdata

# Accès: http://localhost:19999
```

**Métriques disponibles**:
- CPU, RAM, Network, Disk I/O
- Conteneurs Docker individuels
- Processus
- Logs système
- Alertes configurables

---

## Exercice 7 : Registry UI

### 7.1 - Interface pour Docker Registry

```bash
# Démarrer un registry
docker run -d \
  -p 5000:5000 \
  --name registry \
  -v registry_data:/var/lib/registry \
  registry:2

# Ajouter une UI
docker run -d \
  -p 8080:80 \
  --name registry-ui \
  -e REGISTRY_URL=http://registry:5000 \
  -e DELETE_IMAGES=true \
  --link registry \
  joxit/docker-registry-ui:latest

# Accès: http://localhost:8080
```

---

## Exercice 8 : Comparaison des outils

| Outil | Type | Use Case | Complexité |
|-------|------|----------|------------|
| **Portainer** | Web UI complète | Administration générale | Faible |
| **Grafana** | Dashboards | Monitoring/Métriques | Moyenne |
| **Dozzle** | Log viewer | Logs en temps réel | Très faible |
| **Lazy Docker** | TUI | Admin terminal | Faible |
| **Netdata** | Monitoring | Métriques système | Moyenne |
| **Traefik** | Reverse proxy | Routing/SSL | Moyenne |
| **cAdvisor** | Monitoring | Métriques conteneurs | Faible |

---

## 🏆 Validation

- [ ] Installé et configuré Portainer
- [ ] Déployé une stack depuis Portainer
- [ ] Mis en place Prometheus + Grafana
- [ ] Utilisé Dozzle pour les logs
- [ ] Configuré Netdata pour le monitoring
- [ ] Créé des dashboards Grafana
- [ ] Comparé différentes interfaces

---

## 📊 Stack de monitoring complète

```yaml
version: '3.8'

services:
  # Administration
  portainer:
    image: portainer/portainer-ce:latest
    ports:
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data

  # Logs
  dozzle:
    image: amir20/dozzle:latest
    ports:
      - "8888:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock

  # Métriques
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus

  # Visualisation
  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_PASSWORD: admin
    volumes:
      - grafana_data:/var/lib/grafana

  # Collecteur de métriques Docker
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    privileged: true

  # Métriques système
  node-exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'

  # Reverse proxy
  traefik:
    image: traefik:v2.10
    command:
      - "--api.dashboard=true"
      - "--providers.docker=true"
    ports:
      - "80:80"
      - "8081:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock

volumes:
  portainer_data:
  prometheus_data:
  grafana_data:
```

Accès:
- Portainer: https://localhost:9443
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090
- Dozzle: http://localhost:8888
- Traefik: http://localhost:8081
- cAdvisor: http://localhost:8080

---

**[→ Voir les solutions](../solutions/TP13-Solution.md)**

**[← Retour au README du module](../README.md)**
