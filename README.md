# Formation Docker - Guide pratique complet

Formation progressive pour apprendre Docker de A à Z, avec des TPs pratiques et des solutions détaillées.

## 🎯 Objectifs de la formation

À l'issue de cette formation, vous serez capable de :
- Comprendre les concepts de conteneurisation
- Maîtriser Docker en ligne de commande
- Créer vos propres images Docker
- Orchestrer des applications multi-conteneurs
- Administrer Docker en production
- Utiliser les outils d'orchestration (Swarm, Kubernetes)

## 👥 Public cible

- Développeurs souhaitant conteneuriser leurs applications
- Administrateurs systèmes et DevOps
- Architectes techniques
- Toute personne souhaitant apprendre Docker

## 📜 Histoire de la Conteneurisation

Découvrez l'histoire fascinante de la conteneurisation, de **chroot en 1979** à l'écosystème Docker de 2025 :

👉 **[Lire l'histoire complète de la conteneurisation et de Docker](./HISTOIRE-CONTENEURISATION.md)**

**Points clés** :
- 🕰️ Les origines : chroot (1979), FreeBSD jails (2000)
- 🔧 Les fondations : cgroups et namespaces (2006-2008), LXC (2008)
- 🐳 L'ère Docker : lancement en 2013, Docker 1.0 en 2014
- 🚀 L'évolution : de 465M$ en 2020 à 944M$ en 2024
- 🌟 2025 : 92% d'adoption IT, innovations AI/ML, sécurité renforcée

## 📋 Prérequis

- Connaissances de base en ligne de commande Linux/Windows
- Notions de développement (recommandé)
- Un ordinateur avec :
  - **Linux** : Ubuntu 20.04+ ou équivalent
  - **Windows** : Windows 10/11 Pro ou supérieur
  - **macOS** : 10.15 ou supérieur
  - Au moins 8 GB de RAM et 20 GB d'espace disque

## 📚 Structure de la formation

### [Module 1 : De la virtualisation à Docker](./module-01-virtualisation-docker/)
**Durée : 1h**

Comprendre les différences entre virtualisation et conteneurisation, installer Docker.

- **TP1** : Comparaison VM vs Conteneur
- **TP2** : Installation de Docker (Linux/Windows/Mac)

**Compétences acquises** :
- ✅ Différences VM/Conteneurs
- ✅ Installation Docker multi-plateformes
- ✅ Premier conteneur

---

### [Module 2 : Présentation de Docker](./module-02-presentation-docker/)
**Durée : 1h30**

Maîtriser les commandes Docker essentielles et comprendre l'architecture.

- **TP3** : Commandes de base Docker
- **TP4** : Inspection et diagnostic

**Compétences acquises** :
- ✅ Gestion des images et conteneurs
- ✅ Debugging et logs
- ✅ Monitoring des ressources

---

### [Module 3 : Mise en œuvre en ligne de commande](./module-03-ligne-commande/)
**Durée : 2h**

Approfondir la maîtrise de Docker : volumes, réseaux, registres.

- **TP5** : Volumes et persistance des données
- **TP6** : Réseaux Docker
- **TP7** : Gestion avancée des images

**Compétences acquises** :
- ✅ Persistance avec volumes
- ✅ Réseaux personnalisés
- ✅ Registres privés

---

### [Module 4 : Création de conteneur personnalisé](./module-04-conteneur-personnalise/)
**Durée : 2h30**

Créer vos propres images avec Dockerfile, optimiser et sécuriser.

- **TP8** : Dockerfile fondamentaux
- **TP9** : Optimisation des images
- **TP10** : Multi-stage builds

**Compétences acquises** :
- ✅ Écriture de Dockerfile
- ✅ Best practices et optimisation
- ✅ Builds multi-étapes

---

### [Module 5 : Mettre en œuvre une application multiconteneur](./module-05-multiconteneur/)
**Durée : 2h30**

Orchestrer plusieurs conteneurs avec Docker Compose.

- **TP11** : Docker Compose fondamentaux
- **TP12** : Applications complètes (MERN, ELK, monitoring)

**Compétences acquises** :
- ✅ Docker Compose
- ✅ Architectures multi-tiers
- ✅ Gestion des dépendances

---

### [Module 6 : Interfaces d'administration](./module-06-interfaces-administration/)
**Durée : 1h30**

Utiliser des interfaces graphiques et outils de monitoring.

- **TP13** : Portainer, Prometheus, Grafana

**Compétences acquises** :
- ✅ Portainer pour la gestion graphique
- ✅ Monitoring avec Prometheus/Grafana
- ✅ Visualisation des logs

---

### [Module 7 : Administrer des conteneurs en production](./module-07-production/)
**Durée : 4h**

Bonnes pratiques pour la production : sécurité, logging, healthchecks et observabilité avec OpenTelemetry.

- **TP14** : Production best practices
- **TP14b** : Centralisation avec OpenTelemetry

**Compétences acquises** :
- ✅ Healthchecks et restart policies
- ✅ Sécurité Docker
- ✅ Logging centralisé
- ✅ Backup et recovery
- ✅ OpenTelemetry (traces, métriques, logs)
- ✅ Observabilité distribuée (Jaeger, Prometheus, Grafana)

---

### [Module 8 : Orchestration et clustérisation](./module-08-orchestration/)
**Durée : 3h**

Introduction à Docker Swarm et Kubernetes.

- **TP16** : Docker Swarm et Kubernetes

**Compétences acquises** :
- ✅ Docker Swarm
- ✅ Kubernetes basics
- ✅ Services et scaling
- ✅ Rolling updates

---

## ⏱️ Durée totale

**18 heures** de formation pratique (environ 2,5 jours)

## 🚀 Comment utiliser cette formation

### Mode auto-formation

1. **Suivez les modules dans l'ordre** - Ils sont progressifs
2. **Faites tous les exercices** - La pratique est essentielle
3. **Ne regardez les solutions qu'après avoir essayé** - L'apprentissage par l'erreur est le plus efficace
4. **Testez sur votre environnement** - Adaptez aux spécificités de votre système

### Mode formateur

1. **Présentez la théorie** - Supports disponibles dans chaque module
2. **Laissez les participants pratiquer** - TPs en autonomie
3. **Corrigez collectivement** - Utilisez les solutions fournies
4. **Encouragez les questions** - Les TPs contiennent des questions de réflexion

## 📁 Structure des dossiers

```
docker-formation/
├── README.md (ce fichier)
├── module-01-virtualisation-docker/
│   ├── README.md
│   ├── tp/
│   │   ├── TP1-VM-vs-Conteneur.md
│   │   └── TP2-Installation-Docker.md
│   ├── solutions/
│   │   ├── TP1-Solution.md
│   │   └── TP2-Solution.md
│   └── ressources/
├── module-02-presentation-docker/
│   ├── README.md
│   ├── tp/
│   ├── solutions/
│   └── ressources/
├── ... (modules 3 à 8 suivent la même structure)
└── GUIDE-DEMARRAGE.md
```

## 🛠️ Installation et préparation

### Linux (Ubuntu/Debian)

```bash
# Cloner le dépôt
git clone <repository-url>
cd docker-formation

# Installer Docker (voir Module 1, TP2 pour les détails)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
# Se déconnecter et se reconnecter

# Vérifier l'installation
docker --version
docker compose version
```

### Windows

1. Installer **Docker Desktop for Windows**
2. Activer WSL2 (recommandé)
3. Redémarrer
4. Cloner le dépôt avec Git Bash ou PowerShell
5. Vérifier : `docker --version`

### macOS

1. Installer **Docker Desktop for Mac**
2. Lancer Docker Desktop
3. Cloner le dépôt
4. Vérifier : `docker --version`

## 📖 Ressources complémentaires

### Documentation officielle
- [Docker Documentation](https://docs.docker.com/)
- [Docker Hub](https://hub.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

### Outils recommandés
- **VSCode** avec extension Docker
- **Portainer** pour l'interface graphique
- **Lens** pour Kubernetes (module 8)

### Communauté
- [Docker Forums](https://forums.docker.com/)
- [Stack Overflow - Docker Tag](https://stackoverflow.com/questions/tagged/docker)
- [Reddit r/docker](https://www.reddit.com/r/docker/)

## ✅ Validation des compétences

### Module 1-2 : Fondamentaux
- [ ] Docker installé et fonctionnel
- [ ] Capable de lancer et gérer des conteneurs basiques
- [ ] Compréhension de l'architecture Docker

### Module 3-4 : Intermédiaire
- [ ] Maîtrise des volumes et réseaux
- [ ] Capable d'écrire des Dockerfiles
- [ ] Optimisation des images

### Module 5-6 : Avancé
- [ ] Orchestration avec Docker Compose
- [ ] Utilisation d'interfaces de monitoring
- [ ] Déploiement d'applications multi-conteneurs

### Module 7-8 : Expert
- [ ] Bonnes pratiques production
- [ ] Sécurité Docker
- [ ] Introduction à l'orchestration (Swarm/K8s)

## 🎓 Certification

Après avoir complété tous les modules, vous devriez être capable de :
- Passer la certification **Docker Certified Associate (DCA)**
- Mettre en œuvre Docker en environnement professionnel
- Conseiller sur l'architecture Docker

## 🐛 Problèmes courants

### "Permission denied" (Linux)
```bash
sudo usermod -aG docker $USER
# Puis se déconnecter/reconnecter
```

### "Docker daemon not running" (Windows/Mac)
- Vérifier que Docker Desktop est lancé
- Icône dans la barre des tâches doit être verte

### "Cannot connect to Docker daemon"
```bash
# Linux
sudo systemctl start docker

# Windows/Mac
# Redémarrer Docker Desktop
```

### Port déjà utilisé
```bash
# Trouver le processus
sudo lsof -i :8080
# ou
docker ps | grep 8080

# Changer le port dans la commande
docker run -p 8081:80 nginx  # Au lieu de 8080
```

## 📝 Conseils pédagogiques

### Pour les apprenants
1. **Pratiquez régulièrement** - 30 minutes par jour vaut mieux que 3h une fois
2. **Expérimentez** - N'ayez pas peur de casser (c'est l'intérêt des conteneurs !)
3. **Lisez les erreurs** - Les messages d'erreur Docker sont souvent très explicites
4. **Nettoyez régulièrement** - `docker system prune` pour éviter de remplir le disque
5. **Documentez vos apprentissages** - Créez votre propre cheat sheet

### Pour les formateurs
1. **Vérifiez l'installation avant** - Faites installer Docker la veille si possible
2. **Prévoyez du temps de debug** - Problèmes réseau, proxy, etc.
3. **Adaptez le rythme** - Certains modules peuvent être plus longs selon le public
4. **Encouragez l'entraide** - Le pair-programming fonctionne bien avec Docker
5. **Utilisez des exemples concrets** - Liez aux projets de l'entreprise si possible

## 🔄 Mises à jour

Cette formation est régulièrement mise à jour pour refléter :
- Les nouvelles versions de Docker
- Les meilleures pratiques évolutives
- Les retours des participants

**Dernière mise à jour** : Décembre 2025

## 📞 Support

Pour toute question ou problème :
1. Consultez les solutions des TPs
2. Vérifiez les issues GitHub
3. Consultez la documentation officielle Docker

## 📜 Licence

Ce matériel de formation est fourni à des fins éducatives.

## 🙏 Remerciements

Cette formation a été conçue pour permettre un apprentissage progressif et autonome de Docker, de l'installation à l'orchestration en production.

---

## 🚀 Commencer maintenant

**Prêt à démarrer ?**

👉 [Commencez par le Module 1](./module-01-virtualisation-docker/README.md)

ou

👉 [Consultez le guide de démarrage rapide](./GUIDE-DEMARRAGE.md)

---

**Bonne formation ! 🐳**
