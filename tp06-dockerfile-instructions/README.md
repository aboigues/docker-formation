# TP6 — Dockerfile : toutes les instructions courantes

> Durée estimée : 50 min · Port utilisé : `8085`
> Prérequis : avoir fait le **TP5** (écrire un premier `Dockerfile` pour des fichiers statiques).
> Ce TP approfondit le chapitre **« Créer ses propres images »** du jour 1.

## 🎬 Le contexte

Au TP5, votre `Dockerfile` faisait deux choses : `FROM` + `COPY`. C'est suffisant pour une page statique, mais une **vraie appli** doit installer des dépendances, recevoir une configuration, déclarer son port, tourner sans privilèges et signaler sa santé.

Votre mission : conteneuriser le **portail interne « Telemach Cloud »** (une petite API Node) avec un `Dockerfile` **complet et propre**, en utilisant les instructions qu'on retrouve sur 90 % des images de production : `LABEL`, `ARG`, `ENV`, `WORKDIR`, `RUN`, `EXPOSE`, `USER`, `HEALTHCHECK`, et le duo `ENTRYPOINT`/`CMD`.

Le code JavaScript est **fourni** : le cœur du TP, c'est le `Dockerfile`.

## 🎯 Objectif vérifiable

Une image `tp06-portail` qui :
1. répond `200` sur `/healthz` et affiche **« Telemach Cloud »** sur `/` (port 3000 dans le conteneur) ;
2. expose sur `/version` la **version injectée au build** via l'instruction `ARG` ;
3. tourne en **non-root** et **déclare un `HEALTHCHECK`** (bonnes pratiques vérifiées).

C'est exactement ce que `./verify.sh` (et la CI) contrôle.

---

## Les instructions, une par une

| Instruction | À quoi ça sert | Moment |
|-------------|----------------|--------|
| `FROM` | Image de base | build |
| `LABEL` | Métadonnées (auteur, version, source) | build |
| `ARG` | Variable **du build** (ex. n° de version CI) | build seulement |
| `ENV` | Variable disponible **dans le conteneur** | build + runtime |
| `WORKDIR` | Répertoire de travail (créé si absent) | build + runtime |
| `COPY` | Copie des fichiers dans l'image | build |
| `RUN` | Exécute une commande **pendant** le build (crée une couche) | build |
| `EXPOSE` | **Documente** le port d'écoute (ne publie rien) | déclaratif |
| `USER` | Change l'utilisateur (quitter root) | build + runtime |
| `HEALTHCHECK` | Docker sonde la santé du conteneur | runtime |
| `ENTRYPOINT` | L'exécutable **fixe** du conteneur | runtime |
| `CMD` | Les **arguments par défaut** (surchargeables) | runtime |

> 🔑 **ARG vs ENV** : `ARG` n'existe **que** pendant le build (invisible dans le conteneur final). `ENV` persiste **dans** le conteneur. On « fige » souvent un `ARG` dans un `ENV` pour exposer au runtime une valeur connue au build (ici, la version).

## Étape 1 — Explorer le squelette

```bash
cd starter
ls          # server.js, package.json, .dockerignore, Dockerfile (à compléter)
cat Dockerfile
```

Le `Dockerfile` est jalonné de `# TODO` et de `______` à remplacer. L'appli, elle, écoute sur le port `3000` et lit deux variables d'environnement : `PORT` et `APP_VERSION`.

## Étape 2 — Compléter le `Dockerfile`

Remplacez chaque `______` en suivant les `# TODO` (de 1 à 10). Points d'attention :

- **L'ordre des couches** (TODO 5) : on copie `package.json` **et on installe** les dépendances **AVANT** de copier `server.js`. Pourquoi ? Tant que `package.json` ne change pas, Docker **réutilise** la couche d'installation (la plus lente) au lieu de tout réinstaller à chaque modification du code.
- **`ARG` → `ENV`** (TODO 2-3) : déclarez `ARG APP_VERSION=0.0.0-dev`, puis `ENV APP_VERSION=$APP_VERSION` pour que l'appli y accède au runtime.
- **Non-root** (TODO 8) : l'image `node` fournit déjà un utilisateur `node`. Un simple `USER node` suffit.

> ❓ **Question** : si vous mettiez `COPY server.js ./` **avant** le `RUN npm install`, que se passerait-il à chaque modification d'une ligne de `server.js` lors d'un rebuild ? (Indice : pensez à l'invalidation du cache de couches.)

## Étape 3 — Construire en injectant une version

L'instruction `ARG` se renseigne au build avec `--build-arg` :

```bash
docker build --build-arg APP_VERSION=1.4.2 -t tp06-portail:1.4.2 .
```

Lancez le conteneur (on publie le port 3000 du conteneur sur 8085 de l'hôte) :

```bash
docker run -d --name tp06-portail -p 8085:3000 tp06-portail:1.4.2
curl -s http://localhost:8085/            # page « Telemach Cloud »
curl -s http://localhost:8085/version     # {"version":"1.4.2"}  ← votre ARG !
```

> ❓ **Question** : relancez `docker build` **sans** `--build-arg`. Que renvoie `/version` ? (Indice : la valeur **par défaut** de l'`ARG`.)

## Étape 4 — Observer le HEALTHCHECK et l'utilisateur

```bash
docker ps                                  # colonne STATUS : « (healthy) » après ~quelques s
docker exec tp06-portail id                 # uid=1000(node) → PAS root ✅
docker inspect -f '{{json .Config.Healthcheck}}' tp06-portail:1.4.2
```

> 🧠 Le `HEALTHCHECK` rend la santé **visible** (`docker ps`) et exploitable par un orchestrateur (Compose `depends_on: condition: service_healthy`, Swarm, Kubernetes…). Sans lui, « le conteneur tourne » ne dit **pas** « l'appli répond ».

## Étape 5 — Comprendre ENTRYPOINT + CMD

L'image fixe `ENTRYPOINT ["node"]` et `CMD ["server.js"]`. Le `CMD` n'est qu'un **argument par défaut**, surchargeable :

```bash
docker run --rm tp06-portail:1.4.2 --version   # exécute « node --version » (CMD remplacé)
```

> ❓ **Question** : pourquoi `node --version` s'exécute-t-il alors qu'on n'a pas tapé `node` ? Que se passerait-il si on avait tout mis dans un seul `CMD ["node", "server.js"]` à la place ?

## Étape 6 — Validez, puis nettoyez

```bash
cd ..
./verify.sh
```

```bash
docker rm -f tp06-portail && docker rmi tp06-portail:1.4.2
```

---

## 💡 Indices

<details>
<summary>Le bloc ARG → ENV</summary>

```dockerfile
ARG APP_VERSION=0.0.0-dev
ENV NODE_ENV=production \
    PORT=3000 \
    APP_VERSION=$APP_VERSION
```
</details>

<details>
<summary>Dépendances avant le code (cache de couches)</summary>

```dockerfile
COPY package.json ./
RUN npm install --omit=dev && npm cache clean --force
COPY server.js ./
```
</details>

<details>
<summary>HEALTHCHECK + ENTRYPOINT/CMD</summary>

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost:3000/healthz >/dev/null 2>&1 || exit 1
ENTRYPOINT ["node"]
CMD ["server.js"]
```
</details>

---

## 📖 Où chercher (documentation officielle)

- **Référence du `Dockerfile` (toutes les instructions)** : https://docs.docker.com/reference/dockerfile/
- **`ARG` vs `ENV`** : https://docs.docker.com/reference/dockerfile/#arg · https://docs.docker.com/reference/dockerfile/#env
- **`ENTRYPOINT` vs `CMD` (tableau d'interaction)** : https://docs.docker.com/reference/dockerfile/#understand-how-cmd-and-entrypoint-interact
- **`HEALTHCHECK`** : https://docs.docker.com/reference/dockerfile/#healthcheck
- **`USER` & exécution non-root** : https://docs.docker.com/reference/dockerfile/#user
- **Bonnes pratiques d'écriture d'un Dockerfile (cache de couches)** : https://docs.docker.com/build/building/best-practices/
- **Labels OCI standard** : https://github.com/opencontainers/image-spec/blob/main/annotations.md

> 💡 `EXPOSE` ne publie **rien** : c'est de la documentation. Pour rendre le port accessible depuis l'hôte, c'est `docker run -p 8085:3000` (ou `ports:` en Compose) qui compte.

---

## 🚀 Pour aller plus loin

1. **`npm ci` + lockfile.** En production, on préfère `npm ci` (reproductible, basé sur `package-lock.json`) à `npm install`. Générez le lockfile (`npm install` en local), committez-le, et remplacez l'instruction. Qu'est-ce que `npm ci` garantit de plus ?
2. **`.dockerignore`.** Ajoutez `node_modules` (déjà fait) et observez : pourquoi est-il crucial de **ne pas** copier le `node_modules` de l'hôte dans l'image ?
3. **Taille & couches.** Lancez `docker history tp06-portail:1.4.2`. Quelle couche pèse le plus ? Que se passe-t-il si vous **fusionnez** `COPY package.json` et `COPY server.js` en une seule instruction côté cache ?
4. **`ENTRYPOINT` en forme *shell* vs *exec*.** Comparez `ENTRYPOINT node server.js` (forme shell) et `ENTRYPOINT ["node","server.js"]` (forme exec). Lequel transmet correctement le signal `SIGTERM` (arrêt propre) au process Node ? Pourquoi est-ce important pour `docker stop` ?
5. **Vers le multi-stage.** Cette image embarque `npm` et la toolchain. Au **TP7**, vous verrez comment n'embarquer **que** le strict nécessaire avec un *multi-stage build*.
