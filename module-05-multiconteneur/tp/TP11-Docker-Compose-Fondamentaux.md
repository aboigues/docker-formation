# TP11 : Docker Compose fondamentaux

## Objectif

Maîtriser Docker Compose pour orchestrer des applications multi-conteneurs.

## Durée estimée

75 minutes

## Concepts clés

Docker Compose permet de définir et gérer des applications multi-conteneurs avec un fichier YAML simple.

---

## Exercice 1 : Premier docker-compose.yml

### 1.1 - Application web simple

```bash
mkdir -p ~/docker-tp/compose-basics
cd ~/docker-tp/compose-basics

# Créer docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./html:/usr/share/nginx/html:ro
    networks:
      - frontend

networks:
  frontend:
    driver: bridge
EOF

# Créer le contenu web
mkdir -p html
echo "<h1>Hello from Docker Compose!</h1>" > html/index.html

# Démarrer
docker compose up -d

# Vérifier
curl http://localhost:8080

# Voir les services
docker compose ps

# Voir les logs
docker compose logs

# Arrêter
docker compose down
```

**Commandes essentielles** :
```bash
docker compose up -d        # Démarrer en arrière-plan
docker compose ps           # Lister les services
docker compose logs -f      # Suivre les logs
docker compose stop         # Arrêter
docker compose start        # Redémarrer
docker compose restart      # Redémarrer
docker compose down         # Arrêter et supprimer
docker compose down -v      # + supprimer les volumes
```

---

## Exercice 2 : Application WordPress

### 2.1 - WordPress + MySQL

```bash
mkdir -p ~/docker-tp/wordpress-compose
cd ~/docker-tp/wordpress-compose

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  db:
    image: mysql:8.0
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wpuser
      MYSQL_PASSWORD: wppassword
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - backend

  wordpress:
    image: wordpress:latest
    restart: always
    depends_on:
      - db
    ports:
      - "8080:80"
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: wpuser
      WORDPRESS_DB_PASSWORD: wppassword
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - wp_data:/var/www/html
    networks:
      - frontend
      - backend

volumes:
  db_data:
  wp_data:

networks:
  frontend:
  backend:
EOF

# Démarrer
docker compose up -d

# Voir les logs de WordPress
docker compose logs -f wordpress

# Attendre le démarrage
sleep 30

# Tester
curl -I http://localhost:8080

# Accéder: http://localhost:8080
```

**Points clés** :
- `depends_on` : définit l'ordre de démarrage
- Volumes nommés pour la persistance
- Réseaux multiples pour l'isolation
- `restart: always` : redémarre automatiquement

---

## Exercice 3 : Build d'images personnalisées

### 3.1 - Application custom avec Compose

```bash
mkdir -p ~/docker-tp/compose-build/{api,web}
cd ~/docker-tp/compose-build

# API Backend
cat > api/app.py << 'EOF'
from flask import Flask, jsonify
app = Flask(__name__)

@app.route('/api/hello')
def hello():
    return jsonify({'message': 'Hello from API'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

cat > api/requirements.txt << 'EOF'
Flask==3.0.0
EOF

cat > api/Dockerfile << 'EOF'
FROM python:3.11-slim
WORKDIR /app
# Installer curl pour le healthcheck
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY app.py .
CMD ["python", "app.py"]
EOF

# Frontend
cat > web/nginx.conf << 'EOF'
server {
    listen 80;
    location / {
        root /usr/share/nginx/html;
    }
    location /api/ {
        proxy_pass http://api:5000/api/;
    }
}
EOF

cat > web/index.html << 'EOF'
<!DOCTYPE html>
<html>
<body>
    <h1>Frontend</h1>
    <button onclick="fetch('/api/hello').then(r=>r.json()).then(d=>alert(d.message))">
        Call API
    </button>
</body>
</html>
EOF

cat > web/Dockerfile << 'EOF'
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/
EOF

# Docker Compose
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  api:
    build:
      context: ./api
      dockerfile: Dockerfile
    image: myapp-api:latest
    networks:
      - backend
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/api/hello"]
      interval: 30s
      timeout: 3s
      retries: 3

  web:
    build:
      context: ./web
      dockerfile: Dockerfile
    image: myapp-web:latest
    ports:
      - "8080:80"
    depends_on:
      api:
        condition: service_healthy
    networks:
      - frontend
      - backend

networks:
  frontend:
  backend:
EOF

# Builder et démarrer
docker compose build
docker compose up -d

# Tester
curl http://localhost:8080
curl http://localhost:8080/api/hello
```

---

## Exercice 4 : Variables d'environnement

### 4.1 - Fichier .env

```bash
mkdir -p ~/docker-tp/compose-env
cd ~/docker-tp/compose-env

# Créer .env
cat > .env << 'EOF'
# Database
DB_NAME=myapp
DB_USER=dbuser
DB_PASSWORD=secretpassword

# Application
APP_ENV=production
APP_PORT=3000
APP_SECRET=mysecretkey
EOF

# Docker Compose
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - db_data:/var/lib/postgresql/data

  app:
    image: node:18-alpine
    environment:
      DATABASE_URL: postgres://${DB_USER}:${DB_PASSWORD}@db:5432/${DB_NAME}
      NODE_ENV: ${APP_ENV}
      APP_SECRET: ${APP_SECRET}
    ports:
      - "${APP_PORT}:3000"
    depends_on:
      - db
    command: sh -c "echo 'App running' && sleep infinity"

volumes:
  db_data:
EOF

# Démarrer
docker compose up -d

# Vérifier les variables
docker compose exec app env | grep -E "DATABASE_URL|NODE_ENV"
```

### 4.2 - Multiples fichiers d'environnement

```bash
# dev.env
cat > dev.env << 'EOF'
APP_ENV=development
APP_DEBUG=true
EOF

# prod.env
cat > prod.env << 'EOF'
APP_ENV=production
APP_DEBUG=false
EOF

# Utiliser différents fichiers
docker compose --env-file dev.env up -d
docker compose --env-file prod.env up -d
```

---

## Exercice 5 : Scaling et load balancing

### 5.1 - Scaler des services

```bash
mkdir -p ~/docker-tp/compose-scale
cd ~/docker-tp/compose-scale

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  app:
    image: hashicorp/http-echo:latest
    command: sh -c 'http-echo -text="Instance $$HOSTNAME"'
    networks:
      - app-net

  nginx:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - app
    networks:
      - app-net

networks:
  app-net:
EOF

cat > nginx.conf << 'EOF'
events { worker_connections 1024; }

http {
    upstream app {
        server app:5678;
    }

    server {
        listen 80;
        location / {
            proxy_pass http://app;
        }
    }
}
EOF

# Démarrer avec plusieurs instances
docker compose up -d --scale app=3

# Tester le load balancing
for i in {1..10}; do curl http://localhost:8080; done
```

---

## Exercice 6 : Profiles pour différents environnements

### 6.1 - Dev, Test, Prod

```bash
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  app:
    image: myapp:latest
    environment:
      ENV: ${ENV:-production}

  db:
    image: postgres:15-alpine
    profiles: ["dev", "test", "prod"]

  redis:
    image: redis:alpine
    profiles: ["dev", "prod"]

  adminer:
    image: adminer
    ports:
      - "8080:8080"
    profiles: ["dev"]
    depends_on:
      - db

  test:
    image: myapp:latest
    profiles: ["test"]
    command: npm test

volumes:
  db_data:
EOF

# Démarrer seulement dev
docker compose --profile dev up -d

# Démarrer seulement test
docker compose --profile test up

# Démarrer prod (sans adminer)
docker compose --profile prod up -d
```

---

## Exercice 7 : Healthchecks et dépendances

### 7.1 - Attendre que les services soient prêts

```bash
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_PASSWORD: password
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  app:
    image: node:18-alpine
    depends_on:
      db:
        condition: service_healthy
    command: sh -c "echo 'DB is ready!' && sleep infinity"
EOF

docker compose up -d
docker compose logs app
# L'app ne démarre que quand la DB est healthy
```

---

## Exercice 8 : Override files

### 8.1 - docker-compose.override.yml

```bash
# docker-compose.yml (base)
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  app:
    image: myapp:latest
    environment:
      ENV: production
EOF

# docker-compose.override.yml (automatiquement mergé)
cat > docker-compose.override.yml << 'EOF'
version: '3.8'

services:
  app:
    environment:
      DEBUG: "true"
    ports:
      - "3000:3000"
    volumes:
      - ./src:/app/src
EOF

# Les deux fichiers sont automatiquement mergés
docker compose config
```

### 8.2 - Fichiers spécifiques

```bash
# docker-compose.prod.yml
cat > docker-compose.prod.yml << 'EOF'
version: '3.8'

services:
  app:
    deploy:
      replicas: 3
    environment:
      ENV: production
      DEBUG: "false"
EOF

# Utiliser
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

---

## 🏆 Validation

- [ ] Créé un docker-compose.yml basique
- [ ] Déployé une stack WordPress
- [ ] Buildé des images avec Compose
- [ ] Utilisé des variables d'environnement
- [ ] Scalé des services
- [ ] Utilisé des profiles
- [ ] Configuré des healthchecks
- [ ] Utilisé des override files

---

## 📊 Commandes Docker Compose

| Commande | Description |
|----------|-------------|
| `docker compose up` | Démarrer les services |
| `docker compose up -d` | Démarrer en arrière-plan |
| `docker compose down` | Arrêter et supprimer |
| `docker compose ps` | Lister les services |
| `docker compose logs` | Voir les logs |
| `docker compose exec` | Exécuter une commande |
| `docker compose build` | Builder les images |
| `docker compose pull` | Pull les images |
| `docker compose restart` | Redémarrer |
| `docker compose scale` | Scaler un service |
| `docker compose config` | Valider et voir la config |

---

**[→ Voir les solutions](../solutions/TP11-12-Solutions.md)**

**[→ TP suivant : Applications complètes](TP12-Applications-Completes.md)**
