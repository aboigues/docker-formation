# TP9 : Optimisation et bonnes pratiques

## Objectif

Appliquer les bonnes pratiques pour créer des images Docker optimisées, sécurisées et maintenables.

## Durée estimée

45 minutes

---

## Exercice 1 : Optimiser la taille des images

### 1.1 - Choisir la bonne image de base

```bash
mkdir -p ~/docker-tp/optimization
cd ~/docker-tp/optimization

# Comparer les tailles de base
cat > Dockerfile.ubuntu << 'EOF'
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y python3
CMD ["python3", "--version"]
EOF

cat > Dockerfile.alpine << 'EOF'
FROM alpine:latest
RUN apk add --no-cache python3
CMD ["python3", "--version"]
EOF

cat > Dockerfile.distroless << 'EOF'
FROM gcr.io/distroless/python3
CMD ["python3", "--version"]
EOF

# Build et comparer
docker build -f Dockerfile.ubuntu -t python:ubuntu .
docker build -f Dockerfile.alpine -t python:alpine .
docker build -f Dockerfile.distroless -t python:distroless .

docker images | grep python:
# ubuntu: ~150MB
# alpine: ~50MB
# distroless: ~60MB
```

### 1.2 - Minimiser les layers

```bash
# ✗ MAUVAIS : Beaucoup de layers
cat > Dockerfile.bad << 'EOF'
FROM alpine:latest
RUN apk add --no-cache curl
RUN apk add --no-cache wget
RUN apk add --no-cache git
RUN rm -rf /var/cache/apk/*
EOF

# ✓ BON : Layers combinés
cat > Dockerfile.good << 'EOF'
FROM alpine:latest
RUN apk add --no-cache \
    curl \
    wget \
    git \
    && rm -rf /var/cache/apk/*
EOF

docker build -f Dockerfile.bad -t layers:bad .
docker build -f Dockerfile.good -t layers:good .

docker history layers:bad
docker history layers:good
```

### 1.3 - Nettoyer dans le même RUN

```bash
cat > Dockerfile << 'EOF'
FROM ubuntu:22.04

# ✓ BON : Installer et nettoyer dans le même RUN
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Pour Alpine
# RUN apk add --no-cache curl \
#     && rm -rf /var/cache/apk/*

# Pour Python
# RUN pip install --no-cache-dir -r requirements.txt
EOF
```

---

## Exercice 2 : Optimiser le cache

### 2.1 - Ordre des instructions

```bash
# ✗ MAUVAIS : Cache invalidé à chaque changement de code
cat > Dockerfile.bad << 'EOF'
FROM node:18-alpine
WORKDIR /app
COPY . .
RUN npm install
CMD ["npm", "start"]
EOF

# ✓ BON : Dependencies d'abord, code ensuite
cat > Dockerfile.good << 'EOF'
FROM node:18-alpine
WORKDIR /app

# Copier package.json d'abord
COPY package*.json ./
RUN npm install

# Copier le code en dernier
COPY . .
CMD ["npm", "start"]
EOF

# Test : Modifier le code et rebuilder
# Version good utilisera le cache pour npm install
```

### 2.2 - .dockerignore efficace

```bash
cat > .dockerignore << 'EOF'
# Dépendances (seront installées dans le container)
node_modules
vendor
__pycache__

# Fichiers de build
dist
build
*.pyc
*.pyo
.next

# Fichiers de développement
.git
.gitignore
.env
.env.local
*.md
docs/

# Fichiers de test
test/
tests/
*.test.js
*.spec.js
coverage/

# IDE
.vscode
.idea
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# CI/CD
.github/
.gitlab-ci.yml
Jenkinsfile

# Docker
Dockerfile*
docker-compose*
.dockerignore
EOF
```

---

## Exercice 3 : Sécurité

### 3.1 - Utilisateur non-root

```bash
cat > Dockerfile << 'EOF'
FROM node:18-alpine

# Créer un utilisateur non-root
RUN addgroup -g 1000 appgroup && \
    adduser -D -u 1000 -G appgroup appuser

WORKDIR /app

# Copier et installer en tant que root
COPY package*.json ./
RUN npm install --production

# Copier le code
COPY --chown=appuser:appgroup . .

# Changer vers utilisateur non-root
USER appuser

CMD ["node", "server.js"]
EOF
```

### 3.2 - Scanner les vulnérabilités

```bash
# Avec Docker Scout (intégré)
docker scout cves nginx:latest

# Avec Trivy
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image nginx:latest

# Avec Grype
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  anchore/grype:latest nginx:latest
```

### 3.3 - Secrets et données sensibles

```bash
# ✗ MAUVAIS : Secrets dans l'image
cat > Dockerfile.bad << 'EOF'
FROM alpine
ENV API_KEY=secret123
EOF

# ✓ BON : Secrets au runtime
cat > Dockerfile.good << 'EOF'
FROM alpine
# Pas de secrets codés en dur !
# Utiliser -e au runtime ou Docker secrets
EOF

docker run -e API_KEY=secret123 myapp

# Ou avec Docker secrets (Swarm)
echo "secret123" | docker secret create api_key -
```

---

## Exercice 4 : Best Practices complètes

### 4.1 - Application Node.js optimisée

```bash
cat > Dockerfile << 'EOF'
# 1. Utiliser une version spécifique
FROM node:18.17-alpine3.18

# 2. Métadonnées
LABEL maintainer="dev@example.com" \
      version="1.0.0" \
      description="Optimized Node.js app"

# 3. Variables d'environnement
ENV NODE_ENV=production \
    PORT=3000

# 4. Installer les dépendances système si nécessaire
RUN apk add --no-cache \
    dumb-init \
    && rm -rf /var/cache/apk/*

# 5. Créer utilisateur non-root
RUN addgroup -g 1000 node && \
    adduser -D -u 1000 -G node node

# 6. Définir le workdir
WORKDIR /app

# 7. Copier les fichiers de dépendances
COPY package*.json ./

# 8. Installer les dépendances
RUN npm ci --only=production && \
    npm cache clean --force

# 9. Copier le code source
COPY --chown=node:node . .

# 10. Changer vers utilisateur non-root
USER node

# 11. Exposer le port
EXPOSE 3000

# 12. Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD node healthcheck.js || exit 1

# 13. Utiliser dumb-init pour gérer les signaux
ENTRYPOINT ["dumb-init", "--"]

# 14. Commande de démarrage
CMD ["node", "server.js"]
EOF
```

### 4.2 - Application Python optimisée

```bash
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

# Éviter la création de .pyc
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Installer les dépendances système (gcc pour build, curl pour healthcheck)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc \
        curl \
        && rm -rf /var/lib/apt/lists/*

# Copier et installer les dépendances Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    apt-get purge -y --auto-remove gcc

# Note: curl reste installé pour le HEALTHCHECK

# Copier le code
COPY . .

# Utilisateur non-root
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s CMD curl -f http://localhost:8000/health || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "app:app"]
EOF
```

---

## Exercice 5 : Metadata et Labels

### 5.1 - OCI Labels

```bash
cat > Dockerfile << 'EOF'
FROM alpine:latest

# Labels standards OCI
LABEL org.opencontainers.image.title="My App" \
      org.opencontainers.image.description="Application description" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.authors="dev@example.com" \
      org.opencontainers.image.url="https://example.com" \
      org.opencontainers.image.source="https://github.com/user/repo" \
      org.opencontainers.image.created="2024-01-01T00:00:00Z" \
      org.opencontainers.image.revision="abc123"

# Labels personnalisés
LABEL com.example.team="Platform" \
      com.example.environment="production" \
      com.example.tier="backend"

CMD ["sh"]
EOF

# Voir les labels
docker inspect myapp --format '{{json .Config.Labels}}'
```

### 5.2 - Build args pour metadata

```bash
cat > Dockerfile << 'EOF'
FROM alpine:latest

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.version="${VERSION}"
EOF

# Build avec metadata
docker build \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  --build-arg VERSION=1.0.0 \
  -t myapp:1.0.0 .
```

---

## Exercice 6 : Benchmarking et analyse

### 6.1 - Comparer les images

```bash
#!/bin/bash
# compare-images.sh

echo "=== Comparaison d'images ==="
echo ""

for img in myapp:v1 myapp:v2 myapp:v3; do
    echo "Image: $img"
    echo "  Taille: $(docker images $img --format '{{.Size}}')"
    echo "  Layers: $(docker history $img --quiet | wc -l)"
    echo "  Créée: $(docker inspect $img --format '{{.Created}}')"
    echo ""
done

# Analyse avec dive
docker run --rm -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  wagoodman/dive:latest myapp:v1
```

### 6.2 - Build time comparison

```bash
#!/bin/bash

echo "=== Build Time Comparison ==="

# Sans cache
time docker build --no-cache -t myapp:nocache .

# Avec cache
time docker build -t myapp:cache .

# Buildkit
DOCKER_BUILDKIT=1 time docker build -t myapp:buildkit .
```

---

## Exercice 7 : Checklist de production

### 7.1 - Vérifier une image

```bash
#!/bin/bash
# check-image.sh

IMAGE=$1

echo "=== Analyse de $IMAGE ==="
echo ""

# 1. Taille
echo "1. Taille:"
docker images $IMAGE --format "  {{.Size}}"
echo ""

# 2. Utilisateur
echo "2. Utilisateur:"
USER=$(docker inspect $IMAGE --format '{{.Config.User}}')
if [ -z "$USER" ] || [ "$USER" = "root" ] || [ "$USER" = "0" ]; then
    echo "  ⚠️  WARNING: Running as root"
else
    echo "  ✓ Running as user: $USER"
fi
echo ""

# 3. Health check
echo "3. Health Check:"
HEALTHCHECK=$(docker inspect $IMAGE --format '{{.Config.Healthcheck}}')
if [ "$HEALTHCHECK" = "<nil>" ]; then
    echo "  ⚠️  WARNING: No healthcheck defined"
else
    echo "  ✓ Healthcheck configured"
fi
echo ""

# 4. Exposed ports
echo "4. Exposed Ports:"
docker inspect $IMAGE --format '{{range $p, $conf := .Config.ExposedPorts}}  - {{$p}}{{"\n"}}{{end}}'
echo ""

# 5. Environment variables
echo "5. Environment Variables:"
docker inspect $IMAGE --format '{{range .Config.Env}}  - {{.}}{{"\n"}}{{end}}'
echo ""

# 6. Volumes
echo "6. Volumes:"
VOLUMES=$(docker inspect $IMAGE --format '{{.Config.Volumes}}')
if [ "$VOLUMES" = "map[]" ]; then
    echo "  None"
else
    echo "$VOLUMES"
fi
echo ""

# 7. Labels
echo "7. Labels:"
docker inspect $IMAGE --format '{{range $k, $v := .Config.Labels}}  {{$k}}: {{$v}}{{"\n"}}{{end}}'
```

---

## 🏆 Validation

- [ ] Optimisé la taille des images (< 100MB pour apps simples)
- [ ] Minimisé le nombre de layers
- [ ] Utilisé le cache Docker efficacement
- [ ] Configuré un utilisateur non-root
- [ ] Ajouté des healthchecks
- [ ] Créé un .dockerignore approprié
- [ ] Ajouté des labels OCI
- [ ] Scanné les vulnérabilités

---

## 📊 Checklist de bonnes pratiques

```markdown
Image de base:
- [ ] Version spécifique (pas :latest)
- [ ] Image officielle ou de confiance
- [ ] Alpine/slim si possible
- [ ] Distroless pour production

Build:
- [ ] .dockerignore configuré
- [ ] Dépendances avant le code
- [ ] Layers combinés (&&)
- [ ] Nettoyage dans le même RUN
- [ ] Pas de secrets dans l'image

Sécurité:
- [ ] Utilisateur non-root
- [ ] Pas de données sensibles
- [ ] Scan de vulnérabilités
- [ ] Mise à jour régulières

Runtime:
- [ ] Healthcheck défini
- [ ] Ports documentés (EXPOSE)
- [ ] Variables d'environnement
- [ ] Labels OCI

Production:
- [ ] Multi-stage build
- [ ] Taille optimisée
- [ ] Logs vers stdout/stderr
- [ ] Graceful shutdown
```

---

**[→ Voir les solutions](../solutions/TP9-Solution.md)**

**[→ TP suivant : Multi-stage builds](TP10-MultiStage.md)**
