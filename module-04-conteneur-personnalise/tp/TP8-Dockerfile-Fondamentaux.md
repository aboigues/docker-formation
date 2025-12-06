# TP8 : Dockerfile fondamentaux

## Objectif

Maîtriser la création d'images Docker personnalisées avec Dockerfile pour différents types d'applications.

## Durée estimée

60 minutes

## Concepts clés

```
┌────────────────────────────────────────────────────────┐
│              Structure d'un Dockerfile                 │
├────────────────────────────────────────────────────────┤
│                                                        │
│  FROM       Image de base                             │
│  LABEL      Métadonnées                               │
│  ENV        Variables d'environnement                 │
│  WORKDIR    Définir le répertoire de travail          │
│  COPY/ADD   Copier des fichiers                       │
│  RUN        Exécuter des commandes (build-time)       │
│  EXPOSE     Déclarer les ports                        │
│  CMD        Commande par défaut (run-time)            │
│  ENTRYPOINT Point d'entrée de l'application           │
│                                                        │
│  Chaque instruction crée un layer                     │
│  Les layers sont cachés et réutilisés                 │
│                                                        │
└────────────────────────────────────────────────────────┘
```

---

## Exercice 1 : Premier Dockerfile simple

### 1.1 - Site web statique

```bash
# Créer un dossier de projet
mkdir -p ~/docker-tp/static-website
cd ~/docker-tp/static-website

# Créer le contenu du site
cat > index.html << 'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Mon premier Dockerfile</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            background: rgba(255, 255, 255, 0.1);
            padding: 30px;
            border-radius: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Bienvenue sur mon site Docker !</h1>
        <p>Cette page est servie depuis un conteneur Docker personnalisé.</p>
        <p>Image créée avec Dockerfile</p>
    </div>
</body>
</html>
EOF

# Créer le Dockerfile
cat > Dockerfile << 'EOF'
# Image de base
FROM nginx:alpine

# Métadonnées
LABEL maintainer="votre.email@example.com"
LABEL description="Mon premier site web statique"
LABEL version="1.0"

# Copier le contenu du site
COPY index.html /usr/share/nginx/html/index.html

# Exposer le port
EXPOSE 80

# La commande CMD est héritée de nginx:alpine
# CMD ["nginx", "-g", "daemon off;"]
EOF

# Construire l'image
docker build -t mon-site-web:v1 .

# Vérifier l'image
docker images mon-site-web

# Lancer le conteneur
docker run -d -p 8080:80 --name mon-site mon-site-web:v1

# Tester
curl http://localhost:8080
```

**Questions** :
1. Combien de layers votre image a-t-elle ajouté à nginx:alpine ?
2. Que se passe-t-il si vous modifiez index.html et rebuilder ?
3. Pourquoi utiliser nginx:alpine plutôt que nginx ?

### 1.2 - Comprendre le build

```bash
# Build avec sortie détaillée
docker build -t mon-site-web:v1 . --progress=plain

# Voir les étapes:
# [1/3] FROM nginx:alpine
# [2/3] COPY index.html ...
# [3/3] EXPOSE 80

# Chaque étape crée un layer
docker history mon-site-web:v1

# Voir le cache en action
echo "<!-- Modification -->" >> index.html
docker build -t mon-site-web:v2 .
# Les premières étapes utilisent le cache !
```

---

## Exercice 2 : Instructions essentielles

### 2.1 - FROM : Choisir l'image de base

```bash
mkdir -p ~/docker-tp/from-examples
cd ~/docker-tp/from-examples

# Exemple 1: Base minimale
cat > Dockerfile.alpine << 'EOF'
FROM alpine:latest

RUN apk add --no-cache curl

CMD ["curl", "--version"]
EOF

# Exemple 2: Base avec langage
cat > Dockerfile.node << 'EOF'
FROM node:18-alpine

WORKDIR /app
CMD ["node", "--version"]
EOF

# Exemple 3: Multi-stage (aperçu)
cat > Dockerfile.multistage << 'EOF'
FROM node:18 AS builder
WORKDIR /app
# Build steps...

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EOF

# Builder et comparer les tailles
docker build -f Dockerfile.alpine -t test:alpine .
docker build -f Dockerfile.node -t test:node .

docker images test
```

**Règles pour choisir l'image de base** :
- Utiliser des images officielles
- Préférer les versions tagguées (pas `latest`)
- Utiliser `alpine` pour la production
- Utiliser la version complète pour le développement

### 2.2 - RUN : Exécuter des commandes

```bash
cat > Dockerfile << 'EOF'
FROM ubuntu:22.04

# ✗ MAL : Plusieurs RUN = plusieurs layers
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y vim
RUN apt-get install -y git

# ✓ BIEN : Un seul RUN = un seul layer
RUN apt-get update && \
    apt-get install -y \
        curl \
        vim \
        git \
    && rm -rf /var/lib/apt/lists/*
EOF

# Différence de taille
docker build -t bad-practice:v1 -f Dockerfile.bad .
docker build -t good-practice:v1 -f Dockerfile.good .
docker images | grep practice
```

### 2.3 - COPY vs ADD

```bash
mkdir -p ~/docker-tp/copy-add
cd ~/docker-tp/copy-add

# Créer des fichiers
echo "Config file" > config.conf
echo "Data" > data.txt
tar czf archive.tar.gz config.conf data.txt

cat > Dockerfile << 'EOF'
FROM alpine:latest

WORKDIR /app

# COPY : Simple copie de fichiers
COPY config.conf /app/
COPY data.txt /app/

# ADD : Copie + extraction automatique des tar
ADD archive.tar.gz /app/extracted/

# ADD peut aussi télécharger depuis une URL (non recommandé)
# ADD https://example.com/file.txt /app/

# ✓ RECOMMANDATION : Utilisez COPY sauf si vous avez besoin
# de l'extraction automatique des archives
EOF

docker build -t copy-add-demo .
docker run --rm copy-add-demo ls -la /app
docker run --rm copy-add-demo ls -la /app/extracted
```

**Quand utiliser quoi ?** :
- **COPY** : Dans 99% des cas (plus prévisible)
- **ADD** : Seulement pour extraire des tar automatiquement

### 2.4 - WORKDIR : Répertoire de travail

```bash
cat > Dockerfile << 'EOF'
FROM alpine:latest

# ✗ MAL : Utiliser cd et chemins absolus
RUN cd /app && echo "test" > file.txt
RUN cd /app && cat file.txt  # Erreur ! cd ne persiste pas

# ✓ BIEN : Utiliser WORKDIR
WORKDIR /app
RUN echo "test" > file.txt
RUN cat file.txt  # Fonctionne !

# WORKDIR crée le dossier s'il n'existe pas
WORKDIR /app/subdir/deep
RUN pwd  # /app/subdir/deep
EOF
```

### 2.5 - ENV : Variables d'environnement

```bash
cat > Dockerfile << 'EOF'
FROM node:18-alpine

# Définir des variables d'environnement
ENV NODE_ENV=production
ENV APP_PORT=3000
ENV APP_NAME="MyApp"

# Utiliser les variables
WORKDIR /app
RUN echo "Running in $NODE_ENV mode"

# Les ENV sont disponibles au runtime
CMD ["sh", "-c", "echo App: $APP_NAME running on port $APP_PORT"]
EOF

docker build -t env-demo .

# Les variables peuvent être overridées au runtime
docker run --rm env-demo
docker run --rm -e APP_NAME="CustomApp" -e APP_PORT=8080 env-demo
```

### 2.6 - EXPOSE : Documenter les ports

```bash
cat > Dockerfile << 'EOF'
FROM nginx:alpine

# EXPOSE est purement documentaire
# Ça n'ouvre PAS réellement le port
EXPOSE 80
EXPOSE 443

# Pour voir les ports exposés
# docker inspect <image> --format '{{.Config.ExposedPorts}}'
EOF

docker build -t expose-demo .
docker inspect expose-demo --format '{{.Config.ExposedPorts}}'

# Il faut toujours utiliser -p pour publier
docker run -d -p 8080:80 expose-demo  # Fonctionne
docker run -d expose-demo  # Port 80 non accessible depuis l'hôte
```

### 2.7 - CMD vs ENTRYPOINT

```bash
# CMD : Commande par défaut (peut être overridden)
cat > Dockerfile.cmd << 'EOF'
FROM alpine:latest
CMD ["echo", "Hello from CMD"]
EOF

docker build -f Dockerfile.cmd -t cmd-demo .
docker run --rm cmd-demo  # Affiche: Hello from CMD
docker run --rm cmd-demo echo "Override"  # Affiche: Override

# ENTRYPOINT : Point d'entrée fixe
cat > Dockerfile.entrypoint << 'EOF'
FROM alpine:latest
ENTRYPOINT ["echo", "Hello from"]
CMD ["ENTRYPOINT"]
EOF

docker build -f Dockerfile.entrypoint -t entrypoint-demo .
docker run --rm entrypoint-demo  # Hello from ENTRYPOINT
docker run --rm entrypoint-demo Docker  # Hello from Docker

# Combinaison ENTRYPOINT + CMD
cat > Dockerfile.both << 'EOF'
FROM alpine:latest
ENTRYPOINT ["echo"]
CMD ["Default message"]
EOF

docker build -f Dockerfile.both -t both-demo .
docker run --rm both-demo  # Default message
docker run --rm both-demo "Custom message"  # Custom message
```

---

## Exercice 3 : Application Node.js

### 3.1 - Application complète

```bash
mkdir -p ~/docker-tp/node-app
cd ~/docker-tp/node-app

# Créer package.json
cat > package.json << 'EOF'
{
  "name": "docker-node-app",
  "version": "1.0.0",
  "description": "Simple Node.js app",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

# Créer server.js
cat > server.js << 'EOF'
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({
    message: 'Hello from Docker!',
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'OK' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});
EOF

# Créer Dockerfile
cat > Dockerfile << 'EOF'
FROM node:18-alpine

# Métadonnées
LABEL maintainer="dev@example.com"
LABEL app="node-demo"

# Variables d'environnement
ENV NODE_ENV=production
ENV PORT=3000

# Créer le répertoire de l'app
WORKDIR /app

# Copier package.json d'abord (pour le cache)
COPY package*.json ./

# Installer les dépendances
RUN npm install --production

# Copier le code source
COPY server.js ./

# Exposer le port
EXPOSE 3000

# Utilisateur non-root (sécurité)
USER node

# Commande de démarrage
CMD ["npm", "start"]
EOF

# Build
docker build -t node-app:v1 .

# Run
docker run -d -p 3000:3000 --name node-app node-app:v1

# Test
curl http://localhost:3000
curl http://localhost:3000/health
```

**Questions** :
1. Pourquoi copier package.json séparément du code source ?
2. Quel est l'avantage de `USER node` ?
3. Que se passe-t-il si vous modifiez server.js et rebuilder ?

### 3.2 - .dockerignore

```bash
# Créer .dockerignore
cat > .dockerignore << 'EOF'
# Fichiers de développement
node_modules
npm-debug.log
.npm

# Fichiers git
.git
.gitignore

# Fichiers IDE
.vscode
.idea
*.swp
*.swo

# Fichiers de test
test
*.test.js
coverage

# Documentation
README.md
docs

# Fichiers système
.DS_Store
Thumbs.db

# Environnement
.env
.env.local
EOF

# Vérifier l'effet
# Avant .dockerignore
docker build -t test:before .

# Créer node_modules
npm install

# Après .dockerignore
docker build -t test:after .

# Comparer les contextes de build
```

---

## Exercice 4 : Application Python

### 4.1 - Flask API

```bash
mkdir -p ~/docker-tp/python-app
cd ~/docker-tp/python-app

# Créer requirements.txt
cat > requirements.txt << 'EOF'
Flask==3.0.0
gunicorn==21.2.0
EOF

# Créer app.py
cat > app.py << 'EOF'
from flask import Flask, jsonify
import os
from datetime import datetime

app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({
        'message': 'Hello from Python Flask!',
        'version': '1.0.0',
        'environment': os.getenv('FLASK_ENV', 'production'),
        'timestamp': datetime.now().isoformat()
    })

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

# Créer Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

# Variables d'environnement
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Installer les dépendances
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copier le code
COPY app.py .

# Exposer le port
EXPOSE 5000

# Utilisateur non-root
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app
USER appuser

# Commande avec gunicorn (production-ready)
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
EOF

# Build et run
docker build -t python-app:v1 .
docker run -d -p 5000:5000 --name python-app python-app:v1

# Test
curl http://localhost:5000
curl http://localhost:5000/health
```

---

## Exercice 5 : Application Go

### 5.1 - API Go simple

```bash
mkdir -p ~/docker-tp/go-app
cd ~/docker-tp/go-app

# Créer main.go
cat > main.go << 'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
    "time"
)

type Response struct {
    Message     string `json:"message"`
    Version     string `json:"version"`
    Environment string `json:"environment"`
    Timestamp   string `json:"timestamp"`
}

func homeHandler(w http.ResponseWriter, r *http.Request) {
    response := Response{
        Message:     "Hello from Go!",
        Version:     "1.0.0",
        Environment: getEnv("APP_ENV", "production"),
        Timestamp:   time.Now().Format(time.RFC3339),
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    w.Write([]byte(`{"status":"healthy"}`))
}

func getEnv(key, fallback string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return fallback
}

func main() {
    http.HandleFunc("/", homeHandler)
    http.HandleFunc("/health", healthHandler)

    port := getEnv("PORT", "8080")
    fmt.Printf("Server starting on port %s\n", port)
    log.Fatal(http.ListenAndServe(":"+port, nil))
}
EOF

# Créer go.mod
cat > go.mod << 'EOF'
module github.com/example/go-app

go 1.21
EOF

# Dockerfile (version simple)
cat > Dockerfile << 'EOF'
FROM golang:1.21-alpine

WORKDIR /app

# Copier les fichiers
COPY go.mod ./
COPY main.go ./

# Compiler l'application
RUN go build -o server .

# Exposer le port
EXPOSE 8080

# Lancer l'application
CMD ["./server"]
EOF

# Build et run
docker build -t go-app:v1 .
docker run -d -p 8080:8080 --name go-app go-app:v1

# Test
curl http://localhost:8080
```

**Problème** : Cette image fait ~300MB ! On verra l'optimisation au TP10.

---

## Exercice 6 : ARG vs ENV

### 6.1 - Comprendre la différence

```bash
cat > Dockerfile << 'EOF'
FROM alpine:latest

# ARG : Disponible uniquement au BUILD
ARG BUILD_VERSION=1.0.0
ARG BUILD_DATE

# ENV : Disponible au BUILD et au RUNTIME
ENV APP_VERSION=${BUILD_VERSION}
ENV APP_ENV=production

# Utiliser ARG pendant le build
RUN echo "Building version ${BUILD_VERSION} at ${BUILD_DATE}" > /build-info.txt

# ENV sera disponible au runtime
CMD ["sh", "-c", "cat /build-info.txt && echo Running version: $APP_VERSION in $APP_ENV"]
EOF

# Build avec des arguments
docker build \
  --build-arg BUILD_VERSION=2.0.0 \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  -t arg-env-demo .

# Run
docker run --rm arg-env-demo

# Override ENV au runtime
docker run --rm -e APP_ENV=development arg-env-demo
```

---

## Exercice 7 : HEALTHCHECK

### 7.1 - Ajouter des health checks

```bash
cat > Dockerfile << 'EOF'
FROM nginx:alpine

# Copier une page custom
RUN echo "<h1>Healthy App</h1>" > /usr/share/nginx/html/index.html

# Définir un healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

EXPOSE 80
EOF

docker build -t healthcheck-demo .
docker run -d --name healthy healthcheck-demo

# Voir le status
docker ps
# STATUS affichera : starting, healthy, ou unhealthy

# Inspecter les health checks
docker inspect healthy --format='{{json .State.Health}}' | python3 -m json.tool

# Simuler un échec
docker exec healthy rm /usr/share/nginx/html/index.html

# Attendre 30s et vérifier
sleep 35
docker ps  # STATUS: unhealthy
```

---

## Exercice 8 : Scénario pratique complet

### Objectif : Application complète avec base de données

```bash
mkdir -p ~/docker-tp/fullstack-app
cd ~/docker-tp/fullstack-app

# Backend API
mkdir -p backend
cat > backend/package.json << 'EOF'
{
  "name": "backend",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.0"
  }
}
EOF

cat > backend/server.js << 'EOF'
const express = require('express');
const { Pool } = require('pg');

const app = express();
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'myapp',
  user: process.env.DB_USER || 'user',
  password: process.env.DB_PASSWORD || 'password',
  port: 5432,
});

app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'healthy', database: 'connected' });
  } catch (err) {
    res.status(500).json({ status: 'unhealthy', error: err.message });
  }
});

app.get('/api/data', async (req, res) => {
  try {
    const result = await pool.query('SELECT NOW() as current_time');
    res.json({ data: result.rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Backend running on port ${PORT}`);
});
EOF

cat > backend/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --production

COPY server.js ./

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget --quiet --tries=1 --spider http://localhost:3000/api/health || exit 1

USER node

CMD ["node", "server.js"]
EOF

# Frontend
mkdir -p frontend
cat > frontend/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Fullstack App</title>
    <style>
        body { font-family: Arial; max-width: 800px; margin: 50px auto; }
        button { padding: 10px 20px; margin: 10px; cursor: pointer; }
        #result { background: #f5f5f5; padding: 20px; margin-top: 20px; }
    </style>
</head>
<body>
    <h1>Application Fullstack Docker</h1>
    <button onclick="checkHealth()">Check Health</button>
    <button onclick="getData()">Get Data</button>
    <div id="result"></div>

    <script>
        async function checkHealth() {
            const res = await fetch('/api/health');
            const data = await res.json();
            document.getElementById('result').innerHTML =
                '<pre>' + JSON.stringify(data, null, 2) + '</pre>';
        }

        async function getData() {
            const res = await fetch('/api/data');
            const data = await res.json();
            document.getElementById('result').innerHTML =
                '<pre>' + JSON.stringify(data, null, 2) + '</pre>';
        }
    </script>
</body>
</html>
EOF

cat > frontend/nginx.conf << 'EOF'
server {
    listen 80;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }

    location /api/ {
        proxy_pass http://backend:3000/api/;
        proxy_set_header Host $host;
    }
}
EOF

cat > frontend/Dockerfile << 'EOF'
FROM nginx:alpine

COPY index.html /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1
EOF

# Build les images
docker build -t fullstack-backend:v1 ./backend
docker build -t fullstack-frontend:v1 ./frontend

echo "Images créées ! Voir module 5 pour le déploiement avec Docker Compose"
```

---

## 🏆 Validation

À l'issue de ce TP, vous devez savoir :

- [ ] Créer un Dockerfile de base
- [ ] Utiliser les instructions FROM, RUN, COPY, WORKDIR, ENV
- [ ] Comprendre la différence entre CMD et ENTRYPOINT
- [ ] Créer des images pour Node.js, Python, Go
- [ ] Utiliser ARG pour les arguments de build
- [ ] Ajouter des HEALTHCHECK
- [ ] Créer un .dockerignore
- [ ] Builder et tester des images personnalisées

---

## 📊 Récapitulatif des instructions

| Instruction | Usage | Moment |
|-------------|-------|--------|
| `FROM` | Image de base | Build |
| `RUN` | Exécuter commandes | Build |
| `COPY` | Copier fichiers | Build |
| `ADD` | Copier + extraire | Build |
| `WORKDIR` | Changer répertoire | Build & Run |
| `ENV` | Variables permanentes | Build & Run |
| `ARG` | Variables de build | Build only |
| `EXPOSE` | Documenter ports | Documentation |
| `CMD` | Commande par défaut | Run |
| `ENTRYPOINT` | Point d'entrée | Run |
| `HEALTHCHECK` | Vérification santé | Run |
| `USER` | Changer utilisateur | Build & Run |
| `LABEL` | Métadonnées | Documentation |

---

## 🚀 Aller plus loin

```dockerfile
# ONBUILD : Instructions pour les images dérivées
FROM node:18-alpine
WORKDIR /app
ONBUILD COPY package*.json ./
ONBUILD RUN npm install
ONBUILD COPY . .

# VOLUME : Déclarer un point de montage
FROM postgres:15
VOLUME /var/lib/postgresql/data

# SHELL : Changer le shell par défaut
FROM windows:nanoserver
SHELL ["powershell", "-Command"]

# STOPSIGNAL : Signal pour arrêter proprement
FROM nginx
STOPSIGNAL SIGTERM
```

---

**[→ Voir les solutions](../solutions/TP8-Solution.md)**

**[→ TP suivant : Optimisation et bonnes pratiques](TP9-Optimisation.md)**
