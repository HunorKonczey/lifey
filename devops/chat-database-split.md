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
> service cannot even start — Flyway fails on `V1000__chat.sql`. That is the
> intended failure: loud, at startup, before anything depends on it. The two
> ways it shows up:
>
> - `permission denied for table trainer_clients` → the **`references`** grant
>   is missing (step 2/3). Easy to miss, because `select` looks like enough.
> - `permission denied for schema public` → the **`create`** grant is missing
>   (step 2/2).

## 1. Generate a password

Do this locally; the value should go straight into your password manager and
then into Render. It never belongs in git, in a chat window, or in this file.

```bash
openssl rand -base64 32 | tr -d '\n' | tr '+/' '-_'
```

(`+` and `/` are swapped out because the value ends up inside a JDBC URL in some
setups, where they need escaping. `-` and `_` never do.)

## 2. Create the role and grant it exactly what it needs

Neon → your project → **SQL Editor**, against the database `lifey-api` uses.
Or `psql` with the existing owner connection string.

Replace `<PASSWORD>` with the value from step 1. Run the whole block at once.

```sql
-- 1. The role. LOGIN only: no CREATEDB, no CREATEROLE, no SUPERUSER.
create role lifey_chat with login password '<PASSWORD>';

-- 2. Schema rights. USAGE to see the objects at all; CREATE so it can build
--    its own tables and its Flyway history table (flyway_schema_history_chat).
--    Postgres 15+ no longer grants CREATE on `public` to everyone, so this is
--    required, not belt-and-braces.
grant usage, create on schema public to lifey_chat;

-- 3. The monolith's tables. SELECT for the read projections (§4.4) — and
--    REFERENCES, which is the one that is easy to miss: pointing a foreign key
--    AT a table is its own privilege in Postgres, separate from reading it.
--    Without it the chat service dies on its very first migration with
--    "permission denied for table trainer_clients", because V1000__chat.sql
--    declares `references trainer_clients (id)` and `references users (id)`.
grant select, references on users, trainer_clients to lifey_chat;

-- 4. user_settings is read but never referenced by a foreign key, so SELECT
--    alone is right here.
grant select on user_settings to lifey_chat;
```

**That is all of it.** There are deliberately **no grants on the `chat_*`
tables or their sequences**: `lifey_chat` *creates* them, and in Postgres the
creator owns what it creates and holds every privilege on it automatically.
Trying to grant on them up front is not just unnecessary, it is impossible —
they do not exist until the service has started once.

**What is deliberately *not* granted**, and why it stays that way:

- `push_devices`, `refresh_tokens`, anything else — the chat reaches push and
  mail over HTTP through the monolith (§6.1), never through the database.
- Any `insert`/`update`/`delete` on `users` / `user_settings` / `trainer_clients`.
- `CREATEDB` / `CREATEROLE` — a service role has no business making either.

## 3. Verify

Run these **after the chat service has started once** — before that, the
`chat_*` tables do not exist yet.

Connect **as `lifey_chat`**. All five outcomes matter; a "permission denied"
here is the check passing, not failing.

```sql
-- Must SUCCEED — its own table.
select count(*) from chat_messages;

-- Must SUCCEED — the read projection behind ChatUserDirectory (§4.4).
select id, first_name, last_name, email, utc_offset_minutes from users limit 1;

-- Must FAIL: "permission denied for table users".
-- This is the whole point of the separate role.
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

**Order matters:** the grants in step 2 name the monolith's tables, so run
`lifey-api` once first and let Flyway build them. After that the chat service
can start as `lifey_chat` straight away — it creates its own tables, so there is
nothing left to grant.

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
-- The chat tables are OWNED by lifey_chat, so they have to be reassigned or
-- dropped before the role can go. Reassign keeps the data.
reassign owned by lifey_chat to lifey;
drop owned by lifey_chat;          -- removes the remaining grants
drop role lifey_chat;
```

`reassign owned by` moves the `chat_*` tables and
`flyway_schema_history_chat` to the owner role; `drop owned by` then clears the
grants that are left. Without the first statement, `drop role` fails with
"cannot be dropped because some objects depend on it".
