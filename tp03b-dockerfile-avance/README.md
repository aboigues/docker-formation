# TP3b — Dockerfile avancé : multi-stage build

> Durée estimée : 50 min · Port utilisé : `8088`
> Prérequis : avoir fait le **TP3** (écrire un premier `Dockerfile`).
> Ce TP approfondit le chapitre **« Créer ses propres images »** du jour 1 (couches, cache, multi-stage, non-root).

## 🎬 Le contexte

Au TP3, vous avez emballé des fichiers statiques dans une image nginx : aucun **build** n'était nécessaire. Mais la plupart des applis doivent être **compilées** (Go, Java, TypeScript…) avant d'être exécutées.

La tentation est d'embarquer la **toolchain de compilation** dans l'image finale. Résultat : une image obèse (~490 Mo), lente à transférer et truffée d'outils inutiles en production — autant de **surface d'attaque** en plus.

Votre mission : conteneuriser une petite API « Telemach Cloud » (un binaire Go) avec un **multi-stage build**, pour obtenir une image finale qui ne contient **que le binaire** — quelques mégaoctets, sans compilateur, sans shell.

À la fin de ce TP, vous saurez : enchaîner plusieurs étapes `FROM ... AS`, récupérer un artefact avec `COPY --from=`, repartir de `scratch`, injecter une version au build et tourner **sans privilèges root**.

## 🎯 Objectif vérifiable

Une image `tp3b-api` qui :
1. répond `200` sur `/healthz` et affiche **« Telemach Cloud »** sur `/` (port 8088) ;
2. expose la **version injectée au build** sur `/version` ;
3. pèse **moins de 25 Mo** — la preuve que la toolchain de build n'a **pas** fui dans l'image finale.

C'est exactement ce que `./verify.sh` (et la CI) contrôle.

---

## Étape 0 — Mesurer le problème (l'image obèse)

Pour comprendre l'intérêt du multi-stage, construisez d'abord la version **naïve** (mono-étage) fournie. Depuis `solution/` :

```bash
cd solution
docker build -f Dockerfile.naive -t tp3b-naive:1.0 .
docker images tp3b-naive:1.0
```

> ❓ **Question** : notez la taille (plusieurs **centaines** de Mo). Pourquoi ? (Indice : l'image finale contient encore tout `golang:1.26-alpine`, compilateur compris.)

Revenez ensuite dans `starter/` pour faire **mieux** :

```bash
cd ../starter
```

## Étape 1 — Écrire le multi-stage (à vous de jouer)

Ouvrez `starter/Dockerfile`. Il est **incomplet** : complétez les `# TODO`. La structure attendue, en deux étapes :

1. **Étape `build`** — partez de `golang:1.26-alpine`, nommez-la `AS build`, copiez le code et **compilez** un binaire statique (`CGO_ENABLED=0`) dans `/out/server`, en injectant la version via `-ldflags`.
2. **Étape finale** — repartez de **`scratch`** (image vide), récupérez **uniquement** le binaire avec `COPY --from=build`, passez en utilisateur non-root (`USER 10001:10001`) et définissez l'`ENTRYPOINT`.

N'oubliez pas de compléter aussi le **`.dockerignore`**.

Puis construisez et lancez **votre** image :

```bash
docker build --build-arg VERSION=tp3b-1.0 -t tp3b-api:1.0 .
docker run -d --name api -p 8088:8080 tp3b-api:1.0
curl -s http://localhost:8088/         | grep "Telemach"
curl -s http://localhost:8088/version  # → tp3b-1.0
docker images tp3b-api:1.0             # comparez avec tp3b-naive !
```

> ❓ **Question** : comparez la taille de `tp3b-api:1.0` (multi-stage) avec `tp3b-naive:1.0`. Quel facteur de réduction obtenez-vous ?

Nettoyez :

```bash
docker rm -f api
```

## Étape 2 — Validez votre travail

Depuis le dossier du TP :

```bash
./verify.sh          # teste la solution de référence
./verify.sh starter  # teste VOTRE Dockerfile
```

Le script construit l'image, la lance, vérifie la réponse HTTP, la version injectée **et la taille de l'image**, puis nettoie tout. Tant que vous n'avez pas le ✅, votre TP n'est pas terminé.

---

## 💡 Indices (si vous êtes bloqué·e)

<details>
<summary>Comment « nommer » une étape de build ?</summary>

Avec le mot-clé `AS` : `FROM golang:1.26-alpine AS build`. Le nom `build` sert ensuite de référence dans `COPY --from=build`.
</details>

<details>
<summary>Récupérer un fichier produit par une étape précédente ?</summary>

`COPY --from=build /out/server /server` : `--from=<nom_d_étape>` indique que la **source** est dans cette étape, pas dans le contexte de build.
</details>

<details>
<summary>« exec format error » ou le conteneur ne démarre pas sur scratch ?</summary>

L'image `scratch` n'a **ni shell ni bibliothèques**. Le binaire doit être **100 % statique** : compilez avec `CGO_ENABLED=0`. Vérifiez aussi que l'`ENTRYPOINT` pointe bien vers `/server` (forme JSON : `ENTRYPOINT ["/server"]`).
</details>

<details>
<summary>Pourquoi un UID numérique pour USER sur scratch ?</summary>

`scratch` n'a pas de fichier `/etc/passwd` : un nom d'utilisateur (`USER nonroot`) ne peut pas être résolu. On passe donc un **UID:GID numérique** : `USER 10001:10001`.
</details>

---

## 📖 Où chercher (documentation officielle)

- **Multi-stage builds** : https://docs.docker.com/build/building/multi-stage/
- **`COPY --from`** : https://docs.docker.com/reference/dockerfile/#copy---from
- **`FROM ... AS` / étapes nommées** : https://docs.docker.com/reference/dockerfile/#from
- **`scratch` (image vide)** : https://docs.docker.com/build/building/base-images/#create-a-base-image
- **`USER`** : https://docs.docker.com/reference/dockerfile/#user
- **Bonnes pratiques de Dockerfile** : https://docs.docker.com/build/building/best-practices/

---

## 🚀 Pour aller plus loin

> Chaque défi est **indépendant**.

1. **Construire une seule étape.** `docker build --target build -t tp3b-builder .` : seule l'étape `build` est construite. À quoi cela sert-il en CI (lancer les tests dans l'étape de build sans produire l'image finale) ? → doc : https://docs.docker.com/build/building/multi-stage/#stop-at-a-specific-build-stage
2. **Distroless plutôt que scratch.** Remplacez `FROM scratch` par `FROM gcr.io/distroless/static-debian12:nonroot`. Vous gagnez les **certificats CA** et un utilisateur `nonroot` prêt à l'emploi, pour quelques Mo de plus. Comparez les tailles. (Vu au jour 2.)
3. **HEALTHCHECK sur scratch.** `scratch` n'a ni `wget` ni `curl` : impossible d'y faire un `HEALTHCHECK` classique. Ajoutez à l'appli un mode `--health` qui interroge `/healthz` et renvoie le bon code de sortie, puis `HEALTHCHECK CMD ["/server", "--health"]`. C'est le **pattern** des images minimales.
4. **Cache des dépendances.** Modifiez une ligne de `main.go` puis reconstruisez. Quelles couches sont rejouées, lesquelles viennent du cache ? Déplacez le `COPY go.mod` **après** `COPY . .` et observez la différence. (Cf. cours « Cache des couches ».)
5. **Build multi-architecture.** `docker buildx build --platform linux/amd64,linux/arm64 -t tp3b-api:multi .` produit une image pour deux architectures depuis la même recette. → doc : https://docs.docker.com/build/building/multi-platform/
