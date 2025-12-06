# Solutions - Module 4 : Conteneur personnalisé

## TP8 : Dockerfile fondamentaux - Solutions

### Exercice 1.1 - Réponses

**1. Combien de layers ajoutés ?**
3 layers : LABEL, COPY, EXPOSE. Vérifier avec `docker history mon-site-web:v1`.

**2. Rebuild après modification ?**
Docker utilise le cache jusqu'au COPY. Seul le layer COPY est reconstruit.

**3. Pourquoi alpine ?**
- 5x plus petit (~5MB vs ~25MB)
- Moins de vulnérabilités
- Démarrage plus rapide

### Exercice 3.1 - Application Node.js

**1. Pourquoi copier package.json séparément ?**
Cache de Docker : si package.json ne change pas, npm install n'est pas réexécuté.

**2. Avantage de USER node ?**
Sécurité : principe du moindre privilège. Si le conteneur est compromis, l'attaquant n'a pas les droits root.

**3. Modification de server.js ?**
Seulement le layer COPY et CMD sont reconstruits. npm install utilise le cache.

---

## TP9 : Optimisation - Solutions

### Comparaison des tailles

```bash
# Résultats typiques:
ubuntu:22.04 base     → ~150MB
+ python3             → ~200MB

alpine:latest base    → ~7MB
+ python3             → ~50MB

distroless/python3    → ~60MB (sans shell)
```

### Best Dockerfile Node.js annoté

```dockerfile
# Base spécifique (pas latest) et légère
FROM node:18.17-alpine3.18

# Metadata OCI standard
LABEL org.opencontainers.image.title="My App" \
      org.opencontainers.image.version="1.0.0"

# Variables permanentes
ENV NODE_ENV=production \
    PORT=3000

# Dépendances système minimales
RUN apk add --no-cache dumb-init

# Utilisateur non-root
RUN addgroup -g 1000 node && adduser -D -u 1000 -G node node

WORKDIR /app

# Dependencies AVANT le code (cache)
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Code source
COPY --chown=node:node . .

USER node

EXPOSE 3000

# Healthcheck
HEALTHCHECK --interval=30s CMD node healthcheck.js || exit 1

# dumb-init pour proper signal handling
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "server.js"]
```

### Script de vérification complet

```bash
#!/bin/bash
# Production Readiness Check

IMAGE=$1

echo "=== Production Readiness: $IMAGE ==="

# Taille
SIZE=$(docker images $IMAGE --format '{{.Size}}')
echo "1. Taille: $SIZE"
if [[ "$SIZE" == *GB* ]]; then
    echo "   ⚠️  WARNING: Image > 1GB"
fi

# User
USER=$(docker inspect $IMAGE --format '{{.Config.User}}')
if [ "$USER" = "" ] || [ "$USER" = "root" ]; then
    echo "2. User: ✗ RUNNING AS ROOT"
else
    echo "2. User: ✓ $USER"
fi

# Healthcheck
HC=$(docker inspect $IMAGE --format '{{.Config.Healthcheck}}')
if [ "$HC" = "<nil>" ]; then
    echo "3. Healthcheck: ✗ MISSING"
else
    echo "3. Healthcheck: ✓ Configured"
fi

# Version
VERSION=$(docker inspect $IMAGE --format '{{index .Config.Labels "org.opencontainers.image.version"}}')
echo "4. Version: ${VERSION:-⚠️  Not labeled}"

# Scan vulnérabilités
echo "5. Security scan:"
docker scout cves $IMAGE --only-severity high,critical 2>/dev/null || echo "   Install Docker Scout for scanning"
```

---

## TP10 : Multi-stage - Solutions

### Go: Comparaison détaillée

```bash
# Single-stage
FROM golang:1.21
# ... build and run
# Résultat: ~800MB

# Multi-stage
FROM golang:1.21 AS builder
# ... build
FROM alpine:latest
COPY --from=builder /app/server .
# Résultat: ~10MB

# Distroless
FROM gcr.io/distroless/static-debian11
COPY --from=builder /app/server /server
# Résultat: ~3MB
```

**Pourquoi cette différence ?**

```
golang:1.21 contient:
- Compilateur Go: ~400MB
- Outils de développement: ~200MB
- Bibliothèques système: ~200MB

alpine contient:
- Système minimal: ~5MB
+ binaire Go: ~2-5MB

distroless contient:
- Absolument minimal (pas de shell!)
+ binaire Go: ~2-5MB
```

### Pattern: Build + Test + Production

```dockerfile
# Base commune
FROM node:18-alpine AS base
WORKDIR /app
COPY package*.json ./

# Dependencies complètes (dev + prod)
FROM base AS dependencies
RUN npm install

# Tests (dépend de dependencies)
FROM dependencies AS test
COPY . .
RUN npm run test
RUN npm run lint
# Si les tests échouent, le build s'arrête ici !

# Build de production (dépend de dependencies)
FROM dependencies AS builder
COPY . .
RUN npm run build

# Runtime minimal (copie depuis builder)
FROM nginx:alpine AS production
COPY --from=builder /app/dist /usr/share/nginx/html

# Usage:
# docker build --target test .        # Run tests only
# docker build --target production .  # Tests + Build + Package
```

### Cache optimization avec BuildKit

```dockerfile
# syntax=docker/dockerfile:1

FROM node:18-alpine AS builder

WORKDIR /app

# Cache mount: npm cache persiste entre builds
RUN --mount=type=cache,target=/root/.npm \
    --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    npm ci

COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
```

### Multi-stage pour plusieurs architectures

```dockerfile
# Build pour l'architecture cible
FROM --platform=$BUILDPLATFORM golang:1.21 AS builder

ARG TARGETPLATFORM
ARG BUILDPLATFORM

WORKDIR /app
COPY . .

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -o server .

FROM alpine:latest
COPY --from=builder /app/server /server
CMD ["/server"]
```

```bash
# Build multi-arch
docker buildx build --platform linux/amd64,linux/arm64 -t myapp:latest .
```

---

## Patterns complets par langage

### Node.js Production-Ready

```dockerfile
# syntax=docker/dockerfile:1

FROM node:18-alpine AS base
ENV NODE_ENV=production
WORKDIR /app

# Dependencies avec cache
FROM base AS dependencies
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --only=production

# Build
FROM base AS builder
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci
COPY . .
RUN npm run build

# Runtime
FROM base AS runtime
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

COPY --from=dependencies /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY package*.json ./

USER nodejs
EXPOSE 3000

HEALTHCHECK --interval=30s CMD node healthcheck.js || exit 1

CMD ["node", "dist/index.js"]
```

### Python Production-Ready

```dockerfile
FROM python:3.11-slim AS base
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

# Builder
FROM base AS builder
RUN apt-get update && apt-get install -y --no-install-recommends gcc
WORKDIR /app

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install -r requirements.txt

# Runtime
FROM base AS runtime
RUN useradd -m -u 1000 appuser

COPY --from=builder /opt/venv /opt/venv
COPY . /app

WORKDIR /app
ENV PATH="/opt/venv/bin:$PATH"

USER appuser
EXPOSE 8000

HEALTHCHECK --interval=30s CMD curl -f http://localhost:8000/health || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:app"]
```

### Go Production-Ready

```dockerfile
FROM golang:1.21-alpine AS builder

WORKDIR /build

# Dependencies
COPY go.mod go.sum ./
RUN go mod download

# Build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags='-w -s -extldflags "-static"' \
    -o app .

# Runtime (scratch = absolute minimum)
FROM scratch

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /build/app /app

EXPOSE 8080

HEALTHCHECK --interval=30s CMD ["/app", "healthcheck"]

ENTRYPOINT ["/app"]
```

---

## Debugging Tips

### Voir ce qui est dans chaque layer

```bash
# Avec dive
dive myimage:latest

# Ou manuellement
docker history myimage:latest --no-trunc
docker save myimage:latest | tar -xvf -
```

### Builder un stage spécifique

```bash
# Builder et inspecter le stage "builder"
docker build --target builder -t debug:builder .
docker run --rm -it debug:builder sh

# Voir ce qui a été copié
ls -la /app
```

### Comparer avant/après optimization

```bash
#!/bin/bash

echo "Building original..."
docker build -f Dockerfile.original -t app:original .

echo "Building optimized..."
docker build -f Dockerfile.optimized -t app:optimized .

echo ""
echo "=== Comparison ==="
echo "Original:"
docker images app:original --format "  Size: {{.Size}}"
docker history app:original --format "  Layers: {{.ID}}" | wc -l

echo ""
echo "Optimized:"
docker images app:optimized --format "  Size: {{.Size}}"
docker history app:optimized --format "  Layers: {{.ID}}" | wc -l
```

---

## Checklist finale

### Image de Production

```markdown
✅ Base image:
- [ ] Version tagguée (pas latest)
- [ ] Image officielle ou trusted
- [ ] Alpine/slim/distroless

✅ Build:
- [ ] Multi-stage si langage compilé
- [ ] .dockerignore configuré
- [ ] Layers minimisés
- [ ] Cache optimisé

✅ Sécurité:
- [ ] USER non-root
- [ ] Scan de vulnérabilités
- [ ] Pas de secrets
- [ ] Minimal surface d'attaque

✅ Production:
- [ ] HEALTHCHECK défini
- [ ] Labels OCI
- [ ] Taille < 200MB si possible
- [ ] Tests inclus dans le build
```

### Commandes de validation

```bash
# Taille acceptable?
docker images myapp:latest --format '{{.Size}}'

# User non-root?
docker inspect myapp:latest --format '{{.Config.User}}'

# Healthcheck?
docker inspect myapp:latest --format '{{.Config.Healthcheck}}'

# Vulnerabilités?
docker scout cves myapp:latest --only-severity high,critical

# Labels?
docker inspect myapp:latest --format '{{json .Config.Labels}}' | jq
```

---

**[← Retour aux TPs](../tp/)**
