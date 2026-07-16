# Images durcies `telemachlearning/*`

Images dérivées des images tierces utilisées par les TP, reconstruites avec les
paquets système à jour. Publiées sur Docker Hub sous le namespace
`telemachlearning`, en **amd64 + arm64** (les Mac Apple Silicon sont courants en
salle ; les images amont publient jusqu'à 7 architectures, on ne garde que les
deux qui servent).

## Ce que le durcissement corrige — et ce qu'il ne corrige pas

Un `apt-get upgrade` / `apk upgrade` dans une image dérivée ne corrige que les
CVE de **paquets système**. Les CVE de **binaires compilés** (stdlib Go, modules
Node, dépendances Composer) sont figées dans le binaire amont : seul un rebuild
depuis les sources par le mainteneur les corrige. C'est pourquoi le scan
hebdomadaire (`.github/workflows/image-scan.yml`) ne bloque que sur
`--pkg-types os`.

Ces CVE de binaires sont d'ailleurs massivement non exploitables. Sur le `gosu`
de `mariadb:11.8`, Trivy remonte 15 HIGH/CRITICAL là où `govulncheck` (analyse
d'atteignabilité officielle Go) en trouve **0** : `gosu` fait un `setuid` puis un
`exec`, il n'appelle jamais `net/http`.

## Résultat mesuré

CVE de paquets OS, HIGH/CRITICAL, corrigeables (`--ignore-unfixed`) :

| Image | Amont | Durcie |
|---|---:|---:|
| `wordpress:6.8-php8.3-apache` | 606 | **0** |
| `gcr.io/cadvisor/cadvisor:v0.55.1` | 19 | **0** |
| `grafana/grafana:13.0.2` | 7 | **0** |
| `jenkins/jenkins:lts-jdk21` | 6 | **0** |
| `adminer:5` | 1 | **0** |
| `postgres:18-alpine` | 1 | **0** |

Sur les 606 de WordPress, 356 sont `linux-libc-dev` (en-têtes du noyau : le
conteneur utilise celui de l'hôte, ces CVE n'y sont pas exploitables). Les ~180
restantes — `apache2`, `imagemagick` — sont réelles.

Comportement vérifié identique à l'amont : WordPress HTTP 302 (redirection
install), Adminer 200, Grafana 200, Jenkins 200, cAdvisor v0.55.1,
PostgreSQL 18.4 (`pg_isready` OK).

## ⚠️ Ces images périment

Le durcissement est **figé à l'instant du build**. À la prochaine CVE Debian ou
Alpine, elles redeviennent rouges — exactement comme `wordpress:6.8-php8.3-apache`
l'est devenu côté amont. Sans reconstruction régulière, on remplace des images
officielles que Docker reconstruit par des images maison que personne ne
reconstruit : ce serait un recul.

Tant qu'aucun workflow de rebuild automatique n'existe, **reconstruire à la main
dès que le scan hebdomadaire repasse au rouge**.

## Reconstruire et publier

```bash
# Builder multi-arch (une fois)
docker buildx create --name tpmultiarch --driver docker-container --use

# Puis, par image (exemple WordPress)
docker buildx build --builder tpmultiarch \
  --platform linux/amd64,linux/arm64 \
  -f hardened/wordpress/Dockerfile \
  -t telemachlearning/wordpress:6.8-php8.3-apache \
  --push hardened/wordpress
```

Le tag reprend celui de l'amont : la provenance reste lisible et on n'utilise
jamais `latest`. Le build arm64 tourne sous émulation QEMU (comptez ~8 min pour
WordPress, ~5 min pour Jenkins).

Vérifier après publication :

```bash
docker manifest inspect telemachlearning/wordpress:6.8-php8.3-apache   # amd64 + arm64
trivy image --severity HIGH,CRITICAL --ignore-unfixed --pkg-types os \
  telemachlearning/wordpress:6.8-php8.3-apache                          # doit être vide
```

---

<div align="center">

**[Telemach Learning](https://www.telemach-learning.fr)** — Formations DevOps, Cloud & Conteneurs

🌐 [www.telemach-learning.fr](https://www.telemach-learning.fr)

© 2026 Telemach Learning — Code formation DEVOPS-001

</div>
