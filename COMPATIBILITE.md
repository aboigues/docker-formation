# Guide de compatibilité multi-plateforme

Ce document détaille les spécificités de Docker sur différents systèmes d'exploitation.

## Compatibilité des TPs

| TP | Linux | Windows | macOS | Notes |
|----|-------|---------|-------|-------|
| TP1 | ✅ | ✅ | ✅ | Théorique |
| TP2 | ✅ | ✅ | ✅ | Installation spécifique par OS |
| TP3 | ✅ | ✅ | ✅ | Commandes identiques |
| TP4 | ✅ | ✅ | ✅ | Commandes identiques |
| TP5 | ✅ | ✅ | ✅ | Chemins différents pour volumes |
| TP6 | ✅ | ⚠️ | ⚠️ | Réseau host non disponible Win/Mac |
| TP7 | ✅ | ✅ | ✅ | Commandes identiques |
| TP8 | ✅ | ✅ | ✅ | Dockerfile identique |
| TP9 | ✅ | ✅ | ✅ | Dockerfile identique |
| TP10 | ✅ | ✅ | ✅ | Multi-stage identique |
| TP11 | ✅ | ✅ | ✅ | Docker Compose identique |
| TP12 | ✅ | ✅ | ✅ | Docker Compose identique |
| TP13 | ✅ | ✅ | ✅ | Interfaces web identiques |
| TP14 | ✅ | ⚠️ | ⚠️ | Quelques différences de sécurité |
| TP15 | ✅ | ⚠️ | ⚠️ | Swarm limité Win/Mac, K8s OK |

**Légende** :
- ✅ Totalement compatible
- ⚠️ Compatible avec adaptations mineures
- ❌ Non compatible (aucun cas dans cette formation)

## Différences par système d'exploitation

### Linux (Ubuntu, Debian, CentOS, etc.)

#### Avantages
- Docker natif (pas de VM intermédiaire)
- Performances maximales
- Toutes les fonctionnalités disponibles
- Réseau host fonctionnel
- Contrôle total sur le daemon

#### Spécificités
```bash
# Gestion du daemon
sudo systemctl start docker
sudo systemctl stop docker
sudo systemctl status docker

# Logs Docker
sudo journalctl -u docker

# Localisation des volumes
/var/lib/docker/volumes/

# Permissions
sudo usermod -aG docker $USER
```

---

### Windows 10/11 Pro

#### Prérequis
- Windows 10/11 Pro, Enterprise ou Education
- Build 16299 ou supérieur
- Hyper-V activé ou WSL2

#### Avantages
- Docker Desktop avec interface graphique
- WSL2 pour meilleures performances
- Intégration PowerShell

#### Limitations
- Réseau `host` non disponible (utiliser `bridge`)
- Conteneurs Linux via WSL2 ou Hyper-V
- Performance légèrement réduite (VM)

#### Spécificités

**Chemins de fichiers** :
```powershell
# Windows utilise \ au lieu de /
# Dans docker-compose.yml, utiliser / même sous Windows

# Volume Windows → Conteneur
docker run -v C:/Users/moi/data:/data nginx

# Format WSL2
docker run -v /c/Users/moi/data:/data nginx
```

**Réseau** :
```powershell
# Host network ne fonctionne pas
# Utiliser bridge avec port mapping
docker run -p 8080:80 nginx  # ✅ OK
docker run --network host nginx  # ❌ Ne fonctionne pas
```

**Commandes** :
```powershell
# PowerShell
docker ps
Get-Process | Select-String docker

# CMD
docker ps
tasklist | findstr docker
```

**Docker Desktop** :
- Paramètres → Resources → Allouer CPU/RAM
- Partage de disques pour volumes
- WSL2 backend recommandé

---

### macOS

#### Prérequis
- macOS 10.15 (Catalina) ou supérieur
- Mac 2010 ou plus récent
- Virtualisation activée

#### Avantages
- Docker Desktop avec interface graphique
- Intégration Terminal
- Performances correctes

#### Limitations
- Réseau `host` non disponible
- Docker tourne dans une VM (HyperKit/QEMU)
- Pas d'accès direct au daemon

#### Spécificités

**Chemins** :
```bash
# Volumes macOS → Conteneur
docker run -v /Users/moi/data:/data nginx

# Docker Desktop monte automatiquement /Users
```

**Réseau** :
```bash
# Host network ne fonctionne pas
docker run -p 8080:80 nginx  # ✅ OK
docker run --network host nginx  # ❌ Ne fonctionne pas
```

**Docker Desktop** :
- Preferences → Resources → Allouer CPU/RAM
- File Sharing : /Users, /tmp, /private automatiques

---

## Adaptations par TP

### TP5 - Volumes

**Linux** :
```bash
docker run -v /home/user/data:/data nginx
```

**Windows (PowerShell)** :
```powershell
docker run -v C:/Users/User/data:/data nginx
# ou avec WSL2
docker run -v /c/Users/User/data:/data nginx
```

**macOS** :
```bash
docker run -v /Users/user/data:/data nginx
```

### TP6 - Réseaux

**Réseau host** :

**Linux** :
```bash
docker run --network host nginx  # ✅ Fonctionne
```

**Windows/macOS** :
```bash
# Utiliser port mapping à la place
docker run -p 80:80 nginx  # ✅ Alternative
```

### TP14 - Production

**Apparmor/SELinux** (Linux uniquement) :
```bash
# Linux avec Apparmor
docker run --security-opt apparmor=docker-default nginx

# Windows/macOS : Ignorer ces options
```

### TP15 - Orchestration

**Docker Swarm** :
- Linux : Totalement fonctionnel
- Windows/Mac Desktop : Mode Swarm disponible mais limité
- Production : Utiliser Linux

**Kubernetes** :
- Tous systèmes : kubectl fonctionne identiquement
- Docker Desktop : Kubernetes intégré
- Linux : Minikube ou k3s recommandé

---

## Scripts multi-plateformes

### Script shell compatible

```bash
#!/bin/bash

# Détecter l'OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    VOLUME_PATH="/home/$USER/data"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    VOLUME_PATH="/Users/$USER/data"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    OS="windows"
    VOLUME_PATH="/c/Users/$USER/data"
fi

echo "OS détecté: $OS"
docker run -v $VOLUME_PATH:/data nginx
```

### PowerShell (Windows)

```powershell
# Script équivalent PowerShell
$volumePath = "C:\Users\$env:USERNAME\data"
docker run -v ${volumePath}:/data nginx
```

---

## Performances comparées

| Critère | Linux | Windows (WSL2) | macOS |
|---------|-------|----------------|-------|
| Performances CPU | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| I/O disque | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| Réseau | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Volumes | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |

**Recommandation** : Pour la production, Linux est fortement recommandé.

---

## Commandes équivalentes

### Processus

**Linux** :
```bash
ps aux | grep docker
sudo systemctl status docker
```

**Windows (PowerShell)** :
```powershell
Get-Process | Where-Object {$_.Name -like "*docker*"}
Get-Service docker
```

**macOS** :
```bash
ps aux | grep docker
# Docker Desktop gère le daemon automatiquement
```

### Réseau

**Linux** :
```bash
ip addr show
netstat -tlnp
ss -tlnp
```

**Windows (PowerShell)** :
```powershell
ipconfig
netstat -an | findstr LISTENING
```

**macOS** :
```bash
ifconfig
netstat -an | grep LISTEN
lsof -i -P | grep LISTEN
```

---

## Recommandations par cas d'usage

### Développement local
- **Tous systèmes** : Docker Desktop fonctionne bien
- Préférer WSL2 sous Windows pour meilleures performances

### Tests et CI/CD
- **Linux** recommandé (GitLab CI, GitHub Actions, Jenkins)

### Production
- **Linux uniquement** (Ubuntu Server, RHEL, CentOS)
- Pas de Docker Desktop en production

### Apprentissage
- **Tous systèmes** : Cette formation est compatible avec tous

---

## Checklist de vérification

### Avant de commencer un TP

- [ ] Docker est installé : `docker --version`
- [ ] Docker fonctionne : `docker run hello-world`
- [ ] Docker Compose disponible : `docker compose version`
- [ ] Permissions OK (Linux) : pas besoin de `sudo`
- [ ] Espace disque suffisant : au moins 10 GB libres

### Spécifique Windows

- [ ] Docker Desktop lancé (icône verte)
- [ ] WSL2 activé (recommandé)
- [ ] Partage de disques configuré

### Spécifique Linux

- [ ] Utilisateur dans le groupe docker
- [ ] Service docker démarré : `systemctl status docker`

### Spécifique macOS

- [ ] Docker Desktop lancé
- [ ] File Sharing configuré dans Preferences

---

## Dépannage par plateforme

### Linux
```bash
# Daemon ne démarre pas
sudo systemctl restart docker
sudo journalctl -u docker --no-pager | tail -20

# Problème de permissions
sudo usermod -aG docker $USER
# Se déconnecter/reconnecter
```

### Windows
```powershell
# Redémarrer Docker Desktop
# Ouvrir Docker Desktop → Troubleshoot → Restart Docker

# Vérifier WSL2
wsl --list --verbose

# Réinstaller Docker Desktop si problème persistant
```

### macOS
```bash
# Redémarrer Docker Desktop
# Docker Desktop → Troubleshoot → Restart

# Réinitialiser si nécessaire
# Docker Desktop → Troubleshoot → Reset to factory defaults
```

---

## Conclusion

Cette formation Docker est conçue pour fonctionner sur **Linux, Windows et macOS**.

**Différences mineures** :
- Chemins de fichiers (volumes)
- Réseau host (Linux uniquement)
- Quelques commandes système

**99% des TPs sont identiques** sur toutes les plateformes.

Pour toute question de compatibilité, consultez :
- Les solutions des TPs (adaptations mentionnées)
- La documentation officielle Docker
- Ce guide de compatibilité

---

**La formation est prête pour tous les systèmes ! 🚀**
