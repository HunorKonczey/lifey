-- Image attachments on chat messages
-- (docs/chat/40-trainer-chat-plan.md I6, §18).

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

-- Dimensions and size stay *on the message* so the list and thread endpoints
-- can tell a client "there is an image, and it is this shape" without touching
-- the bytes. The client needs the aspect ratio before the image arrives, or
-- every thread would jump as pictures load.
alter table chat_messages
    add column attachment_width     int,
    add column attachment_height    int,
    add column attachment_byte_size int;

-- A message must now carry *something*: text, an image, or a tombstone.
alter table chat_messages
    drop constraint chat_messages_body_present;
alter table chat_messages
    add constraint chat_messages_content_present
        check (deleted_at is not null or body is not null or attachment_width is not null);
