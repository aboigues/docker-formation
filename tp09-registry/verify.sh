#!/usr/bin/env bash
# TP9 — vérifie un registre Docker privé authentifié : push/pull d'une image,
# catalogue protégé (401 sans identifiants), persistance.
source "$(git rev-parse --show-toplevel)/scripts/lib.sh"

TARGET="${1:-starter}"
cd "$TARGET"

REG="localhost:5000"
REG_USER="telescope"
REG_PASS="registry_secret"
SRC="alpine:3.23"
DEST="$REG/demo/alpine:1.0"

cleanup() {
  docker compose down -v >/dev/null 2>&1 || true
  docker logout "$REG" >/dev/null 2>&1 || true
  docker rmi "$DEST" >/dev/null 2>&1 || true
  rm -rf auth
}
trap cleanup EXIT
cleanup  # repartir propre

step "1) Générer le htpasswd (bcrypt) via un conteneur httpd jetable"
mkdir -p auth
docker run --rm --entrypoint htpasswd httpd:2 -Bbn "$REG_USER" "$REG_PASS" > auth/htpasswd
check "Le fichier auth/htpasswd est non vide" test -s auth/htpasswd

step "2) Démarrer le registre privé"
docker compose up -d
# Le registre répond 401 sur /v2/ tant qu'on n'est pas authentifié : c'est le signe qu'il est prêt.
i=0
until [ "$(curl -s -o /dev/null -w '%{http_code}' "http://$REG/v2/")" = "401" ]; do
  i=$((i+2)); sleep 2
  [ "$i" -ge 30 ] && { docker compose logs; exit 1; }
done
info "registre prêt (réponse 401 attendue sans identifiants)"

step "3) Sans identifiants, le registre REFUSE l'accès"
assert_contains "Le catalogue renvoie 401 sans login" "401" \
  "$(curl -s -o /dev/null -w '%{http_code}' "http://$REG/v2/_catalog")"

step "4) Se connecter, étiqueter et pousser une image"
echo "$REG_PASS" | docker login "$REG" -u "$REG_USER" --password-stdin
docker pull "$SRC" >/dev/null
docker tag "$SRC" "$DEST"
check "Push de l'image vers le registre privé" docker push "$DEST"

step "5) Le catalogue (authentifié) liste bien l'image"
assert_contains "demo/alpine présent dans /v2/_catalog" "demo/alpine" \
  "$(curl -fsS -u "$REG_USER:$REG_PASS" "http://$REG/v2/_catalog")"
assert_contains "Le tag 1.0 est listé" '"1.0"' \
  "$(curl -fsS -u "$REG_USER:$REG_PASS" "http://$REG/v2/demo/alpine/tags/list")"

step "6) Supprimer l'image locale puis la re-télécharger depuis le registre privé"
docker rmi "$DEST" >/dev/null 2>&1 || true
check "L'image n'est plus en local" \
  bash -c "! docker image inspect '$DEST' >/dev/null 2>&1"
docker pull "$DEST" >/dev/null
check "Pull réussi depuis le registre privé" docker image inspect "$DEST"

step "7) Persistance : l'image survit à la RECRÉATION du conteneur registre"
check "Le volume registry-data existe" \
  bash -c "docker volume ls --format '{{.Name}}' | grep -q 'registry-data'"
# On DÉTRUIT le conteneur (down SANS -v : le volume nommé doit survivre) puis on le
# recrée. Prouver l'existence du volume ne suffit pas — il faut qu'après recréation du
# conteneur, l'image poussée soit toujours servie par le registre.
docker compose down >/dev/null 2>&1
docker compose up -d >/dev/null
i=0
until [ "$(curl -s -o /dev/null -w '%{http_code}' "http://$REG/v2/")" = "401" ]; do
  i=$((i+2)); sleep 2
  [ "$i" -ge 30 ] && { docker compose logs; break; }
done
assert_contains "Après recréation du conteneur, demo/alpine est toujours dans le registre" "demo/alpine" \
  "$(curl -fsS -u "$REG_USER:$REG_PASS" "http://$REG/v2/_catalog")"

summary
