export type JwtUser = {
    sub: string;
    scope?: "sync";
    device_id?: string;
    iss?: string;
    aud?: string;
    iat?: number;
    exp?: number;
    tv?: number;
    jti?: string;
};

declare module "@fastify/jwt" {
    interface FastifyJWT {
        user: {
            sub: string;
            scope?: string;
            device_id?: string;
            tv?: number;
            jti?: string;
            iss?: string;
            aud?: string;
            iat?: number;
            exp?: number;
            [key: string]: any;
        };
    }
}
