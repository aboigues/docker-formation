#!/usr/bin/env bash
# TP13 — vérifie une CHAÎNE D'INTÉGRATION réelle : un Jenkins configuré as-code
# (JCasC) exécute un pipeline Build → Test → Scan (Trivy) → Push et PUBLIE l'image
# applicative dans un registre privé. On prouve : Jenkins démarre déjà configuré,
# le pipeline passe au VERT, l'image scannée atterrit dans le registre et se re-tire.
source "$(git rev-parse --show-toplevel)/scripts/lib.sh"
set +e  # les boucles d'attente gèrent leurs propres erreurs ; le verdict vient de summary

TARGET="${1:-starter}"
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/$TARGET" || exit 1

JENKINS="http://localhost:8080"
REG="localhost:5000"
JOB="telemach-pipeline"
AUTH="admin:admin"
IMG_REPO="telemach/whoami"

# Le user « jenkins » du conteneur doit pouvoir lire le socket Docker de l'hôte :
# on transmet le GID du socket à compose (group_add).
export DOCKER_GID="$(stat -c '%g' /var/run/docker.sock 2>/dev/null || echo 999)"

cleanup() {
  docker compose down -v >/dev/null 2>&1 || true
  # Images publiées par le pipeline (elles vivent sur le daemon de l'hôte).
  docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null \
    | grep "^${REG}/${IMG_REPO}:" | xargs -r docker rmi -f >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup  # repartir propre

step "1) Construire/démarrer Jenkins (JCasC) + le registre privé"
docker compose up -d --build || { docker compose logs; exit 1; }

step "2) Attendre que le registre privé réponde"
i=0
until [ "$(curl -s -o /dev/null -w '%{http_code}' "http://$REG/v2/")" = "200" ]; do
  i=$((i+2)); sleep 2
  [ "$i" -ge 40 ] && { echo "registre KO"; docker compose logs registry; exit 1; }
done
info "registre prêt"

step "3) Attendre Jenkins ET la config JCasC (le job doit exister sans aucun clic)"
i=0
until curl -fsS -u "$AUTH" "$JENKINS/job/$JOB/api/json" >/dev/null 2>&1; do
  i=$((i+3)); sleep 3
  if [ "$i" -ge 210 ]; then echo "Jenkins/JCasC KO"; docker compose logs jenkins | tail -50; exit 1; fi
done
check "Jenkins démarré et job '$JOB' créé par configuration-as-code" \
  curl -fsS -u "$AUTH" "$JENKINS/job/$JOB/api/json"

step "4) Déclencher le pipeline (comme le ferait un push git via l'API)"
# Jenkins protège les POST par un jeton anti-CSRF (« crumb ») : on le récupère
# puis on le renvoie avec le déclenchement du build (avec la même session/cookie).
CRUMB="$(curl -fsS -c /tmp/tp13-cj.txt -u "$AUTH" "$JENKINS/crumbIssuer/api/json" 2>/dev/null \
         | grep -o '"crumb":"[^"]*"' | cut -d'"' -f4)"
curl -fsS -o /dev/null -b /tmp/tp13-cj.txt -u "$AUTH" -H "Jenkins-Crumb: $CRUMB" \
     -X POST "$JENKINS/job/$JOB/build" 2>/dev/null
info "build demandé"

step "5) Attendre la fin du pipeline et lire son verdict"
RESULT=""; i=0
while [ "$i" -lt 480 ]; do
  RESULT="$(curl -fsS -u "$AUTH" "$JENKINS/job/$JOB/lastBuild/api/json" 2>/dev/null \
            | grep -o '"result":"[A-Z]*"' | head -1 | cut -d'"' -f4)"
  [ -n "$RESULT" ] && break
  i=$((i+5)); sleep 5
done
LOG="$(curl -fsS -u "$AUTH" "$JENKINS/job/$JOB/lastBuild/consoleText" 2>/dev/null)"
info "résultat du pipeline = ${RESULT:-<toujours en cours>}"
if [ "$RESULT" != "SUCCESS" ]; then
  echo "----- console Jenkins (fin) -----"; printf '%s\n' "$LOG" | tail -60
fi
check "Le pipeline se termine en SUCCESS" bash -c "[ '$RESULT' = 'SUCCESS' ]"

step "6) Le pipeline a bien traversé les 4 étapes"
assert_contains "Étape BUILD exécutée"        "STAGE BUILD" "$LOG"
assert_contains "Étape TEST exécutée"         "STAGE TEST"  "$LOG"
assert_contains "Étape SCAN (Trivy) exécutée" "STAGE SCAN"  "$LOG"
assert_contains "Étape PUSH exécutée"         "STAGE PUSH"  "$LOG"

step "7) Le test applicatif et le scan Trivy ont bien validé l'image"
assert_contains "Smoke test réussi (/health répond ok)" "smoke test OK" "$LOG"
assert_contains "Trivy n'a bloqué aucune faille HIGH/CRITICAL" "Aucune vulnerabilite" "$LOG"

step "8) L'image applicative est publiée dans le registre privé"
TAGS="$(curl -fsS "http://$REG/v2/$IMG_REPO/tags/list" 2>/dev/null)"
info "tags dans le registre : ${TAGS:-<aucun>}"
assert_contains "Le dépôt $IMG_REPO existe dans le registre" "$IMG_REPO" "$TAGS"
assert_contains "Un tag versionné (1.0.x) est publié" '1.0.' "$TAGS"
assert_contains "Le tag 'latest' est publié" 'latest' "$TAGS"

step "9) L'image publiée est réellement re-tirable depuis le registre"
docker pull "$REG/$IMG_REPO:latest" >/dev/null 2>&1
check "docker pull depuis le registre privé réussit" \
  docker image inspect "$REG/$IMG_REPO:latest"

summary
