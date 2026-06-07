# Contributing

Thank you for helping improve TENOS Sync Vault.

## Ground Rules

- Keep the server zero-knowledge. Do not add code paths that decrypt, log, index, or inspect medical payloads.
- Keep public documentation and source comments in English.
- Do not commit secrets, local `.env` files, private deployment files, generated build output, or dependency folders.
- Keep changes small and reviewable.
- Prefer explicit security checks over implicit assumptions.

## Local Setup

```bash
cp .env.example .env
docker compose up -d --build
```

Build the API:

```bash
cd api
npm install
npm run build
```

## Pull Request Checklist

- The API builds with `npm run build`.
- Public docs are updated when behavior or configuration changes.
- New endpoints document authentication, request shape, response shape, and failure behavior.
- Logs do not include medical payloads, private keys, JWTs, app tokens, admin tokens, or bundle-cipher secrets.
- Database changes are represented as migrations.

## Documentation Style

Use consistent terms:

- `subject`: anonymous data scope
- `device`: registered sync participant
- `owner device`: device authenticated with the subject root key
- `recipient device`: granted device with its own public key
- `capability`: server-side device permission
- `read_write`: recipient capability that can push encrypted events but cannot perform owner-only actions
