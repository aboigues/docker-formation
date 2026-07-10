# TP4 — Construire sa première image

> Durée estimée : 45 min · Ports utilisés : `8081`
> Prérequis : TP1 à TP3 (lancer des conteneurs, maîtriser la CLI, monter une stack multi-conteneurs à la main).

## 🎬 Le contexte

Jusqu'ici, vous avez **utilisé** des images toutes faites (`nginx`, `hello-world`). Aujourd'hui, vous allez en **fabriquer une**.

Votre équipe doit mettre en ligne la **landing page** d'un nouveau produit, « Telemach Cloud ». Aujourd'hui, la page est livrée « à la main » sur un serveur — fragile et non reproductible. Votre mission : **emballer cette page dans une image Docker** pour la déployer n'importe où, à l'identique, en une commande.

À la fin de ce TP, vous saurez : servir des fichiers depuis l'hôte (bind mount), puis **écrire un `Dockerfile`** pour construire votre propre image autonome.

## 🎯 Objectif vérifiable

Une image `telemach-landing` qui, une fois lancée, sert la landing page sur le port 8081 et répond `200` avec le titre du produit. C'est ce que `./verify.sh` (et la CI) contrôle.

---

## Étape 1 — Servir la page SANS rien construire (bind mount)

La page existe déjà dans `starter/site/index.html`. On la sert d'abord avec une image `nginx` **standard**, en lui **montant** notre dossier. Depuis `starter/` :

```bash
cd starter
docker run -d --name landing-test \
  -p 8081:80 \
  -v "$(pwd)/site:/usr/share/nginx/html:ro" \
  nginx:1.30-alpine
```

Ouvrez http://localhost:8081 (ou `curl -s http://localhost:8081 | head`).

> ❓ **Question** : modifiez une ligne dans `site/index.html`, rechargez la page. Le changement apparaît-il **sans** reconstruire ni relancer le conteneur ? Pourquoi ? (Indice : le bind mount pointe vers vos fichiers réels.)

Nettoyez avant l'étape suivante :

```bash
docker rm -f landing-test
```

> 🧠 Le bind mount est parfait en **développement** (édition en direct). Mais il **lie** le conteneur à l'arborescence de votre machine : impossible de déployer ailleurs tel quel. D'où l'étape suivante — **construire une image autonome**.

## Étape 2 — Écrire le Dockerfile (à vous de jouer)

Ouvrez `starter/Dockerfile`. Il est **incomplet** : complétez les `# TODO`. Vous devez :

1. partir de l'image de base `nginx:1.30-alpine` (instruction `FROM`) ;
2. copier le contenu de `site/` dans le dossier servi par nginx (`/usr/share/nginx/html/`) ;
3. documenter le port exposé (80) ;
4. ajouter un `LABEL` d'auteur (l'instruction `MAINTAINER` est **dépréciée**).

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

## Étape 3 — Validez votre travail

Depuis le dossier du TP :

```bash
./verify.sh              # teste VOTRE travail (dossier starter/)
./verify.sh solution     # (option) rejoue la solution de référence
```

Le script construit l'image de **votre** dossier `starter/`, la lance, vérifie la réponse HTTP et le contenu, puis nettoie tout. Tant que vous n'avez pas le ✅, votre TP n'est pas terminé.

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

## 📖 Où chercher (documentation officielle)

- **Référence complète du Dockerfile** (toutes les instructions) : https://docs.docker.com/reference/dockerfile/
- **`FROM`** (image de base) : https://docs.docker.com/reference/dockerfile/#from
- **`COPY`** (copier des fichiers) : https://docs.docker.com/reference/dockerfile/#copy
- **`EXPOSE`** / **`LABEL`** : https://docs.docker.com/reference/dockerfile/#expose · https://docs.docker.com/reference/dockerfile/#label
- **`docker build`** : https://docs.docker.com/reference/cli/docker/buildx/build/
- **Bonnes pratiques de Dockerfile** : https://docs.docker.com/build/building/best-practices/

> 💡 Astuce : `docker build` affiche un **avertissement** si vous utilisez une instruction dépréciée (comme `MAINTAINER`). Lisez ces avertissements !

---

## 🚀 Pour aller plus loin

> Chaque défi est **indépendant**.

1. **Pesez votre image.** `docker images telemach-landing:1.0`. Comparez avec `nginx:1.30` (sans `-alpine`). Combien de Mo économisés grâce à Alpine ?
2. **Healthcheck.** Ajoutez une instruction `HEALTHCHECK` au Dockerfile (un `wget`/`curl` sur `http://localhost/`). Lancez le conteneur et observez la colonne `STATUS` de `docker ps` passer à `(healthy)`. → doc : https://docs.docker.com/reference/dockerfile/#healthcheck
3. **Page d'erreur personnalisée.** Ajoutez une page `404.html` et configurez nginx (`error_page 404 /404.html;`). Testez avec `curl -i http://localhost:8081/inexistant`.
4. **Versionnez par tag.** Construisez `telemach-landing:1.1` après une modif, gardez `:1.0`. Listez les deux. Comment revenir à la `1.0` en cas de problème ?
5. **Build arg.** Injectez la date de build via `ARG BUILD_DATE` + `LABEL`, et passez-la avec `--build-arg BUILD_DATE=$(date -I)`. Vérifiez avec `docker inspect`. → doc : https://docs.docker.com/reference/dockerfile/#arg


---

<div align="center">

**[Telemach Learning](https://www.telemach-learning.fr)** — Formations DevOps, Cloud & Conteneurs

🌐 [www.telemach-learning.fr](https://www.telemach-learning.fr)

© 2026 Telemach Learning — Code formation DEVOPS-001

</div>
