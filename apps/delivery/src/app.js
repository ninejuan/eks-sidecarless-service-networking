import Fastify from "fastify";
import crypto from "node:crypto";
import { z } from "zod";

import { config } from "./config.js";

const shipRequestSchema = z.object({
    orderId: z.string().min(1),
    address: z.string().min(1),
});

const withTimeout = async (url, timeoutMs) => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
        return await fetch(url, { method: "GET", signal: controller.signal });
    } finally {
        clearTimeout(timer);
    }
};

const requestId = (req) => req.headers["x-request-id"] || req.id;

const accessLog = (req, reply) => {
    const startedAt = req.raw.startedAt || Date.now();
    const entry = {
        timestamp: new Date().toISOString(),
        level: "info",
        msg: "request completed",
        service: config.serviceName,
        env: config.environment,
        requestId: requestId(req),
        userId: req.headers["x-user-id"] || "",
        method: req.method,
        path: req.url,
        status: reply.statusCode,
        latency_ms: Date.now() - startedAt,
        ip: req.ip,
        userAgent: req.headers["user-agent"] || "",
    };
    console.log(JSON.stringify(entry));
};

export const buildApp = () => {
    const app = Fastify({ logger: false });

    app.addHook("onRequest", async (req, reply) => {
        req.raw.startedAt = Date.now();
        reply.header("X-Request-Id", requestId(req));
    });

    app.addHook("onResponse", async (req, reply) => {
        accessLog(req, reply);
    });

    app.setErrorHandler((error, req, reply) => {
        const stack = error.stack || "";
        console.error(
            JSON.stringify({
                timestamp: new Date().toISOString(),
                level: "error",
                msg: error.message,
                service: config.serviceName,
                env: config.environment,
                requestId: requestId(req),
                method: req.method,
                path: req.url,
                status: 500,
                latency_ms: 0,
                ip: req.ip,
                userAgent: req.headers["user-agent"] || "",
                stack,
            }),
        );

        reply.status(500).send({ error: "internal server error" });
    });

    app.get("/health", async () => ({ service: config.serviceName, status: "ok", version: "v1" }));
    app.get("/health/liveness", async () => ({ status: "alive" }));
    app.get("/health/readiness", async (_req, reply) => {
        if (!config.readinessCheckExternal) {
            return { status: "ready" };
        }

        try {
            const response = await withTimeout(config.externalTrackingUrl, config.requestTimeoutMs);
            if (!response.ok) {
                reply.status(503);
                return { status: "not_ready" };
            }
            return { status: "ready" };
        } catch {
            reply.status(503);
            return { status: "not_ready" };
        }
    });

    app.post("/v1/delivery/ship", async (req, reply) => {
        const parsed = shipRequestSchema.safeParse(req.body);
        if (!parsed.success) {
            reply.status(400);
            return { error: "invalid request payload" };
        }

        let providerStatus = "skipped";
        if (config.shipCallExternal) {
            try {
                const response = await withTimeout(config.externalTrackingUrl, config.requestTimeoutMs);
                providerStatus = response.ok ? "ok" : "failed";
            } catch {
                providerStatus = "failed";
            }
        }

        return {
            status: "shipped",
            orderId: parsed.data.orderId,
            trackingNumber: `trk_${crypto.randomUUID().replace(/-/g, "").slice(0, 12)}`,
            providerStatus,
        };
    });

    return app;
};
