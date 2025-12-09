# TP12 : Applications complètes avec Docker Compose

## Objectif

Déployer des applications production-ready complètes avec Docker Compose.

## Durée estimée

75 minutes

---

## Exercice 1 : Stack MERN (MongoDB, Express, React, Node)

**⚠️ Note** : Plusieurs exercices utilisent le port 8080. Pensez à arrêter les stacks précédentes avec `docker compose down` avant de passer à l'exercice suivant.

```bash
mkdir -p ~/docker-tp/mern-stack
cd ~/docker-tp/mern-stack

# Structure
mkdir -p backend frontend

# Backend
cat > backend/package.json << 'EOF'
{
  "name": "backend",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.18.2",
    "mongoose": "^8.0.0",
    "cors": "^2.8.5"
  }
}
EOF

cat > backend/server.js << 'EOF'
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

mongoose.connect(process.env.MONGODB_URI);

const Item = mongoose.model('Item', { name: String, date: Date });

app.get('/api/items', async (req, res) => {
  const items = await Item.find();
  res.json(items);
});

app.post('/api/items', async (req, res) => {
  const item = new Item({ name: req.body.name, date: new Date() });
  await item.save();
  res.json(item);
});

app.listen(5000, () => console.log('Backend on 5000'));
EOF

cat > backend/Dockerfile << 'EOF'
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY server.js ./
CMD ["node", "server.js"]
EOF

# Frontend (simple HTML)
cat > frontend/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>MERN Stack</title>
    <style>
        body { font-family: Arial; max-width: 800px; margin: 50px auto; }
        input, button { padding: 10px; margin: 5px; }
    </style>
</head>
<body>
    <h1>MERN Stack App</h1>
    <div>
        <input id="itemName" placeholder="Item name">
        <button onclick="addItem()">Add</button>
    </div>
    <ul id="items"></ul>

    <script>
        const API = 'http://localhost:5000/api';

        async function loadItems() {
            const res = await fetch(API + '/items');
            const items = await res.json();
            document.getElementById('items').innerHTML = items
                .map(i => `<li>${i.name} - ${new Date(i.date).toLocaleString()}</li>`)
                .join('');
        }

        async function addItem() {
            const name = document.getElementById('itemName').value;
            await fetch(API + '/items', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({name})
            });
            document.getElementById('itemName').value = '';
            loadItems();
        }

        loadItems();
    </script>
</body>
</html>
EOF

cat > frontend/Dockerfile << 'EOF'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EOF

# Docker Compose
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  mongo:
    image: mongo:7
    restart: always
    volumes:
      - mongo_data:/data/db
    networks:
      - backend
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    build: ./backend
    restart: always
    environment:
      MONGODB_URI: mongodb://mongo:27017/mernapp
    ports:
      - "5000:5000"
    depends_on:
      mongo:
        condition: service_healthy
    networks:
      - backend
      - frontend

  frontend:
    build: ./frontend
    restart: always
    ports:
      - "8080:80"
    depends_on:
      - backend
    networks:
      - frontend

volumes:
  mongo_data:

networks:
  backend:
  frontend:
EOF

# Démarrer
docker compose up -d --build

# Vérifier les services
docker compose ps

# Tester l'application
curl -I http://localhost:8080

# Accéder à http://localhost:8080
```

---

## Exercice 2 : Stack ELK (Elasticsearch, Logstash, Kibana)

```bash
mkdir -p ~/docker-tp/elk-stack
cd ~/docker-tp/elk-stack

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - xpack.security.enabled=false
    volumes:
      - es_data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"
    networks:
      - elk

  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline:ro
    ports:
      - "5044:5044"
      - "9600:9600"
    depends_on:
      - elasticsearch
    networks:
      - elk

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    ports:
      - "5601:5601"
    environment:
      ELASTICSEARCH_HOSTS: http://elasticsearch:9200
    depends_on:
      - elasticsearch
    networks:
      - elk

  # Application qui génère des logs
  app:
    image: nginx:alpine
    volumes:
      - ./app/logs:/var/log/nginx
    ports:
      - "8080:80"
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  es_data:

networks:
  elk:
EOF

mkdir -p logstash/pipeline
cat > logstash/pipeline/logstash.conf << 'EOF'
input {
  tcp {
    port => 5044
    codec => json
  }
}

filter {
  if [type] == "nginx" {
    grok {
      match => { "message" => "%{COMBINEDAPACHELOG}" }
    }
    date {
      match => [ "timestamp" , "dd/MMM/yyyy:HH:mm:ss Z" ]
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "logs-%{+YYYY.MM.dd}"
  }
  stdout { codec => rubydebug }
}
EOF

docker compose up -d
# Kibana: http://localhost:5601
```

---

## Exercice 3 : CI/CD avec GitLab

```bash
mkdir -p ~/docker-tp/gitlab-stack
cd ~/docker-tp/gitlab-stack

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  gitlab:
    image: gitlab/gitlab-ce:latest
    restart: always
    hostname: localhost
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://localhost:8080'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222
    ports:
      - '8080:80'
      - '2222:22'
    volumes:
      - gitlab_config:/etc/gitlab
      - gitlab_logs:/var/log/gitlab
      - gitlab_data:/var/opt/gitlab
    networks:
      - gitlab-net
    shm_size: '256m'

  gitlab-runner:
    image: gitlab/gitlab-runner:latest
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - gitlab_runner_config:/etc/gitlab-runner
    networks:
      - gitlab-net
    depends_on:
      - gitlab

  registry:
    image: registry:2
    restart: always
    ports:
      - '5000:5000'
    volumes:
      - registry_data:/var/lib/registry
    networks:
      - gitlab-net

volumes:
  gitlab_config:
  gitlab_logs:
  gitlab_data:
  gitlab_runner_config:
  registry_data:

networks:
  gitlab-net:
EOF

# Attendre le démarrage de GitLab (peut prendre plusieurs minutes)
echo "GitLab démarre... Cela peut prendre 5-10 minutes"
docker compose up -d

# Accéder à GitLab sur http://localhost:8080
# Le mot de passe root initial se trouve dans :
# docker compose exec gitlab cat /etc/gitlab/initial_root_password
```

---

## Exercice 4 : Monitoring Stack (Prometheus + Grafana)

```bash
mkdir -p ~/docker-tp/monitoring-stack/{prometheus,grafana}
cd ~/docker-tp/monitoring-stack

cat > prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
EOF

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    restart: always
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    restart: always
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana
    depends_on:
      - prometheus
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:latest
    restart: always
    ports:
      - "9100:9100"
    networks:
      - monitoring

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:v0.47.0
    restart: always
    ports:
      - "8081:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    privileged: true
    devices:
      - /dev/kmsg
    networks:
      - monitoring

volumes:
  prometheus_data:
  grafana_data:

networks:
  monitoring:
EOF

docker compose up -d

# Prometheus: http://localhost:9090
# Grafana: http://localhost:3000 (admin/admin)
```

---

## Exercice 5 : E-commerce Stack

```bash
mkdir -p ~/docker-tp/ecommerce-stack/{api,frontend,nginx}
cd ~/docker-tp/ecommerce-stack

# API Backend (Node.js + Express)
cat > api/package.json << 'EOF'
{
  "name": "ecommerce-api",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.0",
    "redis": "^4.6.0",
    "amqplib": "^0.10.0"
  }
}
EOF

cat > api/server.js << 'EOF'
const express = require('express');
const app = express();
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

app.get('/api/products', (req, res) => {
  res.json([
    { id: 1, name: 'Product 1', price: 29.99 },
    { id: 2, name: 'Product 2', price: 49.99 }
  ]);
});

app.listen(3000, () => console.log('API running on port 3000'));
EOF

cat > api/Dockerfile << 'EOF'
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY server.js ./
EXPOSE 3000
CMD ["node", "server.js"]
EOF

# Frontend (HTML simple)
cat > frontend/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>E-commerce</title>
    <style>
        body { font-family: Arial; max-width: 1200px; margin: 50px auto; }
        .product { border: 1px solid #ddd; padding: 20px; margin: 10px; }
    </style>
</head>
<body>
    <h1>E-commerce Store</h1>
    <div id="products"></div>
    <script>
        fetch('/api/products')
            .then(r => r.json())
            .then(products => {
                document.getElementById('products').innerHTML = products
                    .map(p => `<div class="product"><h3>${p.name}</h3><p>$${p.price}</p></div>`)
                    .join('');
            });
    </script>
</body>
</html>
EOF

cat > frontend/Dockerfile << 'EOF'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EOF

# Nginx Configuration
cat > nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream api {
        server api:3000;
    }

    upstream frontend {
        server frontend:80;
    }

    server {
        listen 80;

        location / {
            proxy_pass http://frontend;
            proxy_set_header Host $host;
        }

        location /api/ {
            proxy_pass http://api/api/;
            proxy_set_header Host $host;
        }
    }
}
EOF

# Docker Compose
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # Database
  postgres:
    image: postgres:15-alpine
    restart: always
    environment:
      POSTGRES_DB: ecommerce
      POSTGRES_USER: ecommerce
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - backend
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ecommerce"]
      interval: 5s

  # Cache
  redis:
    image: redis:alpine
    restart: always
    networks:
      - backend
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s

  # Message Queue
  rabbitmq:
    image: rabbitmq:3-management-alpine
    restart: always
    ports:
      - "5672:5672"
      - "15672:15672"
    environment:
      RABBITMQ_DEFAULT_USER: admin
      RABBITMQ_DEFAULT_PASS: admin
    networks:
      - backend

  # API Backend
  api:
    build: ./api
    restart: always
    environment:
      DATABASE_URL: postgres://ecommerce:password@postgres:5432/ecommerce
      REDIS_URL: redis://redis:6379
      RABBITMQ_URL: amqp://admin:admin@rabbitmq:5672
    ports:
      - "3000:3000"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - backend
      - frontend

  # Frontend
  frontend:
    build: ./frontend
    restart: always
    ports:
      - "8080:80"
    depends_on:
      - api
    networks:
      - frontend

  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
    depends_on:
      - frontend
      - api
    networks:
      - frontend

volumes:
  postgres_data:

networks:
  frontend:
  backend:
EOF

# Démarrer la stack complète
docker compose up -d --build

# Vérifier les services
docker compose ps

# Tester l'application
curl http://localhost:80

# Accéder à RabbitMQ Management: http://localhost:15672 (admin/admin)
```

---

## Exercice 6 : Development vs Production

### 6.1 - Configurations séparées

```bash
# docker-compose.yml (base)
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  app:
    build: .
    environment:
      NODE_ENV: ${NODE_ENV:-production}
EOF

# docker-compose.dev.yml
cat > docker-compose.dev.yml << 'EOF'
version: '3.8'

services:
  app:
    volumes:
      - ./src:/app/src
    environment:
      NODE_ENV: development
      DEBUG: "true"
    ports:
      - "3000:3000"
      - "9229:9229"  # Debug port
    command: npm run dev
EOF

# docker-compose.prod.yml
cat > docker-compose.prod.yml << 'EOF'
version: '3.8'

services:
  app:
    environment:
      NODE_ENV: production
    deploy:
      replicas: 3
      restart_policy:
        condition: on-failure
        max_attempts: 3
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
EOF

# Usage
docker compose -f docker-compose.yml -f docker-compose.dev.yml up
docker compose -f docker-compose.yml -f docker-compose.prod.yml up
```

---

## 🏆 Validation

- [ ] Déployé une stack MERN complète
- [ ] Mis en place un stack de monitoring
- [ ] Créé des configurations dev/prod
- [ ] Utilisé des healthchecks avancés
- [ ] Configuré des dépendances entre services
- [ ] Géré les logs et le monitoring

---

## 📊 Best Practices

```yaml
# Template production-ready
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        BUILD_DATE: ${BUILD_DATE}
    image: myapp:${VERSION:-latest}
    restart: unless-stopped

    # Health check
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

    # Resources (Compose v3.8+)
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          memory: 256M

    # Logging
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

    # Security
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp

    # Networks
    networks:
      - frontend
      - backend

networks:
  frontend:
    driver: bridge
  backend:
    internal: true  # Pas d'accès externe

volumes:
  app_data:
    driver: local
```

---

**[→ Voir les solutions](../solutions/TP11-12-Solutions.md)**

**[← Retour au README du module](../README.md)**
