# TP1 — Votre première application conteneurisée

> **Jour 1** · Durée estimée : 45 min · Ports utilisés : `8081`

## 🎬 Le contexte

Votre équipe doit mettre en ligne la **landing page** d'un nouveau produit, « Telemach Cloud ». Aujourd'hui, la page est livrée « à la main » sur un serveur — fragile et non reproductible. Votre mission : **emballer cette page dans une image Docker** pour pouvoir la déployer n'importe où, à l'identique, en une commande.

À la fin de ce TP, vous saurez : lancer un conteneur, servir des fichiers depuis l'hôte, puis **construire votre propre image** avec un `Dockerfile`.

## 🎯 Objectif vérifiable

Une image `telemach-landing` qui, une fois lancée, sert la landing page sur le port 8081, et répond `200` avec le titre du produit. C'est ce que `./verify.sh` (et la CI) contrôle.

---

## Étape 1 — Docker répond-il ?

Avant tout, le rituel de vérification. Tapez (ne copiez pas mécaniquement : **lisez chaque sortie**) :

```bash
docker version
docker run --rm hello-world
```

> ❓ **Question** : dans la sortie de `docker version`, repérez les **deux** blocs `Client` et `Server`. Pourquoi y en a-t-il deux ? (Indice : architecture client/daemon.)

`hello-world` s'est lancé puis arrêté : c'est normal, son seul rôle est d'afficher un message. L'option `--rm` a supprimé le conteneur après son exécution.

## Étape 2 — Servir la page SANS rien construire (bind mount)

La page existe déjà dans `starter/site/index.html`. On va d'abord la servir avec une image `nginx` **standard**, en lui **montant** notre dossier. Depuis le dossier `starter/` :

```bash
cd starter
docker run -d --name landing-test \
  -p 8081:80 \
  -v "$(pwd)/site:/usr/share/nginx/html:ro" \
  nginx:1.30-alpine
```

Ouvrez http://localhost:8081 (ou `curl -s http://localhost:8081 | head`).

> ❓ **Question** : modifiez une ligne dans `site/index.html`, rechargez la page. Le changement apparaît-il **sans** reconstruire ni relancer le conteneur ? Pourquoi ? (Indice : `:ro` = read-only, et le bind mount pointe vers vos fichiers.)

Nettoyez avant l'étape suivante :

```bash
docker rm -f landing-test
```

> 🧠 **Ce qu'on vient de voir** : le bind mount est parfait en **développement** (édition en direct). Mais il **lie** le conteneur à l'arborescence de votre machine : impossible de déployer ailleurs tel quel. D'où l'étape suivante.

## Étape 3 — Construire une vraie image (à vous de jouer)

Ouvrez `starter/Dockerfile`. Il est **incomplet** : complétez les `# TODO`. Vous devez :

1. partir de l'image de base `nginx:1.30-alpine` ;
2. copier le contenu de `site/` dans le dossier servi par nginx (`/usr/share/nginx/html/`) ;
3. documenter le port exposé (80) ;
4. ajouter un `LABEL` d'auteur (pas de `MAINTAINER`, qui est déprécié).

Puis construisez et lancez **votre** image :

```bash
docker build -t telemach-landing:1.0 .
docker run -d --name landing -p 8081:80 telemach-landing:1.0
curl -s http://localhost:8081 | grep "Telemach"
```

> ❓ **Question** : relancez `docker build` une 2ᵉ fois sans rien changer. Pourquoi est-ce **instantané** ? (Indice : cache de couches.)

Nettoyez :

```bash
docker rm -f landing
```

## Étape 4 — Validez votre travail

Depuis le dossier du TP :

```bash
./verify.sh
```

Le script construit l'image de la **solution**, la lance, vérifie la réponse HTTP et le contenu, puis nettoie tout. Tant que vous n'avez pas le ✅, votre TP n'est pas terminé.

---

## 💡 Indices (si vous êtes bloqué·e)

<details>
<summary>L'instruction pour copier des fichiers locaux dans l'image ?</summary>

C'est `COPY <source_locale> <destination_dans_l_image>`. La source est relative au **contexte de build** (le dossier du `docker build .`).
</details>

<details>
<summary>« COPY failed: no source files » ?</summary>

Vérifiez que vous lancez `docker build` **depuis le dossier qui contient `site/`**, et que le chemin source dans `COPY` correspond bien (`site/` et non `./starter/site/`).
</details>

---

## 🚀 Pour aller plus loin

> Réservé à celles et ceux qui ont terminé en avance. Chaque défi est **indépendant**.

1. **Pesez votre image.** `docker images telemach-landing:1.0`. Comparez avec `nginx:1.30` (sans `-alpine`). Combien de Mo économisés grâce à Alpine ?
2. **Healthcheck.** Ajoutez une instruction `HEALTHCHECK` au Dockerfile qui fait un `wget`/`curl` sur `http://localhost/`. Lancez le conteneur et observez la colonne `STATUS` de `docker ps` passer à `(healthy)`.
3. **Page d'erreur personnalisée.** Ajoutez une page `404.html` et configurez nginx (`error_page 404 /404.html;`) via un fichier de conf monté ou copié. Testez avec `curl -i http://localhost:8081/inexistant`.
4. **Versionnez par tag.** Construisez `telemach-landing:1.1` après une modif, gardez `:1.0`. Listez les deux. Comment revenir à la `1.0` en cas de problème ?
5. **Build arg.** Injectez la date de build via `ARG BUILD_DATE` + `LABEL`, et passez-la avec `--build-arg BUILD_DATE=$(date -I)`. Vérifiez avec `docker inspect`.

> Les solutions de l'approfondissement ne sont pas fournies : c'est l'occasion de fouiller la doc officielle `docs.docker.com`.
