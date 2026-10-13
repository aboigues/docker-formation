#!/bin/sh
# TP13 — Donne au user « jenkins » l'accès au socket Docker, puis lance Jenkins.
#
# Le GID du socket n'est connu qu'au RUNTIME, et seulement depuis l'INTÉRIEUR du
# conteneur (sous Docker Desktop / WSL, l'hôte voit un lien symbolique ou un
# autre propriétaire). On le lit donc ici, en root, on rattache « jenkins » à ce
# groupe, puis on abandonne les privilèges root avant de démarrer Jenkins.
set -eu

SOCK=/var/run/docker.sock
if [ -S "$SOCK" ]; then
  gid="$(stat -c '%g' "$SOCK")"
  grp="$(getent group "$gid" | cut -d: -f1 || true)"
  if [ -z "$grp" ]; then
    grp=docker-host
    groupadd -g "$gid" "$grp"
  fi
  usermod -aG "$grp" jenkins
  echo "[entrypoint] socket Docker : GID $gid ($grp) -> ajouté au user jenkins"
else
  echo "[entrypoint] ATTENTION : $SOCK absent, les étapes docker échoueront" >&2
fi

# Bascule vers « jenkins » (avec ses groupes, dont celui du socket) et lance
# l'entrypoint officiel de l'image (tini + jenkins.sh).
export HOME=/var/jenkins_home
exec setpriv --reuid=jenkins --regid=jenkins --init-groups \
  /usr/bin/tini -- /usr/local/bin/jenkins.sh "$@"
