-- ============================================================
-- Medical Sync Vault - Initial Schema (DEV)
-- "Best audit chance" version:
--   - Proof-of-possession (Ed25519) via challenges
--   - Device registry
--   - Token revocation via token_version
--   - Subject-level quotas (counters + limits)
--   - Zero-knowledge events (ciphertext only)
-- ============================================================

-- ----------------------------
-- EVENTS (unchanged, your version)
-- ----------------------------

create table if not exists events (
                                      subject_id         uuid        not null,
                                      event_id           uuid        not null,
                                      device_id          uuid        not null,

                                      lamport            bigint      not null,
                                      device_seq         bigint      null,

                                      entity_type        text        null,
                                      entity_id          uuid        null,
                                      op_kind            text        null check (op_kind in ('create','update','delete')),

    client_created_at  timestamptz null,
    server_received_at timestamptz not null default now(),

    alg                text        not null,
    nonce              bytea       not null,
    ciphertext         bytea       not null,
    ciphertext_hash    bytea       not null,  -- sha256(ciphertext) => 32 bytes

    primary key (subject_id, event_id),

    constraint events_alg_len_check check (length(alg) between 3 and 64),
    constraint events_nonce_min_check check (octet_length(nonce) >= 8),
    constraint events_ciphertext_min_check check (octet_length(ciphertext) >= 1),
    constraint events_ciphertext_hash_len_check check (octet_length(ciphertext_hash) = 32)
    );

create index if not exists events_subject_eventid_idx
    on events (subject_id, event_id);

-- Stable pull cursor: order by (server_received_at, event_id)
create index if not exists events_subject_server_received_eventid_idx
    on events (subject_id, server_received_at, event_id);

create index if not exists events_subject_lamport_eventid_idx
    on events (subject_id, lamport, event_id);

create unique index if not exists events_subject_cipherhash_uniq
    on events (subject_id, ciphertext_hash);

-- ----------------------------
-- SUBJECTS (root capability)
-- ----------------------------
-- Stores ONLY the Ed25519 public key (32 bytes) + governance data.
-- Private key stays on device(s) only.

create table if not exists subjects (
                                        subject_id      uuid primary key,
                                        public_key      bytea not null,                -- 32 bytes ed25519 public key (raw)

    -- Revocation/rotation: JWT contains tv (token_version)
                                        token_version   integer not null default 1,

    -- Admin disable switch (optional)
                                        disabled_at     timestamptz null,

                                        created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),

    -- Quotas (tune as needed)
    max_events_total bigint not null default 5000000,
    max_bytes_total  bigint not null default 500000000, -- 500 MB

    max_events_day   bigint not null default 20000,
    max_bytes_day    bigint not null default 50000000,  -- 50 MB/day

-- Counters
    events_total     bigint not null default 0,
    bytes_total      bigint not null default 0,

    day_date         date   not null default current_date,
    events_day       bigint not null default 0,
    bytes_day        bigint not null default 0,

    constraint subjects_public_key_len check (octet_length(public_key) = 32),
    constraint subjects_token_version_min check (token_version >= 1)
    );

create index if not exists subjects_disabled_idx
    on subjects (disabled_at);

-- ----------------------------
-- DEVICES (registered devices per subject)
-- ----------------------------

create table if not exists devices (
                                       subject_id   uuid not null references subjects(subject_id) on delete cascade,
    device_id    uuid not null,
    status       text not null default 'active' check (status in ('active','disabled')),

    -- Per-device identity:
    --   public_key NULL    => owner device, authenticated against subjects.public_key
    --   public_key set     => recipient device with its own Ed25519 key
    public_key   bytea null,
    capability   text not null default 'owner' check (capability in ('owner','read_write')),

    created_at   timestamptz not null default now(),
    last_seen_at timestamptz null,

    primary key (subject_id, device_id),

    constraint devices_public_key_len check (public_key is null or octet_length(public_key) = 32)
    );

create index if not exists devices_subject_idx
    on devices (subject_id);

-- ----------------------------
-- RENDEZVOUS (pre-auth pairing mailbox)
-- Stores only public material and ciphertext. Short TTL. No medical content.
-- slot: 'offer' (recipient to owner: public keys) | 'reply' (owner to recipient: wrapped transport key)
-- ----------------------------

create table if not exists rendezvous (
    token       text not null,
    slot        text not null check (slot in ('offer','reply')),
    payload     jsonb not null,
    created_at  timestamptz not null default now(),
    expires_at  timestamptz not null,

    primary key (token, slot)
    );

create index if not exists rendezvous_expires_idx
    on rendezvous (expires_at);

-- ----------------------------
-- AUTH CHALLENGES (anti-replay PoP)
-- ----------------------------

create table if not exists auth_challenges (
                                               challenge_id uuid primary key,
                                               subject_id   uuid not null references subjects(subject_id) on delete cascade,
    device_id    uuid not null,

    challenge    bytea not null, -- random 32 bytes
    expires_at   timestamptz not null,
    used_at      timestamptz null,

    created_at   timestamptz not null default now(),

    constraint auth_challenge_len check (octet_length(challenge) = 32)
    );

create index if not exists auth_challenges_lookup_idx
    on auth_challenges (subject_id, device_id, expires_at);

create index if not exists auth_challenges_used_idx
    on auth_challenges (used_at);

-- Optional: cleanup helper index for cron jobs (not required)
create index if not exists auth_challenges_exp_idx
    on auth_challenges (expires_at);
