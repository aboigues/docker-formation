# TP5 : Volumes et persistance des données

## Objectif

Comprendre et maîtriser les différentes méthodes de persistance des données avec Docker : volumes, bind mounts, et tmpfs.

## Durée estimée

45 minutes

## Concepts clés

Docker propose trois méthodes pour persister les données :

```
┌─────────────────────────────────────────────────────────┐
│                    Types de montage                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. VOLUMES (recommandé)                                │
│     Géré par Docker : /var/lib/docker/volumes/          │
│     ✓ Meilleure performance                             │
│     ✓ Facile à sauvegarder                              │
│     ✓ Fonctionne sur tous les OS                        │
│                                                         │
│  2. BIND MOUNTS                                         │
│     Lien vers un chemin de l'hôte                       │
│     ✓ Utile pour le développement                       │
│     ✓ Accès direct aux fichiers                         │
│     ⚠ Dépend du système de fichiers de l'hôte          │
│                                                         │
│  3. TMPFS (Linux uniquement)                            │
│     Stocké en mémoire RAM                               │
│     ✓ Très rapide                                       │
│     ✓ Données sensibles (non persistées sur disque)     │
│     ⚠ Perdu au redémarrage du conteneur                │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Exercice 1 : Comprendre le problème de la persistance

### 1.1 - Démonstration : Données non persistantes

```bash
# Créer un conteneur MySQL
docker run -d --name mysql-test -e MYSQL_ROOT_PASSWORD=secret mysql:8.0

# Attendre que MySQL démarre
sleep 15

# Créer une base de données
docker exec -it mysql-test mysql -psecret -e "CREATE DATABASE ma_base;"
docker exec -it mysql-test mysql -psecret -e "SHOW DATABASES;"

# Supprimer et recréer le conteneur
docker rm -f mysql-test
docker run -d --name mysql-test -e MYSQL_ROOT_PASSWORD=secret mysql:8.0
sleep 15

# Vérifier : la base de données a disparu !
docker exec -it mysql-test mysql -psecret -e "SHOW DATABASES;"
```

**Questions** :
1. Pourquoi la base de données `ma_base` a-t-elle disparu ?
2. Où sont stockées les données d'un conteneur par défaut ?
3. Que se passe-t-il quand on supprime un conteneur ?

---

## Exercice 2 : Volumes Docker (méthode recommandée)

### 2.1 - Créer et gérer des volumes

```bash
# Créer un volume
docker volume create mon-volume

# Lister les volumes
docker volume ls

# Inspecter un volume
docker volume inspect mon-volume

# Trouver où le volume est stocké
docker volume inspect mon-volume --format '{{.Mountpoint}}'
```

**Questions** :
1. Où est physiquement stocké le volume sur votre système ?
2. Peut-on accéder directement aux fichiers du volume ?
3. Quelle est la différence entre un volume et un conteneur ?

### 2.2 - Utiliser un volume avec MySQL

```bash
# Créer un volume pour MySQL
docker volume create mysql-data

# Lancer MySQL avec le volume
docker run -d \
  --name mysql-persistent \
  -e MYSQL_ROOT_PASSWORD=secret \
  -v mysql-data:/var/lib/mysql \
  mysql:8.0

# Attendre le démarrage
sleep 15

# Créer une base et des données
docker exec -it mysql-persistent mysql -psecret << EOF
CREATE DATABASE ma_base;
USE ma_base;
CREATE TABLE utilisateurs (id INT, nom VARCHAR(50));
INSERT INTO utilisateurs VALUES (1, 'Alice'), (2, 'Bob');
SELECT * FROM utilisateurs;
EOF

# Vérifier les données
docker exec -it mysql-persistent mysql -psecret -e "USE ma_base; SELECT * FROM utilisateurs;"
```

### 2.3 - Test de persistance

```bash
# Supprimer le conteneur (MAIS PAS LE VOLUME)
docker rm -f mysql-persistent

# Recréer un nouveau conteneur avec le MÊME volume
docker run -d \
  --name mysql-nouveau \
  -e MYSQL_ROOT_PASSWORD=secret \
  -v mysql-data:/var/lib/mysql \
  mysql:8.0

sleep 10

# Vérifier : les données sont toujours là !
docker exec -it mysql-nouveau mysql -psecret -e "USE ma_base; SELECT * FROM utilisateurs;"
```

**Questions** :
1. Les données ont-elles persisté après suppression du conteneur ?
2. Peut-on réutiliser le même volume avec un autre conteneur ?
3. Comment sauvegarder les données d'un volume ?

### 2.4 - Volumes avec Nginx (fichiers statiques)

```bash
# Créer un volume pour le contenu web
docker volume create web-content

# Lancer Nginx avec ce volume
docker run -d --name nginx-vol -p 8080:80 -v web-content:/usr/share/nginx/html nginx:alpine

# Ajouter du contenu via un conteneur temporaire
docker run --rm -v web-content:/data alpine sh -c "echo '<h1>Hello from volume!</h1>' > /data/index.html"

# Tester
curl http://localhost:8080

# Ou modifier depuis le conteneur nginx
docker exec nginx-vol sh -c "echo '<h1>Updated content</h1>' > /usr/share/nginx/html/index.html"
curl http://localhost:8080
```

**Tâches** :
1. Créer une page HTML avec plusieurs fichiers
2. Vérifier qu'ils persistent après redémarrage du conteneur
3. Partager ce volume avec un deuxième conteneur nginx sur un autre port

---

## Exercice 3 : Bind Mounts (développement)

### 3.1 - Monter un dossier local

```bash
# Créer un dossier de travail
mkdir -p ~/docker-tp/website
cd ~/docker-tp/website

# Créer du contenu
cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Mon site Docker</title>
    <style>
        body { font-family: Arial; text-align: center; margin-top: 50px; }
        h1 { color: #0066cc; }
    </style>
</head>
<body>
    <h1>Bienvenue sur mon site</h1>
    <p>Modifiez index.html et rafraîchissez la page !</p>
</body>
</html>
EOF

# Lancer nginx avec bind mount (syntaxe absolue)
docker run -d --name nginx-dev \
  -p 8081:80 \
  -v "$(pwd)":/usr/share/nginx/html:ro \
  nginx:alpine

# Tester
curl http://localhost:8081
```

**Note** : L'option `:ro` (read-only) empêche le conteneur de modifier les fichiers.

### 3.2 - Développement en temps réel

```bash
# Modifier le fichier HTML sur l'hôte
echo '<h1>MODIFICATION EN DIRECT !</h1>' >> ~/docker-tp/website/index.html

# Rafraîchir immédiatement visible
curl http://localhost:8081

# Ajouter un fichier CSS
cat > ~/docker-tp/website/style.css << 'EOF'
body {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
}
EOF

# Modifier index.html pour l'utiliser
cat > ~/docker-tp/website/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <h1>Site avec bind mount</h1>
    <p>Modifications en temps réel !</p>
</body>
</html>
EOF

# Vérifier
curl http://localhost:8081
```

**Questions** :
1. Les modifications sont-elles immédiates dans le conteneur ?
2. Quelle est la différence entre `-v $(pwd):/app` et `-v $(pwd):/app:ro` ?
3. Pourquoi utiliser bind mounts pour le développement ?

### 3.3 - Bind mount avec une application Node.js

```bash
# Créer un projet Node.js simple
mkdir -p ~/docker-tp/node-app
cd ~/docker-tp/node-app

cat > app.js << 'EOF'
const http = require('http');
const fs = require('fs');

const server = http.createServer((req, res) => {
  const message = fs.existsSync('/data/message.txt')
    ? fs.readFileSync('/data/message.txt', 'utf8')
    : 'No message';

  res.writeHead(200, {'Content-Type': 'text/plain'});
  res.end(`Message: ${message}\nTime: ${new Date().toISOString()}`);
});

server.listen(3000, () => {
  console.log('Server running on port 3000');
});
EOF

# Créer un dossier pour les données
mkdir -p ~/docker-tp/node-app/data
echo "Hello from bind mount!" > ~/docker-tp/node-app/data/message.txt

# Lancer avec bind mounts multiples
docker run -d --name node-app \
  -p 3000:3000 \
  -v "$(pwd)/app.js":/app/app.js:ro \
  -v "$(pwd)/data":/data \
  -w /app \
  node:18-alpine \
  node app.js

# Tester
curl http://localhost:3000

# Modifier le message
echo "Message mis à jour !" > ~/docker-tp/node-app/data/message.txt

# Redémarrer l'app pour voir le changement
docker restart node-app
sleep 2
curl http://localhost:3000
```

---

## Exercice 4 : Volumes anonymes et nommés

### 4.1 - Volume anonyme (créé automatiquement)

```bash
# Lancer sans spécifier de volume nommé
docker run -d --name postgres-anon \
  -e POSTGRES_PASSWORD=secret \
  -v /var/lib/postgresql/data \
  postgres:15-alpine

# Docker crée automatiquement un volume anonyme
docker volume ls

# Inspecter le conteneur pour trouver le volume
docker inspect postgres-anon --format '{{json .Mounts}}' | python3 -m json.tool
```

**Questions** :
1. Combien de volumes anonymes avez-vous ?
2. Comment identifier quel volume appartient à quel conteneur ?
3. Que se passe-t-il avec un volume anonyme quand on supprime le conteneur ?

### 4.2 - Nettoyer les volumes anonymes

```bash
# Supprimer le conteneur (le volume anonyme reste)
docker rm -f postgres-anon

# Les volumes anonymes restent !
docker volume ls

# Nettoyer les volumes non utilisés
docker volume prune

# Ou supprimer un conteneur ET son volume
docker run -d --name postgres-temp \
  -e POSTGRES_PASSWORD=secret \
  -v /var/lib/postgresql/data \
  postgres:15-alpine

docker rm -f -v postgres-temp  # -v supprime aussi les volumes anonymes
```

---

## Exercice 5 : Partage de volumes entre conteneurs

### 5.1 - Conteneurs partageant des données

```bash
# Créer un volume partagé
docker volume create shared-data

# Conteneur 1 : écrivain (writer)
docker run -d --name writer \
  -v shared-data:/data \
  alpine \
  sh -c "while true; do date >> /data/log.txt; sleep 2; done"

# Conteneur 2 : lecteur (reader)
docker run -d --name reader \
  -v shared-data:/data:ro \
  alpine \
  sh -c "while true; do tail -5 /data/log.txt; sleep 5; done"

# Voir les logs du reader
docker logs -f reader

# Vérifier que les deux conteneurs voient les mêmes données
docker exec writer cat /data/log.txt
docker exec reader cat /data/log.txt
```

**Questions** :
1. Les deux conteneurs voient-ils les mêmes données ?
2. Pourquoi monter le volume en `:ro` pour le reader ?
3. Combien de conteneurs peuvent partager un même volume ?

### 5.2 - Pattern : Conteneur de sauvegarde

```bash
# Créer un volume avec des données
docker volume create app-data
docker run --rm -v app-data:/data alpine sh -c "echo 'Important data' > /data/file.txt"

# Sauvegarder le volume dans un tar
docker run --rm \
  -v app-data:/source:ro \
  -v "$(pwd)":/backup \
  alpine \
  tar czf /backup/app-data-backup.tar.gz -C /source .

# Vérifier
ls -lh app-data-backup.tar.gz
tar tzf app-data-backup.tar.gz

# Restaurer dans un nouveau volume
docker volume create app-data-restored

docker run --rm \
  -v app-data-restored:/target \
  -v "$(pwd)":/backup \
  alpine \
  tar xzf /backup/app-data-backup.tar.gz -C /target

# Vérifier la restauration
docker run --rm -v app-data-restored:/data alpine cat /data/file.txt
```

---

## Exercice 6 : tmpfs mounts (Linux uniquement)

```bash
# Créer un conteneur avec tmpfs (stockage en RAM)
docker run -d --name app-tmpfs \
  --tmpfs /tmp:rw,size=100m,mode=1777 \
  nginx:alpine

# Vérifier le montage
docker exec app-tmpfs df -h /tmp
docker exec app-tmpfs mount | grep tmpfs

# Écrire des données
docker exec app-tmpfs sh -c "echo 'Sensitive data' > /tmp/secret.txt"
docker exec app-tmpfs cat /tmp/secret.txt

# Redémarrer : les données sont perdues
docker restart app-tmpfs
docker exec app-tmpfs ls /tmp  # Vide !
```

**Use cases pour tmpfs** :
- Données sensibles (mots de passe, tokens)
- Caches temporaires
- Sockets et PID files
- Meilleures performances I/O

---

## Exercice 7 : Scénario pratique complet

### Objectif : Application web avec base de données persistante

```bash
# 1. Créer les volumes
docker volume create wordpress-db
docker volume create wordpress-files

# 2. Lancer MySQL avec volume
docker run -d \
  --name wordpress-mysql \
  --network wordpress-net \
  -v wordpress-db:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=rootpass \
  -e MYSQL_DATABASE=wordpress \
  -e MYSQL_USER=wpuser \
  -e MYSQL_PASSWORD=wppass \
  mysql:8.0

# Créer le réseau si nécessaire
docker network create wordpress-net 2>/dev/null || true
docker network connect wordpress-net wordpress-mysql 2>/dev/null || true

# 3. Lancer WordPress avec volume
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

# 4. Attendre le démarrage
sleep 10

# 5. Vérifier
echo "WordPress disponible sur http://localhost:8080"
curl -s http://localhost:8080 | grep -i wordpress

# 6. Tester la persistance
echo "Simuler un crash : supprimer les conteneurs"
docker rm -f wordpress-app wordpress-mysql

# 7. Recréer avec les mêmes volumes
docker run -d \
  --name wordpress-mysql \
  --network wordpress-net \
  -v wordpress-db:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=rootpass \
  mysql:8.0

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

echo "WordPress restauré avec toutes les données !"
```

---

## Exercice 8 : Commandes utiles

### 8.1 - Inspection et diagnostic

```bash
# Lister tous les volumes avec leur taille
docker system df -v

# Trouver les volumes non utilisés
docker volume ls -f dangling=true

# Voir quel conteneur utilise quel volume
docker ps -a --format '{{.Names}}' | xargs -I {} docker inspect {} --format '{{.Name}}: {{range .Mounts}}{{.Name}} {{end}}'

# Copier des données depuis un volume
docker run --rm -v mon-volume:/source -v $(pwd):/backup alpine cp -r /source/. /backup/
```

### 8.2 - Nettoyage

```bash
# Supprimer un volume spécifique
docker volume rm mon-volume

# Supprimer tous les volumes non utilisés
docker volume prune

# Supprimer TOUS les volumes (ATTENTION !)
docker volume prune -a

# Supprimer conteneur + volumes associés
docker rm -v mon-conteneur
```

---

## 🏆 Validation

À l'issue de ce TP, vous devez savoir :

- [ ] Créer et gérer des volumes Docker
- [ ] Utiliser des bind mounts pour le développement
- [ ] Comprendre les différences entre volumes, bind mounts et tmpfs
- [ ] Partager des volumes entre conteneurs
- [ ] Sauvegarder et restaurer des volumes
- [ ] Diagnostiquer et nettoyer les volumes
- [ ] Implémenter la persistance dans une application réelle

---

## 📊 Comparaison des méthodes

| Caractéristique | Volume | Bind Mount | tmpfs |
|----------------|--------|------------|-------|
| **Géré par Docker** | ✅ Oui | ❌ Non | ✅ Oui |
| **Performance** | ⚡ Excellente | ⚡ Bonne | ⚡⚡ Maximale |
| **Portabilité** | ✅ Multi-OS | ⚠️ Dépend de l'hôte | ❌ Linux uniquement |
| **Sauvegarde** | ✅ Facile | ⚠️ Manuel | ❌ Impossible |
| **Persistance** | ✅ Permanente | ✅ Permanente | ❌ Volatile |
| **Use case** | Production | Développement | Données sensibles |

---

## 🚀 Aller plus loin

```bash
# Créer un volume avec un driver spécifique
docker volume create --driver local \
  --opt type=nfs \
  --opt o=addr=192.168.1.1,rw \
  --opt device=:/path/to/dir \
  nfs-volume

# Utiliser un volume avec un sous-chemin
docker run -v mon-volume:/app/data/subfolder nginx

# Labels pour organiser les volumes
docker volume create --label env=prod --label app=wordpress wp-prod-data
docker volume ls --filter label=env=prod
```

---

**[→ Voir les solutions](../solutions/TP5-Solution.md)**

**[→ TP suivant : Réseaux Docker](TP6-Networks.md)**
