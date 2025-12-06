# Guide de démarrage rapide

Ce guide vous permet de démarrer rapidement avec la formation Docker.

## Installation express de Docker

### Linux (Ubuntu/Debian)

```bash
# Installation automatique
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Ajouter votre utilisateur au groupe docker
sudo usermod -aG docker $USER

# IMPORTANT : Se déconnecter et se reconnecter pour appliquer les changements
# Puis vérifier :
docker --version
docker run hello-world
```

### Windows 10/11 Pro

1. Télécharger [Docker Desktop](https://www.docker.com/products/docker-desktop)
2. Installer et redémarrer
3. Ouvrir PowerShell :
```powershell
docker --version
docker run hello-world
```

### macOS

1. Télécharger [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop)
2. Glisser dans Applications et lancer
3. Ouvrir Terminal :
```bash
docker --version
docker run hello-world
```

## Vérification de l'installation

```bash
# Version Docker
docker --version

# Version Docker Compose
docker compose version

# Test de base
docker run hello-world

# Informations système
docker info
```

Si toutes ces commandes fonctionnent, vous êtes prêt !

## Premiers pas (15 minutes)

### 1. Votre premier conteneur web

```bash
# Lancer un serveur web nginx
docker run -d -p 8080:80 --name mon-premier-web nginx

# Vérifier dans votre navigateur
# http://localhost:8080

# Voir les logs
docker logs mon-premier-web

# Arrêter et supprimer
docker stop mon-premier-web
docker rm mon-premier-web
```

### 2. Conteneur interactif

```bash
# Lancer Ubuntu en mode interactif
docker run -it ubuntu bash

# Dans le conteneur, essayez :
cat /etc/os-release
ls /
exit
```

### 3. Nettoyage

```bash
# Supprimer tous les conteneurs arrêtés
docker container prune

# Voir l'espace utilisé
docker system df
```

## Structure de la formation

```
1. Module 1 (1h) → Installation et concepts de base
2. Module 2 (1h30) → Commandes Docker essentielles
3. Module 3 (2h) → Volumes, réseaux, images
4. Module 4 (2h30) → Création d'images (Dockerfile)
5. Module 5 (2h30) → Docker Compose et multi-conteneurs
6. Module 6 (1h30) → Interfaces d'administration
7. Module 7 (2h) → Production et bonnes pratiques
8. Module 8 (3h) → Orchestration (Swarm, Kubernetes)
```

## Parcours recommandés

### Débutant complet
Suivez tous les modules dans l'ordre : 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8

### Développeur
Modules recommandés : 1, 2, 3, 4, 5, 7

### DevOps/SysAdmin
Tous les modules, avec focus sur 6, 7, 8

### Évaluation rapide
Modules 1, 2, 4, 5 (journée complète)

## Commandes essentielles à connaître

### Images
```bash
docker pull <image>          # Télécharger
docker images                # Lister
docker rmi <image>           # Supprimer
```

### Conteneurs
```bash
docker run <image>           # Créer et démarrer
docker ps                    # Lister (actifs)
docker ps -a                 # Lister (tous)
docker stop <container>      # Arrêter
docker start <container>     # Démarrer
docker rm <container>        # Supprimer
docker logs <container>      # Voir les logs
docker exec -it <container> bash  # Entrer dans le conteneur
```

### Nettoyage
```bash
docker system prune          # Nettoyer tout
docker container prune       # Supprimer conteneurs arrêtés
docker image prune           # Supprimer images non utilisées
```

## Dépannage rapide

### Linux : "permission denied"
```bash
sudo usermod -aG docker $USER
# Puis se déconnecter/reconnecter
```

### Windows/Mac : "Cannot connect to Docker daemon"
→ Vérifier que Docker Desktop est lancé (icône dans la barre)

### Port déjà utilisé
→ Changer le port : `-p 8081:80` au lieu de `-p 8080:80`

### Manque d'espace disque
```bash
docker system prune -a  # Attention : supprime tout !
```

## Prochaines étapes

✅ Installation complète → [Commencez le Module 1](./module-01-virtualisation-docker/README.md)

✅ Besoin d'approfondir → [Consultez le README principal](./README.md)

## Ressources

- [Documentation officielle Docker](https://docs.docker.com/)
- [Docker Hub (images)](https://hub.docker.com/)
- [Cheat sheet Docker](https://docs.docker.com/get-started/docker_cheatsheet.pdf)

---

**Prêt ? Lancez-vous ! 🚀**
