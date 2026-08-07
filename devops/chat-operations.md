# Operations — Trainer ↔ client chat

What to know about the chat when something is wrong with it. Design and
rationale live in [docs/chat/40-trainer-chat-plan.md](../docs/chat/40-trainer-chat-plan.md);
this doc is the operational half — the levers, the numbers, and what they mean.

> **One instance.** The chat's realtime layer keeps its live connections in
> memory on the instance serving them (`InMemoryChatEventBus`). Render runs
> `lifey-api` as a single instance, which is what makes that correct. **Scaling
> to two instances silently degrades realtime**: a message only streams to
> clients connected to the same node as the sender. Nothing breaks — push and
> the 60-second poll cover it — but "instant" becomes "within a minute". See
> [Scaling out](#scaling-out) before you change the instance count.

## The kill switch

`CHAT_ENABLED=false` (Render → Environment → save; the service restarts).

- Existing threads stay **readable**: the list, the history, the images, the
  search all keep working.
- **Sending is refused with 503** — `ChatDisabledException`. Both clients show
  "Chat is temporarily unavailable" and, on mobile, the message stays in the
  local outbox rather than being lost, so it goes out when you flip the switch
  back.
- Realtime, push and the reminder job are unaffected by the flag. It stops new
  writes; it is not a full off switch.

Use it when the chat itself is the problem (a storage issue, an abuse wave).
It is deliberately *not* a rollout flag — the feature is live for everyone.

## Reading the numbers

Metrics are exposed at **`GET /actuator/metrics`**, locked to
**`ROLE_SUPER_ADMIN`** (`SecurityConfig`). There is no Prometheus or Grafana on
this deployment, so this endpoint *is* the dashboard: fetch it with a super-admin
access token.

```bash
# One meter, with its tags broken out:
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://<service>.onrender.com/actuator/metrics/lifey.chat.push.decisions?tag=outcome:sent"
```

| Meter | Type | What it answers |
|---|---|---|
| `lifey.chat.messages.sent` (`kind` = `text` \| `image`) | counter | Is the chat being used, and how much of it is images (the part that costs storage)? |
| `lifey.chat.stream.connections` | gauge | How many SSE connections are open **on this instance right now** |
| `lifey.chat.push.decisions` (`outcome` = `sent` \| `skipped-viewing` \| `skipped-disabled` \| `skipped-quiet-hours` \| `skipped-muted` \| `skipped-coalesced`) | counter | Of every message worth notifying about, how many actually interrupted someone — and when they didn't, which gate stopped it |
| `lifey.chat.reminders.sent` (`channel` = `push` \| `email`) | counter | How often the §5.4 safety net had to fire |

Every series exists from startup, at zero. That is deliberate: "no data" and
"nothing happened" have to look different, or the thresholds below can't be
read.

### Thresholds — what should worry you

There is no alerting system wired up, so these are the numbers to check by hand
when the chat is suspect, not automated alerts. Each says what "bad" looks like
and what it means.

**1. Connection leak.** `lifey.chat.stream.connections` climbing and not coming
back down.

- Normal: roughly the number of people with the app open. It drops to near zero
  overnight.
- Worry: a floor that keeps rising day over day — 50 at 04:00 when nobody is
  awake means 50 emitters nobody closed.
- Why it matters: each connection is ~107 KB of heap (measured, plan §15.5), and
  this instance is capped at 192 MB. A leak ends as an OOM kill.
- First move: restart the service. The emitters are in memory, so a restart is a
  complete fix for the symptom; then look for what changed in
  `ChatEmitterRegistry`'s cleanup paths (`onCompletion` / `onTimeout` / `onError`).
- Bound: `CHAT_STREAM_TIMEOUT` (default 5m) forces every connection closed and
  reopened, so a leaked emitter cannot outlive it. If you see connections older
  than that, the timeout is not being applied.

**2. Nobody is being notified.** `lifey.chat.push.decisions` where `sent` is
near zero while the skip reasons keep climbing.

- Normal: a healthy mix. `skipped-viewing` is *good* — it means people are
  reading the message as it arrives.
- Worry: one skip reason dominating everything. Each points at a different bug:
  - `skipped-disabled` everywhere → the settings read is wrong, or a client
    release is writing `chatPushEnabled: false`.
  - `skipped-quiet-hours` outside the night → `users.utc_offset_minutes` is
    wrong or stale (`ChatQuietHours` derives local time from it).
  - `skipped-coalesced` dominating → `CHAT_PUSH_COALESCE_WINDOW` is too wide, or
    `last_notified_at` is not being cleared.
  - `skipped-viewing` at 100% → presence is stuck; a client is reporting a
    thread it isn't showing. `CHAT_PRESENCE_TTL` (2m) bounds the damage.
- Cross-check: `lifey.chat.reminders.sent{channel=push}` rising at the same time
  is the safety net catching what the gates dropped — reassuring for users,
  still a bug.

**3. Push delivery itself failing.** The decision counter says `sent`; whether
APNs/FCM accepted it is a different question, and one this deployment answers
from **logs**, not metrics — `PushService` logs failures and prunes dead tokens.
Grep the Render logs for push errors; see
[push-notifications-ios.md](push-notifications-ios.md) /
[push-notifications-android.md](push-notifications-android.md).

**4. Storage growth.** `lifey.chat.messages.sent{kind=image}` is the driver.
Attachment bytes live in Postgres (`chat_message_attachments`), capped at
`CHAT_ATTACHMENT_MAX_BYTES` (8 MB) per upload before re-encoding, and stored at
`CHAT_ATTACHMENT_MAX_SIDE` (1600 px) plus a thumbnail — realistically a few
hundred KB each. There is **no retention policy**: nothing ever deletes old
messages or images. At a few images a day this is irrelevant for years; if it
stops being irrelevant, the fix is object storage, not a cleanup job (plan §18.3).

## Symptoms → causes

| Symptom | Look at | Likely cause |
|---|---|---|
| "Messages arrive late / only when I reopen the app" | `lifey.chat.stream.connections` ≈ 0 while people are online | The stream is not connecting. Check that the reverse proxy isn't buffering (`X-Accel-Buffering: no` is set by `ChatStreamController`), and that nothing in front of Render is capping response time below `CHAT_STREAM_TIMEOUT`. |
| "I get pushes for messages I already read" | `skipped-viewing` near zero | Presence isn't reaching the server. Losing presence is the safe direction by design — an extra notification, never a missed message. |
| "I get no push at all" | `push.decisions` by outcome | Walk the gates in the table above. |
| "Sending fails with 503" | `CHAT_ENABLED` | Someone flipped the kill switch. |
| "Sending fails with 429" | — | Per-user rate limit: `CHAT_RATE_LIMIT_PER_MINUTE` (30) / `CHAT_RATE_LIMIT_PER_DAY` (600), in memory per instance. Abuse protection, not accounting. |
| "The image upload fails" | HTTP status | 413 = over `CHAT_ATTACHMENT_MAX_BYTES`; 400 = not a decodable image. The container-wide multipart cap (10 MB, shared with avatars) sits above the chat's own. |
| "Search finds nothing for an accented word" | — | Search goes through Postgres `unaccent` (`V48__unaccent_search.sql`). If that extension is missing on a restored database, every accented search silently returns nothing. `CREATE EXTENSION IF NOT EXISTS unaccent;` |

## Configuration reference

All under `lifey.chat.*`; every one has an env override (see
`backend/src/main/resources/application.yml` for the full commentary).

| Env var | Default | What it does |
|---|---|---|
| `CHAT_ENABLED` | `true` | Kill switch — reads keep working, sends get 503 |
| `CHAT_MAX_BODY_LENGTH` | `2000` | Characters per message, after trimming |
| `CHAT_RATE_LIMIT_PER_MINUTE` / `_PER_DAY` | `30` / `600` | Per-user send budget |
| `CHAT_STREAM_TIMEOUT` | `5m` | Forced SSE reconnect — also the leak bound |
| `CHAT_STREAM_HEARTBEAT` | `20s` | Keeps proxies from closing an idle stream |
| `CHAT_STREAM_CATCH_UP_LIMIT` | `200` | Messages replayed on reconnect before falling back to `resync` |
| `CHAT_PRESENCE_TTL` | `2m` | How long "is viewing this thread" is believed |
| `CHAT_PUSH_COALESCE_WINDOW` | `60s` | At most one push per thread per window |
| `CHAT_REMINDER_AFTER` | `30m` | Unread age before the reminder job picks it up |
| `CHAT_REMINDER_DAILY_CAP` | `1` | `<= 0` disables the reminder job entirely |
| `CHAT_EMAIL_FALLBACK_ENABLED` | `false` | §5.5 email fallback — see below |
| `CHAT_ATTACHMENT_MAX_BYTES` | `8388608` | Largest accepted upload, before re-encoding |
| `CHAT_ATTACHMENT_MAX_SIDE` / `_THUMBNAIL_SIZE` | `1600` / `400` | Stored image and thumbnail bounds |
| `CHAT_TYPING_THROTTLE` / `CHAT_TYPING_TTL` | `2s` / `5s` | Typing indicator pacing |
| `CHAT_SEARCH_MIN_LENGTH` | `2` | Shorter terms answer empty instead of scanning |

### The email fallback is still off

`CHAT_EMAIL_FALLBACK_ENABLED=false`. The code is complete (plan §16.1) but has
never run in production, and the reason was always "look at the numbers first":
an email about an unread chat message reads as spam very easily.

Now that there are numbers, the decision is answerable.
`lifey.chat.reminders.sent{channel=push}` tells you how often the push reminder
already fires; the email only ever goes to users with **no registered push
device at all**, so its volume is a subset of that. Turn it on when the push
reminder count is low enough that the email version would be rare — and watch
`{channel=email}` for a week after.

## Scaling out

If `lifey-api` ever runs on more than one instance, three things become
instance-local and stop being globally correct:

1. **`InMemoryChatEventBus`** — realtime only reaches clients on the same node.
   The fix is a `ChatEventBus` implementation over Postgres `LISTEN/NOTIFY`;
   the seam exists for exactly this (plan §2, §9). Nothing above the interface
   changes.
2. **`ChatPresenceRegistry`** and **`ChatTypingThrottle`** — presence is
   fail-open (worst case: an unnecessary push), and the typing throttle just
   allows a few more signals. Neither is worth distributing.
3. **`ChatRateLimiter`** — the effective limit becomes *n × the configured
   value*. It is abuse protection, not accounting; halve the config or accept it.
4. **`lifey.chat.stream.connections`** becomes per-instance, so the leak
   threshold has to be read per node.

`ChatUnreadReminderJob` and the other `@Scheduled` jobs would run **once per
instance** — that is the one item on this list that causes user-visible harm
(duplicate reminders), and it needs a lock before scaling out.
