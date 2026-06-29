# 🧭 Docker — Conseils & bonnes pratiques

> Mémo de fin de formation (**DEVOPS-001**) pour travailler **en autonomie**.
> À garder sous la main : principes, aide-mémoire commandes, check-lists et anti-patterns.
> Les renvois `→ TPxx` pointent vers le TP où le sujet a été pratiqué.

---

## 0. Les 5 principes qui évitent 90 % des ennuis

1. **Un conteneur = un seul processus / responsabilité.** Pas de « VM-conteneur » qui fait tourner ssh + cron + l'appli.
2. **Image immuable, configuration injectée.** Le code est dans l'image ; la config (URL, secrets) vient de l'extérieur (env, secrets). → TP8, TP10
3. **Moindre privilège partout.** Image minimale, utilisateur non-root, capacités retirées, rien d'exposé inutilement. → TP10
4. **Tout est reproductible et versionné.** Tags figés, `Dockerfile`/`compose.yaml` dans Git, builds déterministes.
5. **Si ce n'est pas observable et testé, ça n'existe pas.** Healthcheck, logs sur stdout, métriques, scan en CI. → TP11

---

## 1. Construire de bonnes images

### Choisir la base
- **Pinnez** une version précise, jamais `latest` : `node:24-alpine`, pas `node`. → TP5, TP8
- Préférez **minimal** : `-alpine`, **distroless** (`gcr.io/distroless/...`) ou **scratch** pour un binaire statique. Moins de paquets = moins de CVE et image plus légère. → TP10
- En entreprise, regardez les **Docker Hardened Images** (`dhi.io/...`) : bases durcies, non-root, signées, SBOM fournie.

### Dockerfile efficace
- **Multi-stage** : compiler dans une image lourde, ne livrer que l'artefact. → TP7, TP10
- **Ordonnez du moins au plus volatil** pour exploiter le cache de couches : copier `package.json` + installer **avant** de copier le code. → TP6
- Un **`.dockerignore`** systématique (`.git`, `node_modules`, `*.md`, `.env`, `*.key`) : build plus rapide **et** pas de fuite de fichiers sensibles dans l'image. → TP5, TP6, TP10
- **`USER` non-root** + `EXPOSE` (documentaire) + `HEALTHCHECK`. → TP6, TP10
- Labels **OCI** utiles : `org.opencontainers.image.source`, `...version`, `...revision`.

### Directives à jour (pièges fréquents)
| Obsolète / à éviter | À utiliser |
|---------------------|-----------|
| `MAINTAINER` | `LABEL org.opencontainers.image.authors=...` |
| `ENV clé valeur` | `ENV clé=valeur` |
| `npm install --only=production` | `npm install --omit=dev` |
| `FROM openjdk` | `eclipse-temurin` |
| clé `version:` dans Compose | (supprimée, ne plus la mettre) → TP4 |
| `docker-compose` (v1) | `docker compose` (v2) |

---

## 2. Construire (build)

- **BuildKit** est le moteur par défaut : profitez du cache et du parallélisme.
- **Secrets de build** : jamais en `ARG`/`ENV` (ils restent dans l'historique de l'image). Utilisez `RUN --mount=type=secret`.
  ```dockerfile
  RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm ci
  ```
- **Reproductibilité** : `npm ci` (lockfile) plutôt que `npm install` ; figez les versions d'OS-packages quand c'est critique.
- **Multi-arch** si besoin : `docker buildx build --platform linux/amd64,linux/arm64`.

---

## 3. Sécurité (le réflexe SRE)

- **Scanner en CI** et faire **échouer** le build sur HIGH/CRITICAL : `trivy image --severity HIGH,CRITICAL --exit-code 1 img`. → TP10
- **Scanner les secrets** : `trivy image --scanners secret --exit-code 1 img` (clé/token oubliés dans une couche). → TP10
- **Pas de secret dans l'image ni dans `ENV`.** Utilisez les **secrets** Compose/Swarm (montés dans `/run/secrets`) ou un coffre (Vault). → TP8
- **Durcir le runtime** :
  ```bash
  docker run --user 1000:1000 \
    --read-only --tmpfs /tmp \
    --cap-drop ALL \
    --security-opt no-new-privileges \
    mon-image
  ```
- **Mettre à jour les bases régulièrement** (les CVE arrivent *après* le build) → rebuild planifié.
- **Provenance** : signer les images (`cosign`) et conserver la **SBOM** (`docker sbom` / `trivy sbom`).
- **Registre privé** pour les images internes, en **HTTPS** + auth. → TP9

---

## 4. Exécuter (runtime)

- **Limiter les ressources** : `--memory=512m --cpus=1.5` (en Compose : `deploy.resources.limits`). Évite qu'un conteneur affame l'hôte.
- **Politique de redémarrage** : `--restart=unless-stopped` (ou `on-failure`), `restart: always` en prod. → TP8, TP12
- **Logs** : écrire sur **stdout/stderr** (jamais dans un fichier interne), et **borner** la rotation côté daemon :
  ```json
  // /etc/docker/daemon.json
  { "log-driver": "json-file", "log-opts": { "max-size": "10m", "max-file": "3" } }
  ```
- **Healthcheck** : que le service soit déclaré *healthy*, pas seulement *running* — base des dépendances `service_healthy`. → TP8
- **Données** : **volumes nommés** pour ce qui doit survivre ; ⚠️ `docker compose down -v` **supprime** les volumes. → TP3, TP4

---

## 5. Réseau

- **Un réseau dédié par stack** : isolation + DNS interne (résolution par nom de service). → TP3, TP8
- **N'exposez (`-p` / `ports:`) que le strict nécessaire.** Une base de données n'a pas à être joignable depuis l'hôte. → TP3, TP8
- En cluster, un **reverse-proxy** (Traefik) gère l'entrée unique + TLS + répartition. → TP12

---

## 6. Compose & multi-environnements

- `compose.yaml` de base **+ surcouches** : `compose.override.yaml` (dev, auto-chargé) vs `-f compose.yaml -f compose.prod.yaml` (prod). → TP8
- Configuration via **`.env`** (et `.env` dans `.gitignore`, seul `.env.example` est versionné). → TP8
- `depends_on` avec **`condition: service_healthy`** pour un démarrage fiable. → TP8
- **`profiles`** pour les services optionnels (debug, outils). → TP8
- Avant tout déploiement : **`docker compose config`** affiche la configuration réellement interprétée (variables résolues, fichiers fusionnés). → TP4, TP8

---

## 7. Mise en production / orchestration

- **Réplicas + état désiré** : l'orchestrateur maintient « je veux N instances » malgré les pannes. → TP12
- **Rolling updates** sans coupure : `update_config` (Swarm) / stratégie de déploiement (k8s).
- **Swarm** = simple, intégré, idéal petits clusters ; **Kubernetes** = standard de l'industrie, plus riche et plus complexe. Choisissez selon l'équipe et l'échelle.
- **TLS automatique** au bord (Let's Encrypt via Traefik/ingress). → TP12

---

## 8. Aide-mémoire (cheat sheet)

```bash
# --- Diagnostic ---
docker ps -a                      # conteneurs (y compris arrêtés)
docker logs -f --tail=100 NAME    # suivre les logs
docker exec -it NAME sh           # shell dans un conteneur
docker inspect -f '{{.State.Status}}' NAME
docker stats --no-stream          # CPU/RAM par conteneur
docker top NAME                    # processus du conteneur

# --- Images ---
docker image ls
docker history --no-trunc IMG     # taille par couche (repérer le gras)
docker build -t app:1.0 .
docker tag app:1.0 registre/app:1.0 && docker push registre/app:1.0

# --- Réseaux & volumes ---
docker network ls ; docker volume ls
docker network create mon-net
docker run --network mon-net ...

# --- Compose ---
docker compose up -d --build
docker compose ps
docker compose logs -f SERVICE
docker compose config             # config finale interprétée
docker compose down               # garde les volumes
docker compose down -v            # ⚠️ supprime aussi les volumes

# --- Nettoyage (récupérer de l'espace) ---
docker system df                  # ce qui occupe l'espace
docker image prune                # images "dangling"
docker container prune
docker system prune -a --volumes  # ⚠️ AGRESSIF : tout l'inutilisé, volumes compris
```

---

## 9. Anti-patterns à bannir

- ❌ `FROM ...:latest` → reproductibilité nulle, surprises au prochain pull.
- ❌ Tourner **en root** par défaut.
- ❌ **Secrets en `ENV`** ou en `ARG` (visibles dans `docker inspect` / l'historique d'image).
- ❌ **Plusieurs processus** dans un conteneur (sshd + appli + cron).
- ❌ Logs écrits **dans un fichier** au lieu de stdout.
- ❌ **Données dans la couche conteneur** (perdues à la recréation) au lieu d'un volume.
- ❌ Exposer une **base de données** sur l'hôte « au cas où ».
- ❌ `COPY . .` sans `.dockerignore` → on embarque `.git`, `.env`, clés…
- ❌ Image **mutable** rebuildée « en prod » au lieu d'un artefact figé et signé.
- ❌ Ignorer les **healthchecks** et les **limites de ressources**.

---

## 10. Check-list « avant la prod »

- [ ] Base **pinnée**, **minimale**, **non-root** ; `.dockerignore` présent. → TP5, TP6, TP10
- [ ] **Multi-stage** : pas d'outillage de build dans l'image finale. → TP7, TP10
- [ ] **Scan CVE + secrets** en CI, build qui **échoue** sur HIGH/CRITICAL. → TP10
- [ ] **Aucun secret** dans l'image / `ENV` ; secrets injectés au runtime. → TP8
- [ ] **Healthcheck** défini ; dépendances en `service_healthy`. → TP6, TP8
- [ ] **Limites** CPU/mémoire et **politique de redémarrage**.
- [ ] **Logs** sur stdout + **rotation** configurée.
- [ ] **Volumes nommés** pour l'état ; stratégie de **sauvegarde**.
- [ ] Réseau **dédié**, surface d'exposition **minimale**.
- [ ] Métriques **/metrics** + tableau de bord ; alertes de base. → TP11
- [ ] Images **versionnées** (tags immuables) et **poussées** dans un registre privé. → TP9
- [ ] En cluster : **réplicas**, **rolling update**, **TLS** au bord. → TP12

---

## 11. Pour creuser

- **Dockerfile best practices** : https://docs.docker.com/build/building/best-practices/
- **Compose** : https://docs.docker.com/compose/
- **Sécurité Docker** : https://docs.docker.com/engine/security/
- **Trivy** : https://trivy.dev/ · **Docker Scout** : https://docs.docker.com/scout/
- **Cosign / Sigstore** : https://docs.sigstore.dev/
- **Docker Hardened Images** : https://docs.docker.com/dhi/
- **The Twelve-Factor App** (config, logs, services externes) : https://12factor.net/fr/

> 🎓 Bonne continuation ! Le meilleur moyen de rester autonome : **relire ce mémo** au début de chaque nouveau projet conteneurisé, et garder le réflexe *« minimal, immuable, observable, moindre privilège »*.
