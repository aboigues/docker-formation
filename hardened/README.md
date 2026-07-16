# Images durcies `telemachlearning/*`

Deux images seulement : `grafana/grafana:13.0.2` et `gcr.io/cadvisor/cadvisor:v0.55.1`.
Publiées en **amd64 + arm64** (les Mac Apple Silicon sont courants en salle).

## Quand durcir — et surtout quand ne PAS durcir

La question n'est pas « cette image a-t-elle des CVE ? » mais **« son tag est-il
encore reconstruit par son mainteneur ? »**. Deux populations, mesurées sur les
images de ce dépôt :

| Type de tag | Exemples | Âge observé | CVE de paquets OS |
|---|---|---|---|
| **Glissant**, entretenu | `nginx:1.30-alpine`, `postgres:18-alpine`, `adminer:5`, `jenkins:lts-jdk21` | 0 à 22 j | transitoires — **l'amont les corrige tout seul** |
| **Version épinglée**, figé | `grafana/grafana:13.0.2` (44 j), `cadvisor:v0.55.1` (203 j) | > 30 j | permanentes — **personne ne les corrigera** |

Sur un tag glissant, durcir est une perte de temps : `postgres:18-alpine` avait
1 CVE, le rebuild amont suivant l'efface sans qu'on lève le petit doigt. Seules
les **versions épinglées** justifient une image dérivée, parce qu'elles sont
gelées par construction.

Et avant de durcir, toujours vérifier qu'un **tag maintenu** ne règle pas le
problème : `wordpress:6.8-php8.3-apache` (plus reconstruit depuis 226 jours)
portait 606 CVE ; `wordpress:7.0-php8.5-apache`, reconstruit la veille, en a 0.
Une ligne de tag a suffi — aucune image maison n'était nécessaire.

## Ce que le durcissement corrige — et ce qu'il ne corrige pas

Un `apk upgrade` ne corrige que les CVE de **paquets système**. Les CVE de
**binaires compilés** (stdlib Go, modules Node, dépendances Composer) sont figées
dans le binaire amont. C'est pourquoi le scan (`.github/workflows/image-scan.yml`)
ne bloque que sur `--pkg-types os`.

Ces CVE de binaires sont d'ailleurs massivement non exploitables. Sur le `gosu`
de `mariadb:11.8`, Trivy remonte 15 HIGH/CRITICAL là où `govulncheck` (analyse
d'atteignabilité officielle Go) en trouve **0** : `gosu` fait un `setuid` puis un
`exec`, il n'appelle jamais `net/http`.

## Résultat mesuré

CVE de paquets OS, HIGH/CRITICAL, corrigeables (`--ignore-unfixed`) :

| Image | Amont | Durcie |
|---|---:|---:|
| `grafana/grafana:13.0.2` | 7 | **0** |
| `gcr.io/cadvisor/cadvisor:v0.55.1` | 19 | **0** |

Comportement vérifié identique à l'amont (Grafana HTTP 200, cAdvisor v0.55.1).

## Ces images périment aussi

Le durcissement est figé à l'instant du build. La barrière du scan applique la
même règle à nos images qu'aux autres : **CVE de paquets OS ET image de plus de
30 jours** ⇒ échec. Nos images ne bénéficient d'aucun passe-droit — quand elles
vieillissent et accumulent des CVE, le scan le dit et il faut les reconstruire.

## Reconstruire et publier

```bash
# Builder multi-arch (une fois)
docker buildx create --name tpmultiarch --driver docker-container --use

# Puis, par image
docker buildx build --builder tpmultiarch \
  --platform linux/amd64,linux/arm64 \
  -f hardened/grafana/Dockerfile \
  -t telemachlearning/grafana:13.0.2 \
  --push hardened/grafana
```

Le tag reprend celui de l'amont : la provenance reste lisible, et on n'utilise
jamais `latest`. Le build arm64 tourne sous émulation QEMU (~5 min).

Vérifier après publication :

```bash
docker manifest inspect telemachlearning/grafana:13.0.2      # amd64 + arm64
trivy image --severity HIGH,CRITICAL --ignore-unfixed --pkg-types os \
  telemachlearning/grafana:13.0.2                            # doit être vide
```

---

<div align="center">

**[Telemach Learning](https://www.telemach-learning.fr)** — Formations DevOps, Cloud & Conteneurs

🌐 [www.telemach-learning.fr](https://www.telemach-learning.fr)

© 2026 Telemach Learning — Code formation DEVOPS-001

</div>
