# TP3b — Solution de référence : Dockerfile multi-stage.
# Étape « build » : image lourde avec la toolchain Go (compilateur).
# Étape finale   : image « scratch » (vide) ne contenant QUE le binaire.
# syntax=docker/dockerfile:1

# Version de Go épinglée et surchargeable au build (--build-arg GO_VERSION=...).
ARG GO_VERSION=1.26

# ---------- Étape 1 : construction ----------
FROM golang:${GO_VERSION}-alpine AS build
WORKDIR /src

# Les dépendances changent rarement → copiées d'abord pour profiter du cache.
# (Ici, pas de dépendances externes, donc pas de go.sum.)
COPY go.mod ./
RUN go mod download

# Le code change souvent → copié après, pour ne pas invalider le cache ci-dessus.
COPY . .

# Numéro de version injecté dans le binaire (voir ARG/ENV du cours).
ARG VERSION=dev

# CGO_ENABLED=0 → binaire 100 % statique, donc exécutable sur « scratch ».
# -ldflags "-s -w" retire les tables de debug → binaire plus léger.
# -X main.version=... injecte la version dans la variable Go.
RUN CGO_ENABLED=0 go build \
      -trimpath \
      -ldflags="-s -w -X main.version=${VERSION}" \
      -o /out/server .

# ---------- Étape 2 : image finale minimale ----------
FROM scratch

# On ne récupère QUE le résultat compilé de l'étape « build ».
COPY --from=build /out/server /server

# Exécution sans privilèges : UID/GID numérique (scratch n'a pas de /etc/passwd).
USER 10001:10001

EXPOSE 8080
ENTRYPOINT ["/server"]
