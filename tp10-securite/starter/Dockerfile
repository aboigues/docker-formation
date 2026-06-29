# Image NAÏVE : elle FONCTIONNE, mais elle est grosse (~300 Mo), embarque tout
# l'outillage de compilation, et tourne en ROOT. À DURCIR (voir TODO ci-dessous).
#
# Objectif : la transformer en image multi-stage, minimale et non-root,
# qui passe le scan Trivy sans faille HIGH/CRITICAL.
FROM golang:1.26-alpine
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
