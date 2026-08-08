# Render environment files

Paste-ready `.env` files for Render's **Environment → Add from .env** import.

| File | Service | What it is |
|---|---|---|
| [`lifey-chat.env`](lifey-chat.env) | `lifey-chat` | The complete environment for the chat service |
| [`lifey-api-chat-additions.env`](lifey-api-chat-additions.env) | `lifey-api` | Only the three variables the chat split **adds** — not the full environment |

Every value that can be known is filled in. The rest are marked
`<<< FILL IN >>>`; Render will happily import those literally, so search for
`<<<` in the dashboard afterwards to make sure none survived.

**These files must never contain real secrets.** They are in git. Fill the
placeholders in the Render dashboard, or in a local copy you do not commit.

Order, and why it matters: [docs/chat/44-chat-service-extraction-plan.md §10.2](../../docs/chat/44-chat-service-extraction-plan.md).
Database roles and grants: [chat-database-split.md](../chat-database-split.md).

## The three values that must match across both services

A mismatch in any of these is a specific, recognisable failure:

| Variable | Symptom when it does not match |
|---|---|
| `JWT_SECRET` | **Every** chat request returns 401 |
| `LIFEY_INTERNAL_TOKEN` | No push notifications; `lifey.chat.internal.push{outcome=failed}` climbs |
| `SPRING_DATASOURCE_URL` | No error at all — the chat quietly runs against a different database |

The third is the dangerous one, because nothing reports it. Copy the URL
verbatim rather than retyping it.
