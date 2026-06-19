# TP10 — Mise en production : cluster Swarm + reverse-proxy Traefik

> Durée estimée : 1 h · Ports utilisés : `8090` (web via Traefik), `8091` (dashboard Traefik)
> Prérequis : TP5/TP6 (Compose). C'est l'aboutissement du parcours.

## 🎬 Le contexte

Au TP6, on a vu la limite de `docker compose up --scale` : impossible d'avoir plusieurs instances derrière **un même port**. En production, on veut : **plusieurs réplicas** d'un service (tolérance de panne + montée en charge), **réparties** automatiquement, et **un seul point d'entrée** qui distribue le trafic.

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

> ❓ **Question** : un seul nœud, est-ce encore un « cluster » ? Que faudrait-il pour une vraie tolérance de panne, et comment ajouterait-on un nœud (`docker swarm join`) ?

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

> 💡 Différence clé avec le TP6 : ici on **ne mappe pas** un port par réplica. Tous les réplicas sont derrière **l'entrypoint Traefik** (`:80`), et c'est Traefik (+ le maillage Swarm) qui répartit. C'est ce qui rend la montée en charge possible.

---

## 🚀 Pour aller plus loin

1. **HTTPS automatique.** Configurez Traefik avec **Let's Encrypt** (résolveur ACME) pour servir whoami en HTTPS. Quels enregistrements DNS faudrait-il en vrai ?
2. **Rolling update.** Changez l'image de whoami et `docker service update --image ... tp10_whoami`. Observez la mise à jour **progressive** (`update_config`). Comment éviter toute coupure ?
3. **Healthcheck & reprise.** Ajoutez un `healthcheck` à whoami. Que fait Swarm d'un réplica qui devient *unhealthy* ?
4. **Secrets & configs Swarm.** Injectez un secret avec `docker secret` et montez-le dans le service. En quoi est-ce plus sûr qu'une variable d'environnement (cf. TP6/TP8) ?
5. **Contraintes de placement.** Sur un cluster multi-nœuds, forcez whoami sur les *workers* et Traefik sur le *manager*. Pourquoi cette séparation ?
6. **Swarm vs Kubernetes.** Swarm est simple et intégré ; Kubernetes est le standard de l'industrie. Listez 3 cas où l'un est préférable à l'autre.
