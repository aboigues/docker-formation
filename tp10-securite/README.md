# TP10 — Sécuriser ses images : scanner, durcir, transférer hors-ligne

> Durée estimée : 1 h · Ports utilisés : `8087`
> Prérequis : TP4 à TP6 (Dockerfile). Outil requis : **Trivy** (installation ci-dessous).

## 🎬 Le contexte

Votre image part en production — et la production est exposée. Trois questions de sécurité se posent :

1. **Contient-elle des failles connues ?** Une image basée sur une distrib complète embarque des centaines de paquets, donc des **CVE**. On va les **scanner** avec Trivy.
2. **Est-elle plus grosse et plus exposée que nécessaire ?** Un compilateur, un shell, un gestionnaire de paquets dans l'image finale = autant d'outils offerts à un attaquant. On va la **durcir** (multi-stage + image minimale + non-root).
3. **Comment la livrer dans un environnement coupé d'Internet** (banque, industrie, zone sensible) ? On va la **transférer hors-ligne** (`save`/`load`).

Cas réel : on durcit un micro-service interne pour qu'il passe la **revue sécurité** avant mise en prod.

## 🎯 Objectif vérifiable

Une image **multi-stage** de moins de **30 Mo**, qui tourne en utilisateur **non-root**, que **Trivy** déclare **sans faille HIGH/CRITICAL**, qui **répond** sur `/health`, et qu'on peut **exporter puis réimporter** via `docker save`/`load`. `./verify.sh` contrôle tout cela.

---

## Étape 0 — Installer Trivy

Trivy est le scanner de vulnérabilités d'Aqua Security. (La CI l'installe automatiquement.)

```bash
# Linux / WSL2
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
# macOS
# brew install trivy
trivy --version
```

## Étape 1 — Mesurer le problème (l'image naïve)

`starter/Dockerfile` construit l'image « à l'ancienne » : une seule étape, sur `golang:1.26-bookworm` (l'image Go **complète**, à base de Debian), en **root**. Construisez-la et regardez les dégâts :

```bash
cd starter
docker build -t telescope:naive .
docker images telescope:naive                                  # ~800 Mo
trivy image --severity HIGH,CRITICAL telescope:naive           # combien de failles ?
docker run --rm telescope:naive id 2>/dev/null || echo "(pas de shell pour 'id')"
```

> ❓ **Question** : pourquoi une image qui contient **le compilateur Go** et **un shell** est-elle un risque en production, même si l'application, elle, n'en a pas besoin pour tourner ?

## Étape 2 — Durcir : le multi-stage

L'idée clé : **compiler dans une image lourde**, mais **livrer** seulement le binaire dans une image **minimale**. Éditez `starter/Dockerfile` (TODO 1) pour obtenir deux étages :

- **Étage `build`** (`FROM golang:1.26-alpine AS build`) : compile un binaire **statique** avec `CGO_ENABLED=0 go build -ldflags="-s -w" -o /telescope .`
- **Étage final** : part d'une image minimale et ne reçoit **que** le binaire via `COPY --from=build /telescope /telescope`.

Pour l'image finale, deux écoles :

| Base finale | Taille | Particularité |
|-------------|--------|---------------|
| `scratch` | la plus petite | **rien** : ni shell, ni certificats CA |
| `gcr.io/distroless/static-debian12:nonroot` | ~2 Mo | pas de shell **mais** certificats CA + utilisateur `nonroot` prêt à l'emploi |

> 🧠 On recommande **distroless** ici : il fournit un utilisateur non-root et les certificats TLS (utiles dès qu'on appelle une API en HTTPS), tout en restant quasi aussi minimal que `scratch`.

## Étape 3 — Durcir : le non-root

Par défaut un conteneur tourne en **root** — si un attaquant s'en échappe, il est root sur des ressources de l'hôte. Ajoutez (TODO 2) une instruction `USER` pour tourner en utilisateur **non privilégié** :

```dockerfile
USER nonroot:nonroot
```

> ❓ **Question** : pourquoi le principe de **moindre privilège** s'applique-t-il aussi à un conteneur ? Qu'est-ce qu'un root « dans » le conteneur peut tenter qu'un utilisateur normal ne peut pas ?

## Étape 4 — Re-scanner et comparer

```bash
docker build -t telescope:hardened .
docker images "telescope:*"                                    # ~10 Mo vs ~800 Mo
trivy image --severity HIGH,CRITICAL --exit-code 1 telescope:hardened && echo "✅ propre"
```

Trivy ne cherche pas que des CVE : il sait aussi repérer un **secret** oublié dans une couche (mot de passe, clé privée, token). C'est une cause classique de fuite. Vérifiez-le :

```bash
trivy image --scanners secret --exit-code 1 telescope:hardened && echo "✅ aucun secret"
```

> ❓ **Question** : pourquoi l'image durcie a-t-elle **mécaniquement** moins de vulnérabilités ? (Indice : on ne peut pas avoir de faille dans un paquet… qu'on n'a pas installé.) Et pourquoi un `COPY .` trop large peut-il embarquer un `.env` ou une clé SSH dans l'image ?

## Étape 5 — Transférer hors-ligne (air-gapped)

Dans un environnement sans accès au registre (site sensible), on transporte l'image **en fichier** :

```bash
# Sur la machine connectée :
docker save telescope:hardened | gzip > telescope.tar.gz     # exporter
# ... transfert par clé USB / canal sécurisé ...

# Sur la machine cible (hors-ligne) :
docker rmi telescope:hardened                                # (simulation : on l'enlève)
gunzip -c telescope.tar.gz | docker load                     # réimporter
docker run --rm -p 8087:8080 telescope:hardened &
curl -s http://localhost:8087/health                         # ok
```

> ❓ **Question** : quelle est la différence entre `docker save` (une **image**) et `docker export` (un **conteneur** à plat) ? Lequel conserve l'historique des layers et les métadonnées ?

## Étape 6 — Validez

```bash
cd ..
./verify.sh              # teste VOTRE Dockerfile durci (dossier starter/)
./verify.sh solution     # (option) rejoue la solution de référence (durcie)
```

---

## 💡 Indices

<details>
<summary>Squelette du Dockerfile multi-stage</summary>

```dockerfile
FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY main.go ./
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /telescope .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /telescope /telescope
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/telescope"]
```
</details>

<details>
<summary>Trivy qui fait ÉCHOUER un pipeline</summary>

```bash
trivy image --severity HIGH,CRITICAL --exit-code 1 mon-image:tag
# exit-code 1 si au moins une faille trouvée → la CI passe au rouge.
```
</details>

---

## 📖 Où chercher (documentation officielle)

- **Builds multi-stage** : https://docs.docker.com/build/building/multi-stage/
- **Trivy (scanner de vulnérabilités)** : https://trivy.dev/latest/docs/target/container_image/
- **Images distroless** : https://github.com/GoogleContainerTools/distroless
- **`USER` & bonnes pratiques Dockerfile** : https://docs.docker.com/build/building/best-practices/#user
- **`docker save` / `docker load`** : https://docs.docker.com/reference/cli/docker/image/save/ · https://docs.docker.com/reference/cli/docker/image/load/
- **Docker Scout** (alternative intégrée à Docker) : https://docs.docker.com/scout/

> 💡 Réflexe CI : faire échouer le build sur `trivy ... --exit-code 1` empêche une image vulnérable d'atteindre la prod. C'est l'application directe de la règle d'or du dépôt à la **sécurité**.

---

## 🚀 Pour aller plus loin

1. **`scratch` vs distroless.** Refaites l'image finale `FROM scratch`. Que se passe-t-il si l'appli doit appeler une API **HTTPS** ? (Indice : les certificats CA absents — il faut les copier depuis l'étage build.)
2. **`.dockerignore`.** Ajoutez-en un pour exclure tout sauf le nécessaire du contexte de build. Quel impact sur la vitesse de build et sur les fuites accidentelles de fichiers ?
3. **Scan en SARIF.** Lancez Trivy avec `--format sarif` et imaginez comment GitHub afficherait ces résultats dans l'onglet *Security* d'un dépôt.
4. **Signature d'image.** Découvrez `cosign` (projet Sigstore) : signez votre image et vérifiez la signature. Pourquoi la **provenance** d'une image compte autant que son contenu ?
5. **Healthcheck distroless.** L'image n'a pas de shell : comment ajouter un `HEALTHCHECK` ? (Piste : un mini binaire de health, ou déléguer la sonde à l'orchestrateur — cf. TP12.)
6. **Docker Hardened Images.** Lisez la page des **Docker Hardened Images** (`dhi.io`). Quelles garanties supplémentaires offrent-elles par rapport à une image distroless que l'on maintient soi-même ?


---

<div align="center">

**[Telemach Learning](https://www.telemach-learning.fr)** — Formations DevOps, Cloud & Conteneurs

🌐 [www.telemach-learning.fr](https://www.telemach-learning.fr)

© 2026 Telemach Learning — Code formation DEVOPS-001

</div>
