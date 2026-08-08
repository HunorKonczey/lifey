-- TEST ONLY — docs/chat/44-chat-service-extraction-plan.md §4.2.1.
--
-- The chat's foreign keys point at tables the monolith owns. Against the shared
-- production database those tables are there; against the chat service's own
-- Testcontainers database they are not, so V1000 would fail on the very first
-- `references users (id)`.
--
-- This creates just enough of them to stand the chat schema up AND to exercise
-- the read projections in com.lifey.chat.spi.jdbc — which is the real value:
-- those three adapters are hand-written SQL against columns this service does
-- not own, so a test that never runs them would be the most dangerous gap in
-- the whole extraction.
--
-- COLUMN-FOR-COLUMN with the monolith's schema for the columns listed in §4.4,
-- and nothing else. If a projection ever needs a new column, it gets added
-- here in the same commit — that is the point of friction that keeps the read
-- contract honest.
--
-- Numbered V1 rather than V1000+: it runs from a separate location under a
-- separate Flyway history in the test profile only, so it can never collide
-- with either application's real migrations.

-- Accent-insensitive in-thread search (§20). In production this comes from the
-- monolith's V48 and this service's role could not install it anyway; a
-- chat-only test database has to create it, or every accented search silently
-- returns nothing.
create extension if not exists unaccent;

create table users
(
    id                 bigserial primary key,
    email              varchar(255) not null unique,
    first_name         varchar(255),
    last_name          varchar(255),
    -- Not read by the chat, but NOT NULL in the real schema: leaving it out
    -- would let a test insert a row production would reject.
    password_hash      varchar(255) not null,
    created_at         timestamptz  not null,
    utc_offset_minutes int          not null default 0
);

create table user_settings
(
    id                      bigserial primary key,
    user_id                 bigint  not null unique references users (id),
    language                varchar(20) not null default 'SYSTEM',
    chat_push_enabled       boolean not null default true,
    chat_quiet_hours_start  time,
    chat_quiet_hours_end    time
);

create table trainer_clients
(
    id         bigserial primary key,
    trainer_id bigint      not null references users (id),
    client_id  bigint      not null references users (id),
    status     varchar(20) not null,
    created_at timestamptz not null
);
