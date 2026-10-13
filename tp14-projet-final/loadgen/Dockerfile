# loadgen — le générateur de trafic (fourni, déjà propre : multi-stage -> scratch).
FROM golang:1.27-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY *.go ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags "-s -w" -o /out/loadgen .

FROM scratch
COPY --from=build /out/loadgen /loadgen
USER 65532:65532
EXPOSE 9100
ENTRYPOINT ["/loadgen"]
