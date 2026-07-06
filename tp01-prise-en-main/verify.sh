#!/usr/bin/env bash
# TP1 — Premiers pas : vérifie que l'environnement Docker permet de lancer,
# interroger et gérer le cycle de vie d'un conteneur. (Pas de fichier à construire.)
source "$(git rev-parse --show-toplevel)/scripts/lib.sh"

# Le 1er argument (solution/starter) est ignoré : ce TP n'a pas de fichier à compléter.
NAME="tp01-verify-nginx"
PORT=8081

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup  # repartir propre

step "1) hello-world (le daemon répond et peut tirer une image)"
HELLO="$(docker run --rm hello-world 2>&1 || true)"
assert_contains "Le message de bienvenue s'affiche" "Hello from Docker" "$HELLO"

step "2) Lancement d'un serveur nginx en arrière-plan"
docker run -d --name "$NAME" -p "$PORT:80" nginx:1.30-alpine >/dev/null
wait_for_http "http://localhost:$PORT" 30 || { docker logs "$NAME"; exit 1; }
BODY="$(curl -fsS "http://localhost:$PORT")"
assert_contains "La page d'accueil nginx répond" "nginx" "$BODY"

step "3) Cycle de vie : stop / start"
docker stop "$NAME" >/dev/null
# Selon la version de Docker (runners CI chargés notamment), l'état peut mettre un
# court instant à basculer après le retour de `docker stop`/`docker start`. On attend
# (borné) d'atteindre l'état voulu avant de l'affirmer, sinon le test devient instable.
i=0
until [ -z "$(docker ps --filter name="$NAME" --filter status=running -q)" ]; do
  i=$((i+1)); sleep 1
  if [ "$i" -ge 10 ]; then break; fi
done
check "Après stop, le conteneur n'est plus 'running'" \
  bash -c "[ -z \"\$(docker ps --filter name=$NAME --filter status=running -q)\" ]"
check "Après stop, le conteneur existe toujours (ps -a)" \
  bash -c "docker ps -a --filter name=$NAME -q | grep -q ."
docker start "$NAME" >/dev/null
i=0
until [ -n "$(docker ps --filter name="$NAME" --filter status=running -q)" ]; do
  i=$((i+1)); sleep 1
  if [ "$i" -ge 10 ]; then break; fi
done
check "Après start, le conteneur est de nouveau 'running'" \
  bash -c "docker ps --filter name=$NAME --filter status=running -q | grep -q ."

step "4) L'image nginx reste disponible localement"
check "L'image nginx:1.30-alpine est présente" \
  bash -c "docker image inspect nginx:1.30-alpine >/dev/null 2>&1"

summary
