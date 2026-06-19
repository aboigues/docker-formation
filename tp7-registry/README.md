# TP7 — Distribuer ses images : un registre privé

> Durée estimée : 50 min · Ports utilisés : `5000`
> Prérequis : TP3 (construire une image), TP5/TP6 (Compose).

## 🎬 Le contexte

Vos images maison (l'API du TP6, la landing page du TP3…) ne peuvent pas rester sur le portable de chaque développeur. Il faut un **endroit central** pour les **pousser** et les **récupérer** — comme Docker Hub, mais **chez vous**, pour vos images internes (et sans dépendre d'Internet).

C'est le rôle d'un **registre privé**. Vous allez en monter un, le **protéger par mot de passe**, y **pousser** une image, vérifier qu'on ne peut **pas** y accéder sans identifiants, puis la **récupérer** ailleurs.

## 🎯 Objectif vérifiable

Un registre `registry:3` authentifié (htpasswd) qui tourne sur `localhost:5000` : sans identifiants `GET /v2/_catalog` renvoie **401** ; après `docker login`, on **pousse** `demo/alpine:1.0`, le catalogue la liste, et on peut la **re-télécharger** après l'avoir supprimée en local. Les images poussées **survivent** dans un volume nommé. `./verify.sh` contrôle tout cela.

---

## Une note sur HTTP vs HTTPS

En production, un registre **doit** être servi en **HTTPS** (TLS). Ici, on l'expose sur `localhost:5000` : Docker considère `localhost`/`127.0.0.1` comme **sûr** et autorise le HTTP sans certificat. Cela nous permet d'apprendre l'**authentification** (htpasswd) sans la complexité des certificats — qu'on ajouterait en vrai derrière un reverse-proxy.

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
./verify.sh
```

```bash
cd starter && docker compose down -v && rm -rf auth
docker logout localhost:5000
```

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

> 💡 Le préfixe du tag **EST** l'adresse du registre : `localhost:5000/demo/alpine:1.0` → registre `localhost:5000`, dépôt `demo/alpine`, tag `1.0`. Sans préfixe d'hôte, Docker vise Docker Hub par défaut.

---

## 🚀 Pour aller plus loin

1. **Portainer.** Lancez `portainer/portainer-ce` (port `9443`) à côté du registre et explorez vos conteneurs/images/volumes via une **interface web**. Dans quels cas une UI est-elle utile à une équipe, et quand la CLI reste-t-elle reine ?
2. **Interface de registre.** Ajoutez `joxit/docker-registry-ui` pour parcourir le contenu du registre dans le navigateur. Branchez-la sur votre registre authentifié.
3. **Nettoyage (garbage collection).** Poussez deux fois la même image avec des tags différents, puis lisez la doc sur le `registry garbage-collect`. Pourquoi un registre grossit-il même quand on « supprime » des tags ?
4. **TLS pour de vrai.** Placez un reverse-proxy (Caddy ou Nginx) devant le registre pour le servir en HTTPS avec un certificat. Qu'est-ce qui change côté client par rapport au mode `localhost` ?
5. **Cache pull-through.** Configurez le registre en **miroir** de Docker Hub (`REGISTRY_PROXY_REMOTEURL`). En quoi cela accélère-t-il les builds d'une équipe et réduit-il les *rate limits* Docker Hub ?
