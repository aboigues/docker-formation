# TP1 — Premiers pas avec Docker

> Durée estimée : 30 min · Ports utilisés : `8081`

## 🎬 Le contexte

C'est votre **tout premier contact** avec Docker. Pas de panique : on ne construit rien aujourd'hui. On apprend simplement à **faire tourner des conteneurs déjà prêts**, à les observer et à les manipuler — comme on apprendrait à conduire avant de réparer un moteur.

À la fin de ce TP, vous saurez : lancer un conteneur, le voir vivre, l'arrêter, le supprimer, et utiliser une image téléchargée depuis Docker Hub. **Aucun fichier à écrire.**

## 🎯 Objectif vérifiable

Savoir lancer un serveur web `nginx` (image officielle) et le rendre accessible dans votre navigateur, puis maîtriser le cycle de vie d'un conteneur. `./verify.sh` rejoue ce scénario de base et confirme que votre environnement Docker fonctionne.

---

## Étape 1 — Dire bonjour 👋

La toute première commande de tout débutant Docker :

```bash
docker run hello-world
```

Lisez le message affiché : il explique **ce que Docker vient de faire** (le client a contacté le daemon, qui a téléchargé une image puis lancé un conteneur).

> ❓ **Question** : d'où vient l'image `hello-world` ? (Indice : le message le dit — un « registry ».)

## Étape 2 — Lancer un vrai serveur web

On lance maintenant **nginx**, un serveur web très répandu, à partir de son image officielle. On le met en arrière-plan (`-d`) et on **publie** son port :

```bash
docker run -d --name mon-serveur -p 8081:80 nginx:1.30-alpine
```

Ouvrez http://localhost:8081 dans votre navigateur (ou `curl http://localhost:8081`). Vous voyez la page d'accueil de nginx : **bravo, vous hébergez un serveur web** !

Décortiquons la commande :

| Morceau | Signification |
|---------|---------------|
| `-d` | *detached* : tourne en arrière-plan |
| `--name mon-serveur` | un nom lisible (sinon Docker en invente un) |
| `-p 8081:80` | publie le port 80 du conteneur sur le 8081 de votre machine |
| `nginx:1.30-alpine` | l'image à utiliser (et sa version) |

> ❓ **Question** : si vous lancez `docker run -d -p 9090:80 nginx:1.30-alpine`, sur quelle adresse verrez-vous nginx ? Pourquoi le port de gauche (hôte) peut-il être différent du port de droite (conteneur) ?

## Étape 3 — Observer le conteneur

```bash
docker ps                 # les conteneurs EN COURS d'exécution
docker logs mon-serveur   # ce que le serveur a écrit
docker stats --no-stream  # consommation CPU / RAM
```

## Étape 4 — Le cycle de vie

Manipulez l'état du conteneur et **observez `docker ps` après chaque commande** :

```bash
docker stop mon-serveur      # arrêt → disparaît de `docker ps`
docker ps -a                 # -a montre AUSSI les conteneurs arrêtés
docker start mon-serveur     # redémarrage
docker restart mon-serveur   # arrêt + démarrage
```

> ❓ **Question** : après `docker stop`, le conteneur a-t-il disparu, ou est-il seulement arrêté ? Quelle commande le prouve ?

## Étape 5 — Faire le ménage

```bash
docker rm -f mon-serveur     # -f force la suppression même s'il tourne
docker ps -a                 # il n'apparaît plus
```

> 🧠 **Conteneur ≠ image.** Vous venez de supprimer le **conteneur** (l'instance). L'**image** `nginx:1.30-alpine`, elle, est toujours téléchargée sur votre machine : `docker images`. On la réutilisera sans la retélécharger.

## Étape 6 — Explorer les images

```bash
docker images                       # images présentes localement
docker pull httpd:2.4               # télécharger une autre image (Apache)
docker search postgres              # chercher des images sur Docker Hub
```

## Étape 7 — Validez

```bash
./verify.sh
```

Le script rejoue le scénario (hello-world, lancement de nginx, vérification HTTP, cycle de vie) et nettoie tout. Le ✅ confirme que votre Docker est opérationnel — vous êtes prêt·e pour la suite.

---

## 📖 Où chercher (documentation officielle)

- **Premiers pas / `docker run`** : https://docs.docker.com/get-started/ et https://docs.docker.com/reference/cli/docker/container/run/
- **Publier des ports (`-p`)** : https://docs.docker.com/engine/network/#published-ports
- **Cycle de vie des conteneurs** : https://docs.docker.com/reference/cli/docker/container/
- **Trouver des images** : https://hub.docker.com (et `docker search`)
- **S'entraîner sans rien installer** : https://labs.play-with-docker.com

> 💡 Réflexe à prendre : la **doc officielle `docs.docker.com`** est la source de vérité. Chaque commande a sa page de référence (`docker <commande> --help` aussi).

---

## 🚀 Pour aller plus loin

> Réservé à celles et ceux qui ont terminé en avance.

1. **Mode interactif.** Lancez un Ubuntu et entrez dedans : `docker run -it ubuntu:24.04 bash`. Tapez `cat /etc/os-release`, puis `exit`. Vous étiez « dans » un conteneur Linux complet.
2. **Auto-nettoyage.** Relancez hello-world avec `docker run --rm hello-world`. Quelle différence voyez-vous dans `docker ps -a` ? À quoi sert `--rm` ?
3. **Port aléatoire.** Lancez nginx avec `-P` (majuscule) au lieu de `-p 8081:80`. Puis `docker port <nom>` : quel port l'hôte a-t-il choisi ?
4. **Deux serveurs en même temps.** Lancez deux nginx sur deux ports différents (8081 et 8082). Pourquoi ne peut-on PAS les mettre tous les deux sur 8081 ?
5. **Variables d'environnement.** Lancez `docker run -d -e POSTGRES_PASSWORD=demo postgres:18` et lisez `docker logs` : la base démarre. Cherchez sur Docker Hub la liste des variables supportées par l'image `postgres`.
