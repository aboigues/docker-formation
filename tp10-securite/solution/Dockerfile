# Image DURCIE : multi-stage + image finale minimale + utilisateur non-root.

# === Étage 1 : build (compilateur Go, lourd, jeté à la fin) ===
FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY main.go ./
# Binaire 100 % statique (CGO désactivé), symboles de debug retirés (-s -w) → plus léger.
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /telescope .

# === Étage 2 : runtime minimal (pas de shell, pas de gestionnaire de paquets) ===
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /telescope /telescope
EXPOSE 8080
# L'utilisateur « nonroot » (UID 65532) est fourni par l'image distroless.
USER nonroot:nonroot
ENTRYPOINT ["/telescope"]
