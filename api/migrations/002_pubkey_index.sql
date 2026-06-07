-- Unique index on public_key for reverse lookup (recovery by pubkey)
CREATE UNIQUE INDEX IF NOT EXISTS subjects_public_key_uniq ON subjects (public_key);
