#!/usr/bin/env bash
# Génère un fichier htpasswd (hash bcrypt) attendu par le registre.
# On utilise un conteneur httpd jetable : pas besoin d'installer apache2-utils.
set -euo pipefail

USER="${1:-telescope}"
PASS="${2:-registry_secret}"

mkdir -p auth
docker run --rm --entrypoint htpasswd httpd:2 -Bbn "$USER" "$PASS" > auth/htpasswd
echo "auth/htpasswd généré pour l'utilisateur « $USER »."
