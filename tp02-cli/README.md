# TP2 — Maîtriser la CLI : déboguer un conteneur

> Durée estimée : 50 min · Ports utilisés : `8082`

## 🎬 Le contexte

3 h du matin. Une alerte tombe : le conteneur `checkout` (le tunnel de paiement) « ne répond plus ». Vous êtes d'astreinte. Vous n'avez **que la CLI Docker** et il faut diagnostiquer vite : le conteneur tourne-t-il ? que disent ses logs ? quelle est son IP interne ? quel processus tourne dedans ?

Ce TP vous fait acquérir les **réflexes de diagnostic** d'un·e ops, puis vous fait écrire un vrai **script de collecte d'informations** réutilisable en astreinte.

## 🎯 Objectif vérifiable

Un script `collect.sh <nom_conteneur>` qui affiche l'IP interne, le nombre de lignes de logs et l'état du process web d'un conteneur. `./verify.sh` lance un conteneur de test et vérifie que votre script en extrait les bonnes informations.

---

## Étape 1 — Le cycle de vie, en pratique

On simule le service `checkout` avec un nginx. Créez d'abord un **réseau dédié** (vous comprendrez pourquoi à l'étape 3) :

```bash
docker network create tp02-net
docker run -d --name checkout --network tp02-net -p 8082:80 nginx:1.30-alpine
docker ps
```

Manipulez son cycle de vie et **observez** `docker ps` / `docker ps -a` après chaque commande :

```bash
docker stop checkout      # → disparaît de `docker ps`, visible dans `docker ps -a`
docker start checkout
docker restart checkout
```

> ❓ **Question** : après `docker stop`, le conteneur existe-t-il encore ? Quelle commande le prouve ? Quelle commande le **supprimerait** définitivement ?

## Étape 2 — Lire les logs (le premier réflexe)

Générez un peu de trafic, puis consultez les logs :

```bash
curl -s http://localhost:8082 >/dev/null
curl -s http://localhost:8082/page-inexistante >/dev/null
docker logs checkout
docker logs --tail=5 -t checkout      # 5 dernières lignes, horodatées
```

> ❓ **Question** : où l'application écrit-elle ses logs pour que `docker logs` les voie ? (Indice : `stdout`/`stderr`, pas un fichier.)

## Étape 3 — Inspecter : extraire une info précise

`docker inspect` renvoie **tout** en JSON. L'art consiste à en extraire **une** valeur avec `--format` :

```bash
# L'IP interne du conteneur sur son réseau
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' checkout

# L'état (running / exited)
docker inspect -f '{{.State.Status}}' checkout
```

> 🧠 C'est exactement ce qu'on automatisera dans `collect.sh`. La syntaxe `{{...}}` est du **Go template**.

## Étape 4 — Entrer dans le conteneur (exec)

```bash
# Ouvrir un shell DANS le conteneur en cours d'exécution
docker exec -it checkout sh
#   (dans le conteneur) : ps aux ; ls /usr/share/nginx/html ; exit

# Ou lancer une seule commande sans entrer
docker exec checkout nginx -t       # teste la config nginx
docker top checkout                 # processus vus depuis l'hôte
```

> ❓ **Question** : quelle est la différence entre `docker run` et `docker exec` ? (Indice : l'un **crée** un conteneur, l'autre entre dans un conteneur **existant**.)

## Étape 5 — Écrire `collect.sh` (à vous de jouer)

Ouvrez `starter/collect.sh` et complétez les `# TODO`. Le script reçoit un nom de conteneur en `$1` et doit afficher **exactement** ces trois lignes :

```
IP=<adresse_ip_interne>
LOGS=<nombre_de_lignes_de_logs>
WEB_RUNNING=<yes|no>
```

- `IP` : via `docker inspect --format` (étape 3).
- `LOGS` : `docker logs <nom> 2>&1 | wc -l`.
- `WEB_RUNNING` : `yes` si un process `nginx` tourne dans le conteneur (`docker top` ou `docker exec ... pgrep`), sinon `no`.

Testez à la main :

```bash
chmod +x starter/collect.sh
./starter/collect.sh checkout
```

## Étape 6 — Validez

```bash
./verify.sh              # teste VOTRE travail (dossier starter/)
./verify.sh solution     # (option) rejoue la solution de référence
```

Nettoyez votre environnement manuel :

```bash
docker rm -f checkout && docker network rm tp02-net
```

---

## 💡 Indices

<details>
<summary>Extraire proprement l'IP ?</summary>

```bash
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$1"
```
</details>

<details>
<summary>Tester si nginx tourne dans le conteneur ?</summary>

```bash
if docker top "$1" 2>/dev/null | grep -q nginx; then echo yes; else echo no; fi
```
</details>

---

## 📖 Où chercher (documentation officielle)

- **`docker logs`** : https://docs.docker.com/reference/cli/docker/container/logs/
- **`docker exec`** (entrer dans un conteneur) : https://docs.docker.com/reference/cli/docker/container/exec/
- **`docker inspect` & format Go template** : https://docs.docker.com/reference/cli/docker/inspect/ et https://docs.docker.com/engine/cli/formatting/
- **`docker top` / `docker stats`** : https://docs.docker.com/reference/cli/docker/container/top/ · https://docs.docker.com/reference/cli/docker/container/stats/
- **Syntaxe des templates Go** (pour `--format`) : https://pkg.go.dev/text/template

> 💡 Pour `--format`, la doc « Formatting » de Docker donne des exemples prêts à l'emploi. Et `docker inspect <nom>` (sans format) montre **tout** le JSON : repérez-y le champ avant de l'extraire.

---

## 🚀 Pour aller plus loin

1. **`docker cp` à chaud.** Copiez une nouvelle `index.html` depuis l'hôte vers `checkout` sans le redémarrer (`docker cp index.html checkout:/usr/share/nginx/html/`). Rechargez la page. Pratique en hotfix… mais pourquoi est-ce une **mauvaise** pratique durable ?
2. **`docker stats`.** Lancez `docker stats checkout --no-stream`. Quelle est sa conso CPU/RAM au repos ?
3. **Réseau & DNS.** Lancez un 2ᵉ conteneur sur `tp02-net` et faites-le `ping checkout` **par son nom**. Refaites l'essai sur le réseau bridge par défaut : pourquoi le ping par nom échoue-t-il là ?
4. **Format JSON ciblé.** Avec `docker inspect`, sortez d'un coup l'IP, le statut et l'image au format `{{.NetworkSettings... }} {{.State.Status}} {{.Config.Image}}`.
5. **Enrichissez `collect.sh`** : ajoutez une ligne `RESTARTS=<n>` (via `.RestartCount`) — utile pour repérer un conteneur qui *crash-loop*.


---

<div align="center">

**[Telemach Learning](https://www.telemach-learning.fr)** — Formations DevOps, Cloud & Conteneurs

🌐 [www.telemach-learning.fr](https://www.telemach-learning.fr)

© 2026 Telemach Learning — Code formation DEVOPS-001

</div>
