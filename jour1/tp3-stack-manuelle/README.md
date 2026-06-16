# TP3 — Monter une stack multi-conteneurs à la main

> **Jour 1** · Durée estimée : 1 h · Ports utilisés : `8083`

## 🎬 Le contexte

Le service communication veut un **blog WordPress** pour publier les actualités de l'entreprise. WordPress a besoin d'une **base de données MySQL**. Deux conteneurs doivent donc coopérer : se **trouver** (réseau), **persister** les données (volume) et se **configurer** (variables d'environnement).

Vous allez tout monter **à la main**, commande par commande. L'objectif n'est pas l'efficacité — c'est de **ressentir la douleur** de la gestion manuelle, pour comprendre au TP4 pourquoi Docker Compose existe.

## 🎯 Objectif vérifiable

WordPress répond sur le port 8083, connecté à MySQL, et les données survivent à la suppression/recréation du conteneur WordPress (persistance par volume). `./verify.sh` le contrôle.

---

## La bonne séquence (à retenir)

Pour une stack multi-conteneurs montée à la main, l'ordre est **toujours** :

1. un **réseau** custom → les conteneurs se résolvent par leur **nom** (DNS interne) ;
2. un **volume** nommé → les données de la base survivent ;
3. le conteneur **base de données** (avec ses variables d'env) ;
4. le conteneur **application**, qui référence la base **par son nom de conteneur**.

> ⚠️ Sur le réseau bridge **par défaut**, les conteneurs ne se résolvent **pas** par nom — d'où le réseau custom obligatoire.

## Étape 1 — Compléter `deploy.sh`

Ouvrez `starter/deploy.sh`. Il pilote la stack avec deux sous-commandes : `up` (monte tout) et `down` (démonte). Complétez les `# TODO` de la fonction `up` :

- créer le réseau `wp-net` ;
- créer le volume `wp-db` ;
- lancer **MySQL** (`mysql:8.4`) sur le réseau, avec le volume monté sur `/var/lib/mysql`, et les variables `MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD` ;
- lancer **WordPress** (`wordpress:6.8-php8.3-apache`) sur le réseau, port `8083:80`, en pointant `WORDPRESS_DB_HOST` vers le **nom du conteneur MySQL**.

## Étape 2 — Monter la stack

```bash
chmod +x starter/deploy.sh
./starter/deploy.sh up
```

Patientez ~30-60 s (MySQL doit s'initialiser au premier démarrage), puis ouvrez http://localhost:8083 : vous devez voir l'écran d'installation de WordPress.

```bash
docker ps                  # les 2 conteneurs tournent
docker logs wp-app | tail  # WordPress a-t-il joint la base ?
```

> ❓ **Question** : dans la commande WordPress, on écrit `WORDPRESS_DB_HOST=wp-mysql`. Pourquoi un **nom** et pas une **adresse IP** ? Que se passerait-il avec une IP si MySQL redémarrait ?

## Étape 3 — Prouver la persistance

C'est tout l'intérêt du volume. Supprimez le conteneur WordPress (pas le volume !) et recréez-le :

```bash
docker rm -f wp-app
# relancez UNIQUEMENT la partie WordPress (réutilisez votre commande de deploy.sh)
./starter/deploy.sh up        # idempotent : ne recrée que ce qui manque
```

Rechargez la page : si vous aviez commencé l'installation, l'état est **conservé**, car les données vivent dans le volume `wp-db`, pas dans le conteneur.

> 🧠 **Le bilan « douloureux »** : comptez le nombre de commandes (et de variables) qu'il a fallu pour 2 services. Imaginez 10 services. Non reproductible, non versionnable, fragile. → **TP4 : Docker Compose.**

## Étape 4 — Validez

```bash
./verify.sh
```

## Étape 5 — Démontez proprement

```bash
./starter/deploy.sh down        # supprime conteneurs + réseau
docker volume rm wp-db          # ⚠️ supprime AUSSI les données
```

---

## 💡 Indices

<details>
<summary>Squelette d'une commande `docker run` avec réseau + volume + env</summary>

```bash
docker run -d --name wp-mysql --network wp-net \
  -v wp-db:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=rootsecret \
  -e MYSQL_DATABASE=wordpress \
  -e MYSQL_USER=wpuser \
  -e MYSQL_PASSWORD=wpsecret \
  mysql:8.4
```
</details>

<details>
<summary>WordPress ne joint pas la base ?</summary>

Vérifiez que les **deux** conteneurs sont sur le **même réseau** (`--network wp-net`) et que `WORDPRESS_DB_HOST` vaut exactement le **nom** du conteneur MySQL.
</details>

---

## 🚀 Pour aller plus loin

1. **phpMyAdmin.** Ajoutez un 3ᵉ conteneur `phpmyadmin` sur le même réseau (`-e PMA_HOST=wp-mysql`, port `8084:80`). Connectez-vous et explorez les tables créées par WordPress.
2. **Healthcheck manuel.** Avant de lancer WordPress, attendez **vraiment** que MySQL réponde avec une boucle : `until docker exec wp-mysql mysqladmin ping -h localhost --silent; do sleep 2; done`. Pourquoi est-ce plus fiable qu'un simple `sleep 30` ?
3. **Sauvegarde de la base.** Exportez la base sans arrêter le service : `docker exec wp-mysql mysqldump -u root -prootsecret wordpress > backup.sql`. Quelle taille fait le dump ?
4. **Isolation réseau.** MySQL n'a **pas besoin** d'être exposé sur l'hôte (pas de `-p`). Vérifiez que `localhost:3306` n'est **pas** accessible depuis votre machine, alors que WordPress joint bien MySQL en interne. Quel principe de sécurité cela illustre-t-il ?
