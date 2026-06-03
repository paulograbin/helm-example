# ─── Stage 1: Build ───────────────────────────────────────────────────────────
# Inherits from the build-base which already has all Maven deps cached in /root/.m2
FROM app-fnd-public.common.repositories.cloud.sap/base:0.0.1 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn package -DskipTests -B

# ─── Stage 2: Runtime ─────────────────────────────────────────────────────────
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app
COPY --from=build /app/target/app-b-0.0.1.jar app.jar

RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
USER appuser

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
