# TP13 — Monter sa chaîne d'intégration (CI) : Jenkins conteneurisé

> Durée estimée : 1 h 15 · Ports utilisés : `8080` (Jenkins), `5000` (registre privé)
> Prérequis : TP4-TP6 (construire des images), TP9 (registre privé), TP10 (scan Trivy).
> C'est la brique qui **automatise** tout ce qu'on a fait à la main jusqu'ici.

## 🎬 Le contexte

Depuis le début de la formation, on **construit, teste, scanne et pousse** des images… **à la main**, une commande après l'autre. En équipe, ça ne tient pas : quelqu'un oublie le scan, un autre pousse une image cassée, personne ne sait si `latest` est fiable.

La réponse, c'est l'**intégration continue (CI)** : un serveur qui, à chaque changement de code, **rejoue automatiquement** la même séquence — toujours dans le même ordre, sans oubli possible. Ici on monte ce serveur avec **Jenkins**, l'un des moteurs de CI les plus répandus (l'alternative type **GitLab CI** ou **GitHub Actions** repose sur les mêmes idées — voir « Pour aller plus loin »).

Et fidèle à l'esprit de la formation : **Jenkins lui-même tourne dans un conteneur**, et c'est lui qui **fabrique des images Docker**. On boucle la boucle.

Cas réel : la CI interne qui, à chaque commit, produit une image applicative **testée et scannée**, prête à être déployée (comme la stack Swarm du TP12).

## 🎯 Objectif vérifiable

Un **Jenkins configuré au démarrage** (aucun clic d'installation), qui exécute un **pipeline en 4 étapes** :

1. **Build** — construire l'image de l'appli (`app/`) ;
2. **Test** — la lancer et vérifier que `/health` répond `ok` ;
3. **Scan** — passer **Trivy** ; échouer si une faille **HIGH/CRITICAL** existe ;
4. **Push** — publier l'image (tag versionné + `latest`) dans le **registre privé**.

Le pipeline passe au **vert** et l'image se retrouve **réellement** dans le registre. `./verify.sh` déclenche le build et contrôle tout cela.

---

## 🧠 Les 3 idées à comprendre avant de commencer

### 1. « Configuration as Code » — un Jenkins sans clic

Le Jenkins « classique » se configure à la souris (assistant, comptes, jobs…). Impossible à reproduire ou à versionner. Ici, tout est décrit dans **`jenkins/casc.yaml`** (plugin **JCasC**) : la sécurité, **et le job du pipeline lui-même**. On reconstruit un Jenkins identique en une commande.

### 2. « Docker-out-of-Docker » — Jenkins pilote le Docker de l'hôte

Jenkins doit lancer des `docker build`. Plutôt que d'installer un **daemon** Docker dans le conteneur (le fameux « Docker-in-Docker », lourd et privilégié), on **monte le socket de l'hôte** (`/var/run/docker.sock`) dans le conteneur Jenkins, qui n'embarque que le **client** `docker`.

```
┌─────────────────┐   docker build/push   ┌──────────────────────┐
│ conteneur       │  ────────────────────▶ │  daemon Docker de     │
│ Jenkins (client)│      via le socket      │  l'HÔTE (fait le vrai │
└─────────────────┘                         │  travail)            │
                                            └──────────────────────┘
```

> ⚠️ **Le socket Docker = les clés de la machine.** Qui l'atteint est **root sur l'hôte**. Acceptable pour un TP / une CI interne maîtrisée ; en production on isole (agents dédiés, runners éphémères, `rootless`, ou build sans daemon type **BuildKit/Buildah/Kaniko**).

Conséquence pratique : comme le **daemon de l'hôte** fait le travail, on parle au registre via **`localhost:5000`** (que Docker traite comme « insecure » par défaut — pas de TLS à configurer).

### 3. Le pipeline « as code » — un `Jenkinsfile`

La séquence des étapes est un fichier **`Jenkinsfile`** (versionné avec le code). Chaque `stage { }` est une étape ; les commandes `sh 'docker …'` s'exécutent côté Jenkins mais frappent le daemon de l'hôte. **C'est LE fichier que vous allez compléter.**

---

## Étape 1 — Démarrer la plateforme de CI

Placez-vous dans `starter/` et donnez à Jenkins l'accès au socket Docker :

```bash
cd starter
export DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)   # GID du socket de l'hôte
docker compose up -d --build                             # build de l'image Jenkins + démarrage
```

Le **premier** build installe les plugins : patientez ~1 à 2 min. Suivez le démarrage :

```bash
docker compose logs -f jenkins    # attendez « Jenkins is fully up and running »
```

Ouvrez **http://localhost:8080** (compte **`admin` / `admin`**). Surprise : **le job `telemach-pipeline` existe déjà** — il a été créé par `casc.yaml`, sans aucune manipulation. C'est ça, la configuration as-code.

> 🧠 Ouvrez `jenkins/casc.yaml` : vous y voyez le compte admin **et** la définition du job. Le contenu des étapes, lui, est lu depuis `./Jenkinsfile` (monté dans le conteneur).

## Étape 2 — Lancer le pipeline « à vide » (il échoue, c'est normal)

Dans l'interface, ouvrez **telemach-pipeline** → **Lancer un build** (Build Now). Le pipeline s'arrête à l'étape **Build** : le `starter/Jenkinsfile` ne contient que des `TODO`. **À vous de le compléter.**

## Étape 3 — Compléter le pipeline (`Jenkinsfile`)

Ouvrez **`starter/Jenkinsfile`** et remplissez les **4 TODO**. Rappels utiles :

- Le code source est monté dans le conteneur Jenkins sous **`/workspace/app`**.
- L'image cible se nomme **`$REF:$TAG`** (soit `localhost:5000/telemach/whoami:1.0.<n°build>`).
- Variables déjà fournies : `REF`, `TAG`, `NET` (réseau jetable pour le test).

| TODO | Étape | Ce qu'on attend |
|------|-------|-----------------|
| 1 | **Build** | `docker build -t "$REF:$TAG" /workspace/app` |
| 2 | **Test** | lancer le conteneur sur `"$NET"`, puis l'interroger depuis un conteneur jetable (`alpine:3.23 wget -q -O- http://<nom>:8080/health`) et vérifier la réponse `ok` |
| 3 | **Scan** | `docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:0.72.0 image --severity HIGH,CRITICAL --exit-code 1 "$REF:$TAG"` puis afficher `Aucune vulnerabilite HIGH/CRITICAL : image validee` |
| 4 | **Push** | `docker push "$REF:$TAG"`, puis `docker tag`/`docker push` pour publier aussi `"$REF:latest"` |

> 🧠 **Pourquoi Trivy passe-t-il au vert ?** Parce que `app/Dockerfile` est un **multi-stage vers `scratch`** (image vide, non-root) : aucun paquet système, donc aucune CVE d'OS. Le durcissement du TP10 est ce qui rend la CI « verte ».

Après chaque modification du `Jenkinsfile`, **rechargez** le pipeline puis relancez un build :

```bash
docker compose restart jenkins      # JCasC relit le Jenkinsfile
# ... puis « Build Now » dans l'interface
```

> 💡 Suivez le déroulé en direct dans **Console Output** (ou la vue « Stages ») : vous voyez les 4 étapes défiler.

## Étape 4 — Vérifier que l'image est bien publiée

Quand le pipeline est **vert**, l'image est dans le registre. Contrôlez-le sans passer par Jenkins :

```bash
curl -s http://localhost:5000/v2/telemach/whoami/tags/list      # -> les tags publiés
docker pull localhost:5000/telemach/whoami:latest               # on la récupère vraiment
```

## Étape 5 — Valider automatiquement (comme la CI)

```bash
cd ..                 # racine du TP
./verify.sh solution  # rejoue tout sur la solution de référence (ce que fait GitHub Actions)
```

`verify.sh` démarre la plateforme, **déclenche le pipeline par une requête HTTP** (exactement comme un webhook git le ferait), attend le verdict `SUCCESS`, puis prouve que l'image scannée est bien dans le registre.

---

## 💡 Indices (si vous bloquez)

- **`docker: permission denied` sur le socket** → vous avez oublié `export DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)` **avant** `docker compose up`.
- **Le job n'apparaît pas dans Jenkins** → regardez `docker compose logs jenkins` : une erreur de syntaxe dans `Jenkinsfile` empêche JCasC de créer le job. Corrigez, puis `docker compose restart jenkins`.
- **L'étape Scan échoue avec des CVE** → vérifiez que vous scannez bien `"$REF:$TAG"` (l'image du build), pas une image tierce.
- **Le push échoue (`connection refused`)** → le registre se joint via `localhost:5000`, pas `registry:5000` (le `docker push` est exécuté par le daemon de **l'hôte**).
- **Modifs du `Jenkinsfile` ignorées** → il est lu au démarrage par JCasC : pensez au `docker compose restart jenkins`.

## 🚀 Pour aller plus loin

1. **Ajoutez une étape « Lint »** en tête de pipeline avec [Hadolint](https://github.com/hadolint/hadolint) (`docker run --rm -i hadolint/hadolint < app/Dockerfile`) : un pipeline échoue **au plus tôt**.
2. **Déclenchez sur `git push`.** Servez un dépôt (même local) et branchez un **webhook**. Note : depuis une machine tierce, Jenkins protège ses POST par un jeton anti-CSRF (« crumb ») — pour un vrai webhook sans session, installez le plugin **Build Authorization Token Root** (endpoint dédié `/buildByToken/build?job=…&token=…`). C'est le chaînon manquant vers la CI déclenchée automatiquement.
3. **Rapport de scan archivé.** Faites produire à Trivy un rapport (`--format json -o trivy.json`) et archivez-le comme artefact de build (traçabilité sécurité).
   - **Démo « le garde-fou bloque une image pourrie ».** Un pipeline prêt à l'emploi est fourni dans `solution/Jenkinsfile.demo-vuln` : il ne construit rien, il re-badge une image publique volontairement vulnérable (`golang:1.26`, base Debian) et la fait passer par le même pipeline. Résultat : **BUILD/TEST verts, SCAN rouge, PUSH jamais exécuté** — l'image n'atteint pas le registre. Pour l'essayer : `cp solution/Jenkinsfile.demo-vuln solution/Jenkinsfile && (cd solution && docker compose restart jenkins)` puis « Build Now ». (Pour garantir l'échec quelle que soit la date, mettez une image EOL dans `BASE`, ex. `node:18` ou `debian:11`.)
4. **Comparez avec GitLab CI / GitHub Actions.** Le même pipeline y tient en un `.gitlab-ci.yml` / `.github/workflows/*.yml` : mêmes étapes (build/test/scan/push), mais **runners** au lieu du socket, et registre intégré. Les concepts du TP se transposent directement — c'est d'ailleurs exactement ce que fait `.github/workflows/ci.yml` de ce dépôt pour valider tous les TP.

## 🧹 Nettoyage

```bash
cd starter        # (ou solution)
docker compose down -v            # arrête et supprime Jenkins + registre + volumes
```

`verify.sh` nettoie déjà tout seul (il inclut un `cleanup`).


---

<div align="center">

**[Telemach Learning](https://www.telemach-learning.fr)** — Formations DevOps, Cloud & Conteneurs

🌐 [www.telemach-learning.fr](https://www.telemach-learning.fr)

© 2026 Telemach Learning — Code formation DEVOPS-001

</div>
