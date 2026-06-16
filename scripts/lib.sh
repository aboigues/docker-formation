#!/usr/bin/env bash
# Helpers partagés par tous les verify.sh des TP.
# Usage : source "$(git rev-parse --show-toplevel)/scripts/lib.sh"

set -euo pipefail

# Couleurs (désactivées si pas de TTY, ex. CI)
if [ -t 1 ]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; BLUE=''; NC=''
fi

PASS=0
FAIL=0

step()  { printf "${BLUE}▶ %s${NC}\n" "$*"; }
info()  { printf "  %s\n" "$*"; }

# check "description" commande...  → exécute, valide le code retour
check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf "  ${GREEN}✓${NC} %s\n" "$desc"; PASS=$((PASS+1))
  else
    printf "  ${RED}✗${NC} %s\n" "$desc"; FAIL=$((FAIL+1))
  fi
}

# assert_contains "description" "aiguille" "botte de foin"
assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -q -- "$needle"; then
    printf "  ${GREEN}✓${NC} %s\n" "$desc"; PASS=$((PASS+1))
  else
    printf "  ${RED}✗${NC} %s ${YELLOW}(attendu : « %s »)${NC}\n" "$desc" "$needle"; FAIL=$((FAIL+1))
  fi
}

# Attendre qu'une URL réponde (HTTP 2xx/3xx), avec timeout en secondes
wait_for_http() {
  local url="$1" timeout="${2:-60}" i=0
  step "Attente de $url (max ${timeout}s)"
  until curl -fsS -o /dev/null "$url" 2>/dev/null; do
    i=$((i+2)); sleep 2
    if [ "$i" -ge "$timeout" ]; then
      printf "  ${RED}✗ Délai dépassé${NC}\n"; return 1
    fi
  done
  printf "  ${GREEN}✓ Service disponible (${i}s)${NC}\n"
}

# Bilan final : code de sortie non nul si au moins un échec
summary() {
  echo "-----------------------------------------"
  if [ "$FAIL" -eq 0 ]; then
    printf "${GREEN}✅ TP validé : %d vérification(s) réussie(s).${NC}\n" "$PASS"
    return 0
  else
    printf "${RED}❌ TP non validé : %d échec(s) sur %d.${NC}\n" "$FAIL" "$((PASS+FAIL))"
    return 1
  fi
}
