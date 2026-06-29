# TP7 — À COMPLÉTER : transformez ce Dockerfile en multi-stage.
# Objectif : une image finale qui ne contient QUE le binaire compilé.
# Remplacez chaque « TODO » ; les indices sont dans le README.
# syntax=docker/dockerfile:1

ARG GO_VERSION=1.26

# ---------- Étape 1 : construction ----------
# TODO 1 : partez de l'image « golang:${GO_VERSION}-alpine » et NOMMEZ
#          cette étape « build » (mot-clé AS).
FROM ___________________ AS ______

WORKDIR /src

# TODO 2 : copiez d'abord go.mod (cache des dépendances), puis téléchargez-les.
COPY ___________ ./
RUN go mod download

# TODO 3 : copiez ensuite le reste du code (il change plus souvent).
COPY . .

ARG VERSION=dev

# TODO 4 : compilez un binaire STATIQUE (CGO_ENABLED=0) vers /out/server,
#          en injectant la version : -ldflags="-s -w -X main.version=${VERSION}"
RUN __________________________________________________________

# ---------- Étape 2 : image finale minimale ----------
# TODO 5 : repartez d'une image VIDE (« scratch »).
FROM ________

# TODO 6 : récupérez UNIQUEMENT le binaire depuis l'étape « build »
#          (COPY --from=...).
COPY ___________________________ /server

# TODO 7 : exécutez sans privilèges (UID:GID numérique, ex. 10001:10001).
USER ____________

EXPOSE 8080
# TODO 8 : définissez le point d'entrée sur le binaire /server.
ENTRYPOINT [__________]
