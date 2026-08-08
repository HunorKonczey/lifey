-- The chat schema — this service's initial migration.
-- Design: docs/chat/40-trainer-chat-plan.md §3.1.
--
-- These tables were written for the monolith (as V64/V66/V67 on the chat feature
-- branch) but never reached a deployed database: main is at V63, so Neon has
-- never seen them. That is why they could simply move here rather than being
-- baselined around — the chat service creates and owns them outright
-- (docs/chat/44-chat-service-extraction-plan.md §17.6). The three original
-- migrations are collapsed into this one final state; there is no history worth
-- replaying for a table that never existed.
--
-- The foreign keys to users/trainer_clients stay: in the shared production
-- database those tables are the monolith's and they are there (§4.1). A
-- chat-only test database gets stand-ins from
-- src/test/resources/db/migration-test/V1__monolith_stub.sql.
--
-- `unaccent` (used by the in-thread search) is NOT created here: it is the
-- monolith's, from its V48, and this service's role has no rights to install
-- extensions. The test stub creates it for a chat-only database.

create table chat_conversations
(
    id                bigserial primary key,
    trainer_client_id bigint      not null references trainer_clients (id),
    trainer_id        bigint      not null references users (id),
    client_id         bigint      not null references users (id),
    created_at        timestamptz not null,
    -- Denormalized list-ordering/preview pointers, written in the same
    -- transaction as the message itself. Deliberately not a foreign key: this
    -- is a cache of chat_messages, not a dependency of it.
    last_message_at   timestamptz,
    last_message_id   bigint,
    archived_at       timestamptz,
    constraint uq_chat_conversation_link unique (trainer_client_id)
);

create index idx_chat_conv_trainer on chat_conversations (trainer_id, last_message_at desc);
create index idx_chat_conv_client on chat_conversations (client_id, last_message_at desc);

create table chat_messages
(
    id                   bigserial primary key,
    conversation_id      bigint      not null references chat_conversations (id),
    sender_id            bigint      not null references users (id),
    -- Nulled out when the sender tombstones the message; the row survives so
    -- the other side keeps the context of their own replies (§1.3/2).
    body                 text,
    -- Client-generated UUID: makes an offline retry of POST /messages idempotent.
    client_message_id    varchar(64) not null,
    created_at           timestamptz not null,
    deleted_at           timestamptz,
    -- Kept on the message rather than joined from the attachment table: a
    -- client needs the aspect ratio to reserve space before the picture
    -- arrives, or the thread reflows as images load.
    attachment_width     int,
    attachment_height    int,
    attachment_byte_size int,
    constraint uq_chat_message_client_id unique (conversation_id, client_message_id),
    -- A message must carry something: text, an image, or a tombstone.
    constraint chat_messages_content_present
        check (deleted_at is not null or body is not null or attachment_width is not null)
);

create index idx_chat_msg_conv on chat_messages (conversation_id, id desc);

-- Per-participant read state. Deliberately NOT a per-message read flag: in a
-- 1:1 thread readership is monotonic, so a single cursor is an O(1) write per
-- receipt and the unread count is one count(*) above it (§3.1).
create table chat_participants
(
    id                        bigserial primary key,
    conversation_id           bigint not null references chat_conversations (id),
    user_id                   bigint not null references users (id),
    last_read_message_id      bigint,
    last_read_at              timestamptz,
    last_delivered_message_id bigint,
    muted_until               timestamptz,
    -- Push coalescing window bookkeeping (§5.3).
    last_notified_at          timestamptz,
    -- The per-user daily reminder cap (§5.4), written to every one of the
    -- user's rows because there is no per-user chat row to hang it on.
    last_reminded_at          timestamptz,
    constraint uq_chat_participant unique (conversation_id, user_id)
);

create index idx_chat_participant_user on chat_participants (user_id);
create index idx_chat_participant_reminder on chat_participants (last_reminded_at);

-- Bytes live in their own table, not on chat_messages: the thread query reads
-- every message on a page, and a bytea column there would drag two re-encoded
-- JPEGs per row through a keyset page that only wants text.
create table chat_message_attachments
(
    id           bigserial primary key,
    -- on delete cascade so a hard row removal (a GDPR erase, a future purge)
    -- cannot leave orphaned image bytes behind. Tombstoning goes through
    -- ChatServiceImpl.deleteMessage, which removes this row explicitly.
    message_id   bigint      not null references chat_messages (id) on delete cascade,
    image        bytea       not null,
    thumbnail    bytea       not null,
    content_type varchar(64) not null,
    created_at   timestamptz not null,
    constraint uq_chat_attachment_message unique (message_id)
);
