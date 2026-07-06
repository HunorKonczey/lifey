-- Trainer-client relationship and invites (docs/personal_trainer/02-domain-es-migraciok.md,
-- "Változás 2"). A single table carries both the invite AND the relationship
-- itself: a pending invite IS the relationship in its PENDING state, so no
-- separate invites table is needed. History is kept (declined/revoked rows
-- are never deleted, only superseded by a new row), which is why uniqueness
-- only applies to the "live" statuses rather than the whole (trainer_id,
-- client_id) pair.
create table trainer_clients (
    id           bigserial primary key,
    trainer_id   bigint not null references users (id),
    client_id    bigint not null references users (id),
    status       varchar(16) not null,        -- PENDING | ACTIVE | DECLINED | REVOKED | EXPIRED
    created_at   timestamptz not null default now(),
    expires_at   timestamptz not null,        -- created_at + 24h (only meaningful while PENDING)
    responded_at timestamptz,                 -- when the client accepted/declined
    revoked_at   timestamptz,
    revoked_by   bigint references users (id),-- who tore down an ACTIVE relationship (trainer or client)
    constraint trainer_clients_no_self check (trainer_id <> client_id)
);

create index trainer_clients_trainer_idx on trainer_clients (trainer_id, status);
create index trainer_clients_client_idx  on trainer_clients (client_id, status);

-- A trainer-client pair can have at most one live (pending or active) row at a time.
create unique index trainer_clients_one_live_uq
    on trainer_clients (trainer_id, client_id)
    where status in ('PENDING', 'ACTIVE');
