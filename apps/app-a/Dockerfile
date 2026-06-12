# ─── Stage 1: Build ───────────────────────────────────────────────────────────
FROM maven:3.9-eclipse-temurin-25 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn package -DskipTests -B

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
