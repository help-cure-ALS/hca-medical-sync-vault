# Deployment

TENOS Sync Vault is deployed with Docker Compose:

- PostgreSQL
- API container
- Caddy reverse proxy

## Environment

Start from:

```bash
cp .env.example .env
```

Production secrets must be long random values. Do not reuse the placeholder values from `.env.example`.

Required production variables:

```text
POSTGRES_DB
POSTGRES_USER
POSTGRES_PASSWORD
DATABASE_URL
JWT_SECRET
APP_ISSUE_TOKEN
ADMIN_STATS_TOKEN
BUNDLE_CIPHER_CURRENT_KID
BUNDLE_CIPHER_CURRENT_SECRET
CADDY_SITE_ADDRESS
```

Required production backup variables:

```text
COMPOSE_PROFILES=backup
BACKUP_RESTIC_REPOSITORY
BACKUP_S3_ACCESS_KEY_ID
BACKUP_S3_SECRET_ACCESS_KEY
BACKUP_RESTIC_PASSWORD
```

Optional variables:

```text
BUNDLE_CIPHER_PREVIOUS_KID
BUNDLE_CIPHER_PREVIOUS_SECRET
JWT_TTL_SECONDS
JWT_ISSUER
JWT_AUDIENCE
MAX_BATCH_EVENTS
MAX_PULL_LIMIT
API_REPLICAS
```

## Local Development

For local development, create `docker-compose.override.yml` next to `docker-compose.yml`:

```yaml
services:
  api:
    ports:
      - "${API_PORT_HOST:-3000}:${API_PORT_INTERNAL:-3000}"

  db:
    ports:
      - "${DB_PORT:-5432}:5432"

  caddy:
    ports:
      - "${CADDY_HTTP_PORT:-18080}:80"
```

Then start:

```bash
docker compose up -d --build
```

Local health check:

```bash
curl http://localhost:18080/healthz
```

`docker-compose.override.yml` is ignored by Git and must not be used as production configuration.

## Production

In production:

- Do not expose the API container directly.
- Let Caddy terminate TLS and forward to the API service over the Docker network.
- Use a real domain in `CADDY_SITE_ADDRESS`.
- Keep `.env` private.
- Enable the `backup` Compose profile.
- Rotate secrets if they were ever copied into logs, tickets, screenshots, or commits.

Start:

```bash
docker compose up -d --build
```

Production health check:

```bash
curl https://<your-domain>/healthz
```

## Hetzner Object Storage Backups

The `backup` service writes encrypted PostgreSQL logical backups directly to an S3-compatible object storage bucket. It does not mount the bucket as a filesystem.

The service uses:

- `pg_dump --format=custom`
- uncompressed dump stream for better Restic deduplication
- Restic encryption
- Hetzner Object Storage via S3 API
- retention pruning

Hetzner Object Storage repository examples:

```text
s3:https://fsn1.your-objectstorage.com/<bucket>/prod
s3:https://nbg1.your-objectstorage.com/<bucket>/prod
s3:https://hel1.your-objectstorage.com/<bucket>/prod
```

Production `.env` example:

```env
COMPOSE_PROFILES=backup
BACKUP_RESTIC_REPOSITORY=s3:https://fsn1.your-objectstorage.com/tenos-sync-vault-backups/prod
BACKUP_S3_ACCESS_KEY_ID=<access-key>
BACKUP_S3_SECRET_ACCESS_KEY=<secret-key>
BACKUP_RESTIC_PASSWORD=<long-random-restic-password>
BACKUP_INTERVAL_SECONDS=21600
BACKUP_RETENTION_DAILY=14
BACKUP_RETENTION_WEEKLY=8
BACKUP_RETENTION_MONTHLY=3
```

Start the production stack with backups:

```bash
docker compose up -d --build
```

Check backup logs:

```bash
docker compose logs --tail=100 backup
```

Trigger a manual backup:

```bash
docker compose exec backup backup-once.sh
```

List snapshots:

```bash
docker compose exec backup restic snapshots
```

Run a repository check:

```bash
docker compose exec backup backup-check.sh
```

This backup layer is a logical backup strategy. It is suitable for regular operational restores. If you need minute-level recovery objectives, add PostgreSQL WAL archiving and point-in-time recovery as a separate layer.

## Bundle-Cipher Rollout

The bundle-cipher endpoints let the mobile app fetch QR and clipboard transfer-bundle key material at runtime.

Recommended rollout:

1. Put the current mobile bundle secret into `BUNDLE_CIPHER_CURRENT_SECRET`.
2. Set a stable identifier in `BUNDLE_CIPHER_CURRENT_KID`.
3. Deploy the Vault first.
4. Verify `/bundle-cipher/current` returns `200` with the app token without printing the response body.
5. Deploy the mobile app.

Rotation model:

- New bundles use `CURRENT`.
- Recently issued bundles can still be opened with `PREVIOUS`.
- Keep `PREVIOUS` available for at least the accepted bundle lifetime plus clock-skew tolerance.

## Admin Statistics

Set `ADMIN_STATS_TOKEN` only on the server side. It must not be included in mobile builds or shared client configuration.

Example request:

```bash
curl https://<your-domain>/admin/stats/summary \
  -H "Authorization: Bearer <ADMIN_STATS_TOKEN>"
```

The endpoint returns aggregate operational data only.
