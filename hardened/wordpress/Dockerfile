# Image durcie : l'amont + ses paquets système à jour.
# Publiée en amd64 + arm64 sous telemachlearning/ — voir ../README.md.
#
# La base est SCIEMMENT vulnérable : c'est la raison d'être de cette image.
# Le marqueur ci-dessous l'exclut de la veille (scripts/list-tp-images.py),
# sinon la barrière bloquerait sur les CVE que ce Dockerfile corrige justement.
# C'est l'image PUBLIÉE (telemachlearning/*), elle, qui est scannée.
# image-scan: ignore
FROM wordpress:6.8-php8.3-apache
USER root
RUN apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
