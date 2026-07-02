create table password_reset_tokens (
    id          uuid primary key,
    user_id     bigint not null references users (id) on delete cascade,
    code_hash   varchar(255) not null,
    expires_at  timestamptz not null,
    used_at     timestamptz,
    attempts    int not null default 0,
    created_at  timestamptz not null default now()
);

create index idx_prt_user_id on password_reset_tokens (user_id);
