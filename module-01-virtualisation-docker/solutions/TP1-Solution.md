# Solution TP1 : Comparaison VM vs Conteneur

## Exercice 1 : Analyse théorique

### 1. Quelle est la principale différence d'architecture entre une VM et un conteneur ?

**Réponse :**

- **Machine Virtuelle** : Virtualise le matériel complet. Chaque VM inclut un système d'exploitation invité complet avec son propre noyau (kernel), bibliothèques et applications. L'hyperviseur gère les VMs.

- **Conteneur Docker** : Virtualise au niveau du système d'exploitation. Les conteneurs partagent le noyau du système hôte et isolent uniquement les processus et ressources au niveau applicatif. Le Docker Engine gère les conteneurs.

**Schéma simplifié :**

```
MACHINE VIRTUELLE                    CONTENEUR DOCKER
┌─────────────────────┐             ┌─────────────────────┐
│   Application A     │             │   Application A     │
│   ───────────────   │             │   ───────────────   │
│   Bibliothèques     │             │   Bibliothèques     │
│   ───────────────   │             └─────────────────────┘
│   OS Invité (Linux) │             ┌─────────────────────┐
└─────────────────────┘             │   Application B     │
┌─────────────────────┐             │   ───────────────   │
│   Application B     │             │   Bibliothèques     │
│   ───────────────   │             └─────────────────────┘
│   Bibliothèques     │             ┌─────────────────────┐
│   ───────────────   │             │   Docker Engine     │
│   OS Invité (Win)   │             └─────────────────────┘
└─────────────────────┘             ┌─────────────────────┐
┌─────────────────────┐             │   OS Hôte (Linux)   │
│    Hyperviseur      │             └─────────────────────┘
└─────────────────────┘             ┌─────────────────────┐
┌─────────────────────┐             │     Serveur         │
│   OS Hôte           │             └─────────────────────┘
└─────────────────────┘
┌─────────────────────┐
│     Serveur         │
└─────────────────────┘
```

### 2. Quels sont les avantages des conteneurs par rapport aux VMs ?

**Réponses :**

1. **Démarrage ultra-rapide** : Quelques secondes vs plusieurs minutes pour une VM
2. **Léger** : Quelques MB vs plusieurs GB pour une VM
3. **Performance** : Presque native (pas de surcharge d'hyperviseur)
4. **Densité** : On peut exécuter beaucoup plus de conteneurs que de VMs sur le même matériel
5. **Portabilité** : "Build once, run anywhere" - l'image contient toutes les dépendances
6. **Consommation de ressources** : Utilise moins de RAM et CPU
7. **Facilité de distribution** : Images versionnées, Docker Hub, registres
8. **Intégration CI/CD** : Idéal pour les pipelines DevOps
9. **Immutabilité** : Les images sont immuables, favorise l'infrastructure as code

### 3. Quels sont les cas d'usage où une VM reste préférable ?

**Réponses :**

1. **Isolation de sécurité maximale** : Pour des environnements multi-tenants critiques où l'isolation doit être totale
2. **Systèmes d'exploitation différents** : Exécuter Windows sur un hôte Linux (ou vice-versa) nécessite une VM
3. **Applications nécessitant leur propre kernel** : Applications avec modules kernel spécifiques
4. **Applications monolithiques legacy** : Applications anciennes difficiles à conteneuriser
5. **Environnements GUI complexes** : Applications avec interfaces graphiques lourdes
6. **Tests de systèmes d'exploitation** : Tester différentes distributions ou versions d'OS
7. **Conformité réglementaire** : Certaines normes imposent l'isolation par VM
8. **Accès matériel direct** : Certains cas nécessitent un accès matériel spécifique

### 4. Qu'est-ce qu'un hyperviseur et a-t-on besoin d'un hyperviseur pour Docker ?

**Réponse :**

**Hyperviseur** : Logiciel qui crée et gère des machines virtuelles. Il alloue les ressources matérielles (CPU, RAM, disque) à chaque VM.

Types d'hyperviseurs :
- **Type 1 (bare-metal)** : S'exécute directement sur le matériel (VMware ESXi, Hyper-V, Xen)
- **Type 2 (hosted)** : S'exécute sur un OS hôte (VirtualBox, VMware Workstation)

**Docker a-t-il besoin d'un hyperviseur ?**

- **Sur Linux : NON** - Docker utilise directement les fonctionnalités du noyau Linux (namespaces, cgroups)
- **Sur Windows : OUI** (pour Linux containers) - Docker Desktop utilise WSL2 (Windows Subsystem for Linux) ou Hyper-V
- **Sur macOS : OUI** - Docker Desktop utilise une VM légère (HyperKit/QEMU) car macOS n'a pas de noyau Linux natif

### 5. Combien de temps faut-il généralement pour démarrer une VM ? Et un conteneur ?

**Réponse :**

- **Machine Virtuelle** :
  - 30 secondes à 2 minutes (selon l'OS et les ressources)
  - Inclut le boot complet de l'OS invité

- **Conteneur Docker** :
  - 1 à 5 secondes en moyenne
  - Presque instantané pour des conteneurs simples
  - C'est simplement le lancement d'un processus isolé

**Exemple concret** :
```bash
# Démarrage d'un conteneur nginx
time docker run -d nginx
# Résultat typique : 2-3 secondes (incluant le téléchargement si première fois)

# Démarrage d'un conteneur déjà téléchargé
time docker run -d nginx
# Résultat typique : < 1 seconde
```

---

## Exercice 2 : Comparaison de ressources

| Critère | Machine Virtuelle | Conteneur Docker |
|---------|-------------------|------------------|
| **Temps de démarrage** | 30s - 2 min | 1 - 5s |
| **Taille sur disque** | 1 GB - 100+ GB | 10 MB - 1 GB |
| **Isolation** | Forte (kernel séparé) | Modérée (kernel partagé) |
| **Performance** | Bonne (overhead hyperviseur ~5-10%) | Excellente (quasi-native) |
| **Portabilité** | Moyenne (images volumineuses, formats propriétaires) | Excellente (images légères, standards) |
| **Consommation RAM** | 512 MB - 8+ GB par VM | 5 MB - 500 MB par conteneur |
| **Densité** | 5-20 VMs par serveur | 100-1000+ conteneurs par serveur |
| **Déploiement** | Minutes | Secondes |
| **Immutabilité** | Faible (état modifiable) | Forte (images immuables) |

---

## Exercice 3 : Schématisation

### 1. Architecture d'un serveur avec 3 VMs

```
┌───────────────────────────────────────────────────────────────────┐
│                         SERVEUR PHYSIQUE                          │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                        HARDWARE                              │ │
│  │         CPU (8 cores) | RAM (64 GB) | DISK (1 TB)           │ │
│  └─────────────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                   OS HÔTE (ex: Ubuntu Server)                │ │
│  └─────────────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              HYPERVISEUR (ex: VMware, KVM)                   │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌─────────────┐      ┌─────────────┐      ┌─────────────┐     │
│  │   VM 1      │      │   VM 2      │      │   VM 3      │     │
│  │             │      │             │      │             │     │
│  │ App Web     │      │ App DB      │      │ App API     │     │
│  │ ─────────── │      │ ─────────── │      │ ─────────── │     │
│  │ Nginx       │      │ PostgreSQL  │      │ Node.js     │     │
│  │ ─────────── │      │ ─────────── │      │ ─────────── │     │
│  │ Libs        │      │ Libs        │      │ Libs        │     │
│  │ ─────────── │      │ ─────────── │      │ ─────────── │     │
│  │ Ubuntu      │      │ CentOS      │      │ Debian      │     │
│  │ (Kernel)    │      │ (Kernel)    │      │ (Kernel)    │     │
│  │             │      │             │      │             │     │
│  │ RAM: 4 GB   │      │ RAM: 8 GB   │      │ RAM: 4 GB   │     │
│  │ Disk: 20 GB │      │ Disk: 50 GB │      │ Disk: 20 GB │     │
│  └─────────────┘      └─────────────┘      └─────────────┘     │
│                                                                   │
│  Total utilisé: 16 GB RAM, 90 GB Disk                           │
└───────────────────────────────────────────────────────────────────┘
```

### 2. Architecture d'un serveur avec 3 conteneurs Docker

```
┌───────────────────────────────────────────────────────────────────┐
│                         SERVEUR PHYSIQUE                          │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                        HARDWARE                              │ │
│  │         CPU (8 cores) | RAM (64 GB) | DISK (1 TB)           │ │
│  └─────────────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │               OS HÔTE (ex: Ubuntu Server)                    │ │
│  │                     KERNEL LINUX                             │ │
│  └─────────────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    DOCKER ENGINE                             │ │
│  │         (containerd, runc, namespaces, cgroups)              │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌─────────────┐      ┌─────────────┐      ┌─────────────┐     │
│  │ Conteneur 1 │      │ Conteneur 2 │      │ Conteneur 3 │     │
│  │             │      │             │      │             │     │
│  │ App Web     │      │ App DB      │      │ App API     │     │
│  │ ─────────── │      │ ─────────── │      │ ─────────── │     │
│  │ Nginx       │      │ PostgreSQL  │      │ Node.js     │     │
│  │ ─────────── │      │ ─────────── │      │ ─────────── │     │
│  │ Libs        │      │ Libs        │      │ Libs        │     │
│  │             │      │             │      │             │     │
│  │ RAM: 100 MB │      │ RAM: 500 MB │      │ RAM: 200 MB │     │
│  │ Disk: 150 MB│      │ Disk: 300 MB│      │ Disk: 200 MB│     │
│  └─────────────┘      └─────────────┘      └─────────────┘     │
│                                                                   │
│  Total utilisé: 800 MB RAM, 650 MB Disk                         │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Kernel partagé - Namespaces pour isolation des processus│   │
│  └──────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────┘
```

### Composants identifiés :

**Architecture VM :**
- Hardware (serveur physique)
- OS Hôte (système d'exploitation du serveur)
- Hyperviseur (VMware, KVM, VirtualBox, etc.)
- OS Invités (un kernel complet par VM)
- Applications dans chaque VM

**Architecture Conteneur :**
- Hardware (serveur physique)
- OS Hôte avec Kernel Linux (partagé par tous les conteneurs)
- Docker Engine (daemon Docker, containerd, runc)
- Applications dans chaque conteneur (avec leurs bibliothèques)
- Pas d'OS invité complet

---

## Questions de réflexion

### 1. Pourquoi Docker ne remplace-t-il pas complètement les VMs ?

**Réponse :**

Docker et les VMs sont complémentaires, pas concurrents :

- **Isolation de sécurité** : VMs offrent une meilleure isolation (kernel séparé)
- **Multi-OS** : Impossible de faire tourner Windows sur un hôte Linux avec des conteneurs natifs
- **Applications legacy** : Certaines applications ne peuvent pas être conteneurisées
- **Réglementation** : Certaines normes imposent des VMs
- **Combinaison** : On peut exécuter Docker DANS des VMs pour combiner les avantages

**Cas d'usage courant** : VMs pour isoler les clients/projets, conteneurs pour les microservices au sein de chaque VM.

### 2. Peut-on faire cohabiter VMs et conteneurs sur un même serveur ?

**Réponse : OUI, absolument !**

**Scénarios courants** :

1. **Conteneurs dans des VMs** :
   - VM 1 : Projet client A avec ses conteneurs Docker
   - VM 2 : Projet client B avec ses conteneurs Docker
   - Avantage : Isolation forte entre clients + agilité des conteneurs

2. **Conteneurs et VMs en parallèle** :
   - Conteneurs Docker sur l'hôte pour les apps modernes
   - VMs pour les applications legacy
   - Utilisation de Kubernetes avec des VMs comme nodes

3. **Cloud providers** :
   - AWS ECS : Conteneurs tournant sur des VMs EC2
   - AWS Fargate : Conteneurs "serverless" (VMs gérées par AWS)

### 3. En quoi la conteneurisation facilite-t-elle le DevOps ?

**Réponse :**

La conteneurisation est un pilier du DevOps :

1. **"Works on my machine" → résolu** :
   - L'image contient TOUTES les dépendances
   - Identique du dev à la production

2. **CI/CD simplifié** :
   - Build une image une fois
   - Deploy partout (dev, staging, prod)
   - Rollback facile (revenir à une image précédente)

3. **Infrastructure as Code** :
   - Dockerfile = recette reproductible
   - docker-compose.yml = orchestration versionnée
   - Pas de "configuration manuelle"

4. **Microservices** :
   - Chaque service dans son conteneur
   - Scalabilité indépendante
   - Déploiement indépendant

5. **Environnements cohérents** :
   - Même conteneur en dev et prod
   - Réduit les "ça marche pas en prod"

6. **Rapidité** :
   - Déploiement en secondes
   - Tests parallélisés
   - Feedback rapide

7. **Collaboration Dev/Ops** :
   - Langage commun (images, conteneurs)
   - Responsabilités claires
   - Autonomie des équipes

**Exemple workflow DevOps avec Docker** :
```
Developer → git push → CI builds Docker image → Tests →
Push to registry → CD pulls image → Deploy to production
```

---

## Conclusion

Les conteneurs Docker ne remplacent pas les VMs mais les complètent. La compréhension de leurs différences permet de choisir la bonne technologie selon le contexte :

- **Conteneurs** : Microservices, CI/CD, applications cloud-native
- **VMs** : Isolation forte, multi-OS, applications legacy
- **Les deux** : Architecture hybride pour le meilleur des deux mondes

**Principe clé** : "Use the right tool for the job"

---

**[← Retour au TP1](../tp/TP1-VM-vs-Conteneur.md)**
