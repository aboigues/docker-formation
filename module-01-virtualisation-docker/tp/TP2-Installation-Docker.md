# TP2 : Installation de Docker

## Objectif

Installer Docker sur votre système d'exploitation et valider l'installation.

## Durée estimée

40 minutes

## Prérequis

- Droits administrateur sur votre machine
- Connexion Internet stable
- Au moins 10 GB d'espace disque disponible

## Important : Instructions spécifiques par OS

Ce TP fonctionne sur Linux, Windows et Mac. Suivez les instructions correspondant à votre système.

---

## 📋 Exercice 1 : Vérification des prérequis

### Linux

```bash
# Vérifier la version du kernel (doit être >= 3.10)
uname -r

# Vérifier l'architecture (doit être 64-bit)
uname -m

# Vérifier l'espace disque disponible
df -h /var/lib
```

### Windows

- Version : Windows 10 64-bit: Pro, Enterprise, ou Education (Build 16299 ou plus récent)
- Hyper-V et conteneurs Windows activés
- Virtualisation activée dans le BIOS

```powershell
# Vérifier la version de Windows (PowerShell)
systeminfo | findstr /B /C:"OS Name" /C:"OS Version"

# Vérifier si la virtualisation est activée
Get-ComputerInfo -Property "HyperV*"
```

### macOS

- macOS 10.15 ou plus récent
- Mac hardware 2010 ou plus récent

```bash
# Vérifier la version de macOS
sw_vers

# Vérifier l'espace disque
df -h
```

---

## 📥 Exercice 2 : Installation de Docker

### Linux (Ubuntu/Debian)

```bash
# Mettre à jour les paquets
sudo apt-get update

# Installer les prérequis
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Ajouter la clé GPG officielle de Docker
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Configurer le dépôt
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Installer Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Ajouter votre utilisateur au groupe docker (évite d'utiliser sudo)
sudo usermod -aG docker $USER

# IMPORTANT: Redémarrez votre session pour appliquer les changements de groupe
```

### Windows

1. Télécharger **Docker Desktop for Windows** depuis : https://www.docker.com/products/docker-desktop
2. Double-cliquer sur l'installeur `Docker Desktop Installer.exe`
3. Suivre l'assistant d'installation
4. Redémarrer l'ordinateur si demandé
5. Lancer Docker Desktop depuis le menu Démarrer

### macOS

1. Télécharger **Docker Desktop for Mac** depuis : https://www.docker.com/products/docker-desktop
2. Double-cliquer sur `Docker.dmg`
3. Glisser l'icône Docker dans le dossier Applications
4. Lancer Docker depuis le dossier Applications
5. Autoriser Docker dans les préférences de sécurité si demandé

---

## ✅ Exercice 3 : Vérification de l'installation

### Pour tous les systèmes

```bash
# Vérifier la version de Docker
docker --version

# Vérifier la version de Docker Compose
docker compose version

# Afficher les informations système Docker
docker info

# Afficher les informations détaillées (optionnel)
docker system info
```

**Questions** :
1. Quelle version de Docker avez-vous installée ?
2. Combien de conteneurs sont actuellement en cours d'exécution ?
3. Quelle est la version du serveur Docker Engine ?

---

## 🚀 Exercice 4 : Premier conteneur

Exécutez votre premier conteneur Docker avec l'image "Hello World" :

```bash
# Lancer le conteneur hello-world
docker run hello-world
```

**Que devez-vous observer ?**

Un message qui commence par :
```
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

**Questions** :
1. Que fait la commande `docker run` ?
2. D'où provient l'image `hello-world` ?
3. Que se passe-t-il si vous exécutez la commande une deuxième fois ?

---

## 🔧 Exercice 5 : Commandes de diagnostic

Testez ces commandes pour vous familiariser :

```bash
# Lister les images téléchargées
docker images

# Lister tous les conteneurs (actifs et arrêtés)
docker ps -a

# Afficher l'utilisation des ressources
docker system df

# Lister les réseaux Docker
docker network ls
```

**Questions** :
1. Combien d'images avez-vous localement ?
2. Combien de conteneurs (même arrêtés) existent sur votre système ?
3. Combien d'espace disque Docker utilise-t-il actuellement ?

---

## 🧪 Exercice 6 : Test avec une image interactive

Exécutez un conteneur Ubuntu interactif :

```bash
# Lancer un conteneur Ubuntu en mode interactif
docker run -it ubuntu bash

# Une fois dans le conteneur, exécutez :
cat /etc/os-release
ls /
whoami
exit
```

**Questions** :
1. Dans quel système d'exploitation êtes-vous une fois dans le conteneur ?
2. Quelle est la taille de l'image Ubuntu téléchargée ?
3. Que se passe-t-il quand vous tapez `exit` ?

---

## 🎯 Exercice 7 : Nettoyage

Apprenez à nettoyer votre environnement Docker :

```bash
# Supprimer tous les conteneurs arrêtés
docker container prune

# Lister à nouveau les conteneurs
docker ps -a

# Supprimer l'image Ubuntu (optionnel)
docker rmi ubuntu

# Supprimer l'image hello-world (optionnel)
docker rmi hello-world
```

**Note** : Si vous obtenez une erreur lors de la suppression d'une image, c'est peut-être qu'un conteneur l'utilise encore.

---

## 🏆 Validation

À l'issue de ce TP, vous devez pouvoir :

- [ ] Docker est correctement installé sur mon système
- [ ] La commande `docker --version` fonctionne
- [ ] J'ai pu exécuter le conteneur `hello-world`
- [ ] J'ai compris les commandes de base : `docker run`, `docker ps`, `docker images`
- [ ] Je sais lister et supprimer des conteneurs et des images

---

## 🐛 Dépannage

### Linux : "permission denied" lors de l'exécution de Docker

```bash
# Vérifier que vous êtes dans le groupe docker
groups

# Si "docker" n'apparaît pas, réexécutez :
sudo usermod -aG docker $USER

# Puis déconnectez-vous et reconnectez-vous
```

### Windows : "Hardware assisted virtualization is not enabled"

- Redémarrer et entrer dans le BIOS (F2, F10, ou Del au démarrage)
- Chercher "Virtualization" ou "VT-x"
- L'activer et sauvegarder

### macOS : "Docker.app can't be opened"

- Aller dans Préférences Système > Sécurité et confidentialité
- Cliquer sur "Ouvrir quand même"

### Tous systèmes : Docker daemon ne démarre pas

```bash
# Vérifier le statut du service
# Linux :
sudo systemctl status docker

# Redémarrer le service
sudo systemctl restart docker

# Windows/Mac : Redémarrer Docker Desktop depuis l'interface
```

---

## 📚 Ressources complémentaires

- [Documentation officielle - Installation Linux](https://docs.docker.com/engine/install/)
- [Documentation officielle - Docker Desktop Windows](https://docs.docker.com/desktop/install/windows-install/)
- [Documentation officielle - Docker Desktop Mac](https://docs.docker.com/desktop/install/mac-install/)
- [Post-installation steps for Linux](https://docs.docker.com/engine/install/linux-postinstall/)

---

**[→ Voir les solutions](../solutions/TP2-Solution.md)**

**[→ Module suivant : Présentation de Docker](../../module-02-presentation-docker/tp/TP3-Commandes-Base.md)**
