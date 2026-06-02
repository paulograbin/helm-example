# ─── Stage 1: Build ───────────────────────────────────────────────────────────
# Use Maven to compile and package the fat JAR
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
# Download dependencies first (cached layer — only re-downloads if pom.xml changes)
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn package -DskipTests -B

# ─── Stage 2: Runtime ─────────────────────────────────────────────────────────
# Using jammy (Ubuntu 22.04) — supports both amd64 and arm64 natively
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app
COPY --from=build /app/target/app-a-1.0.0.jar app.jar

# Run as non-root (K8s security best practice)
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
USER appuser

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
