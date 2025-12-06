# TP3 : Commandes de base Docker

## Objectif

Maîtriser les commandes essentielles pour gérer images et conteneurs Docker.

## Durée estimée

45 minutes

## Architecture Docker - Rappel

```
┌──────────────────────────────────────────────┐
│           Docker Client (CLI)                │
│              docker <command>                │
└──────────────┬───────────────────────────────┘
               │ REST API
┌──────────────▼───────────────────────────────┐
│          Docker Daemon (dockerd)             │
│                                              │
│  ┌─────────────┐  ┌─────────────┐           │
│  │ Containers  │  │   Images    │           │
│  └─────────────┘  └─────────────┘           │
│  ┌─────────────┐  ┌─────────────┐           │
│  │  Volumes    │  │  Networks   │           │
│  └─────────────┘  └─────────────┘           │
└──────────────────────────────────────────────┘
```

---

## Exercice 1 : Gestion des images

### 1.1 - Rechercher des images

```bash
# Rechercher des images nginx sur Docker Hub
docker search nginx

# Rechercher avec un filtre (images officielles uniquement)
docker search --filter "is-official=true" nginx

# Limiter les résultats
docker search --limit 5 nginx
```

**Questions** :
1. Combien d'images nginx trouvez-vous ?
2. Quelle est la différence entre une image officielle et non-officielle ?
3. Qu'est-ce que le nombre de "STARS" indique ?

### 1.2 - Télécharger des images

```bash
# Télécharger la dernière version de nginx
docker pull nginx

# Télécharger une version spécifique
docker pull nginx:1.25

# Télécharger une image alpine (version légère)
docker pull nginx:alpine

# Télécharger plusieurs images en parallèle
docker pull redis
docker pull mysql:8.0
```

**Questions** :
1. Quelle est la différence entre `nginx` et `nginx:latest` ?
2. Quelle est la taille de `nginx:latest` vs `nginx:alpine` ?
3. Pourquoi utiliser une version alpine ?

### 1.3 - Lister et inspecter les images

```bash
# Lister toutes les images locales
docker images

# Format détaillé
docker images --no-trunc

# Filtrer par nom
docker images nginx

# Afficher les ID seulement
docker images -q

# Inspecter une image (JSON détaillé)
docker inspect nginx

# Afficher l'historique d'une image (les layers)
docker history nginx
```

**Questions** :
1. Combien de layers compose l'image nginx ?
2. Quelle est la commande par défaut de l'image nginx ?
3. Quel port est exposé par défaut ?

---

## Exercice 2 : Gestion des conteneurs

### 2.1 - Créer et démarrer des conteneurs

```bash
# Lancer nginx en arrière-plan (detached)
docker run -d --name mon-nginx nginx

# Lancer nginx avec un port mappé
docker run -d --name web -p 8080:80 nginx

# Lancer avec variables d'environnement
docker run -d --name db -e MYSQL_ROOT_PASSWORD=secret mysql:8.0

# Lancer en mode interactif
docker run -it --name ubuntu-shell ubuntu bash
```

**Important** :
- `-d` : Détaché (en arrière-plan)
- `-it` : Interactif avec terminal
- `--name` : Donner un nom au conteneur
- `-p` : Mapper un port (hôte:conteneur)
- `-e` : Variable d'environnement

**Questions** :
1. Quelle est la différence entre `-d` et `-it` ?
2. Comment accéder au nginx sur le port 8080 ?
3. Que se passe-t-il si on oublie `-d` avec nginx ?

### 2.2 - Lister les conteneurs

```bash
# Lister les conteneurs en cours d'exécution
docker ps

# Lister TOUS les conteneurs (même arrêtés)
docker ps -a

# Afficher uniquement les IDs
docker ps -q

# Afficher la taille des conteneurs
docker ps -s

# Format personnalisé
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

**Questions** :
1. Combien de conteneurs avez-vous en cours d'exécution ?
2. Quelle est la différence entre `docker ps` et `docker ps -a` ?
3. Quel est le status de votre conteneur ubuntu-shell ?

### 2.3 - Gérer le cycle de vie

```bash
# Arrêter un conteneur (graceful stop, SIGTERM puis SIGKILL après 10s)
docker stop mon-nginx

# Arrêter immédiatement (SIGKILL)
docker kill mon-nginx

# Démarrer un conteneur arrêté
docker start mon-nginx

# Redémarrer
docker restart mon-nginx

# Mettre en pause (freeze les processus)
docker pause mon-nginx

# Reprendre
docker unpause mon-nginx

# Supprimer un conteneur (doit être arrêté)
docker rm mon-nginx

# Forcer la suppression (même en cours d'exécution)
docker rm -f mon-nginx
```

**Questions** :
1. Peut-on supprimer un conteneur en cours d'exécution avec `docker rm` ?
2. Quelle est la différence entre `stop` et `kill` ?
3. Quelle est la différence entre `pause` et `stop` ?

---

## Exercice 3 : Interaction avec les conteneurs

### 3.1 - Exécuter des commandes dans un conteneur

Recréez d'abord un conteneur nginx :
```bash
docker run -d --name web nginx
```

Puis exécutez des commandes :

```bash
# Exécuter une commande ponctuelle
docker exec web ls /usr/share/nginx/html

# Afficher les processus dans le conteneur
docker exec web ps aux

# Entrer en mode interactif dans un conteneur en cours
docker exec -it web bash

# Une fois à l'intérieur :
root@xxx:/# cat /etc/nginx/nginx.conf
root@xxx:/# curl localhost
root@xxx:/# exit
```

**Questions** :
1. Quelle est la différence entre `docker run` et `docker exec` ?
2. Peut-on exécuter `docker exec` sur un conteneur arrêté ?
3. Que se passe-t-il quand on fait `exit` dans un `docker exec` ?

### 3.2 - Voir les logs

```bash
# Afficher les logs d'un conteneur
docker logs web

# Suivre les logs en temps réel (comme tail -f)
docker logs -f web

# Afficher les 10 dernières lignes
docker logs --tail 10 web

# Afficher avec timestamps
docker logs -t web

# Générer du trafic pour voir les logs
# Dans un autre terminal :
curl http://localhost:8080
```

**Questions** :
1. Où sont stockés les logs des conteneurs ?
2. Comment suivre les logs en temps réel ?
3. Les logs persistent-ils après suppression du conteneur ?

### 3.3 - Afficher les statistiques

```bash
# Statistiques temps réel (CPU, RAM, Réseau, I/O)
docker stats

# Stats d'un conteneur spécifique
docker stats web

# Sans stream (une seule fois)
docker stats --no-stream

# Afficher les processus
docker top web
```

**Questions** :
1. Combien de RAM utilise votre conteneur nginx ?
2. Combien de processus tournent dans le conteneur ?
3. Quel est le PID du processus principal ?

---

## Exercice 4 : Copier des fichiers

### 4.1 - Du conteneur vers l'hôte

```bash
# Créer un conteneur nginx
docker run -d --name nginx-test nginx

# Copier un fichier du conteneur vers l'hôte
docker cp nginx-test:/etc/nginx/nginx.conf ./nginx.conf

# Copier un dossier entier
docker cp nginx-test:/etc/nginx ./nginx-config

# Vérifier
ls -la nginx.conf
cat nginx.conf
```

### 4.2 - De l'hôte vers le conteneur

```bash
# Créer un fichier HTML personnalisé
echo "<h1>Hello Docker!</h1>" > index.html

# Copier vers le conteneur
docker cp index.html nginx-test:/usr/share/nginx/html/index.html

# Vérifier
curl http://localhost:8080  # Si le port est mappé
# ou
docker exec nginx-test cat /usr/share/nginx/html/index.html
```

**Questions** :
1. Peut-on copier des fichiers vers un conteneur arrêté ?
2. Les modifications persistent-elles après redémarrage du conteneur ?
3. Quelle est la meilleure méthode pour avoir des fichiers persistants ? (indice : volumes)

---

## Exercice 5 : Informations et diagnostics

### 5.1 - Inspecter un conteneur

```bash
# Inspecter un conteneur (sortie JSON complète)
docker inspect web

# Filtrer pour obtenir l'IP du conteneur
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' web

# Obtenir l'état du conteneur
docker inspect -f '{{.State.Status}}' web

# Obtenir les variables d'environnement
docker inspect -f '{{.Config.Env}}' web
```

**Tâches** :
1. Trouvez l'adresse IP du conteneur `web`
2. Trouvez l'image utilisée par ce conteneur
3. Trouvez la commande exécutée au démarrage
4. Trouvez la date de création du conteneur

### 5.2 - Voir les modifications du filesystem

```bash
# Créer un conteneur et modifier un fichier
docker run -d --name alpine-test alpine sleep 3600
docker exec alpine-test touch /root/nouveau-fichier.txt
docker exec alpine-test sh -c "echo 'test' > /root/data.txt"

# Voir les différences avec l'image d'origine
docker diff alpine-test
```

**Résultat attendu** :
- `A` = Ajouté
- `C` = Modifié (Changed)
- `D` = Supprimé (Deleted)

**Questions** :
1. Quels fichiers ont été ajoutés ?
2. Ces modifications sont-elles dans l'image ou dans le conteneur ?
3. Que devient cette couche de modifications si on supprime le conteneur ?

---

## Exercice 6 : Scénario pratique

### Objectif : Déployer un serveur web simple

**Étapes** :

1. **Télécharger l'image nginx:alpine**
```bash
docker pull nginx:alpine
```

2. **Créer un fichier HTML personnalisé**
```bash
mkdir -p ~/docker-tp/html
echo "<html><body><h1>Ma première page Docker</h1><p>Servie par Nginx</p></body></html>" > ~/docker-tp/html/index.html
```

3. **Lancer nginx avec votre HTML** (on verra les volumes plus tard, pour l'instant copier après le lancement)
```bash
docker run -d --name mon-site -p 8080:80 nginx:alpine
docker cp ~/docker-tp/html/index.html mon-site:/usr/share/nginx/html/index.html
```

4. **Vérifier que ça fonctionne**
```bash
curl http://localhost:8080
# ou ouvrir dans un navigateur : http://localhost:8080
```

5. **Voir les logs d'accès**
```bash
docker logs mon-site
```

6. **Entrer dans le conteneur et explorer**
```bash
docker exec -it mon-site sh
# Dans le conteneur :
ps aux
netstat -tlnp
cat /etc/nginx/nginx.conf
exit
```

7. **Voir les statistiques**
```bash
docker stats mon-site --no-stream
```

8. **Nettoyage**
```bash
docker stop mon-site
docker rm mon-site
```

---

## Exercice 7 : Commandes en masse

```bash
# Arrêter tous les conteneurs en cours
docker stop $(docker ps -q)

# Supprimer tous les conteneurs arrêtés
docker rm $(docker ps -aq)

# Supprimer toutes les images
docker rmi $(docker images -q)

# Version sécurisée avec prune
docker container prune    # Supprimer conteneurs arrêtés
docker image prune        # Supprimer images non utilisées
docker system prune       # Nettoyer tout
docker system prune -a    # Nettoyer tout (même images utilisées)
```

**⚠️ Attention** : Ces commandes peuvent supprimer beaucoup de choses. Vérifiez toujours avant !

---

## 🏆 Validation

À l'issue de ce TP, vous devez savoir :

- [ ] Chercher, télécharger et lister des images
- [ ] Créer, démarrer, arrêter, redémarrer des conteneurs
- [ ] Différencier `docker run` et `docker exec`
- [ ] Voir les logs et statistiques d'un conteneur
- [ ] Copier des fichiers entre hôte et conteneur
- [ ] Inspecter un conteneur pour obtenir des informations
- [ ] Nettoyer votre environnement Docker

---

## 📊 Tableau récapitulatif des commandes

| Catégorie | Commande | Description |
|-----------|----------|-------------|
| **Images** | `docker search` | Rechercher des images |
| | `docker pull` | Télécharger une image |
| | `docker images` | Lister les images |
| | `docker rmi` | Supprimer une image |
| | `docker history` | Voir les layers |
| **Conteneurs** | `docker run` | Créer et démarrer |
| | `docker ps` | Lister (running) |
| | `docker ps -a` | Lister (tous) |
| | `docker start/stop` | Démarrer/arrêter |
| | `docker restart` | Redémarrer |
| | `docker rm` | Supprimer |
| **Interaction** | `docker exec` | Exécuter une commande |
| | `docker logs` | Voir les logs |
| | `docker cp` | Copier des fichiers |
| | `docker attach` | Attacher au terminal |
| **Monitoring** | `docker stats` | Statistiques en temps réel |
| | `docker top` | Processus |
| | `docker inspect` | Informations détaillées |
| | `docker diff` | Modifications FS |
| **Nettoyage** | `docker prune` | Nettoyer les ressources |
| | `docker system df` | Espace utilisé |

---

## 🚀 Aller plus loin

```bash
# Créer un alias pour faciliter votre vie
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

# Afficher les conteneurs avec leur IP
docker ps -q | xargs docker inspect -f '{{.Name}} - {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'

# Trouver les conteneurs qui utilisent le plus de RAM
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}" | sort -k 2 -h
```

---

**[→ Voir les solutions](../solutions/TP3-Solution.md)**

**[→ TP suivant : Inspection et diagnostic](TP4-Inspection-Diagnostic.md)**
