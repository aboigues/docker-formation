# Image durcie : l'amont + ses paquets système à jour.
# Publiée en amd64 + arm64 sous telemachlearning/ — voir ../README.md.
#
# La base est SCIEMMENT vulnérable : c'est la raison d'être de cette image.
# Le marqueur ci-dessous l'exclut de la veille (scripts/list-tp-images.py),
# sinon la barrière bloquerait sur les CVE que ce Dockerfile corrige justement.
# C'est l'image PUBLIÉE (telemachlearning/*), elle, qui est scannée.
# image-scan: ignore
FROM postgres:18-alpine
USER root
RUN apk upgrade --no-cache
USER postgres
