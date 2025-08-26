# Build stage
FROM golang:1.22 AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o kcd-app main.go

# Run stage (distroless para seguridad)
FROM gcr.io/distroless/base-debian12
USER 65532:65532   # nonroot
COPY --from=builder /app/kcd-app /kcd-app
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["/kcd-app"]