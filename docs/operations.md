# Operations

This runbook focuses on safe checks that do not print secrets or decrypted data.

Use `<your-domain>` for production examples and `localhost` for local development.

## Health

```bash
docker compose ps
curl https://<your-domain>/healthz
docker compose logs --tail=100 api
```

Expected health response:

```json
{ "ok": true }
```

## Environment Checks

Check whether required variables are configured without printing their values:

```bash
docker compose exec api sh -lc 'test -n "$APP_ISSUE_TOKEN" && echo APP_ISSUE_TOKEN=configured'
docker compose exec api sh -lc 'test -n "$ADMIN_STATS_TOKEN" && echo ADMIN_STATS_TOKEN=configured'
docker compose exec api sh -lc 'test -n "$BUNDLE_CIPHER_CURRENT_KID" && echo BUNDLE_CIPHER_CURRENT_KID=configured'
docker compose exec api sh -lc 'test -n "$BUNDLE_CIPHER_CURRENT_SECRET" && echo BUNDLE_CIPHER_CURRENT_SECRET=configured'
```

Validate the rendered Compose file without printing it:

```bash
docker compose config --quiet
```

## Subject Registration

Relevant endpoint:

```text
POST /subjects/register
```

Common failures:

| Error | Meaning |
| --- | --- |
| `unauthorized` | Missing or wrong app token. |
| `invalid_request` | Request schema mismatch. |
| `invalid_public_key` | Public key is not 32 raw Ed25519 bytes after base64 decoding. |
| `invalid_signature` | Signature is not 64 bytes after base64 decoding. |
| `bad_signature` | Registration message was not signed by the provided key. |
| `subject_exists_with_different_key` | Existing subject has a different root key. |

## Challenge and JWT Issue

Relevant endpoints:

```text
POST /auth/challenge
POST /auth/issue
```

Common failures:

| Error | Meaning |
| --- | --- |
| `unknown_subject` | Subject is not registered or has been deleted. |
| `subject_disabled` | Subject has been administratively disabled. |
| `invalid_challenge` | Challenge does not match subject/device or does not exist. |
| `challenge_used` | Challenge was already consumed. |
| `challenge_expired` | Challenge TTL expired. |
| `bad_signature` | Device did not sign the issue message with the expected key. |
| `device_limit_reached` | The subject reached the configured device limit. |

## Device Management

Relevant endpoints:

```text
POST /devices/authorize
POST /devices/deactivate
POST /devices/disable
```

Useful read-only checks:

```sql
SELECT status, capability, created_at, last_seen_at
FROM devices
WHERE subject_id = '<uuid>'
ORDER BY created_at;
```

Do not paste device IDs from production into public issues.

## Event Sync

Relevant endpoints:

```text
POST /events/batch
GET /events
GET /events/head
```

Common failures:

| Error | Meaning |
| --- | --- |
| `invalid_token` | JWT is missing, invalid, expired, or has wrong claims. |
| `token_revoked` | JWT token version no longer matches the subject. |
| `device_not_registered` | Device row is missing for this subject. |
| `device_disabled` | Device row exists but is disabled. |
| `write_forbidden` | Device capability cannot push events. |
| `device_id_mismatch` | Event device ID differs from JWT device ID. |
| `quota_exceeded_total` | Subject total quota exceeded. |
| `quota_exceeded_daily` | Subject daily quota exceeded. |

Quota check:

```sql
SELECT events_total, max_events_total,
       bytes_total, max_bytes_total,
       events_day, max_events_day,
       bytes_day, max_bytes_day,
       day_date
FROM subjects
WHERE subject_id = '<uuid>';
```

Cursor check:

```sql
SELECT event_id, server_received_at
FROM events
WHERE subject_id = '<uuid>'
ORDER BY server_received_at DESC, event_id DESC
LIMIT 5;
```

## Runtime Bundle Cipher

Relevant endpoints:

```text
GET /bundle-cipher/current
GET /bundle-cipher/:kid
```

Common failures:

| Error | Meaning |
| --- | --- |
| `bundle_cipher_unavailable` | Required bundle-cipher environment variables are missing or invalid. |
| `unknown_bundle_cipher_key` | Requested key ID is neither current nor previous. |

Status-only check:

```bash
curl -s -o /dev/null -w "%{http_code}\n" \
  https://<your-domain>/bundle-cipher/current \
  -H "X-App-Token: <APP_ISSUE_TOKEN>"
```

Do not print or paste the returned `key_b64` into tickets or logs.

## Subject Hard-Delete

Relevant endpoint:

```text
POST /subjects/delete
```

This is an owner-only endpoint. It deletes all encrypted events for the subject and then deletes the subject row. Device and challenge rows are removed by cascading deletes.

Read-only verification:

```sql
SELECT count(*) FROM subjects WHERE subject_id = '<uuid>';
SELECT count(*) FROM events WHERE subject_id = '<uuid>';
SELECT count(*) FROM devices WHERE subject_id = '<uuid>';
```

All counts should be `0` after successful deletion.

## Admin Statistics

Relevant endpoint:

```text
GET /admin/stats/summary
```

Safe request shape:

```bash
curl https://<your-domain>/admin/stats/summary \
  -H "Authorization: Bearer <ADMIN_STATS_TOKEN>"
```

The response contains aggregate counts only. It must not contain subject IDs, device IDs, public keys, JWTs, app tokens, admin tokens, bundle-cipher secrets, or event payloads.

## Backups

The production backup service is enabled through the `backup` Compose profile. It writes encrypted Restic snapshots to S3-compatible object storage.

Check that the service is running:

```bash
docker compose ps backup
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

Do not paste `RESTIC_PASSWORD`, S3 credentials, or repository URLs with private bucket names into public issues.

### Restore Drill

Perform restore tests on a temporary server or temporary database whenever possible.

Restore the latest snapshot into a local `restore/` directory:

```bash
mkdir -p restore
docker compose run --rm \
  --entrypoint backup-restore-latest.sh \
  -v "$PWD/restore:/restore" \
  backup /restore
```

The restored file will be a PostgreSQL custom-format dump, for example:

```text
restore/postgres/syncvault/syncvault-20260101T000000Z.dump
```

Restore into a database container:

```bash
docker compose exec -T db sh -lc \
  'pg_restore --clean --if-exists --no-owner --no-acl -U "$POSTGRES_USER" -d "$POSTGRES_DB"' \
  < restore/postgres/syncvault/<dump-file>.dump
```

For production disaster recovery, stop the API before restoring into the live database:

```bash
docker compose stop api
```

After the restore, start the API and run health checks:

```bash
docker compose start api
curl https://<your-domain>/healthz
```

Backups can contain deleted encrypted records until retention expires. Keep retention windows as short as operationally acceptable.

## Maintenance

Expired challenge cleanup:

```sql
DELETE FROM auth_challenges
WHERE expires_at < now() - interval '1 hour';
```

Expired rendezvous cleanup:

```sql
DELETE FROM rendezvous
WHERE expires_at < now() - interval '1 hour';
```

Quota counter consistency check:

```sql
SELECT s.events_total, count(e.event_id) AS actual_count
FROM subjects s
LEFT JOIN events e ON e.subject_id = s.subject_id
GROUP BY s.subject_id, s.events_total
HAVING s.events_total != count(e.event_id);
```
