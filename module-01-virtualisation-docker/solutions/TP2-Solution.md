# Solution TP2 : Installation de Docker

## Exercice 1 : Vérification des prérequis

### Linux - Résultats attendus

```bash
# Vérifier la version du kernel
$ uname -r
5.15.0-91-generic  # ou supérieur (doit être >= 3.10)

# Vérifier l'architecture
$ uname -m
x86_64  # doit être 64-bit

# Vérifier l'espace disque
$ df -h /var/lib
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        50G   15G   33G  32% /
# Au moins 10 GB disponibles recommandés
```

✅ **Validation** : Kernel >= 3.10, architecture 64-bit, espace suffisant

### Windows - Résultats attendus

```powershell
# Version de Windows
OS Name:     Microsoft Windows 10 Pro
OS Version:  10.0.19045 N/A Build 19045
# Doit être Pro, Enterprise, ou Education

# Virtualisation
PS C:\> Get-ComputerInfo -Property "HyperV*"
HyperVisorPresent                : True
HyperVRequirementVirtualizationFirmwareEnabled : True
```

✅ **Validation** : Windows 10/11 Pro ou supérieur, Hyper-V disponible

### macOS - Résultats attendus

```bash
$ sw_vers
ProductName:    macOS
ProductVersion: 13.5.2
BuildVersion:   22G91
# Version 10.15 ou supérieure

$ df -h
Filesystem      Size   Used  Avail Capacity
/dev/disk1s1   500Gi  200Gi  280Gi    42%
```

✅ **Validation** : macOS 10.15+, espace disque suffisant

---

## Exercice 2 : Installation de Docker

### Linux (Ubuntu/Debian) - Installation complète

Les commandes du TP installent Docker correctement. Voici une vérification :

```bash
# Après installation, vérifier le service
$ sudo systemctl status docker
● docker.service - Docker Application Container Engine
   Loaded: loaded (/lib/systemd/system/docker.service; enabled)
   Active: active (running) since Fri 2024-01-15 10:00:00 UTC; 2min ago

# Vérifier que l'utilisateur est dans le groupe docker
$ groups
user adm docker sudo

# Si "docker" n'apparaît pas :
$ sudo usermod -aG docker $USER
# Puis SE DÉCONNECTER et se reconnecter
```

**⚠️ Important** : L'ajout au groupe docker nécessite une **nouvelle session** (logout/login) pour être effectif.

### Windows - Validation post-installation

Après installation de Docker Desktop :

1. **Vérifier que Docker Desktop est lancé** :
   - Icône de baleine dans la barre des tâches
   - Verte = en cours d'exécution

2. **Ouvrir PowerShell ou CMD** :
```powershell
docker --version
Docker version 24.0.7, build afdd53b
```

3. **Paramètres Docker Desktop** :
   - Settings → General → "Use WSL 2 based engine" (recommandé)
   - Settings → Resources → vérifier CPU et RAM alloués

### macOS - Validation post-installation

1. **Docker dans le dock** : Icône de baleine visible
2. **Terminal** :
```bash
docker --version
Docker version 24.0.7, build afdd53b
```

---

## Exercice 3 : Vérification de l'installation

### Commandes et résultats attendus

```bash
# 1. Version de Docker
$ docker --version
Docker version 24.0.7, build afdd53b

# 2. Version de Docker Compose
$ docker compose version
Docker Compose version v2.23.0

# 3. Informations système
$ docker info
Client:
 Version:    24.0.7
 Context:    default

Server:
 Containers: 0
  Running: 0
  Paused: 0
  Stopped: 0
 Images: 0
 Server Version: 24.0.7
 Storage Driver: overlay2
 Logging Driver: json-file
 Cgroup Driver: systemd
 Kernel Version: 5.15.0-91-generic
 Operating System: Ubuntu 22.04.3 LTS
 OSType: linux
 Architecture: x86_64
 CPUs: 4
 Total Memory: 7.75GiB
 Docker Root Dir: /var/lib/docker
```

### Réponses aux questions

**1. Quelle version de Docker avez-vous installée ?**
- Réponse exemple : Docker version 24.0.7 (votre version peut différer)

**2. Combien de conteneurs sont actuellement en cours d'exécution ?**
- Réponse attendue : 0 (installation fraîche)

**3. Quelle est la version du serveur Docker Engine ?**
- Réponse exemple : 24.0.7 (visible dans `docker info`)

---

## Exercice 4 : Premier conteneur

### Commande et résultat attendu

```bash
$ docker run hello-world

Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
c1ec31eb5944: Pull complete
Digest: sha256:1408fec50309afee38f3535383f5b09419e6dc0925bc69891e79d84cc4cdcec6
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/
```

### Réponses aux questions

**1. Que fait la commande `docker run` ?**

La commande `docker run` :
1. Vérifie si l'image existe localement
2. Si non, la télécharge depuis Docker Hub
3. Crée un nouveau conteneur à partir de l'image
4. Démarre le conteneur
5. Exécute la commande définie dans l'image
6. Affiche la sortie
7. Arrête le conteneur une fois terminé

**2. D'où provient l'image `hello-world` ?**

- **Docker Hub** (https://hub.docker.com) : Le registre public par défaut de Docker
- Chemin complet : `library/hello-world:latest`
- `library/` = images officielles Docker
- `:latest` = tag par défaut (dernière version)

**3. Que se passe-t-il si vous exécutez la commande une deuxième fois ?**

```bash
$ docker run hello-world

Hello from Docker!
...
```

Différences :
- ✅ **Pas de téléchargement** : L'image est déjà en cache local
- ✅ **Exécution plus rapide** : Presque instantanée
- ⚠️ **Nouveau conteneur** : Chaque `run` crée un nouveau conteneur

---

## Exercice 5 : Commandes de diagnostic

### Résultats attendus

```bash
# 1. Lister les images
$ docker images
REPOSITORY    TAG       IMAGE ID       CREATED        SIZE
hello-world   latest    9c7a54a9a43c   7 months ago   13.3kB

# 2. Lister tous les conteneurs
$ docker ps -a
CONTAINER ID   IMAGE         COMMAND    CREATED          STATUS                      PORTS     NAMES
abc123def456   hello-world   "/hello"   2 minutes ago    Exited (0) 2 minutes ago              eager_tesla
def456abc789   hello-world   "/hello"   5 minutes ago    Exited (0) 5 minutes ago              amazing_curie

# 3. Utilisation des ressources
$ docker system df
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          1         0         13.3kB    13.3kB (100%)
Containers      2         0         0B        0B
Local Volumes   0         0         0B        0B
Build Cache     0         0         0B        0B

# 4. Lister les réseaux
$ docker network ls
NETWORK ID     NAME      DRIVER    SCOPE
abc123def456   bridge    bridge    local
def456abc789   host      host      local
789abc123def   none      null      local
```

### Réponses aux questions

**1. Combien d'images avez-vous localement ?**
- Réponse : 1 (hello-world)

**2. Combien de conteneurs (même arrêtés) existent ?**
- Réponse : 2 (un par exécution de `docker run`)
- Status : Exited (0) = terminé avec succès

**3. Combien d'espace disque Docker utilise-t-il ?**
- Réponse : ~13.3 kB pour l'image hello-world
- Très léger !

---

## Exercice 6 : Test avec une image interactive

### Commande et résultat attendu

```bash
$ docker run -it ubuntu bash

Unable to find image 'ubuntu:latest' locally
latest: Pulling from library/ubuntu
a48641193f3e: Pull complete
Digest: sha256:6042500cf4b44023ea1894effe7890666b0c5c7871ed83a97c36c76ae560bb9b
Status: Downloaded newer image for ubuntu:latest

# Vous êtes maintenant DANS le conteneur Ubuntu
root@5f8e9a7b1c2d:/#

# Exécutez les commandes demandées :
root@5f8e9a7b1c2d:/# cat /etc/os-release
NAME="Ubuntu"
VERSION="22.04.3 LTS (Jammy Jellyfish)"
ID=ubuntu
ID_LIKE=debian
PRETTY_NAME="Ubuntu 22.04.3 LTS"
VERSION_ID="22.04"
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"

root@5f8e9a7b1c2d:/# ls /
bin  boot  dev  etc  home  lib  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var

root@5f8e9a7b1c2d:/# whoami
root

root@5f8e9a7b1c2d:/# exit
exit

# Vous êtes de retour sur votre système hôte
$
```

### Réponses aux questions

**1. Dans quel système d'exploitation êtes-vous une fois dans le conteneur ?**

- **Ubuntu 22.04 LTS** (ou la dernière version)
- Même si votre hôte est Windows, macOS ou une autre distribution Linux
- C'est un Ubuntu "minimal" sans GUI

**2. Quelle est la taille de l'image Ubuntu téléchargée ?**

```bash
$ docker images ubuntu
REPOSITORY   TAG       IMAGE ID       CREATED       SIZE
ubuntu       latest    01f29b872827   3 weeks ago   77.8MB
```

- Environ **77-80 MB** pour Ubuntu (vs plusieurs GB pour une VM Ubuntu)
- Image optimisée sans GUI, sans outils superflus

**3. Que se passe-t-il quand vous tapez `exit` ?**

- Vous sortez du conteneur
- Le conteneur **s'arrête** (car le processus principal bash se termine)
- Vous revenez sur votre système hôte
- Le conteneur existe toujours (état "Exited") mais n'est plus en cours d'exécution

Vérification :
```bash
$ docker ps -a | grep ubuntu
5f8e9a7b1c2d   ubuntu   "bash"   3 minutes ago   Exited (0) 1 minute ago
```

---

## Exercice 7 : Nettoyage

### Commandes et résultats

```bash
# 1. Supprimer tous les conteneurs arrêtés
$ docker container prune
WARNING! This will remove all stopped containers.
Are you sure you want to continue? [y/N] y
Deleted Containers:
5f8e9a7b1c2d
abc123def456
def456abc789

Total reclaimed space: 84B

# 2. Vérifier qu'ils sont supprimés
$ docker ps -a
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
# Vide = tous les conteneurs arrêtés ont été supprimés

# 3. Supprimer l'image Ubuntu (optionnel)
$ docker rmi ubuntu
Untagged: ubuntu:latest
Untagged: ubuntu@sha256:6042500cf4b44023ea1894effe7890666b0c5c7871ed83a97c36c76ae560bb9b
Deleted: sha256:01f29b872827fa6f9aed0ea0b2ede53aea4ad9d66c7920e81a8db6d1fd9ab7f9
Deleted: sha256:b93c1bd012ab8fda60f5b4f5906bf244586e0e3292d84571d3abb56f10f6c2fd

# 4. Supprimer hello-world (optionnel)
$ docker rmi hello-world
Untagged: hello-world:latest
Untagged: hello-world@sha256:1408fec50309afee38f3535383f5b09419e6dc0925bc69891e79d84cc4cdcec6
Deleted: sha256:9c7a54a9a43cca047013b82af109fe963fde787f63f9e016fdc3384500c2823d
Deleted: sha256:01bb4fce3eb1b56b05adf99504dafd31907a5aadac736e36b27595c8b92f07f1

# 5. Vérifier le nettoyage
$ docker images
REPOSITORY   TAG       IMAGE ID   CREATED   SIZE
# Vide = toutes les images supprimées

$ docker system df
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          0         0         0B        0B
Containers      0         0         0B        0B
Local Volumes   0         0         0B        0B
Build Cache     0         0         0B        0B
```

### Comprendre les commandes de nettoyage

| Commande | Action | Quand l'utiliser |
|----------|--------|------------------|
| `docker container prune` | Supprime tous les conteneurs arrêtés | Libérer de l'espace régulièrement |
| `docker image prune` | Supprime les images non utilisées | Nettoyer les images obsolètes |
| `docker system prune` | Nettoie conteneurs, images, réseaux non utilisés | Grand nettoyage |
| `docker system prune -a` | Nettoie TOUT (même images utilisées) | ⚠️ Attention : très agressif |
| `docker rmi <image>` | Supprime une image spécifique | Supprimer une image précise |
| `docker rm <container>` | Supprime un conteneur spécifique | Supprimer un conteneur précis |

**Note** : On ne peut pas supprimer une image si un conteneur l'utilise (même arrêté). Il faut d'abord supprimer le conteneur.

---

## Dépannage - Solutions détaillées

### Linux : "permission denied"

**Problème** :
```bash
$ docker run hello-world
permission denied while trying to connect to the Docker daemon socket
```

**Solution** :
```bash
# Vérifier l'appartenance au groupe
$ groups
# Si "docker" n'apparaît pas :

sudo usermod -aG docker $USER

# CRITIQUE : Se déconnecter puis se reconnecter
# ou exécuter :
newgrp docker

# Vérifier à nouveau
$ groups
user adm docker sudo  # "docker" doit apparaître

# Tester
$ docker run hello-world
```

### Windows : "Hardware assisted virtualization is not enabled"

**Problème** : Hyper-V n'est pas activé ou la virtualisation est désactivée dans le BIOS.

**Solution** :

1. **Activer la virtualisation dans le BIOS** :
   - Redémarrer le PC
   - Appuyer sur F2, F10, Del ou Esc (selon le fabricant) au démarrage
   - Chercher "Virtualization Technology", "Intel VT-x", ou "AMD-V"
   - Activer et sauvegarder (F10)

2. **Activer Hyper-V dans Windows** :
```powershell
# Ouvrir PowerShell en tant qu'administrateur
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All

# Redémarrer
Restart-Computer
```

Ou via l'interface graphique :
- Panneau de configuration → Programmes → Activer ou désactiver des fonctionnalités Windows
- Cocher "Hyper-V" et "Conteneurs"
- Redémarrer

### macOS : "Docker.app can't be opened"

**Problème** : macOS bloque l'application non vérifiée.

**Solution** :
1. Préférences Système → Sécurité et confidentialité
2. En bas : "Docker.app a été bloquée"
3. Cliquer "Ouvrir quand même"
4. Confirmer

Alternative :
```bash
# Retirer la quarantaine
xattr -dr com.apple.quarantine /Applications/Docker.app
```

### Docker daemon ne démarre pas

**Linux** :
```bash
# Vérifier le statut
sudo systemctl status docker

# Si inactif, démarrer
sudo systemctl start docker

# Activer au démarrage
sudo systemctl enable docker

# Voir les logs
sudo journalctl -u docker -n 50
```

**Windows/Mac** :
- Fermer Docker Desktop complètement
- Redémarrer l'ordinateur
- Relancer Docker Desktop
- Vérifier les logs dans Settings → Troubleshoot → Show logs

### Erreur "Cannot connect to the Docker daemon"

**Toutes plateformes** :

```bash
# Vérifier que Docker tourne
docker info

# Si erreur, vérifier le daemon
# Linux :
sudo systemctl status docker

# Windows/Mac :
# Vérifier que Docker Desktop est lancé (icône dans la barre)
```

---

## Validation finale

✅ **Checklist de validation** :

- [ ] `docker --version` affiche la version
- [ ] `docker run hello-world` fonctionne sans erreur
- [ ] `docker ps` et `docker images` fonctionnent
- [ ] Aucune erreur "permission denied" (Linux)
- [ ] Docker Desktop lancé et icône verte (Windows/Mac)
- [ ] Compréhension des commandes de base

---

## Commandes récapitulatives

```bash
# Vérifications
docker --version                  # Version Docker
docker compose version            # Version Compose
docker info                       # Informations détaillées

# Images
docker images                     # Lister les images
docker pull <image>               # Télécharger une image
docker rmi <image>                # Supprimer une image

# Conteneurs
docker ps                         # Conteneurs en cours
docker ps -a                      # Tous les conteneurs
docker run <image>                # Créer et lancer un conteneur
docker run -it <image> bash       # Lancer en mode interactif
docker rm <container>             # Supprimer un conteneur

# Nettoyage
docker container prune            # Supprimer conteneurs arrêtés
docker image prune                # Supprimer images non utilisées
docker system prune               # Nettoyage global
docker system df                  # Espace utilisé

# Diagnostic
docker logs <container>           # Voir les logs
docker inspect <container/image>  # Inspecter
```

---

## Points clés à retenir

1. **Installation réussie** = `docker run hello-world` fonctionne
2. **Groupe docker** (Linux) nécessite une nouvelle session
3. **Docker Desktop** doit être lancé (Windows/Mac)
4. **Premier conteneur** télécharge l'image, les suivants sont instantanés
5. **Nettoyage régulier** évite l'accumulation de conteneurs/images

---

## Prochaines étapes

Maintenant que Docker est installé :
- ✅ Votre environnement est prêt
- → Module 2 : Découvrir les commandes Docker
- → Module 3 : Gérer images et conteneurs
- → Module 4 : Créer vos propres images

**Félicitations ! Vous avez installé Docker avec succès ! 🎉**

---

**[← Retour au TP2](../tp/TP2-Installation-Docker.md)**

**[→ Module suivant](../../module-02-presentation-docker/README.md)**
