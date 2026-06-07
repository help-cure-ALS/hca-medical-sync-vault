# TENOS Sync Vault

Zero-knowledge sync and backup backend for encrypted medical app data.

TENOS Sync Vault stores encrypted event streams for mobile applications. It is designed as a transport and storage service only: the server never receives medical plaintext, never stores medical encryption keys, and does not implement medical business logic.

The project was created by [help cure ALS e.V.](https://help-cure-als.org/) for [TENOS](https://tenos.app/), but the backend is intentionally project-agnostic.

## What It Does

- Stores append-only encrypted sync events.
- Supports multi-device backup and restore.
- Uses Ed25519 proof-of-possession before issuing sync JWTs.
- Registers and revokes devices per anonymous subject.
- Supports recipient devices with their own public keys and `read_write` capability.
- Provides a short-lived rendezvous mailbox for pre-auth device pairing.
- Provides runtime bundle-cipher bootstrap for QR and clipboard transfer bundles.
- Supports encrypted PostgreSQL backups to S3-compatible object storage.
- Enforces rate limits, device limits, and per-subject quotas.
- Exposes aggregate admin statistics without subject IDs, device IDs, keys, or payloads.

## What It Does Not Do

- It is not a user account system.
- It is not a FHIR query server.
- It does not decrypt or inspect medical content.
- It does not store patient names, emails, diagnoses, or other profile data by design.
- It does not replace application-level consent, export, or deletion workflows.

## Architecture

```text
Mobile app
  - owns encryption keys
  - encrypts FHIR-compatible payloads
  - signs sync/auth messages
        |
        | HTTPS, ciphertext only
        v
TENOS Sync Vault API
  - Fastify
  - Ed25519 proof-of-possession
  - JWT transport capabilities
  - quotas and device registry
        |
        v
PostgreSQL
  - subjects
  - devices
  - events
  - auth_challenges
  - rendezvous
```

For details, see [docs/architecture.md](./docs/architecture.md).

## Repository Structure

```text
.
|- Caddyfile
|- docker-compose.yml
|- .env.example
|- api/
|  |- Dockerfile
|  |- migrations/
|  |- package.json
|  `- src/
|- backup/
|  |- Dockerfile
|  `- scripts/
`- docs/
   |- api.md
   |- architecture.md
   |- deployment.md
   |- operations.md
   `- security-model.md
```

Local-only files such as `.env`, `docker-compose.override.yml`, `node_modules`, build output, logs, and `.DS_Store` are ignored by Git.

## Quick Start

Create a local environment file:

```bash
cp .env.example .env
```

Start the stack:

```bash
docker compose up -d --build
```

Check the service:

```bash
curl http://localhost/healthz
```

For local development with direct host ports, see [docs/deployment.md](./docs/deployment.md).

## API

The API is documented in [docs/api.md](./docs/api.md).

The most important endpoint groups are:

- Health: `GET /healthz`
- Subject registration and recovery
- Challenge/issue proof-of-possession auth
- Device authorization and revocation
- Encrypted event push/pull
- Subject hard-delete
- Runtime bundle-cipher bootstrap
- Aggregate admin statistics
- Encrypted PostgreSQL backups to S3-compatible object storage

## Security Model

The security model is documented in [docs/security-model.md](./docs/security-model.md).

Core principles:

- The server stores ciphertext only.
- Subject IDs are anonymous data scopes, not identities.
- Ed25519 private keys remain on client devices.
- JWTs are transport capabilities, not user identities.
- Registered devices and capabilities define server-side access.
- Owner-only operations are separated from recipient write access.
- Aggregate operational statistics never expose subject IDs or payloads.

## Deployment

Production deployment uses Docker Compose, PostgreSQL, Fastify, and Caddy.

See [docs/deployment.md](./docs/deployment.md) and [docs/operations.md](./docs/operations.md).

## Development

Build the API:

```bash
cd api
npm install
npm run build
```

## Responsible Disclosure

Please do not report suspected vulnerabilities in public issues. See [SECURITY.md](./SECURITY.md).

## License

[MIT](./LICENSE) (c) [help cure ALS e.V.](https://help-cure-als.org/)
