# TP12 — Mise en production : une vraie appli répliquée (Drupal) sur Swarm + Traefik

> Durée estimée : 1 h 15 · Ports utilisés : `8090` (web via Traefik), `8091` (dashboard Traefik)
> Prérequis : TP4/TP8 (Compose), TP9 (images). C'est l'aboutissement du parcours.
> Machine avec ~4 Go de RAM libres recommandés (Drupal + MariaDB + 3 réplicas).

## 🎬 Le contexte

Au TP8, on a vu la limite de `docker compose up --scale` : impossible d'avoir plusieurs instances derrière **un même port**. En production, on veut : **plusieurs réplicas** d'une application (tolérance de panne + montée en charge), **répartis** automatiquement, et **un seul point d'entrée** qui distribue le trafic.

Cette fois, pas de service jouet : on déploie un **vrai CMS — Drupal** — en **3 réplicas** derrière **Traefik**, adossé à une base **MariaDB**. C'est tout l'enjeu de la prod : une application **avec état** (sa base, ses fichiers) qu'on veut quand même **répliquer**.

Cas réel : héberger le site institutionnel de l'entreprise, capable d'encaisser la charge et de survivre à la perte d'une instance.

## 🎯 Objectif vérifiable

Un Swarm actif, une stack déployée avec `docker stack deploy` : **MariaDB en 1/1**, **Drupal en 3/3 réplicas**, le site **réellement installé** et servi via Traefik sur `Host(\`drupal.localhost\`)` (la page d'accueil affiche **« Telemach Swarm »**), avec **répartition de charge** visible (plusieurs réplicas répondent, en-tête `X-Served-By`) et la **base peuplée**. `./verify.sh` contrôle tout cela.

---

## Swarm vs Compose, en une phrase

| | Docker Compose | Docker Swarm |
|--|----------------|--------------|
| Cible | **une** machine (dev) | un **cluster** (prod) |
| Commande | `docker compose up` | `docker stack deploy` |
| Réplicas/HA | non | **oui** (`replicas`, reprise auto) |
| Clé spécifique | — | bloc **`deploy:`** |

## Le défi : répliquer une application **avec état**

`whoami` se réplique sans réfléchir (rien à partager). Une vraie appli, non. Trois règles structurent notre stack :

1. **La base ne se réplique pas comme l'appli.** MariaDB reste en **1 réplica** (épinglée au manager, sur un volume). Répliquer une base SQL « à la main » corromprait les données — c'est un sujet à part (réplication SQL maître/réplica). Ici : **un** serveur de base, **plusieurs** frontaux.
2. **Les frontaux partagent le même état.** Les 3 réplicas Drupal pointent vers la **même** base (leur `settings.php` lit la connexion depuis l'**environnement**) et le **même** volume de fichiers. C'est pour ça qu'on **installe le site une seule fois** : tous les réplicas servent ce même site.
3. **Le stockage de fichiers doit être partagé.** Sur notre Swarm **mono-nœud**, un volume nommé est partagé par les 3 réplicas du nœud. ⚠️ En **vrai multi-nœuds**, un volume est **local à son nœud** : il faudrait un **stockage réseau** (NFS, GlusterFS, un driver CSI cloud…). On y revient en [Annexe A](#annexe-a--un-vrai-cluster-à-3-nœuds-en-local-docker-in-docker).

## Étape 1 — Construire l'image et activer Swarm

Swarm **ne construit pas** les images : il les tire d'un registre (ou du cache local du nœud). On construit donc d'abord notre image Drupal (Drupal officiel + **drush** pour l'install + un en-tête `X-Served-By` qui révèle quel réplica répond) :

```bash
docker build -t tp12-telemach-drupal:1.0 drupal/
docker swarm init                 # transforme votre Docker en manager d'un cluster (à 1 nœud)
docker node ls                    # vous êtes « Leader »
```

> 🧠 `drupal/settings.php` lit la BDD depuis des variables d'env (`DRUPAL_DB_*`). Résultat : **tous** les réplicas ont la même config, sans installation par réplica.

> ❓ **Question** : un seul nœud, est-ce encore un « cluster » ? Que faudrait-il pour une vraie tolérance de panne ? (Voir l'**[Annexe A](#annexe-a--un-vrai-cluster-à-3-nœuds-en-local-docker-in-docker)** : un cluster 3 nœuds en 5 min, sans VM.)

## Étape 2 — Compléter la stack (`stack.yml`)

Ouvrez `starter/stack.yml`. Les services `db` (MariaDB) et `traefik` sont **fournis** ; complétez le service `drupal` (**TODO 1 à 4**) :

- **TODO 1** : le bloc `environment:` de connexion BDD (`DRUPAL_DB_HOST=db`, `DRUPAL_DB_NAME=drupal`, `DRUPAL_DB_USER=drupal`, `DRUPAL_DB_PASSWORD=drupalpass`) ;
- **TODO 2** : monter le volume partagé `drupal-files` sur `/opt/drupal/web/sites/default/files` ;
- **TODO 3** : `replicas: 3` ;
- **TODO 4** : les 4 labels Traefik (sous `deploy.labels`, car en Swarm c'est le **service** qui porte les labels) :
  - `traefik.enable=true`
  - `traefik.http.routers.drupal.rule=Host(\`drupal.localhost\`)`
  - `traefik.http.routers.drupal.entrypoints=web`
  - `traefik.http.services.drupal.loadbalancer.server.port=80`

> 🧠 Traefik **découvre** Drupal tout seul en lisant l'API Swarm (socket Docker monté). Aucun fichier de conf de proxy : on **décrit** le routage sur le service.

## Étape 3 — Déployer et observer

```bash
# --resolve-image=never : l'image est locale (pas dans un registre), pas de lookup
docker stack deploy --resolve-image=never -c starter/stack.yml tp12
docker stack services tp12            # db -> 1/1, drupal -> 3/3, traefik -> 1/1
docker service ps tp12_drupal         # les 3 réplicas (et leur nœud)
```

Patientez que **MariaDB** soit prêt et que les **3 réplicas Drupal** tournent. Tant que le site n'est pas installé, Drupal renvoie une erreur (pas encore de tables) : c'est normal.

## Étape 4 — Installer le site **une seule fois**

On installe via **drush**, dans **n'importe lequel** des réplicas (ils partagent la même base) :

```bash
CID=$(docker ps --filter "label=com.docker.swarm.service.name=tp12_drupal" -q | head -1)
docker exec "$CID" drush -y site:install standard \
  --site-name="Telemach Swarm" --account-name=admin --account-pass=admin
```

> 🧠 Une **seule** installation suffit : elle crée les tables dans la base **partagée**. Les 3 réplicas servent aussitôt ce même site — c'est exactement le principe « plusieurs frontaux, une base ».

## Étape 5 — Tester le routage et la **répartition de charge**

Le routage se fait sur l'en-tête **Host** (pas de vrai DNS, on le simule avec `curl`) :

```bash
curl -s -H "Host: drupal.localhost" http://localhost:8090/ | grep -i '<title>'
#   -> <title>Welcome! | Telemach Swarm</title>

# QUI a répondu ? L'en-tête X-Served-By porte le nom du réplica (drupal-1/2/3) :
for i in $(seq 1 8); do
  curl -s -D - -o /dev/null -H "Host: drupal.localhost" http://localhost:8090/ | grep -i x-served-by
done
```

Ouvrez le **dashboard Traefik** : http://localhost:8091 → routeur `drupal` et ses cibles.

> ❓ **Question** : `X-Served-By` change d'un appel à l'autre — qui décide vers quel réplica part chaque requête ? Et pourquoi tous renvoient-ils le **même** contenu ?

## Étape 6 — Éprouver la résilience (le moment « waouh »)

```bash
docker service scale tp12_drupal=5      # passe à 5 réplicas À CHAUD
docker rm -f "$(docker ps --filter name=tp12_drupal -q | head -1)"   # on tue un réplica
docker service ps tp12_drupal           # Swarm en a relancé un AUTOMATIQUEMENT
```

Le site reste joignable pendant l'opération : les autres réplicas encaissent.

> 🧠 La promesse de l'orchestrateur : l'**état désiré** (« je veux N Drupal ») est maintenu malgré les pannes, sans intervention humaine.

## Étape 7 — Validez, puis démontez

```bash
./verify.sh
```

```bash
docker stack rm tp12
docker volume rm tp12_db-data tp12_drupal-files   # ⚠️ supprime la base ET les fichiers
docker swarm leave --force                        # ⚠️ quitte le mode Swarm sur votre machine
```

---

## 💡 Indices

<details>
<summary>Le service drupal complété (TODO 1 à 4)</summary>

```yaml
  drupal:
    image: tp12-telemach-drupal:1.0
    hostname: "drupal-{{.Task.Slot}}"
    environment:
      DRUPAL_DB_HOST: db
      DRUPAL_DB_NAME: drupal
      DRUPAL_DB_USER: drupal
      DRUPAL_DB_PASSWORD: drupalpass
    volumes:
      - drupal-files:/opt/drupal/web/sites/default/files
    deploy:
      replicas: 3
      labels:
        - traefik.enable=true
        - traefik.http.routers.drupal.rule=Host(`drupal.localhost`)
        - traefik.http.routers.drupal.entrypoints=web
        - traefik.http.services.drupal.loadbalancer.server.port=80
```
</details>

<details>
<summary>drupal reste à 0/3 ou redémarre en boucle ?</summary>

Regardez `docker service ps tp12_drupal --no-trunc` et `docker logs <cid>`. Causes fréquentes : l'image `tp12-telemach-drupal:1.0` n'a pas été **construite** (étape 1), ou MariaDB n'est pas encore prête. Avant l'install, une erreur Drupal est **attendue** (pas de tables).
</details>

---

## 📖 Où chercher (documentation officielle)

- **Démarrer avec Swarm** : https://docs.docker.com/engine/swarm/swarm-tutorial/
- **`docker stack deploy` & format `deploy:`** : https://docs.docker.com/reference/cli/docker/stack/deploy/ · https://docs.docker.com/reference/compose-file/deploy/
- **`docker service` (scale, ps, logs)** : https://docs.docker.com/reference/cli/docker/service/
- **Traefik — provider Swarm & routers** : https://doc.traefik.io/traefik/providers/swarm/ · https://doc.traefik.io/traefik/routing/routers/
- **Image Drupal officielle** : https://hub.docker.com/_/drupal · **drush `site:install`** : https://www.drush.org/latest/commands/site_install/
- **Image MariaDB** : https://hub.docker.com/_/mariadb

> 💡 Différence clé avec le TP8 : ici on **ne mappe pas** un port par réplica. Les 3 Drupal sont derrière **l'entrypoint Traefik** (`:80`), et c'est Traefik qui répartit. C'est ce qui rend la montée en charge possible — et c'est aussi pourquoi l'appli doit **partager son état** (base + fichiers) entre réplicas.

---

## 🚀 Pour aller plus loin

1. **HTTPS automatique.** Configurez Traefik avec **Let's Encrypt** (résolveur ACME) pour servir Drupal en HTTPS.
2. **Rolling update.** Changez l'image et `docker service update --image ... tp12_drupal`. Observez la mise à jour **progressive** (`update_config`). Comment éviter toute coupure côté visiteurs ?
3. **Healthcheck applicatif.** Ajoutez un `healthcheck` HTTP au service drupal (ex. `/user/login`). Que fait Swarm d'un réplica *unhealthy* ?
4. **Secrets Swarm.** Remplacez le mot de passe BDD en clair par un `docker secret` monté dans `/run/secrets` (cf. TP10). Pourquoi est-ce plus sûr qu'une variable d'environnement ?
5. **Stockage partagé multi-nœuds.** Sur le cluster de l'Annexe A, le volume `drupal-files` est **local à chaque nœud** : les réplicas ne partagent plus leurs fichiers. Montez un partage **NFS** comme volume Docker et redéployez. Qu'est-ce qui change ?
6. **Réplication de la base.** Notre MariaDB est en 1 réplica (SPOF). Cherchez comment mettre en place une **réplication maître/réplica** (ou Galera). Pourquoi est-ce plus délicat que répliquer un frontal sans état ?

---

## Annexe A — Un vrai cluster à 3 nœuds en local (Docker-in-Docker)

> Optionnel · ~5 min · indépendant du reste du TP (on ne touche pas à votre Docker hôte).

En production, un nœud = une machine. Pas besoin de 3 serveurs ni de VM pour s'entraîner : on lance **3 conteneurs Docker** qui font chacun tourner **leur propre Docker** (image officielle `docker:dind`, « Docker-in-Docker »). Chaque conteneur devient **un nœud** du Swarm.

### A.1 — Démarrer 3 « machines »

Il leur faut un réseau commun pour se parler, et le mode `--privileged` (un daemon Docker complet tourne dedans).

```bash
docker network create swarm-net

for n in node1 node2 node3; do
  docker run -d --privileged --name "$n" --hostname "$n" \
    --network swarm-net docker:29-dind
done

sleep 8                                  # laisse les daemons Docker démarrer
docker ps --filter name=node             # 3 conteneurs « machines » en route
```

> 🧠 `--privileged` est nécessaire **uniquement** pour cet exercice imbriqué. On ne l'utilise jamais pour de vrais services : c'est une porte ouverte sur l'hôte.

### A.2 — Initialiser le manager et récupérer le jeton

On exécute les commandes Swarm **à l'intérieur** de chaque nœud avec `docker exec node1 docker …`.

```bash
# IP de node1 sur le réseau swarm-net (c'est par là que les workers le joindront)
NODE1_IP=$(docker inspect -f '{{ (index .NetworkSettings.Networks "swarm-net").IPAddress }}' node1)

docker exec node1 docker swarm init --advertise-addr "$NODE1_IP"

# le jeton qui autorise un worker à rejoindre le cluster
TOKEN=$(docker exec node1 docker swarm join-token -q worker)
echo "Jeton worker : $TOKEN"
```

> 🧠 Deux jetons existent : `worker` (rejoint pour exécuter des tâches) et `manager` (rejoint **et** participe aux décisions/quorum). Ici node1 reste le seul manager.

### A.3 — Rattacher les 2 workers

```bash
docker exec node2 docker swarm join --token "$TOKEN" "$NODE1_IP:2377"
docker exec node3 docker swarm join --token "$TOKEN" "$NODE1_IP:2377"

docker exec node1 docker node ls          # 🎉 3 lignes : node1 (Leader) + node2 + node3
```

C'est tout : `docker swarm join` est **toute** la procédure d'ajout d'un nœud, que ce soit ici ou sur 3 vrais serveurs. La seule différence en prod : l'IP est celle d'une vraie machine et le port `2377/tcp` doit être ouvert entre elles.

> 📡 **Ports à ouvrir entre nœuds en vrai** : `2377/tcp` (gestion du cluster), `7946/tcp+udp` (découverte des nœuds), `4789/udp` (réseau overlay des conteneurs).

### A.4 — Voir la répartition à l'œuvre

```bash
docker exec node1 docker service create --name web --replicas 6 nginx:alpine
docker exec node1 docker service ps web   # colonne NODE : les 6 réplicas sont étalés sur node1/2/3
```

Vous tenez là ce qu'un seul nœud ne montrait pas : Swarm **place** les réplicas sur plusieurs machines. Coupez un worker et regardez Swarm recaser ses tâches ailleurs :

```bash
docker stop node3
docker exec node1 docker node ls          # node3 = Down
docker exec node1 docker service ps web    # ses réplicas ont été relancés sur node1/node2
```

> ⚠️ **Et notre Drupal là-dedans ?** `nginx` est **sans état**, donc se répartit sans souci. Notre stack Drupal, elle, a besoin que **les 3 réplicas voient la même base et les mêmes fichiers** : sur un vrai cluster, le volume `drupal-files` étant **local à chaque nœud**, il faudrait le remplacer par un **stockage réseau** (NFS/GlusterFS/CSI). C'est LA difficulté du stateful réparti.

### A.5 — Tout démonter

```bash
docker rm -f node1 node2 node3
docker network rm swarm-net
```

> ⚠️ Cette annexe est **isolée** : votre Docker hôte n'a jamais été mis en Swarm. Vous pouvez donc la faire avant **ou** après le TP principal sans rien casser.
