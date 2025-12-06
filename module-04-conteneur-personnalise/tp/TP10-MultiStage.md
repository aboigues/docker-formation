# TP10 : Multi-stage builds

## Objectif

Maîtriser les builds multi-étapes pour créer des images optimisées, légères et sécurisées.

## Durée estimée

60 minutes

## Concept clé

```
┌──────────────────────────────────────────────────┐
│          Multi-Stage Build Pattern               │
├──────────────────────────────────────────────────┤
│                                                  │
│  Stage 1: BUILD                                  │
│  ┌────────────────────┐                         │
│  │ Image complète     │                         │
│  │ + Compilateurs     │                         │
│  │ + Dev tools        │                         │
│  │ + Source code      │                         │
│  └────────┬───────────┘                         │
│           │ Compilation                          │
│           ▼                                      │
│      Binary/Artifacts                            │
│           │                                      │
│           │ COPY --from=build                    │
│           ▼                                      │
│  Stage 2: RUNTIME                                │
│  ┌────────────────────┐                         │
│  │ Image minimale     │                         │
│  │ + Runtime only     │                         │
│  │ + Binary           │                         │
│  └────────────────────┘                         │
│                                                  │
│  Résultat: Image finale légère !                │
│                                                  │
└──────────────────────────────────────────────────┘
```

---

## Exercice 1 : Premier multi-stage build

### 1.1 - Application Go (exemple parfait)

```bash
mkdir -p ~/docker-tp/multistage-go
cd ~/docker-tp/multistage-go

# Créer une application Go simple
cat > main.go << 'EOF'
package main

import (
    "fmt"
    "log"
    "net/http"
)

func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintf(w, "Hello from multi-stage build!")
    })

    log.Println("Server starting on :8080")
    log.Fatal(http.ListenAndServe(":8080", nil))
}
EOF

cat > go.mod << 'EOF'
module example.com/app

go 1.21
EOF

# ✗ SANS multi-stage (image énorme)
cat > Dockerfile.single << 'EOF'
FROM golang:1.21
WORKDIR /app
COPY . .
RUN go build -o server .
CMD ["./server"]
EOF

# ✓ AVEC multi-stage (image minimale)
cat > Dockerfile << 'EOF'
# Stage 1: Build
FROM golang:1.21 AS builder

WORKDIR /app
COPY go.mod ./
COPY main.go ./

# Compiler en statique pour Alpine
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o server .

# Stage 2: Runtime
FROM alpine:latest

# Installer certificats SSL
RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copier SEULEMENT le binaire compilé
COPY --from=builder /app/server .

EXPOSE 8080

CMD ["./server"]
EOF

# Comparer les tailles
docker build -f Dockerfile.single -t go-app:single .
docker build -f Dockerfile -t go-app:multi .

docker images | grep go-app
# go-app:single  ~800MB
# go-app:multi   ~10MB (!!)
```

**Résultat** : Réduction de 98% de la taille !

### 1.2 - Distroless pour sécurité maximale

```bash
cat > Dockerfile.distroless << 'EOF'
# Stage 1: Build
FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 go build -o server .

# Stage 2: Distroless (pas de shell, pas d'outils)
FROM gcr.io/distroless/static-debian11

COPY --from=builder /app/server /server

EXPOSE 8080

ENTRYPOINT ["/server"]
EOF

docker build -f Dockerfile.distroless -t go-app:distroless .
docker images | grep go-app:distroless
# ~3MB seulement !
```

---

## Exercice 2 : Node.js avec multi-stage

### 2.1 - Application React

```bash
mkdir -p ~/docker-tp/multistage-react
cd ~/docker-tp/multistage-react

# Créer package.json
cat > package.json << 'EOF'
{
  "name": "react-app",
  "version": "1.0.0",
  "scripts": {
    "build": "echo 'Building...'; mkdir -p dist && echo '<h1>React App</h1>' > dist/index.html"
  },
  "dependencies": {},
  "devDependencies": {}
}
EOF

cat > Dockerfile << 'EOF'
# Stage 1: Build
FROM node:18 AS builder

WORKDIR /app

# Copier les fichiers de dépendances
COPY package*.json ./

# Installer TOUTES les dépendances (dev included)
RUN npm install

# Copier le code source
COPY . .

# Builder l'application
RUN npm run build

# Stage 2: Production
FROM nginx:alpine

# Copier SEULEMENT les fichiers buildés
COPY --from=builder /app/dist /usr/share/nginx/html

# Configuration nginx custom
RUN echo 'server { listen 80; location / { root /usr/share/nginx/html; try_files $uri /index.html; } }' \
    > /etc/nginx/conf.d/default.conf

# Installer wget pour le healthcheck
RUN apk add --no-cache wget

EXPOSE 80

HEALTHCHECK CMD wget --quiet --tries=1 --spider http://localhost || exit 1
EOF

docker build -t react-app:multi .
docker run -d -p 8080:80 react-app:multi
```

**Avantages** :
- Image de build: ~1GB (avec tous les outils)
- Image finale: ~20MB (seulement les assets)
- Pas de code source dans l'image finale
- Pas de node_modules en production

---

## Exercice 3 : Python avec multi-stage

### 3.1 - Compiler des dépendances natives

```bash
mkdir -p ~/docker-tp/multistage-python
cd ~/docker-tp/multistage-python

cat > requirements.txt << 'EOF'
Flask==3.0.0
gunicorn==21.2.0
pandas==2.1.0
numpy==1.26.0
EOF

cat > app.py << 'EOF'
from flask import Flask, jsonify
import pandas as pd
import numpy as np

app = Flask(__name__)

@app.route('/')
def home():
    # Démonstration que pandas/numpy fonctionnent
    df = pd.DataFrame({'a': [1, 2, 3]})
    arr = np.array([1, 2, 3])

    return jsonify({
        'message': 'Hello from multi-stage Python!',
        'pandas_sum': int(df['a'].sum()),
        'numpy_sum': int(arr.sum())
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

cat > Dockerfile << 'EOF'
# Stage 1: Builder
FROM python:3.11 AS builder

WORKDIR /app

# Installer les dépendances de compilation
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Créer un virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Installer les dépendances Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim

WORKDIR /app

# Copier le virtual environment depuis builder
COPY --from=builder /opt/venv /opt/venv

# Copier le code
COPY app.py .

# Activer le venv
ENV PATH="/opt/venv/bin:$PATH"

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
EOF

docker build -t python-app:multi .

# Comparer avec version sans multi-stage
cat > Dockerfile.single << 'EOF'
FROM python:3.11
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY app.py .
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
EOF

docker build -f Dockerfile.single -t python-app:single .

docker images | grep python-app
# single: ~1.2GB
# multi:  ~400MB
```

---

## Exercice 4 : Stages multiples avancés

### 4.1 - Stages nommés et réutilisation

```bash
cat > Dockerfile << 'EOF'
# Stage: Base commune
FROM node:18-alpine AS base
WORKDIR /app
COPY package*.json ./

# Stage: Dependencies de développement
FROM base AS development
RUN npm install
COPY . .
CMD ["npm", "run", "dev"]

# Stage: Dependencies de production
FROM base AS dependencies
RUN npm ci --only=production

# Stage: Builder
FROM base AS builder
RUN npm ci
COPY . .
RUN npm run build

# Stage: Production finale
FROM node:18-alpine AS production
WORKDIR /app

COPY --from=dependencies /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY package*.json ./

USER node

CMD ["node", "dist/server.js"]
EOF

# Builder différents stages
docker build --target development -t myapp:dev .
docker build --target production -t myapp:prod .
```

### 4.2 - Copier depuis plusieurs stages

```bash
cat > Dockerfile << 'EOF'
# Stage 1: Compiler le backend
FROM golang:1.21 AS backend-builder
WORKDIR /app
COPY backend/ ./
RUN go build -o server .

# Stage 2: Builder le frontend
FROM node:18 AS frontend-builder
WORKDIR /app
COPY frontend/ ./
RUN npm install && npm run build

# Stage 3: Image finale
FROM alpine:latest
WORKDIR /app

# Copier depuis les deux builders
COPY --from=backend-builder /app/server ./
COPY --from=frontend-builder /app/dist ./static/

CMD ["./server"]
EOF
```

---

## Exercice 5 : Optimisation avancée

### 5.1 - Cache mount avec BuildKit

```bash
# Activer BuildKit
export DOCKER_BUILDKIT=1

cat > Dockerfile << 'EOF'
# syntax=docker/dockerfile:1

FROM node:18-alpine AS builder

WORKDIR /app

# Utiliser le cache mount pour npm
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm install

COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EOF

# Le cache npm persiste entre les builds !
docker build -t app:v1 .
docker build -t app:v2 .  # Beaucoup plus rapide
```

### 5.2 - Bind mount pour development

```bash
cat > Dockerfile << 'EOF'
# syntax=docker/dockerfile:1

FROM node:18-alpine AS development

WORKDIR /app

# Utiliser bind mount pour ne pas copier node_modules
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=cache,target=/root/.npm \
    npm ci

COPY . .

CMD ["npm", "run", "dev"]
EOF
```

---

## Exercice 6 : Patterns avancés

### 6.1 - Build ARG dans multi-stage

```bash
cat > Dockerfile << 'EOF'
ARG NODE_VERSION=18

# Stage 1: Builder
FROM node:${NODE_VERSION}-alpine AS builder

ARG BUILD_ENV=production
ARG API_URL=https://api.example.com

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .

# Passer les build args à l'app
RUN echo "VITE_API_URL=${API_URL}" > .env.production && \
    npm run build

# Stage 2: Runtime
FROM nginx:alpine

COPY --from=builder /app/dist /usr/share/nginx/html
EOF

# Builder avec différents arguments
docker build --build-arg API_URL=https://api.prod.com -t app:prod .
docker build --build-arg API_URL=https://api.dev.com -t app:dev .
```

### 6.2 - Stage de test

```bash
cat > Dockerfile << 'EOF'
FROM node:18-alpine AS base
WORKDIR /app
COPY package*.json ./

# Stage: Dependencies
FROM base AS dependencies
RUN npm ci

# Stage: Test
FROM dependencies AS test
COPY . .
RUN npm run test
RUN npm run lint

# Stage: Build
FROM dependencies AS builder
COPY . .
RUN npm run build

# Stage: Production
FROM nginx:alpine AS production
COPY --from=builder /app/dist /usr/share/nginx/html
EOF

# Runner les tests pendant le build
docker build --target test -t myapp:test .

# Ou builder directement en prod (tests inclus)
docker build --target production -t myapp:prod .
```

---

## Exercice 7 : Cas pratiques complets

### 7.1 - API Go complète avec migrations

```bash
mkdir -p ~/docker-tp/go-api-complete
cd ~/docker-tp/go-api-complete

cat > main.go << 'EOF'
package main

import (
    "fmt"
    "log"
    "net/http"
    "os"
)

func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintf(w, "API version: %s\n", os.Getenv("VERSION"))
    })

    log.Fatal(http.ListenAndServe(":8080", nil))
}
EOF

cat > go.mod << 'EOF'
module api

go 1.21
EOF

cat > Dockerfile << 'EOF'
# Stage 1: Build
FROM golang:1.21-alpine AS builder

WORKDIR /build

# Installer les dépendances de build
RUN apk add --no-cache git ca-certificates tzdata

# Copier et télécharger les dépendances
COPY go.mod go.sum* ./
RUN go mod download

# Copier le code source
COPY . .

# Compiler avec optimisations
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -o app .

# Stage 2: Runtime minimal
FROM scratch

# Copier les certificats SSL
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copier timezone data
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copier le binaire
COPY --from=builder /build/app /app

# Variables d'environnement
ENV VERSION=1.0.0

EXPOSE 8080

ENTRYPOINT ["/app"]
EOF

docker build -t go-api:optimized .
docker images go-api:optimized
# Taille: ~7MB !
```

### 7.2 - Frontend + Backend dans un seul Dockerfile

```bash
cat > Dockerfile << 'EOF'
# Backend build
FROM golang:1.21-alpine AS backend-builder
WORKDIR /app
COPY backend/ ./
RUN CGO_ENABLED=0 go build -o server .

# Frontend build
FROM node:18-alpine AS frontend-builder
WORKDIR /app
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

# Runtime
FROM alpine:latest
WORKDIR /app

# Installer runtime dependencies
RUN apk add --no-cache ca-certificates

# Copier les artifacts
COPY --from=backend-builder /app/server ./
COPY --from=frontend-builder /app/dist ./public/

EXPOSE 8080

CMD ["./server"]
EOF
```

---

## Exercice 8 : Debugging multi-stage builds

### 8.1 - Examiner un stage spécifique

```bash
# Builder et taguer un stage intermédiaire
docker build --target builder -t myapp:builder .

# Inspecter le stage
docker run --rm -it myapp:builder sh

# Voir les fichiers copiés
docker run --rm myapp:builder ls -la /app
```

### 8.2 - Comparer les stages

```bash
#!/bin/bash

echo "=== Analyse multi-stage ==="

# Builder chaque stage
docker build --target builder -t app:builder .
docker build --target runtime -t app:runtime .

echo ""
echo "Stage Builder:"
docker images app:builder --format "  Taille: {{.Size}}"
docker history app:builder --quiet | wc -l | xargs echo "  Layers:"

echo ""
echo "Stage Runtime:"
docker images app:runtime --format "  Taille: {{.Size}}"
docker history app:runtime --quiet | wc -l | xargs echo "  Layers:"

echo ""
echo "Réduction:"
```

---

## 🏆 Validation

- [ ] Créé un multi-stage build pour Go
- [ ] Créé un multi-stage build pour Node.js/React
- [ ] Créé un multi-stage build pour Python
- [ ] Utilisé des stages nommés
- [ ] Copié depuis plusieurs stages
- [ ] Optimisé avec cache mounts
- [ ] Réduit la taille de l'image de 80%+
- [ ] Créé une image de type "scratch" ou "distroless"

---

## 📊 Checklist multi-stage

```markdown
Structure:
- [ ] Stage de build séparé du runtime
- [ ] Stages nommés (AS builder)
- [ ] Stage de test (optionnel)
- [ ] Image de base minimale pour runtime

Optimisation:
- [ ] Copier seulement les artifacts nécessaires
- [ ] Pas de code source dans l'image finale
- [ ] Pas d'outils de build dans l'image finale
- [ ] Utiliser scratch/distroless si possible

Build:
- [ ] Cache mount pour dépendances (BuildKit)
- [ ] Build args pour configuration
- [ ] Targets pour dev/prod
- [ ] Version pinning

Sécurité:
- [ ] Pas de secrets dans aucun stage
- [ ] Scanner toutes les images
- [ ] Utilisateur non-root dans runtime
- [ ] Image minimale = surface d'attaque réduite
```

---

## Comparaison avant/après

| Aspect | Sans Multi-Stage | Avec Multi-Stage |
|--------|------------------|------------------|
| **Taille** | 800MB - 2GB | 10MB - 100MB |
| **Layers** | 15-30 | 5-10 |
| **Sécurité** | Code source inclus | Seulement binaire |
| **Attaque** | Tous les outils | Minimal |
| **Build time** | ~5 min | ~2 min (cache) |
| **Best for** | Développement | Production |

---

**[→ Voir les solutions](../solutions/TP10-Solution.md)**

**[← Retour au README du module](../README.md)**
