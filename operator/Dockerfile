# ── Build context must be the repo root so COPY charts/ works ─────────────────
# docker build -f operator/Dockerfile -t ... .

# ── Stage 1: Build the Go binary ──────────────────────────────────────────────
FROM golang:1.22-alpine AS builder

WORKDIR /workspace

# Cache dependencies before copying source
COPY operator/go.mod operator/go.sum ./
RUN go mod download

# Copy operator source (relative to repo root build context)
COPY operator/ .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s" -o manager .

# ── Stage 2: Minimal runtime image ────────────────────────────────────────────
FROM gcr.io/distroless/static:nonroot

# Operator binary
COPY --from=builder /workspace/manager /manager

# Bundle charts from repo root so the operator can load them at runtime
COPY charts/ /charts/

USER 65532:65532

ENTRYPOINT ["/manager", "--charts-root=/charts"]
