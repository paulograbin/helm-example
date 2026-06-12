# ─── Stage 1: Build ───────────────────────────────────────────────────────────
# Inherits from the build-base which already has all Maven deps cached in /root/.m2
FROM app-fnd-public.common.repositories.cloud.sap/base:0.0.1 AS build
WORKDIR /app
COPY pom.xml .
# No download needed — deps are already in the base image's Maven cache
COPY src ./src
RUN mvn package -DskipTests -B
# -o (offline) ensures we ONLY use cached deps — fails fast if something is missing

# ─── Stage 2: Runtime ─────────────────────────────────────────────────────────
# Using jammy (Ubuntu 22.04) — supports both amd64 and arm64 natively
FROM eclipse-temurin:25-jre-jammy
WORKDIR /app
COPY --from=build /app/target/app-a-0.0.1.jar app.jar

# Run as non-root (K8s security best practice)
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
USER appuser

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
