#!/usr/bin/env bash
# TP3 — Solution de référence : stack WordPress + MySQL à la main.
# Usage : ./deploy.sh up | down
set -euo pipefail

NET=wp-net
VOL=wp-db
DB=wp-mysql
APP=wp-app

up() {
  docker network inspect "$NET" >/dev/null 2>&1 || docker network create "$NET"
  docker volume inspect "$VOL" >/dev/null 2>&1 || docker volume create "$VOL"

  if ! docker ps -a --format '{{.Names}}' | grep -qx "$DB"; then
    docker run -d --name "$DB" \
      --network "$NET" \
      -v "$VOL:/var/lib/mysql" \
      -e MYSQL_ROOT_PASSWORD=rootsecret \
      -e MYSQL_DATABASE=wordpress \
      -e MYSQL_USER=wpuser \
      -e MYSQL_PASSWORD=wpsecret \
      mysql:8.4
  fi

  if ! docker ps -a --format '{{.Names}}' | grep -qx "$APP"; then
    docker run -d --name "$APP" \
      --network "$NET" \
      -p 8083:80 \
      -e WORDPRESS_DB_HOST="$DB" \
      -e WORDPRESS_DB_NAME=wordpress \
      -e WORDPRESS_DB_USER=wpuser \
      -e WORDPRESS_DB_PASSWORD=wpsecret \
      telemachlearning/wordpress:6.8-php8.3-apache
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
