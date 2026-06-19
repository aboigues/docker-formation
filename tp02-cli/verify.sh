#!/usr/bin/env bash
# TP2 — vérifie que collect.sh extrait correctement les infos d'un conteneur.
source "$(git rev-parse --show-toplevel)/scripts/lib.sh"

TARGET="${1:-solution}"
HERE="$(cd "$(dirname "$0")" && pwd)"
NET="tp2-verify-net"
NAME="tp2-verify-target"

cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup  # repartir propre

step "Mise en place d'un conteneur de test"
docker network create "$NET" >/dev/null
docker run -d --name "$NAME" --network "$NET" nginx:1.30-alpine >/dev/null
# Générer quelques logs
docker exec "$NAME" sh -c 'wget -qO- http://localhost/ >/dev/null 2>&1 || true'
sleep 1

step "Exécution de collect.sh ($TARGET)"
OUT="$(bash "$HERE/$TARGET/collect.sh" "$NAME")"
echo "$OUT" | sed 's/^/    /'

assert_contains "Une ligne IP= est présente"   "IP="             "$OUT"
assert_contains "Une ligne LOGS= est présente"  "LOGS="           "$OUT"
assert_contains "Le process web est détecté"    "WEB_RUNNING=yes" "$OUT"

# L'IP doit être une adresse IPv4 valide (sans présumer du sous-réseau)
IPVAL="$(printf '%s' "$OUT" | sed -n 's/^IP=//p')"
check "IP est une adresse IPv4 valide" bash -c "[[ '$IPVAL' =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]"

# LOGS doit être un entier >= 0
LOGVAL="$(printf '%s' "$OUT" | sed -n 's/^LOGS=//p')"
check "LOGS est un nombre" bash -c "[[ '$LOGVAL' =~ ^[0-9]+$ ]]"

summary
