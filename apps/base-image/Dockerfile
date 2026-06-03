# ═══════════════════════════════════════════════════════════════════════════════
# Shared base image — provides both a build stage and a runtime stage.
#
# Build with two targets:
#   docker build --target build-base -t .../base:0.0.1-build ./apps/base-image
#   docker build --target runtime    -t .../base:0.0.1       ./apps/base-image
# ═══════════════════════════════════════════════════════════════════════════════

# ─── Stage 1: Build base ─────────────────────────────────────────────────────
# Maven + JDK + ALL dependencies pre-fetched into /root/.m2
# App Dockerfiles inherit this so they skip the download step entirely.
FROM maven:3.9-eclipse-temurin-17 AS build-base
WORKDIR /app

# Copy the union pom (contains deps from ALL apps) and download everything
COPY pom.xml .
RUN mvn dependency:go-offline -B && \
    mvn dependency:resolve-plugins -B

# ─── Stage 2: Runtime base ────────────────────────────────────────────────────
# Slim JRE image with non-root user — no build tools, no source code.
FROM eclipse-temurin:17-jre-jammy AS runtime
WORKDIR /app

RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
USER appuser

EXPOSE 8080
