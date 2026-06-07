import Fastify from "fastify";
import rateLimit from "@fastify/rate-limit";
import authPlugin from "./auth";
import { routes } from "./routes";
import { runMigrations } from "./db";

async function main() {
    const app = Fastify({ logger: true });

    await app.register(rateLimit, {
        global: false, // We only activate it on certain routes.
    });

    await runMigrations();
    await app.register(authPlugin);
    await routes(app);

    const port = Number(process.env.PORT ?? "3000");
    await app.listen({ port, host: "0.0.0.0" });
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});
