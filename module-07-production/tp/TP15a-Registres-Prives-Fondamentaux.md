# TP15a : Registres privés Docker - Fondamentaux

## Objectif

Maîtriser les bases des registres Docker privés : installation, configuration, push/pull d'images et gestion de la persistance.

## Durée estimée

60 minutes

## Prérequis

- Docker installé et fonctionnel
- Connaissance de base des images Docker (TP7)
- Accès à un terminal avec droits sudo (pour certains exercices)

## Concepts clés

```
┌─────────────────────────────────────────────────────────┐
│          Architecture d'un registre Docker privé         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Client Docker                    Registre Docker       │
│  ┌──────────┐                    ┌──────────────┐      │
│  │  docker  │ ─── push/pull ───▶ │  Registry:2  │      │
│  │  daemon  │                    │  (Port 5000) │      │
│  └──────────┘                    └──────┬───────┘      │
│                                          │              │
│                                          ▼              │
│                                   ┌─────────────┐      │
│                                   │   Storage   │      │
│                                   │  /var/lib/  │      │
│                                   │  registry/  │      │
│                                   └─────────────┘      │
│                                                          │
│  Avantages d'un registre privé :                        │
│  • Contrôle total sur vos images                        │
│  • Pas de limite de bande passante                      │
│  • Sécurité et confidentialité                          │
│  • Performance (réseau local)                           │
│  • Conformité réglementaire                             │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Exercice 1 : Déploiement d'un registre basique

### 1.1 - Premier registre

```bash
# Lancer un registre Docker sur le port 5000
docker run -d \
  --name registry \
  -p 5000:5000 \
  registry:2

# Vérifier que le registre fonctionne
docker ps | grep registry

# Tester l'API du registre
curl http://localhost:5000/v2/

# Réponse attendue : {}
```

**Questions** :
1. Que signifie le port 5000 ?
2. Pourquoi utilise-t-on l'image `registry:2` ?
3. Comment vérifier que le registre est accessible ?

### 1.2 - Explorer l'API du registre

```bash
# Lister les images (catalogue vide pour le moment)
curl http://localhost:5000/v2/_catalog

# Vérifier la santé du registre
curl -I http://localhost:5000/v2/

# Voir les logs du registre
docker logs registry

# Suivre les logs en temps réel
docker logs -f registry
```

---

## Exercice 2 : Push et Pull d'images

### 2.1 - Pousser votre première image

```bash
# Télécharger une image depuis Docker Hub
docker pull alpine:latest

# Tagger l'image pour votre registre privé
# Format : localhost:5000/nom-image:tag
docker tag alpine:latest localhost:5000/my-alpine:latest

# Pousser vers le registre privé
docker push localhost:5000/my-alpine:latest

# Vérifier que l'image est dans le registre
curl http://localhost:5000/v2/_catalog

# Voir les tags disponibles
curl http://localhost:5000/v2/my-alpine/tags/list
```

**Observation** : Regardez les logs du registre pendant le push :
```bash
docker logs registry
```

### 2.2 - Pousser plusieurs images

```bash
# Télécharger plusieurs images
docker pull nginx:alpine
docker pull redis:alpine
docker pull postgres:15-alpine

# Tagger et pousser
docker tag nginx:alpine localhost:5000/nginx:alpine
docker tag redis:alpine localhost:5000/redis:alpine
docker tag postgres:15-alpine localhost:5000/postgres:15-alpine

docker push localhost:5000/nginx:alpine
docker push localhost:5000/redis:alpine
docker push localhost:5000/postgres:15-alpine

# Vérifier le catalogue
curl http://localhost:5000/v2/_catalog | python3 -m json.tool
```

### 2.3 - Pull depuis le registre privé

```bash
# Supprimer les images locales
docker rmi localhost:5000/my-alpine:latest
docker rmi localhost:5000/nginx:alpine

# Vérifier qu'elles sont supprimées
docker images | grep localhost:5000

# Télécharger depuis votre registre privé
docker pull localhost:5000/my-alpine:latest
docker pull localhost:5000/nginx:alpine

# Vérifier
docker images | grep localhost:5000

# Tester l'image nginx
docker run -d --name test-nginx -p 8080:80 localhost:5000/nginx:alpine
curl http://localhost:8080
docker rm -f test-nginx
```

---

## Exercice 3 : Gestion de la persistance

### 3.1 - Le problème sans persistance

```bash
# Vérifier le contenu actuel
curl http://localhost:5000/v2/_catalog

# Arrêter et supprimer le registre
docker rm -f registry

# Relancer un nouveau registre
docker run -d --name registry -p 5000:5000 registry:2

# Vérifier le catalogue (vide !)
curl http://localhost:5000/v2/_catalog

# Résultat : {"repositories":[]}
```

**Constat** : Les images sont perdues car elles étaient stockées dans le conteneur, pas sur l'hôte.

### 3.2 - Registre avec volume Docker

```bash
# Nettoyer
docker rm -f registry

# Créer un volume dédié
docker volume create registry-data

# Vérifier le volume
docker volume inspect registry-data

# Lancer le registre avec le volume
docker run -d \
  --name registry \
  -p 5000:5000 \
  -v registry-data:/var/lib/registry \
  registry:2

# Pousser une image
docker tag alpine:latest localhost:5000/alpine:v1
docker push localhost:5000/alpine:v1

# Vérifier
curl http://localhost:5000/v2/_catalog
```

### 3.3 - Test de persistance

```bash
# Arrêter le registre
docker stop registry

# Supprimer le conteneur
docker rm registry

# Relancer avec le même volume
docker run -d \
  --name registry \
  -p 5000:5000 \
  -v registry-data:/var/lib/registry \
  registry:2

# Vérifier que les images sont toujours là
curl http://localhost:5000/v2/_catalog

# Succès ! Les données persistent
```

### 3.4 - Registre avec bind mount

```bash
# Nettoyer
docker rm -f registry

# Créer un répertoire local
mkdir -p ~/docker-registry/data

# Lancer avec bind mount
docker run -d \
  --name registry \
  -p 5000:5000 \
  -v ~/docker-registry/data:/var/lib/registry \
  registry:2

# Pousser une image
docker tag nginx:alpine localhost:5000/nginx:test
docker push localhost:5000/nginx:test

# Explorer le répertoire de stockage
ls -la ~/docker-registry/data/
tree ~/docker-registry/data/ 2>/dev/null || find ~/docker-registry/data/ -type f
```

**Questions** :
1. Quelle est la différence entre volume et bind mount ?
2. Quand utiliser l'un ou l'autre ?
3. Où sont stockés les layers des images ?

---

## Exercice 4 : Configuration du registre

### 4.1 - Configuration basique

```bash
# Créer un fichier de configuration
mkdir -p ~/docker-registry/config

cat > ~/docker-registry/config/config.yml << 'EOF'
version: 0.1
log:
  level: info
  formatter: text
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
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

# Arrêter l'ancien registre
docker rm -f registry

# Lancer avec la configuration personnalisée
docker run -d \
  --name registry \
  -p 5000:5000 \
  -v ~/docker-registry/data:/var/lib/registry \
  -v ~/docker-registry/config/config.yml:/etc/docker/registry/config.yml \
  registry:2

# Vérifier les logs
docker logs registry
```

### 4.2 - Limites de stockage

```bash
# Configuration avec limite de stockage
cat > ~/docker-registry/config/config.yml << 'EOF'
version: 0.1
log:
  level: debug
storage:
  filesystem:
    rootdirectory: /var/lib/registry
    maxthreads: 100
  delete:
    enabled: true
http:
  addr: :5000
EOF

# Redémarrer le registre
docker rm -f registry
docker run -d \
  --name registry \
  -p 5000:5000 \
  -v ~/docker-registry/data:/var/lib/registry \
  -v ~/docker-registry/config/config.yml:/etc/docker/registry/config.yml \
  registry:2
```

### 4.3 - Variables d'environnement

```bash
# Configuration via variables d'environnement (plus simple)
docker rm -f registry

docker run -d \
  --name registry \
  -p 5000:5000 \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
  -e REGISTRY_LOG_LEVEL=debug \
  -v registry-data:/var/lib/registry \
  registry:2

# Vérifier la configuration
docker logs registry | head -20
```

---

## Exercice 5 : Gestion des images dans le registre

### 5.1 - API du registre

```bash
# Lister toutes les images
curl http://localhost:5000/v2/_catalog | python3 -m json.tool

# Obtenir les tags d'une image
curl http://localhost:5000/v2/nginx/tags/list | python3 -m json.tool

# Obtenir le manifeste d'une image
curl http://localhost:5000/v2/nginx/manifests/alpine | python3 -m json.tool

# Obtenir le digest d'une image
curl -I -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  http://localhost:5000/v2/nginx/manifests/alpine

# Regarder la ligne Docker-Content-Digest
```

### 5.2 - Inspection détaillée

```bash
# Créer un script pour lister toutes les images avec leurs détails
cat > ~/list-registry-images.sh << 'EOF'
#!/bin/bash
REGISTRY="localhost:5000"

echo "Images dans le registre $REGISTRY:"
echo "================================="

# Obtenir le catalogue
REPOS=$(curl -s http://$REGISTRY/v2/_catalog | jq -r '.repositories[]')

for repo in $REPOS; do
    echo ""
    echo "Repository: $repo"
    # Obtenir les tags
    TAGS=$(curl -s http://$REGISTRY/v2/$repo/tags/list | jq -r '.tags[]')
    for tag in $TAGS; do
        echo "  - $tag"
        # Obtenir la taille (approximative depuis le manifest)
        SIZE=$(curl -s http://$REGISTRY/v2/$repo/manifests/$tag | jq '[.layers[].size] | add')
        echo "    Taille: $((SIZE / 1024 / 1024)) MB"
    done
done
EOF

chmod +x ~/list-registry-images.sh

# Exécuter le script
~/list-registry-images.sh
```

### 5.3 - Nettoyage et suppression

```bash
# Activer la suppression dans la configuration
docker rm -f registry

docker run -d \
  --name registry \
  -p 5000:5000 \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
  -v registry-data:/var/lib/registry \
  registry:2

# Obtenir le digest d'une image à supprimer
DIGEST=$(curl -I -s -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  http://localhost:5000/v2/alpine/manifests/v1 | \
  grep -i Docker-Content-Digest | awk '{print $2}' | tr -d '\r')

echo "Digest: $DIGEST"

# Supprimer l'image (soft delete)
curl -X DELETE http://localhost:5000/v2/alpine/manifests/$DIGEST

# Vérifier (le tag peut encore apparaître)
curl http://localhost:5000/v2/alpine/tags/list

# Pour un vrai nettoyage, exécuter garbage collection
docker exec registry bin/registry garbage-collect /etc/docker/registry/config.yml
```

---

## Exercice 6 : Scénario pratique - Pipeline de développement

### Objectif : Simuler un workflow de développement avec registre privé

```bash
# 1. Setup du registre
docker rm -f registry 2>/dev/null || true
docker run -d \
  --name registry \
  -p 5000:5000 \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
  -v registry-data:/var/lib/registry \
  registry:2

# 2. Créer une application de test
mkdir -p ~/docker-tp/myapp
cd ~/docker-tp/myapp

cat > app.py << 'EOF'
from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def hello():
    version = os.environ.get('APP_VERSION', '1.0.0')
    return f'Hello from MyApp version {version}!'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

cat > requirements.txt << 'EOF'
flask==3.0.0
EOF

cat > Dockerfile << 'EOF'
FROM python:3.11-alpine
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY app.py .
ENV APP_VERSION=1.0.0
CMD ["python", "app.py"]
EOF

# 3. Build et tag version 1.0.0
docker build -t myapp:1.0.0 .
docker tag myapp:1.0.0 localhost:5000/myapp:1.0.0
docker tag myapp:1.0.0 localhost:5000/myapp:latest

# 4. Push vers le registre
docker push localhost:5000/myapp:1.0.0
docker push localhost:5000/myapp:latest

# 5. Déployer depuis le registre
docker run -d --name myapp-prod -p 8080:5000 localhost:5000/myapp:latest
curl http://localhost:8080

# 6. Créer une version 2.0.0
sed -i 's/APP_VERSION=1.0.0/APP_VERSION=2.0.0/' Dockerfile
docker build -t myapp:2.0.0 .
docker tag myapp:2.0.0 localhost:5000/myapp:2.0.0
docker tag myapp:2.0.0 localhost:5000/myapp:latest

# 7. Push la nouvelle version
docker push localhost:5000/myapp:2.0.0
docker push localhost:5000/myapp:latest

# 8. Update du déploiement
docker rm -f myapp-prod
docker pull localhost:5000/myapp:latest
docker run -d --name myapp-prod -p 8080:5000 localhost:5000/myapp:latest
curl http://localhost:8080

# 9. Rollback si nécessaire
docker rm -f myapp-prod
docker run -d --name myapp-prod -p 8080:5000 localhost:5000/myapp:1.0.0
curl http://localhost:8080

# 10. Voir toutes les versions disponibles
curl http://localhost:5000/v2/myapp/tags/list | python3 -m json.tool

# Nettoyer
docker rm -f myapp-prod
cd ~
```

---

## Exercice 7 : Monitoring et diagnostics

### 7.1 - Health checks

```bash
# Vérifier la santé du registre
curl http://localhost:5000/v2/

# Check détaillé (si activé dans la config)
docker exec registry wget -qO- http://localhost:5000/debug/health || echo "Health endpoint not enabled"

# Voir les métriques Docker du conteneur
docker stats registry --no-stream

# Espace disque utilisé par le registre
docker exec registry du -sh /var/lib/registry
```

### 7.2 - Logs et debugging

```bash
# Voir tous les logs
docker logs registry

# Logs en temps réel
docker logs -f registry

# Filtrer les logs
docker logs registry 2>&1 | grep -i error
docker logs registry 2>&1 | grep -i push
docker logs registry 2>&1 | grep -i pull

# Définir le niveau de log à debug
docker rm -f registry
docker run -d \
  --name registry \
  -p 5000:5000 \
  -e REGISTRY_LOG_LEVEL=debug \
  -v registry-data:/var/lib/registry \
  registry:2

# Tester une opération et voir les logs détaillés
docker pull alpine:latest
docker tag alpine:latest localhost:5000/test:debug
docker push localhost:5000/test:debug

docker logs registry | tail -50
```

### 7.3 - Analyse de l'espace disque

```bash
# Taille totale du volume
docker volume inspect registry-data | grep Mountpoint
MOUNTPOINT=$(docker volume inspect registry-data --format '{{.Mountpoint}}')
sudo du -sh $MOUNTPOINT 2>/dev/null || echo "Besoin de sudo pour voir le mountpoint"

# Via le conteneur
docker exec registry du -sh /var/lib/registry

# Détail par répertoire
docker exec registry du -h /var/lib/registry | sort -h | tail -20

# Nombre de layers stockés
docker exec registry find /var/lib/registry -type f | wc -l
```

---

## Exercice 8 : Bonnes pratiques

### 8.1 - Stratégie de naming

```bash
# Convention recommandée : registry/project/component:version
# Exemples :
# - localhost:5000/company/webapp:1.0.0
# - localhost:5000/company/webapp:1.0.0-alpine
# - localhost:5000/company/api:2.1.0
# - localhost:5000/project/service:dev
# - localhost:5000/project/service:staging
# - localhost:5000/project/service:prod

# Exemple avec organisation
docker tag nginx:alpine localhost:5000/infrastructure/nginx:1.25-alpine
docker tag redis:alpine localhost:5000/infrastructure/redis:7-alpine
docker tag postgres:15-alpine localhost:5000/infrastructure/postgres:15-alpine

docker push localhost:5000/infrastructure/nginx:1.25-alpine
docker push localhost:5000/infrastructure/redis:7-alpine
docker push localhost:5000/infrastructure/postgres:15-alpine

curl http://localhost:5000/v2/_catalog | python3 -m json.tool
```

### 8.2 - Versioning sémantique

```bash
# Appliquer semantic versioning (major.minor.patch)
# Exemple pour une application en version 2.3.5

docker build -t myapp:2.3.5 .

# Créer tous les tags pertinents
docker tag myapp:2.3.5 localhost:5000/myapp:2.3.5  # Version exacte
docker tag myapp:2.3.5 localhost:5000/myapp:2.3    # Minor version
docker tag myapp:2.3.5 localhost:5000/myapp:2      # Major version
docker tag myapp:2.3.5 localhost:5000/myapp:latest # Latest

# Push tous les tags
docker push localhost:5000/myapp:2.3.5
docker push localhost:5000/myapp:2.3
docker push localhost:5000/myapp:2
docker push localhost:5000/myapp:latest
```

### 8.3 - Backup du registre

```bash
# Méthode 1 : Backup du volume
docker run --rm \
  -v registry-data:/data \
  -v ~/backups:/backup \
  alpine tar czf /backup/registry-backup-$(date +%Y%m%d).tar.gz /data

ls -lh ~/backups/

# Méthode 2 : Export de toutes les images
mkdir -p ~/registry-export

# Script pour exporter toutes les images
cat > ~/export-all-images.sh << 'EOF'
#!/bin/bash
REGISTRY="localhost:5000"
OUTPUT_DIR="$HOME/registry-export"

mkdir -p $OUTPUT_DIR

REPOS=$(curl -s http://$REGISTRY/v2/_catalog | jq -r '.repositories[]')

for repo in $REPOS; do
    TAGS=$(curl -s http://$REGISTRY/v2/$repo/tags/list | jq -r '.tags[]')
    for tag in $TAGS; do
        IMAGE="$REGISTRY/$repo:$tag"
        FILENAME=$(echo "$repo-$tag" | tr '/' '-')
        echo "Exporting $IMAGE..."
        docker pull $IMAGE
        docker save $IMAGE | gzip > "$OUTPUT_DIR/$FILENAME.tar.gz"
    done
done

echo "Export completed in $OUTPUT_DIR"
ls -lh $OUTPUT_DIR
EOF

chmod +x ~/export-all-images.sh
# ~/export-all-images.sh  # Décommenter pour exécuter
```

### 8.4 - Restauration

```bash
# Restaurer depuis un backup de volume
docker volume create registry-data-restored

docker run --rm \
  -v registry-data-restored:/data \
  -v ~/backups:/backup \
  alpine sh -c "cd /data && tar xzf /backup/registry-backup-*.tar.gz --strip-components=1"

# Lancer un registre avec le volume restauré
docker run -d \
  --name registry-restored \
  -p 5001:5000 \
  -v registry-data-restored:/var/lib/registry \
  registry:2

# Vérifier
curl http://localhost:5001/v2/_catalog
```

---

## 🏆 Validation

À l'issue de ce TP, vous devez savoir :

- [ ] Déployer un registre Docker privé
- [ ] Push et pull des images vers/depuis un registre privé
- [ ] Configurer la persistance avec volumes ou bind mounts
- [ ] Utiliser l'API du registre pour lister et inspecter les images
- [ ] Configurer le registre via fichier ou variables d'environnement
- [ ] Monitorer les logs et la santé du registre
- [ ] Implémenter une stratégie de versioning
- [ ] Sauvegarder et restaurer un registre

---

## 📊 Commandes essentielles

| Commande | Description |
|----------|-------------|
| `docker run -d -p 5000:5000 registry:2` | Lancer un registre |
| `docker tag image localhost:5000/image:tag` | Tagger pour registre privé |
| `docker push localhost:5000/image:tag` | Push vers registre privé |
| `docker pull localhost:5000/image:tag` | Pull depuis registre privé |
| `curl http://localhost:5000/v2/_catalog` | Lister les images |
| `curl http://localhost:5000/v2/image/tags/list` | Lister les tags |
| `docker volume create registry-data` | Créer volume pour registre |
| `docker logs registry` | Voir logs du registre |

---

## 🚀 Aller plus loin

### Registre avec Docker Compose

```bash
mkdir -p ~/docker-registry-compose
cd ~/docker-registry-compose

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  registry:
    image: registry:2
    container_name: private-registry
    ports:
      - "5000:5000"
    environment:
      REGISTRY_STORAGE_DELETE_ENABLED: "true"
      REGISTRY_LOG_LEVEL: "info"
    volumes:
      - registry-data:/var/lib/registry
    restart: unless-stopped

volumes:
  registry-data:
    driver: local
EOF

# Démarrer
docker-compose up -d

# Voir les logs
docker-compose logs -f

# Arrêter
docker-compose down
```

### Registry UI (Interface web)

```bash
# Ajouter une UI pour visualiser le registre
docker run -d \
  --name registry-ui \
  -p 8082:80 \
  -e REGISTRY_URL=http://registry:5000 \
  -e DELETE_IMAGES=true \
  -e SINGLE_REGISTRY=true \
  --link registry \
  joxit/docker-registry-ui:latest

# Accéder à l'interface
echo "Registry UI disponible sur : http://localhost:8082"
```

---

## 🧹 Nettoyage

```bash
# Arrêter et supprimer le registre
docker rm -f registry

# Supprimer le volume
docker volume rm registry-data

# Nettoyer les images de test
docker images | grep localhost:5000 | awk '{print $1":"$2}' | xargs docker rmi

# Nettoyer les fichiers de test
rm -rf ~/docker-tp/myapp
rm -rf ~/docker-registry
```

---

**[→ Suite : TP15b - Sécurité et authentification](TP15b-Registres-Prives-Securite.md)**

**[→ Voir les solutions](../solutions/TP15a-Solution.md)**

**[← Retour au README du module](../README.md)**
