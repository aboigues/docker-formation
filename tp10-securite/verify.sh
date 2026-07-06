#!/usr/bin/env bash
# TP10 — vérifie qu'une image est DURCIE : minimale, non-root, sans faille
# HIGH/CRITICAL (Trivy), fonctionnelle, et transférable hors-ligne (save/load).
source "$(git rev-parse --show-toplevel)/scripts/lib.sh"

TARGET="${1:-starter}"
cd "$TARGET"

IMG="telescope-secure:tp10-$TARGET"
NAME="tp10-secure-run"
PORT=8087

cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker rmi "$IMG" >/dev/null 2>&1 || true
  rm -f image.tar.gz
}
trap cleanup EXIT
cleanup  # repartir propre

step "1) Build de l'image (multi-stage attendu)"
docker build -t "$IMG" .

step "2) Taille : l'image finale est mince (< 30 Mo)"
SIZE=$(docker image inspect "$IMG" --format '{{.Size}}')
MB=$((SIZE / 1000 / 1000))
info "taille = ${MB} Mo"
check "Image finale < 30 Mo (multi-stage efficace)" bash -c "[ '$MB' -lt 30 ]"

step "3) Sécurité : l'image ne tourne PAS en root"
UCFG=$(docker image inspect "$IMG" --format '{{.Config.User}}')
info "Config.User = '${UCFG:-<vide>}'"
check "Un USER non-root est défini" \
  bash -c "[ -n '$UCFG' ] && [ '$UCFG' != 'root' ] && [ '$UCFG' != '0' ]"

step "4) Scan Trivy : aucune vulnérabilité HIGH ou CRITICAL"
check "Trivy ne trouve aucune faille HIGH/CRITICAL" \
  trivy image --quiet --severity HIGH,CRITICAL --exit-code 1 --no-progress "$IMG"

step "4b) Scan Trivy : aucun secret embarqué dans l'image"
check "Trivy ne détecte aucun secret (mot de passe, clé, token)" \
  trivy image --quiet --scanners secret --exit-code 1 --no-progress "$IMG"

step "5) L'image durcie reste fonctionnelle (le service répond)"
docker run -d --name "$NAME" -p "$PORT:8080" "$IMG" >/dev/null
wait_for_http "http://localhost:$PORT/health" 20 || { docker logs "$NAME"; exit 1; }
assert_contains "Le endpoint /health répond ok" "ok" "$(curl -fsS "http://localhost:$PORT/health")"
docker rm -f "$NAME" >/dev/null

step "6) Transfert air-gapped : save -> transport -> load"
docker save "$IMG" | gzip > image.tar.gz
check "L'archive image.tar.gz est créée et non vide" test -s image.tar.gz
docker rmi "$IMG" >/dev/null
check "L'image a bien disparu du cache local" \
  bash -c "! docker image inspect '$IMG' >/dev/null 2>&1"
gunzip -c image.tar.gz | docker load
check "L'image est restaurée après 'docker load'" docker image inspect "$IMG"

summary
