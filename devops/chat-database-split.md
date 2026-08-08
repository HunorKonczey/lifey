# Chat ↔ monolith database split

The chat service (`lifey-chat`) and the API (`lifey-api`) share **one** Neon
database, but not one set of tables. This doc is the one-time setup that makes
that boundary real, plus how to verify it and how to undo it.

Design and reasoning: [docs/chat/44-chat-service-extraction-plan.md §4](../docs/chat/44-chat-service-extraction-plan.md).
Nothing here deploys anything — the credentials it produces are what the
`lifey-chat` service starts with (§10.1).

## The rule being enforced

| | `chat_conversations`, `chat_messages`, `chat_participants`, `chat_message_attachments` | `users`, `user_settings`, `trainer_clients` | everything else |
|---|---|---|---|
| `lifey-api` (role `lifey`) | **never touches them** — it has no chat code | owner | owner |
| `lifey-chat` (role `lifey_chat`) | owner | **read only** | no access |

Two things enforce it, and both are needed:

1. **Postgres grants** — this document. A bug cannot get past them.
2. **[`check-schema-ownership.sh`](check-schema-ownership.sh)** in CI — catches a
   migration that crosses the line while it is still a pull request, which is
   the cheaper place to find out.

> **Do this before the first `lifey-chat` deploy.** Without the grants the
> service cannot even start: Flyway's first statement is a `create table` it has
> no rights for. That is the intended failure — loud, at startup, before anything
> depends on it.

## 1. Generate a password

Do this locally; the value should go straight into your password manager and
then into Render. It never belongs in git, in a chat window, or in this file.

```bash
openssl rand -base64 32 | tr -d '\n' | tr '+/' '-_'
```

(`+` and `/` are swapped out because the value ends up inside a JDBC URL in some
setups, where they need escaping. `-` and `_` never do.)

## 2. Create the role and grant it exactly what it needs

Neon → your project → **SQL Editor**, against the `lifey` database. Or `psql`
with the existing owner connection string.

Replace `<PASSWORD>` with the value from step 1. Run the whole block at once.

```sql
-- 1. The role. LOGIN only: no CREATEDB, no CREATEROLE, no SUPERUSER.
create role lifey_chat with login password '<PASSWORD>';

-- 2. Its own tables: full access.
grant select, insert, update, delete on
    chat_conversations,
    chat_messages,
    chat_participants,
    chat_message_attachments
    to lifey_chat;

-- 3. The sequences behind those tables' bigserial ids. Without this every
--    insert fails with "permission denied for sequence" — the grant on the
--    table is not enough.
grant usage, select on sequence
    chat_conversations_id_seq,
    chat_messages_id_seq,
    chat_participants_id_seq,
    chat_message_attachments_id_seq
    to lifey_chat;

-- 4. The monolith's tables: READ ONLY. This is the whole §4.1 compromise in
--    one statement — the chat can resolve a display name and check a
--    trainer-client link, and can do nothing else.
grant select on users, user_settings, trainer_clients to lifey_chat;

-- 5. Schema rights. USAGE to see the objects at all; CREATE because Flyway
--    creates its own history table (flyway_schema_history_chat) on first run.
--    Postgres 15+ no longer grants CREATE on `public` to everyone, so this is
--    required, not belt-and-braces.
grant usage, create on schema public to lifey_chat;
```

**What is deliberately *not* granted**, and why it stays that way:

- `push_devices`, `refresh_tokens`, anything else — the chat reaches push and
  mail over HTTP through the monolith (§6.1), never through the database.
- Any `insert`/`update`/`delete` on `users` / `user_settings` / `trainer_clients`.
- `CREATEDB` / `CREATEROLE` — a service role has no business making either.

## 3. Verify

Connect **as `lifey_chat`** and run these five. All five outcomes matter; a
"permission denied" here is the check passing, not failing.

```sql
-- Must SUCCEED — its own table.
select count(*) from chat_messages;

-- Must SUCCEED — the read projection behind ChatUserDirectory (§4.4).
select id, first_name, last_name, email, utc_offset_minutes from users limit 1;

-- Must FAIL: "permission denied for table users".
-- This is the definition of done for M2.
insert into users (email, password_hash, created_at, utc_offset_minutes)
values ('nope@example.com', 'x', now(), 0);

-- Must FAIL: "permission denied for table user_settings".
update user_settings set chat_push_enabled = false;

-- Must FAIL: "permission denied for table push_devices".
select count(*) from push_devices;
```

If the `insert` succeeds, you are still connected as the owner role — check the
connection string before going further. `select current_user;` settles it.

## 4. Store the credentials

Nothing uses them yet. Put them where M6 will need them:

| Where | Key | Value |
|---|---|---|
| Password manager | — | the role password |
| Render → `lifey-chat` → Environment | `SPRING_DATASOURCE_USERNAME` | `lifey_chat` |
| Render → `lifey-chat` → Environment | `SPRING_DATASOURCE_PASSWORD` | the password |
| Render → `lifey-chat` → Environment | `SPRING_DATASOURCE_URL` | the **same** JDBC URL as `lifey-api` — same host, same database, `?sslmode=require`, direct (non-pooler) endpoint |

The URL being identical is the point: one database, two roles.

## Local development

The same split locally, so a permission mistake shows up on your machine rather
than in production. Against the `docker-compose.yml` Postgres:

```bash
docker compose exec postgres psql -U lifey -d lifey
```

Then run the block from step 2 with a throwaway password (`lifey_chat` is fine
locally — it never leaves your machine).

**Order matters, and differently than you might expect.** The grants in step 2
name tables, so those tables have to exist first — but `lifey-chat` is the thing
that creates them, and it cannot until it has the grants. Locally, break the
circle by running the chat service once as the `lifey` role (the default in
`application.yml`), letting it build the schema, then applying the grants and
switching the role. In production the same applies: create the role and the
schema-level grants first, deploy once, then add the table-level grants.

## Flyway ownership

Each application gets its own history table, so their migrations cannot collide
or overwrite each other's checksums:

| Application | History table | Version range |
|---|---|---|
| `lifey-api` | `flyway_schema_history` (default) | `V1`–`V65`, and onward |
| `lifey-chat` | `flyway_schema_history_chat` | `V1000`+ |

Separate history tables make a collision technically impossible; the disjoint
version ranges are for humans, so it is obvious at a glance which migration
belongs to which deployable.

The chat schema moved wholesale into `chat/` as a single `V1000__chat.sql`. It
could, because it had never run anywhere: `main` was at `V63` and the chat lived
on a feature branch, so there was no applied history to preserve. **`V65` is the
one piece that stayed** in `backend/` — it adds chat *columns* to
`user_settings`, which is the monolith's table.

The chat service's Flyway config:

```yaml
spring:
  flyway:
    table: flyway_schema_history_chat
    baseline-on-migrate: true
    baseline-version: 999
```

`baseline-on-migrate` is not about the chat tables — it is about the monolith's.
The shared database is full of them, and Flyway refuses to touch a non-empty
schema it has no history for. Baselining at 999 says "everything below this is
somebody else's business"; the chat's own migrations start at `V1000` and all
run normally.

## Locking the monolith out (optional)

The monolith never writes to these tables — it does not even have the code any
more (§17.6). The grants below were never given to `lifey`, so there is normally
nothing to revoke. Run this only if an older deployment left them behind:

```sql
revoke insert, update, delete on
    chat_conversations,
    chat_messages,
    chat_participants,
    chat_message_attachments
    from lifey;
```

`select` is left in place on purpose: a support query, a data export or an
incident investigation from the monolith's connection is legitimate, and
read-only access cannot corrupt anything.

Harmless to skip. It is belt-and-braces against a grant that predates the
split.

## Undo

```sql
-- Grants first: Postgres refuses to drop a role that still holds any.
revoke all on chat_conversations, chat_messages, chat_participants,
    chat_message_attachments, users, user_settings, trainer_clients from lifey_chat;
revoke all on sequence chat_conversations_id_seq, chat_messages_id_seq,
    chat_participants_id_seq, chat_message_attachments_id_seq from lifey_chat;
revoke all on schema public from lifey_chat;
drop role lifey_chat;
```

If `drop role` still complains about dependent objects, `\drds` and
`select * from pg_shdepend` will name them — most likely the
`flyway_schema_history_chat` table, if the chat service has already run once.
