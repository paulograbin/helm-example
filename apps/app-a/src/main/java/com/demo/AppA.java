package com.demo;

import io.javalin.Javalin;
import io.javalin.http.Context;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * App A — the "backend" service that owns database access.
 *
 * Endpoints:
 *   GET  /health  → liveness/readiness probe
 *   GET  /items   → list all items from postgres
 *   POST /items   → create a new item (JSON body: {"name": "..."})
 *
 * Configuration is read from environment variables (injected by K8s ConfigMap/Secret):
 *   DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
 */
public class AppA {

    // Connection details from environment — K8s injects these from ConfigMap + Secret
    private static final String DB_HOST = env("DB_HOST", "localhost");
    private static final String DB_PORT = env("DB_PORT", "5432");
    private static final String DB_NAME = env("DB_NAME", "demo");
    private static final String DB_USER = env("DB_USER", "postgres");
    private static final String DB_PASSWORD = env("DB_PASSWORD", "postgres");
    private static final String APP_VERSION = env("APP_VERSION", "unknown");

    private static final String JDBC_URL = String.format(
        "jdbc:postgresql://%s:%s/%s", DB_HOST, DB_PORT, DB_NAME
    );

    public static void main(String[] args) {
        initDatabase();

        Javalin app = Javalin.create(config -> {
            config.routes.get("/health", ctx -> ctx.result("OK"));
            config.routes.get("/version", ctx -> ctx.json(Map.of("version", APP_VERSION)));
            config.routes.get("/java", ctx -> ctx.json(Map.of("java", System.getProperty("java.version"))));
            config.routes.get("/items", AppA::getItems);
            config.routes.post("/items", AppA::createItem);
        });
        app.start(8080);

        System.out.println("App A running on port 8080");
    }

    /**
     * Create the items table if it doesn't exist.
     * Runs once at startup — simple schema migration.
     */
    private static void initDatabase() {
        try (Connection conn = DriverManager.getConnection(JDBC_URL, DB_USER, DB_PASSWORD);
             Statement stmt = conn.createStatement()) {
            stmt.execute("""
                CREATE TABLE IF NOT EXISTS items (
                    id SERIAL PRIMARY KEY,
                    name VARCHAR(255) NOT NULL,
                    created_at TIMESTAMP DEFAULT NOW()
                )
            """);
            System.out.println("Database initialized");
        } catch (SQLException e) {
            System.err.println("Failed to initialize database: " + e.getMessage());
            // In production you'd want a retry loop here; for the demo we fail fast
            System.exit(1);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // TODO: Implement these two methods!
    //
    // This is your contribution point. You'll write the JDBC logic to:
    //   1. Query all items and return them as JSON
    //   2. Insert a new item from the request body
    //
    // See the guidance below each method for hints.
    // ─────────────────────────────────────────────────────────────────────────────

    /**
     * GET /items — Fetch all items from the database and return as JSON array.
     *
     * Expected response format:
     *   [{"id": 1, "name": "widget", "created_at": "2024-01-15T10:30:00"}, ...]
     *
     * Hints:
     *   - Use DriverManager.getConnection(JDBC_URL, DB_USER, DB_PASSWORD) to get a connection
     *   - Use PreparedStatement for the query (even without params — good habit)
     *   - Call ctx.json(yourList) to serialize the response
     *   - Javalin + Jackson will handle the JSON serialization
     */
    private static void getItems(Context ctx) {
        try (Connection conn = DriverManager.getConnection(JDBC_URL, DB_USER, DB_PASSWORD);
             PreparedStatement ps = conn.prepareStatement(
                 "SELECT id, name, created_at FROM items ORDER BY created_at DESC")) {
            ResultSet rs = ps.executeQuery();
            List<Map<String, Object>> items = new ArrayList<>();
            while (rs.next()) {
                items.add(Map.of(
                    "id", rs.getInt("id"),
                    "name", rs.getString("name"),
                    "created_at", rs.getTimestamp("created_at").toString()
                ));
            }
            ctx.json(items);
        } catch (SQLException e) {
            ctx.status(500).result("DB error: " + e.getMessage());
        }
    }

    /**
     * POST /items — Insert a new item into the database.
     *
     * Expected request body: {"name": "my-item"}
     * Expected response: 201 Created with the new item as JSON
     *
     * Hints:
     *   - Parse body: Map body = ctx.bodyAsClass(Map.class);
     *   - Use PreparedStatement with RETURNING to get the generated ID
     *   - Return 201 status with the created item
     */
    private static void createItem(Context ctx) {
        Map body = ctx.bodyAsClass(Map.class);
        String name = (String) body.get("name");
        if (name == null || name.isBlank()) {
            ctx.status(400).result("Missing 'name' field");
            return;
        }
        try (Connection conn = DriverManager.getConnection(JDBC_URL, DB_USER, DB_PASSWORD);
             PreparedStatement ps = conn.prepareStatement(
                 "INSERT INTO items (name) VALUES (?) RETURNING id, name, created_at")) {
            ps.setString(1, name);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                ctx.status(201).json(Map.of(
                    "id", rs.getInt("id"),
                    "name", rs.getString("name"),
                    "created_at", rs.getTimestamp("created_at").toString()
                ));
            }
        } catch (SQLException e) {
            ctx.status(500).result("DB error: " + e.getMessage());
        }
    }

    /** Read an env var with a fallback default (for local development). */
    private static String env(String key, String defaultValue) {
        String value = System.getenv(key);
        return (value != null && !value.isBlank()) ? value : defaultValue;
    }
}
