import { buildApp } from "./app.js";
import { config } from "./config.js";

const app = buildApp();

const start = async () => {
    try {
        await app.listen({ port: config.port, host: "0.0.0.0" });
        console.log(`delivery service listening on :${config.port}`);
    } catch (error) {
        console.error(error);
        process.exit(1);
    }
};

start();
