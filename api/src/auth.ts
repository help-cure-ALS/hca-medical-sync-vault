import fp from "fastify-plugin";
import fastifyJwt from "@fastify/jwt";
import type { FastifyInstance } from "fastify";

export default fp(async function authPlugin(app: FastifyInstance) {
    const secret = process.env.JWT_SECRET;
    if (!secret || secret.length < 16) {
        throw new Error("JWT_SECRET missing or too short");
    }

    const issuer = process.env.JWT_ISSUER ?? "medical-sync-vault";
    const audience = process.env.JWT_AUDIENCE ?? "sync-vault";

    // Register jwt plugin
    await app.register(fastifyJwt, { secret });

    // Expose config for minting tokens in routes.ts
    app.decorate("jwtCfg", { issuer, audience });

    // Auth guard for routes: verify signature + standard claims
    app.decorate("auth", async (req: any, reply: any) => {
        try {
            await req.jwtVerify({ issuer, audience });
        }
        catch {
            return reply.code(401).send({ error: "invalid_token" });
        }

        // Optional: minimal payload sanity (audit-friendly)
        // (You already enforce tv in routes via DB)
        const sub = req.user?.sub;
        if (typeof sub !== "string" || sub.length < 8) {
            return reply.code(401).send({ error: "invalid_token" });
        }
    });
});

declare module "fastify" {
    interface FastifyInstance {
        auth: (req: any, reply: any) => Promise<void>;
        jwtCfg: { issuer: string; audience: string };
    }
}
