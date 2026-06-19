#!/usr/bin/env bash
# TP4 — Monter une stack WordPress + MySQL À LA MAIN.
# Usage : ./deploy.sh up | down
set -euo pipefail

NET=wp-net
VOL=wp-db
DB=wp-mysql
APP=wp-app

up() {
  # TODO 1 : créer le réseau "$NET" s'il n'existe pas.
  #   Indice : docker network inspect "$NET" >/dev/null 2>&1 || docker network create "$NET"
  ______

  # TODO 2 : créer le volume "$VOL" s'il n'existe pas.
  ______

  # TODO 3 : lancer MySQL (mysql:8.4) s'il ne tourne pas déjà.
  #   - réseau "$NET", volume "$VOL" sur /var/lib/mysql
  #   - variables : MYSQL_ROOT_PASSWORD=rootsecret, MYSQL_DATABASE=wordpress,
  #                 MYSQL_USER=wpuser, MYSQL_PASSWORD=wpsecret
  if ! docker ps -a --format '{{.Names}}' | grep -qx "$DB"; then
    docker run -d --name "$DB" ______
  fi

  # TODO 4 : lancer WordPress (wordpress:6.8-php8.3-apache) s'il ne tourne pas déjà.
  #   - réseau "$NET", port 8083:80
  #   - variables : WORDPRESS_DB_HOST=$DB (le NOM du conteneur MySQL),
  #                 WORDPRESS_DB_NAME=wordpress, WORDPRESS_DB_USER=wpuser,
  #                 WORDPRESS_DB_PASSWORD=wpsecret
  if ! docker ps -a --format '{{.Names}}' | grep -qx "$APP"; then
    docker run -d --name "$APP" ______
  fi

  echo "Stack montée. WordPress → http://localhost:8083"
}

down() {
  docker rm -f "$APP" "$DB" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
  echo "Stack démontée (le volume $VOL est conservé — supprimez-le avec : docker volume rm $VOL)."
}

case "${1:-}" in
  up)   up ;;
  down) down ;;
  *)    echo "Usage: $0 up|down" ; exit 1 ;;
esac
