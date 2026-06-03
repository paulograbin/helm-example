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

# Copy the union pom + dummy source, then run a full build.
# This forces Maven to download ALL dependencies AND all default lifecycle plugins
# (maven-resources-plugin, maven-compiler-plugin, maven-jar-plugin, maven-shade-plugin, etc.)
COPY pom.xml .
COPY src ./src
RUN mvn package -DskipTests -B && \
    rm -rf target
