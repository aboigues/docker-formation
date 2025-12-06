# TP7 : Solutions - Gestion avancée des images

## Exercice 1 : Comprendre les tags

### 1.1 - Réponses aux questions

**1. Certains tags ont-ils le même IMAGE ID ?**

Oui ! C'est normal et voulu. Les tags sont juste des pointeurs vers la même image :

```bash
docker images nginx
# REPOSITORY   TAG       IMAGE ID       SIZE
# nginx        1.25      a72860cb95fd   188MB
# nginx        stable    a72860cb95fd   188MB  # <- Même ID !
# nginx        latest    a72860cb95fd   188MB  # <- Même ID !
```

Analogie : Comme des liens symboliques ou des raccourcis. L'image existe une seule fois sur le disque, mais plusieurs tags peuvent pointer vers elle.

**2. Quelle est la différence entre `latest` et `stable` ?**

Les tags sont des conventions de nommage définies par le mainteneur de l'image :

- **`latest`** : Dernière version publiée (peut être une version de développement ou beta)
- **`stable`** : Dernière version stable recommandée pour la production
- **`1.25`** : Version majeure.mineure spécifique

⚠️ **Important** : `latest` ne signifie pas "la plus récente dans votre système local", mais "le tag par défaut" défini par l'auteur !

**3. Pourquoi `nginx:alpine` est-elle plus petite ?**

Alpine Linux est une distribution minimaliste :

```bash
# Comparaison
nginx:latest     ~188 MB  (basée sur Debian)
nginx:alpine     ~43 MB   (basée sur Alpine Linux)

# Différences:
- Alpine utilise musl libc au lieu de glibc
- Pas de packages inutiles
- Système de fichiers minimal
- Gestionnaire de paquets apk au lieu d'apt
```

**Avantages d'Alpine** :
- Moins d'espace disque
- Téléchargement plus rapide
- Surface d'attaque réduite (sécurité)

**Inconvénients** :
- Parfois incompatibilités avec certains binaires
- Débogage plus complexe (moins d'outils)

### 1.2 - Informations clés extraites

```bash
# Commandes utiles pour inspecter
# Date de création
docker inspect nginx:alpine --format '{{.Created}}'
# 2024-01-15T12:34:56.789Z

# Architecture
docker inspect nginx:alpine --format '{{.Architecture}}'
# amd64

# OS
docker inspect nginx:alpine --format '{{.Os}}'
# linux

# Taille
docker inspect nginx:alpine --format '{{.Size}} bytes'
# 42456789 bytes

# Variables d'environnement par défaut
docker inspect nginx:alpine --format '{{.Config.Env}}'

# Port exposé
docker inspect nginx:alpine --format '{{.Config.ExposedPorts}}'

# Commande par défaut
docker inspect nginx:alpine --format '{{.Config.Cmd}}'
# [nginx -g daemon off;]

# Working directory
docker inspect nginx:alpine --format '{{.Config.WorkingDir}}'
```

---

## Exercice 2 : Créer et gérer ses propres tags

### 2.1 - Réponses aux questions

**1. Créer un tag crée-t-il une copie de l'image ?**

Non ! `docker tag` crée seulement un nouveau pointeur (référence) vers la même image :

```bash
# Une seule image sur le disque
docker tag nginx:alpine mon-nginx:v1
docker tag nginx:alpine mon-nginx:v2

# Même IMAGE ID = même image physique
docker images --format "{{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}" | grep nginx

# Vérification de l'espace disque
docker system df
# Images        3         1         43MB      0B (0%)
# 3 tags mais 1 seule image physique !
```

**2. Combien d'espace disque utilisent ces 4 tags ?**

L'espace d'une seule image ! Les tags ne prennent pratiquement pas de place (quelques octets de métadonnées).

```bash
# Tester
TAILLE_AVANT=$(docker system df --format "{{.Size}}")

# Créer 100 tags
for i in {1..100}; do
  docker tag nginx:alpine mon-nginx:$i
done

TAILLE_APRES=$(docker system df --format "{{.Size}}")

echo "Différence négligeable !"
```

**3. Qu'est-ce qu'un tag exactement ?**

Un tag est une **référence nommée** vers une image identifiée par son SHA256 digest :

```
Nom complet : registry/repository:tag
                ↓
Résolution vers : sha256:abc123...xyz789
                ↓
Image physique stockée dans /var/lib/docker
```

### 2.2 - Personnalisation avec commit

⚠️ **Note importante** : `docker commit` est utile pour comprendre le fonctionnement, mais **n'est pas la meilleure pratique** en production. Préférez les Dockerfiles (module 4).

**Pourquoi éviter `docker commit` en production ?**

1. **Non reproductible** : Pas de trace de comment l'image a été créée
2. **Pas de versioning** : Difficile de suivre les changements
3. **Couches supplémentaires** : Image plus grosse
4. **Manque de documentation** : Autres développeurs ne savent pas ce qui a été modifié

```bash
# ✗ MAL (mais fonctionne)
docker run -d --name custom nginx
docker exec custom sh -c 'echo "Hello" > /usr/share/nginx/html/index.html'
docker commit custom my-nginx:v1

# ✓ BIEN (avec Dockerfile)
cat > Dockerfile << 'EOF'
FROM nginx:alpine
RUN echo "Hello" > /usr/share/nginx/html/index.html
EOF
docker build -t my-nginx:v1 .
```

---

## Exercice 3 : Sauvegarder et charger des images

### 3.1 - Différences export vs save

```bash
# DOCKER SAVE (images)
# ✓ Sauvegarde l'image complète
# ✓ Conserve l'historique et les layers
# ✓ Conserve les tags et métadonnées
# ✓ Peut restaurer exactement

docker save nginx:alpine -o nginx-save.tar
tar tvf nginx-save.tar
# manifest.json      <- Métadonnées
# repositories       <- Tags
# <layer-id>/        <- Chaque layer
#   layer.tar
#   json
#   VERSION

# DOCKER EXPORT (conteneurs)
# ✓ Exporte seulement le filesystem
# ✗ Perd l'historique
# ✗ Perd les métadonnées
# ✗ Devient une seule couche

docker export mon-conteneur -o container-export.tar
tar tvf container-export.tar
# bin/
# etc/
# usr/
# ...  <- Juste le filesystem
```

**Quand utiliser quoi ?**

```bash
# Use docker save quand:
- Backup d'images pour restauration exacte
- Transfert d'images entre environnements
- Archives versionnées

# Use docker export quand:
- Créer une image de base minimale
- Aplatir les layers
- Exporter l'état actuel d'un conteneur
```

### 3.2 - Optimisation de la sauvegarde

```bash
# Sauvegarder avec compression
docker save nginx:alpine | gzip -9 > nginx-alpine.tar.gz

# Comparaison des tailles
docker save nginx:alpine > nginx-alpine.tar
docker save nginx:alpine | gzip > nginx-alpine.tar.gz
docker save nginx:alpine | bzip2 > nginx-alpine.tar.bz2
docker save nginx:alpine | xz -9 > nginx-alpine.tar.xz

ls -lh nginx-alpine.tar*
# .tar     ~42 MB
# .tar.gz  ~16 MB  (gzip - rapide)
# .tar.bz2 ~14 MB  (bzip2 - plus compact)
# .tar.xz  ~12 MB  (xz - le plus compact, plus lent)

# Recommandation: gzip pour le meilleur compromis vitesse/taille
```

### 3.3 - Script de backup automatique

```bash
#!/bin/bash
# backup-images.sh

BACKUP_DIR="./docker-backups"
DATE=$(date +%Y%m%d-%H%M%S)

mkdir -p "$BACKUP_DIR"

# Lister toutes les images personnalisées (pas les officielles)
images=$(docker images --filter "reference=localhost/*" --filter "reference=*//*" --format "{{.Repository}}:{{.Tag}}")

if [ -z "$images" ]; then
    echo "Aucune image personnalisée trouvée"
    exit 0
fi

echo "=== Backup des images Docker ==="
echo "Date: $DATE"
echo "Destination: $BACKUP_DIR"
echo ""

total_size=0

for img in $images; do
    # Nom de fichier sécurisé
    filename=$(echo "$img" | tr '/:' '_')
    output="$BACKUP_DIR/${filename}_${DATE}.tar.gz"

    echo "Backup de $img..."

    # Sauvegarder avec compression
    docker save "$img" | gzip > "$output"

    # Vérifier la taille
    size=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output")
    size_mb=$((size / 1024 / 1024))
    total_size=$((total_size + size_mb))

    echo "  ✓ Sauvegardé: $output ($size_mb MB)"
done

echo ""
echo "=== Résumé ==="
echo "Images sauvegardées: $(echo "$images" | wc -l)"
echo "Taille totale: $total_size MB"
echo "Emplacement: $BACKUP_DIR"

# Créer un index
echo "$images" > "$BACKUP_DIR/images_${DATE}.txt"
```

---

## Exercice 4 : Registres Docker

### 4.1 - Docker Hub - Workflow complet

```bash
# 1. Créer un compte sur hub.docker.com
# 2. Se connecter
docker login
# Username: votre_username
# Password: votre_password (ou token)

# ⚠️ Sécurité: Utiliser des access tokens, pas votre mot de passe !
# Créer un token sur https://hub.docker.com/settings/security

# 3. Préparer une image
docker pull nginx:alpine
docker tag nginx:alpine votre_username/mon-nginx:v1.0
docker tag nginx:alpine votre_username/mon-nginx:latest

# 4. Pousser vers Docker Hub
docker push votre_username/mon-nginx:v1.0
docker push votre_username/mon-nginx:latest

# 5. Rendre l'image publique (sur le site web)
# https://hub.docker.com/repository/docker/votre_username/mon-nginx/general

# 6. Tester depuis n'importe où
docker pull votre_username/mon-nginx:v1.0

# 7. Automatiser avec des tags multiples
for tag in v1.0 v1.0.1 latest stable; do
  docker tag nginx:alpine votre_username/mon-nginx:$tag
  docker push votre_username/mon-nginx:$tag
done
```

### 4.2 - Registre privé - Configuration avancée

```bash
# Registre de base
docker run -d -p 5000:5000 --name registry registry:2

# Problème: Pas de persistance, pas de sécurité

# ✓ Configuration production-ready
docker run -d \
  -p 5000:5000 \
  --name registry \
  --restart=always \
  -v registry-data:/var/lib/registry \
  -v $(pwd)/config.yml:/etc/docker/registry/config.yml:ro \
  -e REGISTRY_HTTP_SECRET=changeme \
  registry:2

# config.yml
cat > config.yml << 'EOF'
version: 0.1
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
  delete:
    enabled: true
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
EOF
```

### 4.3 - API du registre

```bash
# Le registre expose une API REST complète

# 1. Lister tous les repositories
curl http://localhost:5000/v2/_catalog
# {"repositories":["nginx","myapp","redis"]}

# 2. Lister les tags d'une image
curl http://localhost:5000/v2/nginx/tags/list
# {"name":"nginx","tags":["alpine","latest","1.25"]}

# 3. Obtenir le manifest d'une image
curl http://localhost:5000/v2/nginx/manifests/alpine

# 4. Supprimer une image (si delete enabled)
# a. Obtenir le digest
DIGEST=$(curl -I -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  http://localhost:5000/v2/nginx/manifests/alpine 2>/dev/null | \
  grep Docker-Content-Digest | awk '{print $2}' | tr -d '\r')

# b. Supprimer
curl -X DELETE http://localhost:5000/v2/nginx/manifests/$DIGEST

# c. Garbage collection (libérer l'espace)
docker exec registry bin/registry garbage-collect /etc/docker/registry/config.yml

# 5. Script de maintenance
#!/bin/bash
# registry-maintenance.sh

REGISTRY="localhost:5000"

echo "=== Images dans le registre ==="
repos=$(curl -s http://$REGISTRY/v2/_catalog | jq -r '.repositories[]')

for repo in $repos; do
    echo ""
    echo "Repository: $repo"
    tags=$(curl -s http://$REGISTRY/v2/$repo/tags/list | jq -r '.tags[]')

    for tag in $tags; do
        # Obtenir la date de création
        manifest=$(curl -s http://$REGISTRY/v2/$repo/manifests/$tag)
        created=$(echo "$manifest" | jq -r '.history[0].v1Compatibility' | jq -r '.created')

        echo "  - $tag (created: $created)"
    done
done
```

---

## Exercice 5 : Inspection et analyse des images

### 5.1 - Analyse approfondie des layers

```bash
# Comprendre les layers

# 1. Voir l'historique complet
docker history nginx:alpine --no-trunc

# Chaque ligne = une instruction du Dockerfile original

# 2. Comprendre la taille
docker history nginx:alpine --format "table {{.CreatedBy}}\t{{.Size}}"

# Layers avec 0B = Instructions de métadonnées (ENV, CMD, etc.)
# Layers avec taille = Instructions modifiant le filesystem (RUN, COPY, ADD)

# 3. Identifier les layers "lourds"
docker history nginx:alpine --format "{{.Size}}\t{{.CreatedBy}}" | sort -h | tail -5

# 4. Extraire un layer spécifique
# Les layers sont dans /var/lib/docker/overlay2/ (Linux)

# Pour examiner le contenu d'un layer
image_id=$(docker images nginx:alpine -q)
docker save nginx:alpine | tar -x

# Contenu extrait:
# manifest.json - Description de l'image
# <hash>/layer.tar - Contenu de chaque layer

# 5. Analyser les duplications
docker history nginx:alpine --format "{{.CreatedBy}}" | grep -c "ADD\|COPY"
```

### 5.2 - Comparaison détaillée

```bash
#!/bin/bash
# compare-images.sh

img1=$1
img2=$2

echo "=== Comparaison: $img1 vs $img2 ==="
echo ""

# Tailles
size1=$(docker images $img1 --format "{{.Size}}")
size2=$(docker images $img2 --format "{{.Size}}")
echo "Taille:"
echo "  $img1: $size1"
echo "  $img2: $size2"
echo ""

# Nombre de layers
layers1=$(docker history $img1 --format "{{.ID}}" | wc -l)
layers2=$(docker history $img2 --format "{{.ID}}" | wc -l)
echo "Layers:"
echo "  $img1: $layers1"
echo "  $img2: $layers2"
echo ""

# Architecture
arch1=$(docker inspect $img1 --format "{{.Architecture}}")
arch2=$(docker inspect $img2 --format "{{.Architecture}}")
echo "Architecture:"
echo "  $img1: $arch1"
echo "  $img2: $arch2"
echo ""

# OS
os1=$(docker inspect $img1 --format "{{.Os}}")
os2=$(docker inspect $img2 --format "{{.Os}}")
echo "OS:"
echo "  $img1: $os1"
echo "  $img2: $os2"
echo ""

# Date de création
created1=$(docker inspect $img1 --format "{{.Created}}")
created2=$(docker inspect $img2 --format "{{.Created}}")
echo "Créé:"
echo "  $img1: $created1"
echo "  $img2: $created2"
```

### 5.3 - Utilisation de dive

Dive est un outil excellent pour analyser les images :

```bash
# Installation
wget https://github.com/wagoodman/dive/releases/download/v0.11.0/dive_0.11.0_linux_amd64.deb
sudo dpkg -i dive_0.11.0_linux_amd64.deb

# Ou avec Docker
alias dive="docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock wagoodman/dive:latest"

# Analyser une image
dive nginx:alpine

# Interface:
# - Navigation avec ↑↓ entre les layers
# - Tab pour basculer entre layers et fichiers
# - Ctrl+C pour quitter

# Informations affichées:
# - Taille de chaque layer
# - Fichiers ajoutés/modifiés/supprimés
# - Inefficacités (fichiers ajoutés puis supprimés)
# - Score d'efficacité

# Utiliser en CI/CD
CI=true dive nginx:alpine

# Options utiles
dive --ci-config=.dive-ci.yml nginx:alpine
```

Configuration `.dive-ci.yml` :

```yaml
rules:
  - name: efficiency
    fatal: false
    value: 0.95  # Au moins 95% d'efficacité

  - name: size
    fatal: true
    value: 100MB  # Max 100MB
```

---

## Exercice 6 : Optimisation et nettoyage

### 6.1 - Identifier le gaspillage

```bash
# Voir l'espace utilisé
docker system df

# Détails
docker system df -v

# Images dangling (layers orphelins)
docker images -f dangling=true

# Images non utilisées
docker images --filter "dangling=false" --format "{{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}" | \
  while read line; do
    id=$(echo $line | awk '{print $2}')
    used=$(docker ps -a --filter ancestor=$id -q)
    if [ -z "$used" ]; then
      echo "Non utilisée: $line"
    fi
  done
```

### 6.2 - Stratégie de nettoyage

```bash
#!/bin/bash
# cleanup-strategy.sh

function cleanup_light() {
    echo "=== Nettoyage léger ==="
    # Seulement les dangling images
    docker image prune -f
}

function cleanup_medium() {
    echo "=== Nettoyage moyen ==="
    # Images non utilisées depuis 24h
    docker image prune -a --filter "until=24h" -f
}

function cleanup_aggressive() {
    echo "=== Nettoyage agressif ==="
    # TOUTES les images non utilisées
    docker image prune -a -f
}

function cleanup_nuclear() {
    echo "=== Nettoyage complet (ATTENTION!) ==="
    # TOUT: conteneurs, images, volumes, réseaux
    docker system prune -a --volumes -f
}

# Cleanup intelligent
function cleanup_smart() {
    echo "=== Nettoyage intelligent ==="

    # 1. Dangling images
    echo "1. Suppression des dangling images..."
    docker image prune -f

    # 2. Images de plus de 30 jours non utilisées
    echo "2. Suppression des vieilles images..."
    docker image prune -a --filter "until=720h" -f

    # 3. Build cache de plus de 7 jours
    echo "3. Nettoyage du build cache..."
    docker builder prune --filter "until=168h" -f

    # 4. Rapport
    echo ""
    echo "=== Espace récupéré ==="
    docker system df
}

case $1 in
    light) cleanup_light ;;
    medium) cleanup_medium ;;
    aggressive) cleanup_aggressive ;;
    nuclear) cleanup_nuclear ;;
    smart) cleanup_smart ;;
    *)
        echo "Usage: $0 {light|medium|aggressive|nuclear|smart}"
        echo "  light      - Dangling images uniquement"
        echo "  medium     - Images non utilisées depuis 24h"
        echo "  aggressive - Toutes images non utilisées"
        echo "  nuclear    - TOUT (conteneurs, images, volumes, réseaux)"
        echo "  smart      - Nettoyage intelligent (recommandé)"
        ;;
esac
```

---

## Exercice 7 : Images multi-architecture

### 7.1 - Manifests détaillés

```bash
# Un manifest est une "liste de pointeurs" vers différentes architectures

# Inspecter le manifest
docker manifest inspect nginx:alpine

# Structure:
{
  "manifests": [
    {
      "platform": {
        "architecture": "amd64",
        "os": "linux"
      },
      "digest": "sha256:abc123..."
    },
    {
      "platform": {
        "architecture": "arm64",
        "os": "linux"
      },
      "digest": "sha256:def456..."
    },
    ...
  ]
}

# Docker tire automatiquement la bonne architecture
# Sur Mac M1: arm64
# Sur PC Windows/Linux: amd64

# Forcer une architecture spécifique
docker pull --platform linux/amd64 nginx:alpine
docker pull --platform linux/arm64 nginx:alpine
docker pull --platform linux/arm/v7 nginx:alpine

# Vérifier
docker inspect nginx:alpine --format '{{.Architecture}}'
```

### 7.2 - Créer des images multi-arch

```bash
# Buildx est l'outil pour créer des images multi-architecture

# 1. Créer un builder
docker buildx create --name multiarch --use

# 2. Booter le builder
docker buildx inspect multiarch --bootstrap

# 3. Build pour plusieurs plateformes
cat > Dockerfile << 'EOF'
FROM alpine:latest
RUN echo "Multi-arch image"
CMD ["echo", "Hello from $(uname -m)"]
EOF

docker buildx build \
  --platform linux/amd64,linux/arm64,linux/arm/v7 \
  -t username/myapp:multiarch \
  --push \
  .

# 4. Vérifier le manifest
docker manifest inspect username/myapp:multiarch

# 5. Test
# Sur n'importe quelle plateforme:
docker run username/myapp:multiarch
```

---

## Exercice 8 : Scénario pratique

### Pipeline complet annoté

```bash
#!/bin/bash
# complete-image-pipeline.sh

set -e

PROJECT="myapp"
VERSION="1.0.0"
REGISTRY="localhost:5000"

echo "=== Pipeline de gestion d'images ==="
echo "Projet: $PROJECT"
echo "Version: $VERSION"
echo "Registre: $REGISTRY"
echo ""

# 1. Démarrer le registre local
echo "1. Démarrage du registre local..."
docker run -d -p 5000:5000 \
  --name registry \
  -v registry-data:/var/lib/registry \
  registry:2 || echo "Registre déjà en cours"

# 2. Créer l'application
echo "2. Création de l'application..."
mkdir -p app
cat > app/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>$PROJECT v$VERSION</title>
</head>
<body>
    <h1>$PROJECT</h1>
    <p>Version: $VERSION</p>
    <p>Build: $(date)</p>
</body>
</html>
EOF

# 3. Build depuis un conteneur
echo "3. Build de l'image..."
docker run -d --name app-builder nginx:alpine
docker cp app/index.html app-builder:/usr/share/nginx/html/
docker commit app-builder $PROJECT:$VERSION
docker rm -f app-builder

# 4. Tagging stratégique
echo "4. Tagging..."

# Semantic versioning
docker tag $PROJECT:$VERSION $PROJECT:1.0
docker tag $PROJECT:$VERSION $PROJECT:1
docker tag $PROJECT:$VERSION $PROJECT:latest

# Environnements
docker tag $PROJECT:$VERSION $PROJECT:stable
docker tag $PROJECT:$VERSION $PROJECT:prod

# Date
DATE_TAG=$(date +%Y%m%d)
docker tag $PROJECT:$VERSION $PROJECT:$DATE_TAG

# Afficher
echo "Tags créés:"
docker images $PROJECT

# 5. Push vers registre local
echo "5. Push vers registre local..."
for tag in $VERSION 1.0 1 latest stable prod $DATE_TAG; do
  docker tag $PROJECT:$tag $REGISTRY/$PROJECT:$tag
  docker push $REGISTRY/$PROJECT:$tag
done

# 6. Vérifier le registre
echo "6. Vérification du registre..."
curl -s http://$REGISTRY/v2/_catalog | jq
curl -s http://$REGISTRY/v2/$PROJECT/tags/list | jq

# 7. Backup
echo "7. Sauvegarde..."
mkdir -p backups
docker save $PROJECT:$VERSION | gzip > backups/$PROJECT-$VERSION-$(date +%Y%m%d).tar.gz
echo "Backup créé: backups/$PROJECT-$VERSION-$(date +%Y%m%d).tar.gz"

# 8. Nettoyage local (garder le registre)
echo "8. Nettoyage des tags locaux..."
docker rmi $PROJECT:1 $PROJECT:1.0 $PROJECT:stable $PROJECT:prod $PROJECT:$DATE_TAG

# 9. Test de pull depuis registre
echo "9. Test de pull depuis registre..."
docker pull $REGISTRY/$PROJECT:$VERSION
docker run -d --name $PROJECT-test -p 8080:80 $REGISTRY/$PROJECT:$VERSION

echo ""
echo "=== Pipeline terminé ==="
echo "Application disponible: http://localhost:8080"
echo "Registre: http://$REGISTRY/v2/_catalog"
echo ""

# 10. Rapport final
echo "=== Rapport ==="
echo "Images locales:"
docker images $PROJECT --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}"

echo ""
echo "Images dans le registre:"
curl -s http://$REGISTRY/v2/$PROJECT/tags/list | jq -r '.tags[]' | while read tag; do
  echo "  - $REGISTRY/$PROJECT:$tag"
done

echo ""
echo "Backup:"
ls -lh backups/$PROJECT-$VERSION-*.tar.gz

# Cleanup script
cat > cleanup.sh << 'EOFCLEANUP'
#!/bin/bash
docker rm -f myapp-test registry
docker rmi $(docker images myapp -q)
docker rmi $(docker images localhost:5000/myapp -q)
docker volume rm registry-data
rm -rf app backups
echo "Nettoyage terminé"
EOFCLEANUP

chmod +x cleanup.sh
echo ""
echo "Pour nettoyer: ./cleanup.sh"
```

---

## Exercice 9 : Bonnes pratiques

### Stratégies de versioning

```bash
# Semantic Versioning (RECOMMANDÉ)
# Format: MAJOR.MINOR.PATCH

# v1.2.3 signifie:
# MAJOR (1) = Breaking changes
# MINOR (2) = Nouvelles fonctionnalités (compatible)
# PATCH (3) = Bug fixes

# Tagging strategy
docker tag myapp:1.2.3 myapp:1.2    # Pointe vers latest 1.2.x
docker tag myapp:1.2.3 myapp:1      # Pointe vers latest 1.x.x
docker tag myapp:1.2.3 myapp:latest # Latest de toutes versions

# Avantages:
# - Users peuvent choisir leur niveau de stabilité
# - myapp:1.2.3 = Version exacte (immuable)
# - myapp:1.2 = Recevra les patches automatiquement
# - myapp:1 = Recevra les minor updates automatiquement
# - myapp:latest = Toujours la plus récente
```

### Convention de nommage

```bash
# Bonne structure:
# [registry/][namespace/]name:version[-variant]

# Exemples:
docker.io/library/nginx:1.25-alpine
registry.company.com/team/webapp:2.1.0-production
localhost:5000/dev/api:v1.0.0-debug

# Variants utiles:
myapp:1.0.0            # Standard
myapp:1.0.0-alpine     # Version légère
myapp:1.0.0-slim       # Version réduite
myapp:1.0.0-debug      # Avec outils de debug
myapp:1.0.0-dev        # Version développement
```

### Script de versioning automatique

```bash
#!/bin/bash
# version-manager.sh

REGISTRY="localhost:5000"
IMAGE_NAME="myapp"

# Lire la version actuelle
if [ -f VERSION ]; then
    CURRENT_VERSION=$(cat VERSION)
else
    CURRENT_VERSION="0.0.0"
fi

# Parse semantic version
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

function bump_major() {
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
}

function bump_minor() {
    MINOR=$((MINOR + 1))
    PATCH=0
}

function bump_patch() {
    PATCH=$((PATCH + 1))
}

# Incrémenter selon l'argument
case $1 in
    major) bump_major ;;
    minor) bump_minor ;;
    patch) bump_patch ;;
    *)
        echo "Usage: $0 {major|minor|patch}"
        echo "Current version: $CURRENT_VERSION"
        exit 1
        ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"

echo "Bumping version: $CURRENT_VERSION -> $NEW_VERSION"

# Sauvegarder la nouvelle version
echo "$NEW_VERSION" > VERSION

# Build
echo "Building $IMAGE_NAME:$NEW_VERSION..."
docker build -t $IMAGE_NAME:$NEW_VERSION .

# Tagging
docker tag $IMAGE_NAME:$NEW_VERSION $IMAGE_NAME:$MAJOR.$MINOR
docker tag $IMAGE_NAME:$NEW_VERSION $IMAGE_NAME:$MAJOR
docker tag $IMAGE_NAME:$NEW_VERSION $IMAGE_NAME:latest

# Push
echo "Pushing to registry..."
for tag in $NEW_VERSION $MAJOR.$MINOR $MAJOR latest; do
    docker tag $IMAGE_NAME:$tag $REGISTRY/$IMAGE_NAME:$tag
    docker push $REGISTRY/$IMAGE_NAME:$tag
done

echo "✓ Version $NEW_VERSION released"

# Git tag (si dans un repo git)
if git rev-parse --git-dir > /dev/null 2>&1; then
    git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION"
    echo "✓ Git tag created: v$NEW_VERSION"
    echo "  Don't forget to: git push --tags"
fi
```

---

## Checklist de validation

- [x] Compris le système de tags et références
- [x] Créé et géré des tags multiples
- [x] Sauvegardé et restauré des images
- [x] Utilisé Docker Hub et un registre privé
- [x] Analysé les layers et optimisé les images
- [x] Implémenté une stratégie de versioning
- [x] Nettoyé efficacement les images inutilisées
- [x] Compris les images multi-architecture

---

## Ressources supplémentaires

- [Docker Hub](https://hub.docker.com)
- [Registry API](https://docs.docker.com/registry/spec/api/)
- [Semantic Versioning](https://semver.org)
- [Dive tool](https://github.com/wagoodman/dive)
- [BuildKit](https://docs.docker.com/build/buildkit/)

**[← Retour au TP](../tp/TP7-Gestion-Images.md)**
