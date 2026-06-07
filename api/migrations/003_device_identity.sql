-- T-002: bring databases created before the per-device identity model up to the
-- current devices schema. 001_init.sql only creates tables if they do not exist,
-- so pre-existing databases never received these columns.
--
-- Idempotent: this file runs on every boot.

alter table devices add column if not exists public_key bytea;
alter table devices add column if not exists capability text not null default 'owner';

do $$
begin
    -- Column check constraint gets the auto-name devices_capability_check when the
    -- table is created via 001_init.sql; guard so both paths converge.
    if not exists (select 1 from pg_constraint where conname = 'devices_capability_check') then
        alter table devices add constraint devices_capability_check
            check (capability in ('owner','read_write'));
    end if;

    if not exists (select 1 from pg_constraint where conname = 'devices_public_key_len') then
        alter table devices add constraint devices_public_key_len
            check (public_key is null or octet_length(public_key) = 32);
    end if;
end $$;
