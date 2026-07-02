create table user_identities (
    id                uuid primary key,
    user_id           bigint not null references users (id) on delete cascade,
    provider          varchar(20) not null,
    provider_user_id  varchar(255) not null,
    email             varchar(255),
    created_at        timestamptz not null default now(),
    unique (provider, provider_user_id)
);

create index idx_user_identities_user_id on user_identities (user_id);

alter table users alter column password_hash drop not null;
