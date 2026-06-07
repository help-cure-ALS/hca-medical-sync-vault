#!/usr/bin/env bash
set -Eeuo pipefail

require_env() {
    local name="$1"
    if [[ -z "${!name:-}" ]]; then
        echo "Missing required environment variable: ${name}" >&2
        exit 1
    fi
}

require_env DATABASE_URL
require_env RESTIC_REPOSITORY
require_env RESTIC_PASSWORD
require_env AWS_ACCESS_KEY_ID
require_env AWS_SECRET_ACCESS_KEY

export RESTIC_CACHE_DIR="${RESTIC_CACHE_DIR:-/cache/restic}"
mkdir -p "${RESTIC_CACHE_DIR}"

db_name="${BACKUP_DATABASE_NAME:-${POSTGRES_DB:-syncvault}}"
snapshot_host="${BACKUP_RESTIC_HOSTNAME:-sync-vault}"
timestamp="$(date -u +"%Y%m%dT%H%M%SZ")"
stdin_filename="postgres/${db_name}/${db_name}-${timestamp}.dump"

echo "Starting PostgreSQL logical backup: ${stdin_filename}"

pg_dump \
    --format=custom \
    --compress=0 \
    --no-owner \
    --no-acl \
    --dbname="${DATABASE_URL}" \
    | restic backup \
        --host "${snapshot_host}" \
        --tag postgres \
        --tag sync-vault \
        --tag "${db_name}" \
        --stdin \
        --stdin-filename "${stdin_filename}"

echo "Backup completed. Applying retention policy."

restic forget \
    --host "${snapshot_host}" \
    --tag postgres \
    --tag sync-vault \
    --keep-daily "${BACKUP_RETENTION_DAILY:-14}" \
    --keep-weekly "${BACKUP_RETENTION_WEEKLY:-8}" \
    --keep-monthly "${BACKUP_RETENTION_MONTHLY:-3}" \
    --prune

if [[ "${BACKUP_RUN_CHECK_AFTER_BACKUP:-false}" == "true" ]]; then
    echo "Running restic repository check."
    restic check
fi

echo "Backup maintenance completed."
