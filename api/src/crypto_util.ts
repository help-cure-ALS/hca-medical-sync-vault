import nacl = require("tweetnacl");

export function b64ToBytes(b64: string): Uint8Array {
    // atob expects standard base64 (not base64url)
    const bin = globalThis.atob(b64);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return bytes;
}

export function bytesToB64(bytes: Uint8Array): string {
    let bin = "";
    for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
    // btoa expects binary string
    return globalThis.btoa(bin);
}

export function utf8Bytes(s: string): Uint8Array {
    return new TextEncoder().encode(s);
}

export function ed25519Verify(message: Uint8Array, sig: Uint8Array, publicKey: Uint8Array): boolean {
    return nacl.sign.detached.verify(message, sig, publicKey);
}
