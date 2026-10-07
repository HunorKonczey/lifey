-- Replay store for the Idempotency-Key header (com.lifey.idempotency).
--
-- The mobile outbox retries a create after a timeout or a gateway 502/503/504, but the request may well have
-- reached the server and committed before the answer was lost: the retry then created the same entity a second
-- time, and the first row came back on the next pull as a duplicate the user never made. The outbox now sends the
-- entity's own clientId as Idempotency-Key; the first request with a key claims a row here, and once it has
-- answered 2xx its status and body are kept so a repeat gets that same answer instead of running again.
--
-- (user_id, idem_key) is the identity, so one user's key can never replay another's response. A row without a
-- response_status is a request still in flight (or one whose server died); the service lets a later request take
-- it over after a couple of minutes. Rows are only worth keeping while a client could still retry, and are
-- swept by IdempotencyKeyCleanupJob.
create table idempotency_keys (
    id                    bigserial primary key,
    user_id               bigint not null references users (id) on delete cascade,
    idem_key              varchar(80) not null,
    method                varchar(10) not null,
    path                  varchar(500) not null,
    response_status       integer,
    response_content_type varchar(200),
    response_body         bytea,
    created_at            timestamptz not null default now(),
    constraint idempotency_keys_user_key_uq unique (user_id, idem_key)
);

create index idx_idempotency_keys_created_at on idempotency_keys (created_at);
