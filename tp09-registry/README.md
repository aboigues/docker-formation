# TP9 — Distribuer ses images : un registre privé

> Durée estimée : 50 min · Ports utilisés : `5000`
> Prérequis : TP4 (construire une image), TP7/TP8 (Compose).

## 🎬 Le contexte

Vos images maison (l'API du TP8, la landing page du TP4…) ne peuvent pas rester sur le portable de chaque développeur. Il faut un **endroit central** pour les **pousser** et les **récupérer** — comme Docker Hub, mais **chez vous**, pour vos images internes (et sans dépendre d'Internet).

C'est le rôle d'un **registre privé**. Vous allez en monter un, le **protéger par mot de passe**, y **pousser** une image, vérifier qu'on ne peut **pas** y accéder sans identifiants, puis la **récupérer** ailleurs.

## 🎯 Objectif vérifiable

Un registre `registry:3` authentifié (htpasswd) qui tourne sur `localhost:5000` : sans identifiants `GET /v2/_catalog` renvoie **401** ; après `docker login`, on **pousse** `demo/alpine:1.0`, le catalogue la liste, et on peut la **re-télécharger** après l'avoir supprimée en local. Les images poussées **survivent** dans un volume nommé. `./verify.sh` contrôle tout cela.

---

## Une note sur HTTP vs HTTPS

En production, un registre **doit** être servi en **HTTPS** (TLS). Ici, on l'expose sur `localhost:5000` : Docker considère `localhost`/`127.0.0.1` comme **sûr** et autorise le HTTP sans certificat. Cela nous permet d'apprendre l'**authentification** (htpasswd) sans la complexité des certificats — qu'on ajouterait en vrai derrière un reverse-proxy.

## ⚠️ Accéder au registre par son **nom d'hôte ou IP** (≠ `localhost`)

Le confort de `localhost` disparaît **dès qu'une autre machine** (ou un autre nom) veut utiliser le registre. C'est le cas réel : un registre interne sert toute l'équipe via `registre.interne:5000` ou `192.168.1.50:5000`, pas via `localhost`.

Or Docker n'accorde le passe-droit HTTP **qu'à** `localhost`/`127.0.0.1`. Pour **toute autre** adresse, il **exige HTTPS** et refuse un registre en HTTP :

```text
$ docker push registre.interne:5000/demo/alpine:1.0
Error response from daemon: Get "https://registre.interne:5000/v2/":
  http: server gave HTTP response to HTTPS client
```

Le message est explicite : le client tente du **HTTPS**, le serveur répond en **HTTP**. Deux solutions :

1. **La bonne (prod)** : servir le registre en **TLS** (certificat, reverse-proxy) — voir « Pour aller plus loin ».
2. **Le contournement (dev / réseau de confiance)** : déclarer le registre comme **`insecure-registries`** dans la configuration du **démon Docker** de **chaque client**. Éditez `/etc/docker/daemon.json` :

   ```json
   {
     "insecure-registries": ["registre.interne:5000"]
   }
   ```

   puis **rechargez le démon** (la config démon n'est lue qu'au démarrage) :

   ```bash
   sudo systemctl restart docker        # Linux avec systemd
   # (Docker Desktop : Settings → Docker Engine → ajouter la clé → Apply & restart)
   ```

   Vérifiez la prise en compte :

   ```bash
   docker info | grep -A2 'Insecure Registries'
   ```

> 🛑 **`insecure-registries` = HTTP en clair, sans authentification de serveur.** Les images (et le `docker login`) transitent **non chiffrées**. À réserver à un **réseau de confiance** (LAN, CI isolée). En production : **TLS, toujours.** C'est aussi pourquoi ce TP reste sur `localhost` — pour ne pas avoir à toucher au démon de votre poste.

## Étape 1 — Générer les identifiants (htpasswd)

Le registre lit un fichier `htpasswd` (utilisateur + mot de passe hashé en **bcrypt**). Plutôt que d'installer `apache2-utils`, on emprunte l'outil `htpasswd` à un conteneur `httpd` jetable :

```bash
cd starter
./make-auth.sh telescope registry_secret      # crée auth/htpasswd
cat auth/htpasswd                              # telescope:$2y$05$....  (hash bcrypt)
```

> ❓ **Question** : pourquoi versionner ce fichier dans Git serait-il une mauvaise idée ? (Regardez le `.gitignore` du TP.)

## Étape 2 — Configurer le registre (`compose.yaml`)

Complétez les `# TODO` :

- **Activer l'auth** via trois variables d'environnement :
  `REGISTRY_AUTH=htpasswd`, `REGISTRY_AUTH_HTPASSWD_REALM="..."`, `REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd`.
- **Monter** `./auth` (en lecture seule) sur `/auth`, et un **volume nommé** `registry-data` sur `/var/lib/registry` (là où le registre stocke les images).

Démarrez-le :

```bash
docker compose up -d
curl -i http://localhost:5000/v2/        # 401 Unauthorized = il est bien protégé ✅
```

> ❓ **Question** : un `401` ici, est-ce une erreur… ou exactement le comportement attendu ? Que prouve-t-il ?

## Étape 3 — Pousser une image (`push.sh`)

Pousser dans un registre privé suit **toujours** trois temps : *login → tag → push*. Le **tag** est crucial : une image n'est poussée vers `localhost:5000` que si son nom **commence** par `localhost:5000/...`.

Complétez les `# TODO` de `push.sh`, puis :

```bash
./push.sh
```

> 🧠 `docker login ... --password-stdin` : on évite de taper le mot de passe en clair dans la ligne de commande (il resterait dans l'historique shell). Réflexe de sécurité.

> ❓ **Question** : que se passe-t-il si vous essayez `docker push alpine:3.23` (sans le préfixe `localhost:5000/`) ? Vers quel registre Docker tente-t-il alors de pousser ?

## Étape 4 — Vérifier et récupérer

```bash
# Le catalogue (authentifié)
curl -s -u telescope:registry_secret http://localhost:5000/v2/_catalog
curl -s -u telescope:registry_secret http://localhost:5000/v2/demo/alpine/tags/list

# Simuler « une autre machine » : on supprime l'image locale puis on la re-télécharge
docker rmi localhost:5000/demo/alpine:1.0
docker pull localhost:5000/demo/alpine:1.0      # revient depuis VOTRE registre
```

## Étape 5 — Prouver la persistance

```bash
docker compose restart
curl -s -u telescope:registry_secret http://localhost:5000/v2/_catalog   # toujours là
```

> ❓ **Question** : grâce à quoi l'image est-elle toujours présente après un redémarrage du conteneur ? (Indice : le `volumes:` du registre.)

## Étape 6 — Validez, puis démontez

```bash
cd ..
./verify.sh              # teste VOTRE travail (dossier starter/)
./verify.sh solution     # (option) rejoue la solution de référence
```

```bash
cd starter && docker compose down -v && rm -rf auth
docker logout localhost:5000
```

---

## 🌍 Bonus — Pousser **votre** image sur Docker Hub

Vous venez de monter un registre **privé**. Docker Hub, c'est le **même mécanisme**, mais **public** et hébergé : le registre par défaut de Docker. Le trio reste identique — *login → tag → push* — seul le **préfixe du tag** change. Sur `localhost:5000` on préfixait par l'adresse du registre ; sur Docker Hub, le préfixe est simplement **votre nom d'utilisateur**.

### 1. Créer un compte

1. Allez sur **https://hub.docker.com** et créez un compte gratuit. Le nom d'utilisateur choisi **est** votre espace de noms : toutes vos images s'appelleront `votre-user/…` (remplacez `votre-user` par votre identifiant Docker Hub dans les commandes ci-dessous).
2. Confirmez votre adresse e-mail.

### 2. Créer un jeton d'accès (recommandé)

Plutôt que votre mot de passe de compte, utilisez un **Personal Access Token** : il est **révocable** et se limite au push/pull, sans donner accès aux réglages du compte.

- Docker Hub → **Account settings → Personal access tokens → Generate new token**.
- Portée **Read & Write**, copiez le jeton (il ne s'affiche **qu'une fois**).

### 3. Se connecter

`docker login` **sans adresse** vise Docker Hub par défaut :

```bash
docker login -u votre-user           # colle le jeton quand le mot de passe est demandé
# ou, sans laisser le secret dans l'historique shell :
echo "$DOCKERHUB_TOKEN" | docker login -u votre-user --password-stdin
```

### 4. Taguer avec votre nom d'utilisateur

Le tag doit commencer par `votre-user/`. Reprenons l'image du TP :

```bash
docker tag localhost:5000/demo/alpine:1.0 votre-user/demo-alpine:1.0
```

> 💡 Ici **pas de préfixe d'hôte** (`localhost:5000/…`) : sans hôte, Docker vise Docker Hub. `votre-user/demo-alpine:1.0` = registre Docker Hub, dépôt `votre-user/demo-alpine`, tag `1.0`.

### 5. Pousser

```bash
docker push votre-user/demo-alpine:1.0
```

Votre image est en ligne : **n'importe qui** peut désormais faire `docker pull votre-user/demo-alpine:1.0` (un dépôt est **public** par défaut).

### 6. Vérifier et nettoyer

```bash
# Simuler une autre machine
docker rmi votre-user/demo-alpine:1.0
docker pull votre-user/demo-alpine:1.0     # revient depuis Docker Hub
docker logout
```

Sur **hub.docker.com**, votre dépôt apparaît dans **Repositories**. Vous pouvez y ajouter une description, et le passer en **privé** dans **Settings** (le plan gratuit inclut des dépôts privés).

> ❓ **Question** : quelle est la différence de visibilité entre pousser sur `localhost:5000` (TP) et sur `votre-user/…` (Docker Hub) ? Dans quels cas préférer l'un ou l'autre ?

> 🛑 **Ne poussez jamais** d'image contenant des secrets (clés, mots de passe, `.env`) sur un dépôt public — elle devient consultable et téléchargeable par tous, et un tag « supprimé » peut rester dans des caches. C'est la même prudence que le `.gitignore` de l'étape 1.

> 📌 **Rate limits.** Docker Hub applique des **quotas de pull** pour les utilisateurs anonymes ; s'authentifier (`docker login`) relève ces limites. C'est l'une des raisons d'être d'un registre privé ou d'un cache pull-through (voir « Pour aller plus loin »).

---

## 💡 Indices

<details>
<summary>Le bloc environment du registre</summary>

```yaml
    environment:
      REGISTRY_AUTH: htpasswd
      REGISTRY_AUTH_HTPASSWD_REALM: "Registre interne Telescope"
      REGISTRY_AUTH_HTPASSWD_PATH: /auth/htpasswd
```
</details>

<details>
<summary>Le trio login / tag / push</summary>

```bash
echo "registry_secret" | docker login localhost:5000 -u telescope --password-stdin
docker pull alpine:3.23
docker tag  alpine:3.23 localhost:5000/demo/alpine:1.0
docker push localhost:5000/demo/alpine:1.0
```
</details>

---

## 📖 Où chercher (documentation officielle)

- **Déployer un registre (`registry`)** : https://distribution.github.io/distribution/
- **Authentification htpasswd du registre** : https://distribution.github.io/distribution/about/deploying/#native-basic-auth
- **`docker login` / `--password-stdin`** : https://docs.docker.com/reference/cli/docker/login/
- **`docker tag` (nommage & registre cible)** : https://docs.docker.com/reference/cli/docker/image/tag/
- **`docker push` / `docker pull`** : https://docs.docker.com/reference/cli/docker/image/push/
- **API HTTP V2 du registre (`/v2/_catalog`, `/tags/list`)** : https://distribution.github.io/distribution/spec/api/
- **Registre non sécurisé (`insecure-registries`, `daemon.json`)** : https://docs.docker.com/reference/cli/dockerd/#insecure-registries · https://docs.docker.com/engine/security/protect-access/
- **Docker Hub (dépôts, visibilité)** : https://docs.docker.com/docker-hub/repos/
- **Jetons d'accès personnels Docker Hub** : https://docs.docker.com/security/for-developers/access-tokens/
- **Quotas de pull Docker Hub (rate limits)** : https://docs.docker.com/docker-hub/usage/

> 💡 Le préfixe du tag **EST** l'adresse du registre : `localhost:5000/demo/alpine:1.0` → registre `localhost:5000`, dépôt `demo/alpine`, tag `1.0`. Sans préfixe d'hôte, Docker vise Docker Hub par défaut.

---

## 🚀 Pour aller plus loin

1. **Portainer.** Lancez `portainer/portainer-ce` (port `9443`) à côté du registre et explorez vos conteneurs/images/volumes via une **interface web**. Dans quels cas une UI est-elle utile à une équipe, et quand la CLI reste-t-elle reine ?
2. **Interface de registre.** Ajoutez `joxit/docker-registry-ui` pour parcourir le contenu du registre dans le navigateur. Branchez-la sur votre registre authentifié.
3. **Nettoyage (garbage collection).** Poussez deux fois la même image avec des tags différents, puis lisez la doc sur le `registry garbage-collect`. Pourquoi un registre grossit-il même quand on « supprime » des tags ?
4. **TLS pour de vrai.** Placez un reverse-proxy (Caddy ou Nginx) devant le registre pour le servir en HTTPS avec un certificat. Qu'est-ce qui change côté client par rapport au mode `localhost` ?
5. **Cache pull-through.** Configurez le registre en **miroir** de Docker Hub (`REGISTRY_PROXY_REMOTEURL`). En quoi cela accélère-t-il les builds d'une équipe et réduit-il les *rate limits* Docker Hub ?
