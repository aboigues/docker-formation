# TP8 — Docker Compose avancé : une vraie appli en plusieurs environnements

> Durée estimée : 1 h 15 · Ports utilisés : `8085` (API), `8086` (Adminer, profil debug), `6379` (Redis, dev)
> Prérequis : TP7 (les bases de Compose). On passe ici au niveau « production-ready ».

## 🎬 Le contexte

L'entreprise a besoin d'un **raccourcisseur d'URL interne** (« Telescope ») : on lui envoie une URL longue, il renvoie un code court ; quand on visite ce code, il **redirige**. Pour tenir la charge, les redirections les plus fréquentes sont servies depuis un **cache Redis** ; la source de vérité reste une base **PostgreSQL**.

Trois services doivent donc coopérer : **api** (Node/Express) + **db** (PostgreSQL) + **cache** (Redis). Et surtout, la **même** stack doit tourner :

- en **dev** : code monté en direct, rechargement à chaud, cache exposé pour debug ;
- en **prod** : image figée, redémarrage automatique, rien d'exposé inutilement.

Au TP7, votre Compose était « plat ». Ici vous allez le rendre **robuste** (l'API ne démarre que si la base est prête), **paramétrable** (`.env`), **multi-environnements** (override dev / surcouche prod) et **modulaire** (`profiles`).

> 💡 Le **code de l'API est fourni** (dossier `app/`). Le cœur du TP, c'est l'**orchestration Compose** — pas le JavaScript.

## 🎯 Objectif vérifiable

Une stack qui démarre **dans le bon ordre** (API gardée par la santé de db + cache), où `POST /shorten` crée un lien, `GET /r/:code` redirige avec un en-tête `X-Cache: MISS` puis `HIT`, où Postgres **n'est pas** exposé sur l'hôte, où `adminer` ne démarre **que** sur demande, et où une surcouche **prod** retire le montage du code. `./verify.sh` contrôle tout cela.

---

## L'arborescence du TP

```
tp08-compose-avance/
├── app/                     # l'API Telescope (FOURNIE — ne pas modifier pour réussir le TP)
│   ├── server.js
│   ├── package.json
│   └── Dockerfile
├── starter/                 # ← vous travaillez ICI
│   ├── compose.yaml             (à compléter : TODO)
│   ├── compose.override.yaml    (à compléter : TODO)
│   ├── .env.example             (à copier en .env)
│   └── .gitignore
└── solution/                # référence testée par la CI (à ne consulter qu'en dernier recours)
```

## Étape 0 — Préparer le `.env`

Les secrets et réglages ne se mettent **jamais en dur** dans le YAML. Compose lit un fichier `.env` **automatiquement** :

```bash
cd starter
cp .env.example .env
```

> ❓ **Question** : pourquoi `.env` est-il dans le `.gitignore` alors que `.env.example` est versionné ? Que se passerait-il si on committait un vrai mot de passe de prod ?

## Étape 1 — Câbler la base (`compose.yaml`)

Ouvrez `starter/compose.yaml` et complétez les `# TODO` du bas vers le haut.

**1.a — `DATABASE_URL`.** L'API joint Postgres via une URL de connexion. Reconstituez-la à partir des variables du `.env` et du **nom de service** `db` :

```
postgres://<user>:<password>@db:5432/<database>
```

> 🧠 On écrit `db`, pas une IP : Compose fournit un **DNS interne** où chaque service est joignable par son nom (vu au TP7).

**1.b — Le volume de Postgres.** Montez le volume nommé `db-data` sur le répertoire de données de Postgres pour que la base **survive** à un `down`.

> ⚠️ **Piège Postgres 18+** : le répertoire à monter est `/var/lib/postgresql` (et **non plus** `/var/lib/postgresql/data` comme dans les versions ≤ 17 et les vieux tutoriels). Monter l'ancien chemin « marche » au démarrage… mais ne persiste rien.

## Étape 2 — Rendre le démarrage fiable (healthchecks + `depends_on`)

Aux TP3 et TP7, l'API pouvait démarrer **avant** que MySQL soit prêt → erreurs au boot. On corrige ça proprement.

**2.a — Un `healthcheck` par dépendance :**

- **db** : `pg_isready -U <user> -d <db>` répond 0 quand Postgres accepte les connexions ;
- **cache** : `redis-cli ping` répond `PONG`.

**2.b — Un démarrage *gardé*.** Sur le service `api`, complétez `depends_on` pour exiger que db **et** cache soient *healthy* :

```yaml
    depends_on:
      db:
        condition: service_healthy
      cache:
        condition: service_healthy
```

**2.c — La santé de l'API elle-même.** Ajoutez un `healthcheck` sur `api` qui appelle `http://localhost:3000/health` (voir Indices). C'est ce que la CI et Compose utilisent pour savoir si le service est réellement « up ».

> ❓ **Question** : quelle est la différence entre « le conteneur tourne » (`running`) et « le service est *healthy* » ? Pourquoi `depends_on` sans `condition` ne suffit-il pas ?

## Étape 3 — La surcouche dev (`compose.override.yaml`)

`docker compose up` **fusionne automatiquement** `compose.yaml` **+** `compose.override.yaml`. C'est le fichier de **développement**. Complétez ses `# TODO` :

- monter `../app` dans `/usr/src/app` (éditer le code de l'hôte = effet immédiat) ;
- **préserver** les `node_modules` de l'image via un **volume anonyme** (`- /usr/src/app/node_modules`) ;
- lancer l'API avec rechargement à chaud : `command: ["node", "--watch", "server.js"]`.

> ❓ **Question** : sans la ligne du volume anonyme `node_modules`, pourquoi l'API planterait-elle (`Cannot find module 'express'`) une fois le code de l'hôte monté ?

## Étape 4 — Lever la stack et la tester

```bash
docker compose up -d --build
docker compose ps          # api doit finir 'healthy', pas seulement 'running'
```

Testez le parcours complet :

```bash
# 1) Raccourcir une URL → on récupère un "code"
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"url":"https://docs.docker.com"}' http://localhost:8085/shorten

# 2) Résoudre le code (remplacez XXddYY) — regardez l'en-tête X-Cache
curl -si http://localhost:8085/r/XXddYY | head -n 5    # 1re fois : X-Cache: MISS
curl -si http://localhost:8085/r/XXddYY | head -n 5    # 2e fois  : X-Cache: HIT
```

> ❓ **Question** : à la 1re visite, l'appli lit Postgres puis écrit dans Redis (MISS). À la 2e, elle répond depuis Redis (HIT). Pourquoi ce cache est-il précieux quand un lien devient viral et reçoit 10 000 visites/minute ?

Inspectez le cache (Redis est exposé en dev) :

```bash
docker compose exec cache redis-cli keys 'link:*'
```

## Étape 5 — Le profil `debug` (Adminer à la demande)

On ne veut **pas** d'interface d'admin de base lancée en permanence. Ajoutez (TODO du `compose.yaml`) un service `adminer` (image `telemachlearning/adminer:5`, port `8086:8080`) derrière `profiles: ["debug"]`, puis :

```bash
docker compose --profile debug up -d adminer
# Ouvrez http://localhost:8086  (Système: PostgreSQL, Serveur: db, user/db = vos valeurs .env)
docker compose ps          # sans --profile, adminer n'apparaît même pas
```

## Étape 6 — La surcouche prod

En prod, on **n'utilise pas** l'override dev. On combine explicitement la base + la surcouche prod :

```bash
docker compose -f compose.yaml -f compose.prod.yaml config | less   # la config FINALE interprétée
```

> ❓ **Question** : dans cette config prod, le code de `../app` est-il monté ? `NODE_ENV` vaut quoi ? Pourquoi une image **immuable** (sans bind mount) est-elle préférable en production ?

## Étape 7 — Validez, puis démontez

```bash
cd ..              # revenir à la racine du TP
./verify.sh              # teste VOTRE travail (dossier starter/)
./verify.sh solution     # (option) rejoue la solution de référence (comme la CI)
```

```bash
cd starter && docker compose down -v      # -v supprime aussi le volume db-data
```

---

## 💡 Indices

<details>
<summary>Healthcheck HTTP de l'API (sans curl dans l'image)</summary>

L'image `node:24-alpine` n'a ni `curl` ni `wget`, mais Node 24 a `fetch` intégré :

```yaml
    healthcheck:
      test: ["CMD", "node", "-e", "fetch('http://localhost:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s
```
</details>

<details>
<summary>Healthcheck Postgres / Redis</summary>

```yaml
  db:
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 5s
      timeout: 3s
      retries: 10
  cache:
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 10
```
</details>

<details>
<summary>Le bloc volumes de l'override dev</summary>

```yaml
    volumes:
      - ../app:/usr/src/app          # bind mount : votre code hôte
      - /usr/src/app/node_modules    # volume anonyme : garde les deps de l'image
```

**Ce qui se passe, étape par étape :**

1. **La 1re ligne est un *bind mount*** : elle remplace tout `/usr/src/app` dans le conteneur par votre dossier hôte `../app`. Or, sur l'hôte, `node_modules` **n'existe pas** (les dépendances ont été installées **dans l'image** au `build`, pas sur votre poste). Résultat : le conteneur ne voit plus `express` → `Cannot find module 'express'`.
2. **La 2de ligne n'a pas de partie gauche** (`hôte:conteneur`), seulement un chemin conteneur : c'est un **volume anonyme** — un volume géré par Docker, sans nom, monté sur le sous-dossier `/usr/src/app/node_modules`.
3. **Le montage le plus profond gagne.** `…/node_modules` est plus spécifique que `…/app` : à cet endroit précis, c'est le volume anonyme qui s'applique, **par-dessus** le bind mount.
4. **Pourquoi il contient les bonnes deps ?** C'est LA propriété clé des volumes Docker (nommés **ou** anonymes) : à sa **première création**, un volume vide est **pré-rempli avec le contenu de l'image** à ce chemin. Le `node_modules` de l'image y est donc recopié — un bind mount, lui, ne fait jamais ça.

**Bilan :** votre code vient de l'hôte (édition à chaud), `node_modules` vient de l'image (deps intactes). Le meilleur des deux.

> ⚠️ Corollaire : ce volume anonyme n'est peuplé qu'**une fois**. Si vous **ajoutez une dépendance** dans `package.json`, il faut la réinstaller (rebuild de l'image + `docker compose up --build --force-recreate`, ou `npm install` dans le conteneur) — le volume ne se met pas à jour tout seul.
</details>

---

## 📖 Où chercher (documentation officielle)

- **Fusion & surcouches (`override`, `-f` multiples)** : https://docs.docker.com/compose/how-tos/multiple-compose-files/
- **Variables d'environnement & fichier `.env`** : https://docs.docker.com/compose/how-tos/environment-variables/
- **`depends_on` avec `condition: service_healthy`** : https://docs.docker.com/reference/compose-file/services/#depends_on
- **Définir un `healthcheck`** : https://docs.docker.com/reference/compose-file/services/#healthcheck
- **`profiles` (services optionnels)** : https://docs.docker.com/compose/how-tos/profiles/
- **`docker compose config`** (voir la config finale) : https://docs.docker.com/reference/cli/docker/compose/config/
- **Images de base** : [postgres](https://hub.docker.com/_/postgres) · [redis](https://hub.docker.com/_/redis) · [adminer](https://hub.docker.com/_/adminer)

> 💡 Le réflexe pro : `docker compose config` **avant** un déploiement. Il affiche la configuration réellement interprétée (variables résolues, fichiers fusionnés) — c'est là qu'on attrape une `${VARIABLE}` oubliée.

---

## 🚀 Pour aller plus loin

1. **`restart: always` en action.** En prod, tuez le process Node dans le conteneur (`docker compose -f compose.yaml -f compose.prod.yaml kill -s SIGKILL api`). Que fait Docker ? Comparez avec le comportement en dev.
2. **TTL du cache.** Le cache expire après 60 s (`CACHE_TTL` dans `server.js`). Vérifiez-le : résolvez un code (HIT), attendez 61 s, re-résolvez → de nouveau MISS. Pourquoi met-on un TTL plutôt qu'un cache éternel ?
3. **Secrets Compose.** Remplacez le mot de passe Postgres par un **`secret`** Compose (fichier monté dans `/run/secrets/`) au lieu d'une variable d'environnement. Pourquoi est-ce plus sûr ? (doc : *Compose file — secrets*).
4. **Scaler l'API.** `docker compose up -d --scale api=3`. Pourquoi le mapping `8085:3000` pose-t-il problème au-delà d'une instance ? (réponse complète au TP12 avec un reverse-proxy).
5. **`docker compose watch`.** Remplacez le bind mount dev par la fonctionnalité `develop: watch:` (sync + rebuild ciblé). En quoi est-ce plus propre qu'un montage de volume brut ?


---

<div align="center">

**[Telemach Learning](https://www.telemach-learning.fr)** — Formations DevOps, Cloud & Conteneurs

🌐 [www.telemach-learning.fr](https://www.telemach-learning.fr)

© 2026 Telemach Learning — Code formation DEVOPS-001

</div>
