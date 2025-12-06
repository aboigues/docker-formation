# TP7 : Gestion avancée des images

## Objectif

Maîtriser la gestion des images Docker : tags, registres, optimisation et bonnes pratiques.

## Durée estimée

45 minutes

## Concepts clés

```
┌────────────────────────────────────────────────────┐
│            Anatomie d'une image Docker             │
├────────────────────────────────────────────────────┤
│                                                    │
│  registry.example.com:5000/organization/app:v1.0   │
│  └─────┬────────────┘ └─────┬─────┘ └─┬┘ └──┬──┘  │
│        │                    │         │     │     │
│    Registry              Namespace   Name  Tag    │
│                                                    │
│  Si omis:                                          │
│  - Registry → docker.io (Docker Hub)               │
│  - Namespace → library (images officielles)        │
│  - Tag → latest                                    │
│                                                    │
│  Exemples:                                         │
│  nginx         = docker.io/library/nginx:latest    │
│  redis:7       = docker.io/library/redis:7         │
│  user/app:dev  = docker.io/user/app:dev            │
│                                                    │
└────────────────────────────────────────────────────┘
```

---

## Exercice 1 : Comprendre les tags

### 1.1 - Tags et versions

```bash
# Télécharger différentes versions
docker pull nginx:1.25
docker pull nginx:1.25-alpine
docker pull nginx:alpine
docker pull nginx:latest
docker pull nginx:stable

# Lister avec tags
docker images nginx

# Voir les IDs (certains tags pointent vers la même image)
docker images nginx --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}"
```

**Questions** :
1. Certains tags ont-ils le même IMAGE ID ?
2. Quelle est la différence entre `latest` et `stable` ?
3. Pourquoi `nginx:alpine` est-elle plus petite ?

### 1.2 - Anatomie d'une image

```bash
# Voir les layers (couches) d'une image
docker history nginx:alpine

# Voir de manière plus lisible
docker history nginx:alpine --no-trunc --format "table {{.CreatedBy}}\t{{.Size}}"

# Inspecter les détails
docker inspect nginx:alpine --format '{{json .}}' | less

# Informations clés
docker inspect nginx:alpine --format 'Created: {{.Created}}'
docker inspect nginx:alpine --format 'Architecture: {{.Architecture}}'
docker inspect nginx:alpine --format 'OS: {{.Os}}'
docker inspect nginx:alpine --format 'Size: {{.Size}} bytes'
```

---

## Exercice 2 : Créer et gérer ses propres tags

### 2.1 - Tagger une image

```bash
# Télécharger une image de base
docker pull nginx:alpine

# Créer un nouveau tag
docker tag nginx:alpine mon-nginx:v1.0
docker tag nginx:alpine mon-nginx:latest
docker tag nginx:alpine mon-nginx:production

# Lister : même IMAGE ID
docker images mon-nginx
docker images --filter reference=mon-nginx

# Comparer
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}" | grep -E "(nginx|mon-nginx)"
```

**Questions** :
1. Créer un tag crée-t-il une copie de l'image ?
2. Combien d'espace disque utilisent ces 4 tags ?
3. Qu'est-ce qu'un tag exactement ?

### 2.2 - Personnaliser et tagger

```bash
# Créer un conteneur et le modifier
docker run -d --name custom-nginx nginx:alpine

# Personnaliser la page d'accueil
docker exec custom-nginx sh -c 'echo "<h1>My Custom Nginx v1.0</h1>" > /usr/share/nginx/html/index.html'

# Tester
docker exec custom-nginx cat /usr/share/nginx/html/index.html

# Créer une nouvelle image à partir du conteneur modifié
docker commit custom-nginx my-custom-nginx:v1.0

# Vérifier
docker images my-custom-nginx

# Tester la nouvelle image
docker run -d --name test-custom -p 8080:80 my-custom-nginx:v1.0
curl http://localhost:8080

# Nettoyer
docker rm -f custom-nginx test-custom
```

**⚠️ Note** : `docker commit` est pratique pour tester, mais **pas recommandé en production**. Utilisez des Dockerfiles (module suivant).

---

## Exercice 3 : Sauvegarder et charger des images

### 3.1 - Export/Import d'images

```bash
# Sauvegarder une image dans un fichier tar
docker save nginx:alpine -o nginx-alpine.tar

# Voir la taille
ls -lh nginx-alpine.tar

# Compresser pour gagner de l'espace
docker save nginx:alpine | gzip > nginx-alpine.tar.gz
ls -lh nginx-alpine.tar.gz

# Supprimer l'image locale
docker rmi nginx:alpine

# Charger depuis le fichier
docker load -i nginx-alpine.tar

# Vérifier
docker images nginx:alpine
```

**Use cases** :
- Transfert d'images sans registre
- Sauvegarde hors-ligne
- Air-gapped environments

### 3.2 - Sauvegarder plusieurs images

```bash
# Sauvegarder plusieurs images en une fois
docker save -o mes-images.tar nginx:alpine redis:alpine postgres:15-alpine

# Taille du fichier
ls -lh mes-images.tar

# Supprimer les images
docker rmi nginx:alpine redis:alpine postgres:15-alpine

# Recharger tout
docker load -i mes-images.tar

# Vérifier
docker images --filter reference="*:alpine"
```

### 3.3 - Export/Import de conteneurs

```bash
# Créer un conteneur avec des données
docker run --name data-container alpine sh -c "echo 'Important data' > /data.txt && cat /data.txt"

# Exporter le conteneur (filesystem seulement, pas l'historique)
docker export data-container -o container-export.tar

# Importer comme nouvelle image
cat container-export.tar | docker import - my-alpine:from-container

# Différence de taille
docker images alpine
docker images my-alpine
```

**Différences** :
- `docker save` : sauvegarde l'image avec historique et metadata
- `docker export` : exporte seulement le filesystem du conteneur

---

## Exercice 4 : Registres Docker

### 4.1 - Docker Hub

```bash
# Se connecter à Docker Hub
docker login

# Tagger pour Docker Hub (username/image:tag)
docker tag nginx:alpine VOTRE_USERNAME/mon-nginx:v1.0

# Pousser vers Docker Hub
docker push VOTRE_USERNAME/mon-nginx:v1.0

# Rendre l'image publique depuis le site Docker Hub
# https://hub.docker.com/

# Tester le pull depuis Docker Hub
docker rmi VOTRE_USERNAME/mon-nginx:v1.0
docker pull VOTRE_USERNAME/mon-nginx:v1.0
```

**Tâches** :
1. Créer une image personnalisée
2. La pousser sur Docker Hub
3. La télécharger depuis un autre terminal/machine

### 4.2 - Registre privé local

```bash
# Lancer un registre Docker local
docker run -d -p 5000:5000 --name registry registry:2

# Tagger une image pour le registre local
docker tag nginx:alpine localhost:5000/nginx:alpine

# Pousser vers le registre local
docker push localhost:5000/nginx:alpine

# Lister les images dans le registre
curl http://localhost:5000/v2/_catalog

# Voir les tags d'une image
curl http://localhost:5000/v2/nginx/tags/list

# Tester le pull
docker rmi localhost:5000/nginx:alpine
docker pull localhost:5000/nginx:alpine
```

### 4.3 - Registre avec volume persistant

```bash
# Arrêter l'ancien registre
docker rm -f registry

# Créer un volume pour la persistance
docker volume create registry-data

# Lancer le registre avec volume
docker run -d \
  -p 5000:5000 \
  --name registry \
  -v registry-data:/var/lib/registry \
  registry:2

# Pousser des images
docker tag redis:alpine localhost:5000/redis:alpine
docker push localhost:5000/redis:alpine

# Le registre survit au redémarrage
docker restart registry

# Les images sont toujours là
curl http://localhost:5000/v2/_catalog
```

---

## Exercice 5 : Inspection et analyse des images

### 5.1 - Analyser les layers

```bash
# Télécharger une image complexe
docker pull node:18

# Voir tous les layers
docker history node:18

# Voir seulement les layers créés par l'utilisateur (pas <missing>)
docker history node:18 --no-trunc | grep -v "<missing>"

# Calculer la taille totale des layers
docker history node:18 --format "{{.Size}}" | sed 's/MB//g' | awk '{sum += $1} END {print sum " MB"}'

# Inspecter un layer spécifique
docker inspect node:18 --format '{{json .RootFS.Layers}}' | python3 -m json.tool
```

### 5.2 - Comparer des images

```bash
# Comparer les tailles
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep -E "(nginx|node)"

# Comparer alpine vs standard
docker pull node:18
docker pull node:18-alpine

echo "=== Node standard ==="
docker images node:18 --format "Size: {{.Size}}"
docker history node:18 --no-trunc | wc -l

echo "=== Node alpine ==="
docker images node:18-alpine --format "Size: {{.Size}}"
docker history node:18-alpine --no-trunc | wc -l
```

**Questions** :
1. Quelle est la différence de taille entre standard et alpine ?
2. Combien de layers dans chaque image ?
3. Quand utiliser alpine vs standard ?

### 5.3 - Analyser avec dive (outil externe)

```bash
# Installer dive (optionnel)
# Linux:
# wget https://github.com/wagoodman/dive/releases/download/v0.11.0/dive_0.11.0_linux_amd64.deb
# sudo dpkg -i dive_0.11.0_linux_amd64.deb

# Analyser une image
dive nginx:alpine

# Ou avec Docker
docker run --rm -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  wagoodman/dive:latest nginx:alpine
```

---

## Exercice 6 : Optimisation et nettoyage

### 6.1 - Identifier les images inutilisées

```bash
# Voir toutes les images
docker images -a

# Images "dangling" (sans tag, layers orphelins)
docker images -f dangling=true

# Calculer l'espace utilisé
docker system df

# Détails par type
docker system df -v
```

### 6.2 - Nettoyage ciblé

```bash
# Supprimer les images dangling
docker image prune

# Supprimer les images non utilisées par des conteneurs
docker image prune -a

# Supprimer une image spécifique
docker rmi nginx:1.25

# Supprimer plusieurs images
docker rmi nginx:alpine redis:alpine postgres:15-alpine

# Supprimer toutes les images avec un pattern
docker images --format "{{.Repository}}:{{.Tag}}" | grep "alpine" | xargs docker rmi

# Forcer la suppression (même si utilisée)
docker rmi -f mon-nginx:v1.0
```

### 6.3 - Nettoyage complet

```bash
# Voir l'espace total utilisé
docker system df

# Nettoyer TOUT (conteneurs, images, volumes, réseaux, build cache)
docker system prune -a --volumes

# Confirmer l'espace libéré
docker system df
```

**⚠️ Attention** : `docker system prune -a` supprime TOUTES les images non utilisées !

---

## Exercice 7 : Images multi-architecture

### 7.1 - Manifests et plateformes

```bash
# Voir les architectures supportées
docker manifest inspect nginx:alpine | grep -A 5 "architecture"

# Ou avec jq
docker manifest inspect nginx:alpine | jq -r '.manifests[] | "\(.platform.architecture) / \(.platform.os)"'

# Télécharger une architecture spécifique
docker pull --platform linux/arm64 nginx:alpine

# Voir l'architecture de l'image locale
docker inspect nginx:alpine --format '{{.Architecture}}'
```

### 7.2 - Buildx pour multi-arch (aperçu)

```bash
# Vérifier buildx
docker buildx version

# Lister les builders
docker buildx ls

# Créer un builder multi-arch
docker buildx create --name multiarch --use

# Inspecter le builder
docker buildx inspect multiarch --bootstrap
```

---

## Exercice 8 : Scénario pratique

### Objectif : Pipeline complet de gestion d'images

```bash
# 1. Créer une image personnalisée
mkdir -p ~/docker-tp/custom-app
cd ~/docker-tp/custom-app

cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>My App v1.0</title>
</head>
<body>
    <h1>Custom Application v1.0</h1>
    <p>Built: $(date)</p>
</body>
</html>
EOF

# 2. Créer depuis un conteneur
docker run -d --name app-builder nginx:alpine
docker cp index.html app-builder:/usr/share/nginx/html/index.html
docker commit app-builder myapp:v1.0
docker rm -f app-builder

# 3. Tagger pour différents environnements
docker tag myapp:v1.0 myapp:latest
docker tag myapp:v1.0 myapp:dev
docker tag myapp:v1.0 myapp:1.0.0
docker tag myapp:v1.0 myapp:1.0
docker tag myapp:v1.0 myapp:1

# 4. Lister les tags
docker images myapp

# 5. Tester l'image
docker run -d --name app-test -p 8080:80 myapp:v1.0
curl http://localhost:8080
docker rm -f app-test

# 6. Sauvegarder pour backup
docker save myapp:v1.0 | gzip > myapp-v1.0.tar.gz
ls -lh myapp-v1.0.tar.gz

# 7. Pousser vers un registre local
docker run -d -p 5000:5000 --name registry -v registry-data:/var/lib/registry registry:2

docker tag myapp:v1.0 localhost:5000/myapp:v1.0
docker push localhost:5000/myapp:v1.0

# 8. Vérifier dans le registre
curl http://localhost:5000/v2/_catalog
curl http://localhost:5000/v2/myapp/tags/list

# 9. Créer une v2.0
docker run -d --name app-builder-v2 myapp:v1.0
docker exec app-builder-v2 sh -c 'echo "<h1>Custom Application v2.0</h1>" > /usr/share/nginx/html/index.html'
docker commit app-builder-v2 myapp:v2.0
docker tag myapp:v2.0 myapp:latest
docker rm -f app-builder-v2

# 10. Pousser v2.0
docker tag myapp:v2.0 localhost:5000/myapp:v2.0
docker tag myapp:v2.0 localhost:5000/myapp:latest
docker push localhost:5000/myapp:v2.0
docker push localhost:5000/myapp:latest

# 11. Voir toutes les versions
curl http://localhost:5000/v2/myapp/tags/list

# 12. Nettoyer les anciennes versions localement
docker rmi myapp:dev myapp:1 myapp:1.0 myapp:1.0.0

# 13. Analyse de l'espace
docker system df
```

---

## Exercice 9 : Bonnes pratiques

### 9.1 - Stratégie de tagging

```bash
# ✓ BONNES PRATIQUES
docker tag myapp:latest myapp:$(date +%Y%m%d)  # Tag avec date
docker tag myapp:latest myapp:v1.0.0           # Semantic versioning
docker tag myapp:latest myapp:prod-stable      # Tag par environnement

# ✗ MAUVAISES PRATIQUES
# Ne pas utiliser uniquement :latest en production
# Ne pas réutiliser les mêmes tags pour différentes versions
```

### 9.2 - Conventions de nommage

```bash
# Pattern recommandé : registry/organization/app:version-variant
# Exemples:
# - localhost:5000/mycompany/webapp:1.0.0-alpine
# - localhost:5000/mycompany/webapp:1.0.0-ubuntu
# - localhost:5000/mycompany/api:2.1.0-prod
# - localhost:5000/mycompany/api:2.1.0-dev

# Créer une hiérarchie
docker tag nginx:alpine localhost:5000/mycompany/nginx:latest
docker tag nginx:alpine localhost:5000/mycompany/nginx:1.25-alpine
docker tag nginx:alpine localhost:5000/mycompany/nginx:stable
```

### 9.3 - Audit et maintenance

```bash
# Script pour lister les images par date
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}\t{{.Size}}" | sort -k 3

# Trouver les vieilles images (plus de 30 jours)
docker images --format "{{.Repository}}:{{.Tag}} {{.CreatedAt}}" | \
  awk -v date=$(date -d '30 days ago' +%s) \
  '{cmd="date -d \""$2" "$3"\" +%s"; cmd | getline created; close(cmd); if (created < date) print $1}'

# Supprimer les images de plus de 30 jours
# (Attention : testez d'abord sans le xargs docker rmi)
```

---

## 🏆 Validation

À l'issue de ce TP, vous devez savoir :

- [ ] Comprendre l'anatomie d'une référence d'image
- [ ] Créer et gérer des tags
- [ ] Sauvegarder et charger des images
- [ ] Utiliser Docker Hub et des registres privés
- [ ] Analyser les layers et l'espace disque
- [ ] Optimiser et nettoyer les images
- [ ] Implémenter une stratégie de versioning
- [ ] Gérer un registre Docker privé

---

## 📊 Commandes essentielles

| Commande | Description |
|----------|-------------|
| `docker images` | Lister les images |
| `docker tag` | Créer un tag |
| `docker rmi` | Supprimer une image |
| `docker save` | Sauvegarder image(s) |
| `docker load` | Charger image(s) |
| `docker push` | Pousser vers registre |
| `docker pull` | Tirer depuis registre |
| `docker history` | Voir les layers |
| `docker inspect` | Inspecter une image |
| `docker image prune` | Nettoyer les images |

---

## 🚀 Aller plus loin

```bash
# Créer un registre avec authentification
docker run -d -p 5000:5000 \
  -e REGISTRY_AUTH=htpasswd \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  -e REGISTRY_AUTH_HTPASSWD_REALM="Registry Realm" \
  -v registry-auth:/auth \
  -v registry-data:/var/lib/registry \
  registry:2

# Créer un utilisateur (installer htpasswd d'abord)
docker run --rm --entrypoint htpasswd registry:2 \
  -Bbn username password > auth/htpasswd

# Se connecter
docker login localhost:5000

# Registre avec UI (Registry UI)
docker run -d -p 8082:80 \
  -e REGISTRY_URL=http://registry:5000 \
  -e DELETE_IMAGES=true \
  --link registry \
  joxit/docker-registry-ui:latest
```

---

**[→ Voir les solutions](../solutions/TP7-Solution.md)**

**[← Retour au README du module](../README.md)**
