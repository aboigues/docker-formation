# shop-api — le Dockerfile LIVRÉ PAR LE PRESTATAIRE. Il fonctionne... sur son poste.
#
# Problèmes à corriger (phase 1) :
#   • une seule étape : l'image finale embarque TOUTE la chaîne Go et une Debian
#     complète (~1 Go, des centaines de paquets -> des failles HIGH/CRITICAL) ;
#   • le processus tourne en ROOT.
#
# Base volontairement vulnérable (support pédagogique) : le marqueur ci-dessous
# l'exclut de la veille hebdomadaire des images (scripts/list-tp-images.py).
# image-scan: ignore
FROM golang:1.27-bookworm
WORKDIR /src
COPY . .
ARG VERSION=dev
RUN go build -ldflags "-X main.version=${VERSION}" -o /shop-api .
EXPOSE 8080

# TODO 1 : passez en MULTI-STAGE — un étage « build » (golang:1.27-alpine) qui
#          compile un binaire statique (CGO_ENABLED=0), puis un étage final minimal
#          qui ne reçoit QUE le binaire (COPY --from=build ...).
#          Pistes : gcr.io/distroless/static-debian13:nonroot, ou scratch.
# TODO 2 : faites tourner le processus en utilisateur NON-root (USER).
# (Gardez ARG VERSION et le -ldflags : c'est ce qui affiche la version sur /version.)

ENTRYPOINT ["/shop-api"]
