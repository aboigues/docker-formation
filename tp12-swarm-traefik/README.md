# TP12 — Mise en production : cluster Swarm + reverse-proxy Traefik

> Durée estimée : 1 h · Ports utilisés : `8090` (web via Traefik), `8091` (dashboard Traefik)
> Prérequis : TP4/TP8 (Compose). C'est l'aboutissement du parcours.

## 🎬 Le contexte

Au TP8, on a vu la limite de `docker compose up --scale` : impossible d'avoir plusieurs instances derrière **un même port**. En production, on veut : **plusieurs réplicas** d'un service (tolérance de panne + montée en charge), **réparties** automatiquement, et **un seul point d'entrée** qui distribue le trafic.

C'est le rôle d'un **orchestrateur** (ici **Docker Swarm**, intégré à Docker) couplé à un **reverse-proxy** (ici **Traefik**) qui découvre les services **automatiquement** et route selon le nom de domaine.

Cas réel : exposer une API en **3 réplicas** derrière une seule URL, sans recharger le proxy à chaque déploiement.

## 🎯 Objectif vérifiable

Un Swarm actif, une stack déployée avec `docker stack deploy`, un service `whoami` en **3/3 réplicas**, joignable via Traefik sur `Host(\`whoami.localhost\`)`, avec **répartition de charge** visible (plusieurs réplicas répondent) et le routeur enregistré dans l'API Traefik. `./verify.sh` contrôle tout cela.

---

## Swarm vs Compose, en une phrase

| | Docker Compose | Docker Swarm |
|--|----------------|--------------|
| Cible | **une** machine (dev) | un **cluster** (prod) |
| Commande | `docker compose up` | `docker stack deploy` |
| Réplicas/HA | non | **oui** (`replicas`, reprise auto) |
| Clé spécifique | — | bloc **`deploy:`** |

## Étape 1 — Activer le mode Swarm

```bash
docker swarm init                 # transforme votre Docker en manager d'un cluster (à 1 nœud)
docker node ls                    # vous êtes « Leader »
```

Un seul nœud suffit pour tout le reste du TP (Traefik, réplicas, résilience). Mais « cluster à 1 nœud », ça reste un cluster… de poche. Pour **voir** ce qu'apporte vraiment Swarm — des réplicas répartis sur **plusieurs machines** —, faites l'**[Annexe A](#annexe-a--un-vrai-cluster-à-3-nœuds-en-local-docker-in-docker)** : on monte un cluster à 3 nœuds en 5 minutes, sur votre seule machine, sans VM.

> ❓ **Question** : un seul nœud, est-ce encore un « cluster » ? Que faudrait-il pour une vraie tolérance de panne ?

## Étape 2 — Compléter la stack (`stack.yml`)

Ouvrez `starter/stack.yml`. Le service `traefik` est fourni ; complétez le service `whoami` (**TODO**) :

- **TODO 1** : `replicas: 3` ;
- **TODO 2** : les 4 labels Traefik (sous `deploy.labels`, car en Swarm c'est le **service** qui porte les labels, pas le conteneur) :
  - `traefik.enable=true`
  - `traefik.http.routers.whoami.rule=Host(\`whoami.localhost\`)`
  - `traefik.http.routers.whoami.entrypoints=web`
  - `traefik.http.services.whoami.loadbalancer.server.port=80`

> 🧠 Traefik **découvre** whoami tout seul en lisant l'API Swarm (socket Docker monté). Aucun fichier de conf de proxy à éditer : on **décrit** le routage sur le service lui-même.

## Étape 3 — Déployer et observer

```bash
docker stack deploy -c starter/stack.yml tp10
docker stack services tp10            # whoami doit passer à 3/3
docker service ps tp10_whoami         # sur quel(s) nœud(s) tournent les réplicas
```

## Étape 4 — Tester le routage et la répartition de charge

Le routage se fait sur l'en-tête **Host**. Comme on n'a pas de vrai DNS, on le simule avec `curl` :

```bash
# Plusieurs appels : le « Hostname » renvoyé change = on tombe sur des réplicas différents
for i in $(seq 1 6); do
  curl -s -H "Host: whoami.localhost" http://localhost:8090/ | grep Hostname
done
```

Ouvrez le **dashboard Traefik** : http://localhost:8091 → vous y voyez le routeur `whoami` et ses 3 cibles.

> ❓ **Question** : pourquoi le `Hostname:` renvoyé change-t-il d'un appel à l'autre ? Qui décide vers quel réplica va chaque requête ?

## Étape 5 — Éprouver la résilience (le moment « waouh »)

```bash
docker service scale tp10_whoami=5      # passe à 5 réplicas À CHAUD
# tuez un conteneur whoami au hasard :
docker rm -f "$(docker ps --filter name=tp10_whoami -q | head -1)"
docker service ps tp10_whoami           # Swarm en a relancé un AUTOMATIQUEMENT
```

> 🧠 C'est la promesse de l'orchestrateur : l'**état désiré** (« je veux 5 whoami ») est maintenu malgré les pannes, sans intervention humaine.

## Étape 6 — Validez, puis démontez

```bash
cd ..
./verify.sh
```

```bash
docker stack rm tp10
docker swarm leave --force      # ⚠️ quitte le mode Swarm sur votre machine
```

---

## 💡 Indices

<details>
<summary>Le bloc deploy de whoami</summary>

```yaml
    deploy:
      replicas: 3
      labels:
        - traefik.enable=true
        - traefik.http.routers.whoami.rule=Host(`whoami.localhost`)
        - traefik.http.routers.whoami.entrypoints=web
        - traefik.http.services.whoami.loadbalancer.server.port=80
```
</details>

<details>
<summary>« nothing found in stack » ou whoami à 0/3 ?</summary>

Regardez `docker service ps tp10_whoami --no-trunc` : souvent l'image met quelques secondes à être tirée, ou une contrainte de placement bloque. Vérifiez aussi que vous êtes bien `docker node ls` = manager.
</details>

---

## 📖 Où chercher (documentation officielle)

- **Démarrer avec Swarm** : https://docs.docker.com/engine/swarm/swarm-tutorial/
- **`docker stack deploy` & format `deploy:`** : https://docs.docker.com/reference/cli/docker/stack/deploy/ · https://docs.docker.com/reference/compose-file/deploy/
- **`docker service` (scale, ps, logs)** : https://docs.docker.com/reference/cli/docker/service/
- **Traefik — provider Swarm** : https://doc.traefik.io/traefik/providers/swarm/
- **Traefik — routers & règles (`Host`)** : https://doc.traefik.io/traefik/routing/routers/
- **Traefik — labels de service** : https://doc.traefik.io/traefik/reference/dynamic-configuration/docker/

> 💡 Différence clé avec le TP8 : ici on **ne mappe pas** un port par réplica. Tous les réplicas sont derrière **l'entrypoint Traefik** (`:80`), et c'est Traefik (+ le maillage Swarm) qui répartit. C'est ce qui rend la montée en charge possible.

---

## 🚀 Pour aller plus loin

1. **HTTPS automatique.** Configurez Traefik avec **Let's Encrypt** (résolveur ACME) pour servir whoami en HTTPS. Quels enregistrements DNS faudrait-il en vrai ?
2. **Rolling update.** Changez l'image de whoami et `docker service update --image ... tp10_whoami`. Observez la mise à jour **progressive** (`update_config`). Comment éviter toute coupure ?
3. **Healthcheck & reprise.** Ajoutez un `healthcheck` à whoami. Que fait Swarm d'un réplica qui devient *unhealthy* ?
4. **Secrets & configs Swarm.** Injectez un secret avec `docker secret` et montez-le dans le service. En quoi est-ce plus sûr qu'une variable d'environnement (cf. TP8/TP10) ?
5. **Contraintes de placement.** Sur un cluster multi-nœuds, forcez whoami sur les *workers* et Traefik sur le *manager*. Pourquoi cette séparation ?
6. **Swarm vs Kubernetes.** Swarm est simple et intégré ; Kubernetes est le standard de l'industrie. Listez 3 cas où l'un est préférable à l'autre.

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

### A.5 — Tout démonter

```bash
docker rm -f node1 node2 node3
docker network rm swarm-net
```

> ⚠️ Cette annexe est **isolée** : votre Docker hôte n'a jamais été mis en Swarm. Vous pouvez donc la faire avant **ou** après le TP principal sans rien casser.
