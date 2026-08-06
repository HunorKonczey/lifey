-- Trainer <-> client chat, backend foundation
-- (docs/chat/40-trainer-chat-plan.md §3.1, iteration I1).

-- One conversation per trainer-client relationship. 1:1, hence the unique link.
-- A re-invited client gets a *new* trainer_clients row and therefore a new
-- conversation; the old thread stays around, archived and read-only (§1.3/1).
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
    id                bigserial primary key,
    conversation_id   bigint      not null references chat_conversations (id),
    sender_id         bigint      not null references users (id),
    -- Nulled out when the sender tombstones the message; the row survives so
    -- the other side keeps the context of their own replies (§1.3/2).
    body              text,
    -- Client-generated UUID: makes an offline retry of POST /messages idempotent.
    client_message_id varchar(64) not null,
    created_at        timestamptz not null,
    deleted_at        timestamptz,
    constraint uq_chat_message_client_id unique (conversation_id, client_message_id),
    constraint chat_messages_body_present check (deleted_at is not null or body is not null)
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
    -- Push coalescing window bookkeeping (§5.3) — unused until iteration I5.
    last_notified_at          timestamptz,
    constraint uq_chat_participant unique (conversation_id, user_id)
);

create index idx_chat_participant_user on chat_participants (user_id);
