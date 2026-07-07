# Image applicative — multi-stage (rappel du TP6) pour obtenir une image
# MINIMALE et SANS FAILLE : c'est ce qui permet à l'étape « Scan » (Trivy)
# du pipeline de passer au vert.

# --- Étape 1 : compilation d'un binaire statique ---
FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY main.go ./
# CGO_ENABLED=0 -> binaire 100 % statique, sans dépendance libc : indispensable
# pour tourner sur une image « scratch » (qui ne contient RIEN).
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /whoami .

# --- Étape 2 : image finale, réduite à l'essentiel ---
# « scratch » = image vide : aucun paquet système -> surface d'attaque quasi nulle,
# donc aucune CVE d'OS pour Trivy.
FROM scratch
COPY --from=build /whoami /whoami
# On ne tourne PAS en root (bonne pratique du TP10).
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["/whoami"]
