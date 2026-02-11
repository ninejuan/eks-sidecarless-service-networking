import { afterAll, beforeAll, describe, expect, it } from "vitest";

import { buildApp } from "../src/app.js";

describe("delivery service", () => {
    const app = buildApp();

    beforeAll(async () => {
        await app.ready();
    });

    afterAll(async () => {
        await app.close();
    });

    it("returns health endpoints", async () => {
        const health = await app.inject({ method: "GET", url: "/health" });
        expect(health.statusCode).toBe(200);

        const liveness = await app.inject({ method: "GET", url: "/health/liveness" });
        expect(liveness.statusCode).toBe(200);

        const readiness = await app.inject({ method: "GET", url: "/health/readiness" });
        expect(readiness.statusCode).toBe(200);
    });

    it("ships order via v1 endpoint", async () => {
        const response = await app.inject({
            method: "POST",
            url: "/v1/delivery/ship",
            payload: { orderId: "order-1", address: "Seoul" },
        });

        expect(response.statusCode).toBe(200);
        const body = response.json();
        expect(body.status).toBe("shipped");
        expect(body.orderId).toBe("order-1");
        expect(body.trackingNumber).toBeTruthy();
    });
});
