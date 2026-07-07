# Image NAÏVE : elle FONCTIONNE, mais elle est grosse (~800 Mo), embarque tout
# l'outillage de compilation, une distrib Debian complète (des centaines de
# paquets, donc des CVE), et tourne en ROOT. À DURCIR (voir TODO ci-dessous).
#
# Objectif : la transformer en image multi-stage, minimale et non-root,
# qui passe le scan Trivy sans faille HIGH/CRITICAL.
#
# Base volontairement vulnérable (support pédagogique) : le marqueur ci-dessous
# l'exclut de la veille hebdomadaire (scripts/list-tp-images.py), sinon ses CVE
# — intentionnelles — pollueraient le tableau « code scanning ».
# image-scan: ignore
FROM golang:1.26-bookworm
WORKDIR /src
COPY go.mod ./
COPY main.go ./
RUN go build -o /telescope .
EXPOSE 8080

# TODO 1 : séparez en DEUX étages — un « build » (golang) qui compile le binaire,
#          puis un étage final qui PART d'une image minimale et ne reçoit QUE le binaire
#          (COPY --from=build ...). Pistes d'images finales : gcr.io/distroless/static-debian12
#          ou « scratch ». Compilez en statique : CGO_ENABLED=0.
# TODO 2 : faites tourner le conteneur en utilisateur NON-root (instruction USER).

ENTRYPOINT ["/telescope"]
