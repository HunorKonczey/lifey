-- Authentication: password storage, roles, and persisted (rotatable) refresh tokens.

alter table users
    add column password_hash varchar(255);

-- Backfill any pre-auth user rows with a hash nobody knows the plaintext for
-- (a valid bcrypt-format placeholder), then enforce the column going forward.
-- This is a one-time migration concern, not a real account: nothing in the API
-- issues a password for it, so it can never be logged into.
update users
    set password_hash = '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy'
    where password_hash is null;

alter table users
    alter column password_hash set not null;

create table user_roles (
    user_id bigint      not null references users (id) on delete cascade,
    role    varchar(20) not null,
    primary key (user_id, role)
);

-- Every pre-existing user becomes a regular user; nobody is silently promoted to admin.
insert into user_roles (user_id, role)
    select id, 'ROLE_USER' from users
    on conflict do nothing;

create table refresh_tokens (
    id          uuid primary key,
    user_id     bigint                   not null references users (id) on delete cascade,
    token_hash  varchar(255)             not null unique,
    expires_at  timestamp with time zone not null,
    revoked     boolean                  not null default false,
    created_at  timestamp with time zone not null,
    device_info varchar(255)
);

create index refresh_tokens_user_id_idx on refresh_tokens (user_id);
