# TP5 — La même stack, mais avec Docker Compose

> **Jour 1** · Durée estimée : 45 min · Ports utilisés : `8083`
> Prérequis : TP4 (la même stack montée à la main).

## 🎬 Le contexte

Au TP4, monter WordPress + MySQL à la main vous a coûté ~6 commandes longues, non reproductibles et impossibles à versionner. Un·e collègue qui veut la même stack doit tout retaper sans se tromper. **Inacceptable** en équipe.

Docker Compose décrit toute la stack dans **un seul fichier YAML**, versionnable dans Git, déployable en **une commande**. Vous allez convertir le TP4 et mesurer le gain.

## 🎯 Objectif vérifiable

Un `docker-compose.yml` qui lève la même stack (WordPress sur 8083 + MySQL) avec `docker compose up -d`, le réseau et le volume créés automatiquement. `./verify.sh` le contrôle.

---

## ⚠️ Avant de commencer

Si la stack du TP4 tourne encore, démontez-la (même port 8083) :

```bash
cd ../tp4-stack-manuelle && ./solution/deploy.sh down && docker volume rm wp-db 2>/dev/null; cd -
```

## Étape 1 — Lire la correspondance run → Compose

Chaque option `docker run` du TP4 a son équivalent en YAML. Gardez cette table sous les yeux :

| `docker run` | `docker-compose.yml` |
|--------------|----------------------|
| `--name wp-mysql` | la **clé** du service (`mysql:`) |
| `mysql:8.4` | `image: mysql:8.4` |
| `-v wp-db:/var/lib/mysql` | `volumes: [ "db-data:/var/lib/mysql" ]` |
| `-e MYSQL_...=...` | `environment:` |
| `-p 8083:80` | `ports: [ "8083:80" ]` |
| `--network wp-net` | **automatique** (réseau créé par Compose) |

> 🧠 Le réseau, vous n'avez **plus** à le créer : Compose crée un réseau dédié au projet où chaque service est joignable **par son nom de service**.

## Étape 2 — Compléter `docker-compose.yml`

Ouvrez `starter/docker-compose.yml` et complétez les `# TODO` :

- service `mysql` : image, volume, 4 variables d'environnement ;
- service `wordpress` : image, port `8083:80`, variables (`WORDPRESS_DB_HOST` = **nom du service** `mysql`), `depends_on: [mysql]` ;
- déclaration du volume nommé `db-data`.

> ℹ️ Ne mettez **pas** de clé `version:` en haut du fichier : elle est **obsolète** depuis Compose v2.

## Étape 3 — Lever la stack

Depuis `starter/` :

```bash
cd starter
docker compose up -d
docker compose ps
docker compose logs -f wordpress     # Ctrl-C pour quitter
```

Ouvrez http://localhost:8083.

> ❓ **Question** : lancez `docker network ls` et `docker volume ls`. Repérez le réseau et le volume **préfixés du nom du projet** (le nom du dossier). Qui les a créés ? Vous n'avez pourtant tapé aucune commande `network create` ni `volume create`.

## Étape 4 — Observer la magie du DNS

```bash
docker compose exec wordpress getent hosts mysql
```

Le nom `mysql` (le **nom du service**) se résout vers l'IP du conteneur MySQL. C'est pourquoi `WORDPRESS_DB_HOST: mysql` fonctionne.

## Étape 5 — Démonter (et le piège du `-v`)

```bash
docker compose down        # supprime conteneurs + réseau, GARDE le volume
# docker compose down -v   # ⚠️ supprime AUSSI le volume = perte des données
```

> ❓ **Question** : quelle est la différence **cruciale** entre `down` et `down -v` en production ?

## Étape 6 — Validez

Depuis le dossier du TP :

```bash
./verify.sh
```

---

## 💡 Indices

<details>
<summary>Structure minimale d'un service Compose</summary>

```yaml
services:
  mysql:
    image: mysql:8.4
    volumes:
      - db-data:/var/lib/mysql
    environment:
      MYSQL_ROOT_PASSWORD: rootsecret
```
</details>

<details>
<summary>« services.wordpress.depends_on must be a list » ?</summary>

```yaml
    depends_on:
      - mysql
```
</details>

---

## 📖 Où chercher (documentation officielle)

- **Présentation de Docker Compose** : https://docs.docker.com/compose/
- **Référence du fichier `compose.yaml`** (toutes les clés) : https://docs.docker.com/reference/compose-file/
- **Section `services`** (image, ports, volumes, environment, depends_on) : https://docs.docker.com/reference/compose-file/services/
- **Volumes nommés dans Compose** : https://docs.docker.com/reference/compose-file/volumes/
- **CLI `docker compose`** : https://docs.docker.com/reference/cli/docker/compose/

> 💡 La clé `version:` que l'on voit dans de vieux tutoriels est **obsolète** : la doc officielle ne la mentionne plus. Fiez-vous à `docs.docker.com`, pas aux blogs de 2019.

---

## 🚀 Pour aller plus loin

1. **Comparez.** Comptez les lignes du `docker-compose.yml` vs le nombre de commandes du TP4. Lequel est le plus facile à relire pour un·e collègue dans 6 mois ?
2. **`docker compose config`.** Lancez-la : Compose affiche la configuration **finale** interprétée. À quoi ça sert avant un déploiement ?
3. **Scaler ?** Essayez `docker compose up -d --scale wordpress=2`. Que se passe-t-il ? Pourquoi le mapping de port `8083:80` pose-t-il problème au-delà d'une instance ? (On résoudra ça au TP10 avec un reverse-proxy.)
4. **Externaliser les secrets.** Déplacez les mots de passe dans un fichier `.env` et référencez-les avec `${...}` dans le YAML. Ajoutez `.env` au `.gitignore`. (C'est le cœur du TP6.)
5. **Profiles.** Ajoutez un service `adminer` (interface DB web) derrière un `profiles: ["debug"]`, et ne le lancez qu'avec `docker compose --profile debug up -d`.
