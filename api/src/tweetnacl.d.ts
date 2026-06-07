declare module "tweetnacl" {
export as namespace nacl;

    type DetachedFn = ((
        message: Uint8Array,
        secretKey: Uint8Array
    ) => Uint8Array) & {
        verify(
            message: Uint8Array,
            signature: Uint8Array,
            publicKey: Uint8Array
        ): boolean;
    };

    const nacl: {
        randomBytes(length: number): Uint8Array;
        sign: {
            detached: DetachedFn;
        };
    };

    export = nacl; // CommonJS
}
