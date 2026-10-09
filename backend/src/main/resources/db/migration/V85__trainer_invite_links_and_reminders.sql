-- Two additions to the trainer invite model (LIF-103):
--
-- 1. A shareable join link. An email invite is bound to one existing account from the moment it is sent; a link is
--    not - the trainer sends it anywhere (a chat, a text), and whoever opens it, signs in and accepts becomes the
--    client. So it cannot live in trainer_clients (client_id is mandatory there, and one live row per pair is
--    enforced): it is its own table, and redeeming it creates - or promotes - the ordinary ACTIVE trainer_clients
--    row, which is what the rest of the system (history, seats, chat) already reads.
--
--    Only the SHA-256 of the token is stored, like the emailed accept/decline token: the link is shown once, when it
--    is made. A link is single-use and short-lived (expires_at); revoked_at is the trainer taking it back.
--    redeemed_by is a plain fact about who used it, so it becomes null if that account is deleted.
create table trainer_invite_links (
    id          bigserial primary key,
    trainer_id  bigint not null references users (id) on delete cascade,
    token_hash  varchar(64) not null,
    created_at  timestamptz not null,
    expires_at  timestamptz not null,
    redeemed_at timestamptz,
    redeemed_by bigint references users (id) on delete set null,
    revoked_at  timestamptz
);

create unique index trainer_invite_links_token_hash_idx on trainer_invite_links (token_hash);
create index trainer_invite_links_trainer_idx on trainer_invite_links (trainer_id, created_at desc);

-- 2. A reminder for a pending email invite: when the trainer last nudged the client. Null until the first one; the
--    cooldown between two reminders is counted from it (or from created_at before the first).
alter table trainer_clients add column last_reminded_at timestamptz;
