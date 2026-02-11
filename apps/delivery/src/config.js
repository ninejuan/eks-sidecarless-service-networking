import dotenv from "dotenv";

dotenv.config();

const toBool = (value, fallback) => {
    if (value === undefined || value === "") {
        return fallback;
    }
    return value.toLowerCase() === "true";
};

export const config = {
    serviceName: process.env.SERVICE_NAME || "delivery",
    environment: process.env.APP_ENV || "dev",
    port: Number(process.env.APP_PORT || 8083),
    externalTrackingUrl: process.env.EXTERNAL_TRACKING_URL || "https://www.google.com/generate_204",
    shipCallExternal: toBool(process.env.SHIP_CALL_EXTERNAL, false),
    readinessCheckExternal: toBool(process.env.READINESS_CHECK_EXTERNAL, false),
    requestTimeoutMs: Number(process.env.REQUEST_TIMEOUT_MS || 1500),
};
