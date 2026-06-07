# API Reference

This API transports encrypted medical sync data. Request and response examples intentionally omit real keys, JWTs, tokens, and payloads.

## Authentication Layers

### App Token

Pre-auth endpoints require:

```http
X-App-Token: <APP_ISSUE_TOKEN>
```

The app token is an abuse-protection mechanism. It is not a user identity boundary and should not be treated as a medical-data secret.

### Sync JWT

Sync endpoints require:

```http
Authorization: Bearer <access_token>
```

JWTs are transport capabilities. They contain the subject ID, device ID, and token version.

### Admin Stats Token

The admin statistics endpoint requires:

```http
Authorization: Bearer <ADMIN_STATS_TOKEN>
```

This token must never be shipped in a mobile app.

## Health

### `GET /healthz`

Returns:

```json
{ "ok": true }
```

## Runtime Bundle Cipher

These endpoints provide runtime bundle-cipher material for QR and clipboard transfer bundles. Responses are marked `Cache-Control: no-store`.

### `GET /bundle-cipher/current`

Requires `X-App-Token`.

Returns the current derived bundle-cipher key and optional previous key ID.

```json
{
  "kid": "2026-03-13",
  "key_b64": "<base64>",
  "previous_kid": null
}
```

### `GET /bundle-cipher/:kid`

Requires `X-App-Token`.

Returns the derived key for the configured current or previous key ID.

Unknown key IDs return `404 unknown_bundle_cipher_key`.

## Subject Registration and Recovery

### `POST /subjects/register`

Requires `X-App-Token`.

Registers a subject root public key.

Request:

```json
{
  "subject_id": "<uuid>",
  "public_key_b64": "<base64-ed25519-public-key>",
  "signature_b64": "<base64-signature>"
}
```

The signature must cover:

```text
register|<subject_id>|<public_key_b64>
```

Returns:

```json
{ "ok": true }
```

If the subject already exists with a different public key, the server returns `409 subject_exists_with_different_key`.

### `POST /subjects/by-pubkey`

Requires `X-App-Token`.

Looks up a subject by root public key for recovery flows.

Request:

```json
{
  "public_key_b64": "<base64-ed25519-public-key>"
}
```

Returns:

```json
{
  "subject_id": "<uuid>"
}
```

## Proof-of-Possession Token Flow

### `POST /auth/challenge`

Requires `X-App-Token`.

Request:

```json
{
  "subject_id": "<uuid>",
  "device_id": "<uuid>"
}
```

Returns:

```json
{
  "challenge_id": "<uuid>",
  "challenge_b64": "<base64-random-challenge>",
  "expires_in": 60
}
```

### `POST /auth/issue`

Requires `X-App-Token`.

Request:

```json
{
  "subject_id": "<uuid>",
  "device_id": "<uuid>",
  "challenge_id": "<uuid>",
  "signature_b64": "<base64-signature>"
}
```

The signature must cover:

```text
issue|<subject_id>|<device_id>|<challenge_id>|<challenge_b64>
```

Returns:

```json
{
  "access_token": "<jwt>",
  "token_type": "Bearer",
  "expires_in": 15552000
}
```

## Device Management

### `POST /devices/authorize`

Requires `X-App-Token`.

Creates or updates a recipient device grant. The request is signed by the subject root key.

Request:

```json
{
  "subject_id": "<uuid>",
  "target_device_id": "<uuid>",
  "target_public_key_b64": "<base64-ed25519-public-key>",
  "capability": "read_write",
  "signature_b64": "<base64-signature>"
}
```

The signature must cover:

```text
authorize|<subject_id>|<target_device_id>|<target_public_key_b64>|<capability>
```

Returns:

```json
{
  "ok": true,
  "device_id": "<uuid>",
  "capability": "read_write"
}
```

### `POST /devices/deactivate`

Requires sync JWT.

Disables the current device.

Returns:

```json
{
  "ok": true,
  "device_id": "<uuid>",
  "status": "disabled"
}
```

### `POST /devices/disable`

Requires owner sync JWT.

Disables another device for the same subject.

Request:

```json
{
  "target_device_id": "<uuid>"
}
```

Returns:

```json
{
  "ok": true,
  "device_id": "<uuid>",
  "status": "disabled"
}
```

## Rendezvous Pairing

### `POST /rendezvous/:token`

Requires `X-App-Token`.

Stores a short-lived pairing slot.

Request:

```json
{
  "slot": "offer",
  "payload": {}
}
```

`slot` may be `offer` or `reply`.

Returns:

```json
{
  "ok": true,
  "expires_in": 300
}
```

### `GET /rendezvous/:token`

Requires `X-App-Token`.

Returns available pairing slots:

```json
{
  "offer": {},
  "reply": null
}
```

If a reply is returned, all slots for that token are deleted.

## Events

### `POST /events/batch`

Requires sync JWT.

Owner and `read_write` devices may push events.

Request:

```json
{
  "events": [
    {
      "event_id": "<uuid>",
      "device_id": "<uuid>",
      "lamport": 1,
      "device_seq": 1,
      "entity_type": "Observation",
      "entity_id": "<uuid>",
      "op_kind": "create",
      "client_created_at": "2026-01-01T00:00:00.000Z",
      "alg": "nacl-secretbox",
      "nonce_b64": "<base64>",
      "ciphertext_b64": "<base64>",
      "ciphertext_hash_b64": "<base64-sha256>"
    }
  ]
}
```

Returns:

```json
{
  "acked": ["<uuid>"]
}
```

Duplicate event IDs are acknowledged idempotently.

### `GET /events`

Requires sync JWT.

Query parameters:

- `limit`
- `since_ts`
- `since_id`

Returns encrypted events and the next cursor:

```json
{
  "events": [],
  "next": null
}
```

### `GET /events/head`

Requires sync JWT.

Returns the current head cursor:

```json
{
  "head": {
    "since_ts": "2026-01-01T00:00:00.000Z",
    "since_id": "<uuid>"
  }
}
```

If there are no events:

```json
{ "head": null }
```

## Subject Lifecycle

### `POST /subjects/delete`

Requires owner sync JWT.

Hard-deletes the subject and all associated encrypted events. Device and challenge rows are removed through cascading deletes.

Returns:

```json
{
  "ok": true,
  "deleted_events": 0
}
```

The endpoint is idempotent for already deleted subjects.

### `POST /subjects/update-key`

Requires owner sync JWT.

Updates the subject root public key and increments the token version, invalidating existing JWTs.

Request:

```json
{
  "new_public_key_b64": "<base64-ed25519-public-key>",
  "signature_b64": "<base64-signature>"
}
```

The signature must cover:

```text
update-key|<subject_id>|<new_public_key_b64>
```

Returns:

```json
{
  "ok": true,
  "token_version": 2
}
```

## Admin Statistics

### `GET /admin/stats/summary`

Requires `Authorization: Bearer <ADMIN_STATS_TOKEN>`.

Returns aggregate operational statistics only:

```json
{
  "generated_at": "2026-01-01T00:00:00.000Z",
  "patients": {
    "total": 0,
    "active": 0,
    "disabled": 0,
    "active_24h": 0,
    "active_7d": 0,
    "active_30d": 0
  },
  "devices": {
    "total": 0,
    "active": 0,
    "disabled": 0,
    "owner": 0,
    "read_write": 0,
    "active_24h": 0,
    "active_7d": 0,
    "active_30d": 0,
    "avg_per_patient": 0,
    "p50_per_patient": 0,
    "p95_per_patient": 0
  },
  "events": {
    "total": 0,
    "accounted_total": 0,
    "last_24h": 0,
    "last_7d": 0,
    "last_30d": 0
  },
  "storage": {
    "encrypted_bytes": 0,
    "accounted_bytes": 0,
    "avg_accounted_bytes_per_patient": 0
  },
  "pairing": {
    "open_offers": 0,
    "open_replies": 0,
    "expired": 0
  },
  "auth_challenges": {
    "open": 0,
    "used": 0,
    "expired": 0
  },
  "quotas": {
    "patients_above_80_percent_events": 0,
    "patients_above_80_percent_bytes": 0
  }
}
```

No subject IDs, device IDs, public keys, JWTs, app tokens, admin tokens, bundle-cipher secrets, or payloads are returned.
