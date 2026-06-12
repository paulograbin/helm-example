package com.demo;

import io.javalin.Javalin;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Map;

/**
 * App B — the "frontend/consumer" service.
 *
 * This app has NO database access. It fetches data by calling App A's REST API.
 * The NetworkPolicy in K8s ensures it physically cannot reach PostgreSQL,
 * even if someone accidentally hardcodes a connection string here.
 *
 * Endpoints:
 *   GET /health → liveness/readiness probe
 *   GET /data   → proxy to App A's /items endpoint
 *   POST /data  → proxy to App A's /items endpoint (create an item)
 *
 * Configuration (from env, injected by K8s ConfigMap):
 *   APP_A_URL — base URL of App A (e.g., http://app-a.backend.svc.cluster.local:8080)
 */
public class AppB {

    // K8s DNS for cross-namespace communication:
    //   <service-name>.<namespace>.svc.cluster.local
    // This is injected via ConfigMap so it's not hardcoded
    private static final String APP_A_URL = env("APP_A_URL",
        "http://app-a.backend.svc.cluster.local:8080");

    private static final String APP_VERSION = env("APP_VERSION", "unknown");

    // Java's built-in HTTP client — no external library needed
    private static final HttpClient httpClient = HttpClient.newBuilder()
        .connectTimeout(Duration.ofSeconds(5))
        .build();

    public static void main(String[] args) {
        Javalin app = Javalin.create().start(8080);

        app.get("/health", ctx -> ctx.result("OK"));
        app.get("/version", ctx -> ctx.json(Map.of("version", APP_VERSION)));

        // GET /data → forwards to App A's GET /items
        app.get("/data", ctx -> {
            HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(APP_A_URL + "/items"))
                .timeout(Duration.ofSeconds(10))
                .GET()
                .build();

            HttpResponse<String> response = httpClient.send(request,
                HttpResponse.BodyHandlers.ofString());

            ctx.status(response.statusCode())
               .contentType("application/json")
               .result(response.body());
        });

        // POST /data → forwards to App A's POST /items
        app.post("/data", ctx -> {
            HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(APP_A_URL + "/items"))
                .timeout(Duration.ofSeconds(10))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(ctx.body()))
                .build();

            HttpResponse<String> response = httpClient.send(request,
                HttpResponse.BodyHandlers.ofString());

            ctx.status(response.statusCode())
               .contentType("application/json")
               .result(response.body());
        });

        System.out.println("App B running on port 8080 — proxying to " + APP_A_URL);
    }

    private static String env(String key, String defaultValue) {
        String value = System.getenv(key);
        return (value != null && !value.isBlank()) ? value : defaultValue;
    }
}
