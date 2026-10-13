# shop-api — image DURCIE (phase 1 du TP14).
#   • multi-stage : la chaîne de compilation Go reste dans l'étage « build » ;
#   • image finale distroless « static » : ni shell, ni gestionnaire de paquets,
#     presque rien à scanner -> 0 faille HIGH/CRITICAL ;
#   • utilisateur non-root ;
#   • version injectée au build (lue par /version et la métrique shop_build_info).
FROM golang:1.27-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY *.go ./
ARG VERSION=dev
RUN CGO_ENABLED=0 go build -trimpath -ldflags "-s -w -X main.version=${VERSION}" -o /out/shop-api .

FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=build /out/shop-api /shop-api
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/shop-api"]
