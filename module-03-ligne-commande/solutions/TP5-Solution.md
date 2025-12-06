# TP5 : Solutions - Volumes et persistance

## Exercice 1 : Comprendre le problème de la persistance

### Réponses aux questions

**1. Pourquoi la base de données `ma_base` a-t-elle disparu ?**

Les données sont stockées dans la couche writable du conteneur. Quand on supprime le conteneur avec `docker rm`, toutes les données non persistées dans un volume sont perdues. C'est le comportement par défaut : les conteneurs sont éphémères.

**2. Où sont stockées les données d'un conteneur par défaut ?**

Dans le système de fichiers du conteneur lui-même, géré par le storage driver (overlay2, aufs, etc.). Spécifiquement dans `/var/lib/docker/overlay2/[container-id]/`.

**3. Que se passe-t-il quand on supprime un conteneur ?**

La couche writable (R/W layer) du conteneur est supprimée avec toutes les modifications. Les layers de l'image de base restent intacts car ils sont en lecture seule et partagés.

---

## Exercice 2 : Volumes Docker

### 2.1 - Réponses aux questions

**1. Où est physiquement stocké le volume sur votre système ?**

Sur Linux : `/var/lib/docker/volumes/[volume-name]/_data`
Sur Mac : `/var/lib/docker/volumes/` (dans la VM Docker Desktop)
Sur Windows : `\\wsl$\docker-desktop-data\data\docker\volumes\`

**2. Peut-on accéder directement aux fichiers du volume ?**

Oui, mais :
- Linux : accès direct avec sudo à `/var/lib/docker/volumes/`
- Mac/Windows : via la VM Docker Desktop
- Meilleure pratique : utiliser un conteneur temporaire pour accéder aux données

```bash
# Accéder aux données d'un volume
docker run --rm -v mon-volume:/data alpine ls -la /data
```

**3. Quelle est la différence entre un volume et un conteneur ?**

- **Volume** : stockage de données persistant, géré par Docker, indépendant des conteneurs
- **Conteneur** : instance exécutable d'une image, éphémère par défaut, contient l'application

### 2.3 - Réponses aux questions

**1. Les données ont-elles persisté après suppression du conteneur ?**

Oui ! C'est tout l'intérêt des volumes. Les données dans `mysql-data` restent disponibles même après `docker rm`.

**2. Peut-on réutiliser le même volume avec un autre conteneur ?**

Absolument. Un volume peut être monté par plusieurs conteneurs simultanément, et peut être réutilisé après suppression d'un conteneur.

**3. Comment sauvegarder les données d'un volume ?**

```bash
# Méthode 1 : Avec tar
docker run --rm -v mysql-data:/source -v $(pwd):/backup alpine \
  tar czf /backup/mysql-backup.tar.gz -C /source .

# Méthode 2 : Avec rsync (si disponible)
docker run --rm -v mysql-data:/source -v $(pwd)/backup:/backup alpine \
  sh -c "cp -r /source/* /backup/"

# Méthode 3 : Backup de la base directement
docker exec mysql-persistent mysqldump -psecret --all-databases > backup.sql
```

---

## Exercice 3 : Bind Mounts

### 3.2 - Réponses aux questions

**1. Les modifications sont-elles immédiates dans le conteneur ?**

Oui ! Les bind mounts créent un lien direct vers le système de fichiers de l'hôte. Toute modification est instantanément visible des deux côtés.

**2. Quelle est la différence entre `-v $(pwd):/app` et `-v $(pwd):/app:ro` ?**

- Sans `:ro` : Le conteneur peut lire ET écrire dans le dossier
- Avec `:ro` (read-only) : Le conteneur peut seulement lire, pas modifier

**3. Pourquoi utiliser bind mounts pour le développement ?**

Avantages :
- Modifications du code immédiatement visibles dans le conteneur
- Pas besoin de rebuild l'image à chaque changement
- Les outils de développement (IDE, git) fonctionnent normalement sur l'hôte
- Hot-reload des applications possible

---

## Exercice 4 : Volumes anonymes et nommés

### 4.1 - Réponses aux questions

**1. Combien de volumes anonymes avez-vous ?**

```bash
docker volume ls -f "dangling=false" -f "name=[0-9a-f]" | wc -l
```

Les volumes anonymes ont des noms générés automatiquement (hash).

**2. Comment identifier quel volume appartient à quel conteneur ?**

```bash
# Inspecter le conteneur
docker inspect postgres-anon --format '{{json .Mounts}}'

# Ou voir tous les mappings
docker ps -a --format '{{.Names}}' | while read c; do
  echo "=== $c ==="
  docker inspect $c --format '{{range .Mounts}}{{.Name}} -> {{.Destination}}{{"\n"}}{{end}}'
done
```

**3. Que se passe-t-il avec un volume anonyme quand on supprime le conteneur ?**

Par défaut, le volume anonyme RESTE même après suppression du conteneur. C'est un piège courant !

```bash
# Pour supprimer aussi le volume
docker rm -v mon-conteneur

# Ou nettoyer après coup
docker volume prune
```

---

## Exercice 5 : Partage de volumes entre conteneurs

### 5.1 - Réponses aux questions

**1. Les deux conteneurs voient-ils les mêmes données ?**

Oui, parfaitement synchronisées. Le volume est le même point de montage pour les deux conteneurs.

**2. Pourquoi monter le volume en `:ro` pour le reader ?**

Principe de moindre privilège :
- Limite les risques de corruption accidentelle
- Empêche le reader de modifier les logs
- Meilleure sécurité

**3. Combien de conteneurs peuvent partager un même volume ?**

Théoriquement illimité. Mais attention aux conflits d'écriture simultanée !

Bonnes pratiques :
- Un seul writer, plusieurs readers
- Ou utiliser des applications conçues pour l'accès concurrent (bases de données, etc.)

### 5.2 - Commandes complètes de restauration

```bash
# Restauration complète d'un volume
docker volume create app-data-restored

docker run --rm \
  -v app-data-restored:/target \
  -v $(pwd):/backup \
  alpine \
  sh -c "cd /target && tar xzf /backup/app-data-backup.tar.gz"

# Vérification
docker run --rm -v app-data-restored:/data alpine ls -la /data
```

---

## Exercice 6 : tmpfs mounts

### Use cases détaillés

**1. Données sensibles**
```bash
# Stocker des secrets en RAM (jamais sur disque)
docker run -d --name secure-app \
  --tmpfs /run/secrets:rw,size=10m,mode=700 \
  myapp

# Les secrets ne touchent jamais le disque
docker exec secure-app sh -c "echo 'secret-token' > /run/secrets/api-key"
```

**2. Performance I/O**
```bash
# Cache haute performance
docker run -d --name cache-server \
  --tmpfs /tmp/cache:rw,size=1g \
  redis:alpine

# Benchmarks montrent 5-10x plus rapide que le disque
```

**3. Fichiers temporaires**
```bash
# Build temporaire
docker run --rm \
  --tmpfs /tmp:rw,size=2g \
  -v $(pwd):/app \
  -w /app \
  node:18 \
  npm run build
```

---

## Exercice 7 : Scénario pratique complet

### Script complet automatisé

```bash
#!/bin/bash
set -e

echo "=== Déploiement WordPress avec persistance ==="

# Nettoyage si existe
docker rm -f wordpress-mysql wordpress-app 2>/dev/null || true
docker network rm wordpress-net 2>/dev/null || true

# Création infrastructure
echo "1. Création du réseau..."
docker network create wordpress-net

echo "2. Création des volumes..."
docker volume create wordpress-db
docker volume create wordpress-files

echo "3. Démarrage MySQL..."
docker run -d \
  --name wordpress-mysql \
  --network wordpress-net \
  -v wordpress-db:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=rootpass \
  -e MYSQL_DATABASE=wordpress \
  -e MYSQL_USER=wpuser \
  -e MYSQL_PASSWORD=wppass \
  mysql:8.0

echo "4. Attente démarrage MySQL..."
sleep 15

echo "5. Démarrage WordPress..."
docker run -d \
  --name wordpress-app \
  --network wordpress-net \
  -p 8080:80 \
  -v wordpress-files:/var/www/html \
  -e WORDPRESS_DB_HOST=wordpress-mysql:3306 \
  -e WORDPRESS_DB_USER=wpuser \
  -e WORDPRESS_DB_PASSWORD=wppass \
  -e WORDPRESS_DB_NAME=wordpress \
  wordpress:latest

echo "6. Attente démarrage WordPress..."
sleep 10

echo ""
echo "=== WordPress prêt ! ==="
echo "URL: http://localhost:8080"
echo ""
echo "Volumes créés:"
docker volume ls | grep wordpress

echo ""
echo "Conteneurs actifs:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Test de persistance

```bash
#!/bin/bash

echo "=== Test de persistance ==="

# 1. Installer WordPress (simulé)
echo "1. Installation WordPress..."
curl -X POST http://localhost:8080/wp-admin/install.php \
  -d "weblog_title=Test Site" \
  -d "user_name=admin" \
  -d "admin_email=test@example.com" \
  -d "admin_password=testpass123" \
  -d "Submit=Install"

# 2. Créer du contenu
echo "2. Création de contenu..."
# (utiliser wp-cli ou l'interface web)

# 3. Crash simulé
echo "3. Simulation d'un crash..."
docker rm -f wordpress-app wordpress-mysql

# 4. Récupération
echo "4. Redémarrage des services..."
docker run -d --name wordpress-mysql --network wordpress-net \
  -v wordpress-db:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=rootpass mysql:8.0

sleep 10

docker run -d --name wordpress-app --network wordpress-net \
  -p 8080:80 -v wordpress-files:/var/www/html \
  -e WORDPRESS_DB_HOST=wordpress-mysql:3306 \
  -e WORDPRESS_DB_USER=wpuser \
  -e WORDPRESS_DB_PASSWORD=wppass \
  -e WORDPRESS_DB_NAME=wordpress \
  wordpress:latest

sleep 10

# 5. Vérification
echo "5. Vérification..."
curl -s http://localhost:8080 | grep -q "Test Site" && \
  echo "✓ Site restauré avec succès !" || \
  echo "✗ Échec de la restauration"
```

---

## Exercice 8 : Commandes utiles

### Scripts d'administration

```bash
# Script de diagnostic des volumes
#!/bin/bash

echo "=== Diagnostic des volumes Docker ==="
echo ""

echo "1. Volumes par taille:"
docker system df -v | grep -A 100 "Local Volumes" | grep -v "VOLUME NAME" | sort -k3 -h

echo ""
echo "2. Volumes orphelins (dangling):"
docker volume ls -qf dangling=true

echo ""
echo "3. Mapping conteneurs -> volumes:"
docker ps -a --format '{{.Names}}' | while read c; do
  volumes=$(docker inspect $c --format '{{range .Mounts}}{{.Name}} {{end}}' 2>/dev/null)
  if [ -n "$volumes" ]; then
    echo "$c: $volumes"
  fi
done

echo ""
echo "4. Espace total utilisé:"
docker system df

# Script de backup automatique
#!/bin/bash

BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d-%H%M%S)

mkdir -p $BACKUP_DIR

echo "=== Backup des volumes ==="

docker volume ls --format '{{.Name}}' | while read vol; do
  echo "Backup de $vol..."
  docker run --rm \
    -v $vol:/source:ro \
    -v $(pwd)/$BACKUP_DIR:/backup \
    alpine \
    tar czf /backup/${vol}-${DATE}.tar.gz -C /source .

  echo "✓ Sauvegardé: ${vol}-${DATE}.tar.gz"
done

echo ""
echo "Backups créés dans $BACKUP_DIR:"
ls -lh $BACKUP_DIR/*${DATE}*
```

---

## Bonnes pratiques

### 1. Nommage des volumes

```bash
# ✓ BIEN : Noms descriptifs
docker volume create app-prod-database
docker volume create app-prod-uploads
docker volume create app-dev-cache

# ✗ MAL : Volumes anonymes ou noms peu clairs
docker run -v /data nginx  # Crée un volume anonyme
docker volume create data  # Trop générique
```

### 2. Cycle de vie

```bash
# ✓ BIEN : Volumes explicites survivent aux conteneurs
docker volume create mon-volume
docker run -v mon-volume:/data nginx

# ✗ MAL : Volume anonyme peut être oublié
docker run -v /data nginx
```

### 3. Sécurité

```bash
# ✓ BIEN : Montage read-only quand approprié
docker run -v config-volume:/etc/config:ro nginx

# ✓ BIEN : Isolation par réseau et volumes
docker run --network isolated-net -v isolated-data:/data app

# ✗ MAL : Monter tout le système de fichiers
docker run -v /:/host nginx  # DANGEREUX !
```

### 4. Performance

```bash
# ✓ BIEN : Volumes pour bases de données
docker run -v postgres-data:/var/lib/postgresql/data postgres

# ✗ MAL : Bind mount pour bases de données en production
docker run -v ./data:/var/lib/postgresql/data postgres  # Plus lent

# ✓ BIEN : Bind mount pour développement
docker run -v $(pwd)/src:/app/src node  # Hot reload
```

---

## Tableau comparatif complet

| Aspect | Volume | Bind Mount | tmpfs |
|--------|--------|------------|-------|
| **Gestion** | Docker | Système hôte | Docker |
| **Path hôte** | /var/lib/docker/volumes/ | N'importe où | RAM |
| **Portabilité** | ✓✓✓ Excellente | ✗ Dépend de l'hôte | ✓ Bonne |
| **Performance** | ✓✓ Très bonne | ✓ Bonne | ✓✓✓ Maximale |
| **Backup** | ✓✓ Facile | ✓ Manuel | ✗ Impossible |
| **Partage** | ✓✓✓ Facile | ✓ Possible | ✗ Non |
| **Persistance** | ✓ Permanente | ✓ Permanente | ✗ Volatile |
| **Permissions** | ✓✓ Gérées | ⚠ Complexes | ✓ Simples |
| **Dev** | ✓ Bon | ✓✓✓ Excellent | ✗ Rare |
| **Prod** | ✓✓✓ Recommandé | ⚠ Acceptable | ✓✓ Spécifique |
| **Taille limite** | ✗ Disque | ✗ Disque | ✓ Configurable |
| **OS** | ✓ Tous | ✓ Tous | Linux only |

---

## Checklist de validation

- [x] Créé et utilisé des volumes nommés
- [x] Testé la persistance après suppression de conteneur
- [x] Utilisé des bind mounts pour le développement
- [x] Compris les différences entre les trois types
- [x] Partagé un volume entre plusieurs conteneurs
- [x] Sauvegardé et restauré un volume
- [x] Utilisé tmpfs pour des données sensibles
- [x] Nettoyé les volumes orphelins
- [x] Implémenté une application avec persistance complète

---

## Ressources supplémentaires

- [Documentation officielle - Volumes](https://docs.docker.com/storage/volumes/)
- [Bind mounts](https://docs.docker.com/storage/bind-mounts/)
- [tmpfs mounts](https://docs.docker.com/storage/tmpfs/)
- [Storage drivers](https://docs.docker.com/storage/storagedriver/)

**[← Retour au TP](../tp/TP5-Volumes.md)**
