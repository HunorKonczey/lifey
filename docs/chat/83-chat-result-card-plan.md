# 83 – Chat result card: sharing a workout or a PR as a message

Status: built (2026-10-03, branch `feature/chat-result-card`) — S1–S7 done; chat 218, backend, mobile 2,972 and web 1,089 tests green; two-device emulator walk done 2026-10-07 (LIF-92, §9); web tile in a browser, the client-side "cannot open a trainer's card" rule and iOS still unchecked
Scope: chat service · backend (monolith) · mobile · web (read-only)
Depends on: `docs/chat/40-trainer-chat-plan.md` (messages, attachments §18, push §5),
`docs/chat/44-chat-service-extraction-plan.md` (the chat is its own service with its own migrations),
`docs/redesign/77-mobile-redesign-plan.md` §6 (the non-goal this closes; canvas 5 › "Megosztható eredmények"),
`docs/38-personal-records-plan.md` (what a PR is), `docs/chat/41-trainer-mobile-v2-plan.md` T3 (the trainer's session view)

A client finishes a workout or breaks a record and wants their trainer to see it — today that means typing
numbers into a text message or sending a screenshot. This plan lets either of them be sent as a **card**: a
structured message that renders as a designed tile in the thread, reads out properly in the push and the
conversation list, and opens the real session when the trainer taps it.

## 1. What we're building

1. **A message can carry a card** — exactly one of two kinds for now: `WORKOUT` (a finished strength or cardio
   session: name, when, how long, volume or distance, how many records it produced) and `PR` (one personal
   record: the exercise, which kind of record, the new value, how far it moved the old one). The message's
   `body` is an optional caption, like it is for an image.
2. **Share from where the result is shown** — the workout-success sheet (the whole workout, and each record row
   on its own), the finished strength session, and the cardio summary. One shared "send to chat" sheet shows
   the card as it will arrive, a caption field and, only when the person has more than one open thread, who to
   send it to. With no open thread the share action is not offered at all.
3. **The thread renders it** — a card of its own in the thread (not text in a bubble: a card inside a bubble is
   the nested box the design system forbids), in dark and light, HU and EN, with the numbers formatted for the
   *reader's* locale.
4. **Tap to open** — the trainer taps a card from their client and the real session opens (the same detail
   sheet as the client's Workouts tab, comment box included). The owner taps their own card and their own
   session detail opens. Anyone else sees a static card.
5. **Everywhere else a message appears** — the push says "🏋️ Shared a workout" instead of nothing, the
   conversation list previews the same, the web admin chat shows the card (read-only).
6. **Offline works like text does** — a card written offline waits in the outbox as a `pending` row and goes out
   on reconnect; a retry never duplicates it (same `clientMessageId` idempotency).

## 2. Key design decisions

### 2.1 A card is typed data on the message, not a picture of a widget

Chosen: a `card` object on the message, rendered by each client from its fields.
Rejected: render the card widget to a PNG and send it through the existing image path — it needs *no* chat
service change, which is why it is tempting. But the picture bakes in one theme and one language (a Hungarian
trainer would read an English card from an English client), cannot be opened into the session, cannot be said
in a push or a list preview ("📷 Photo" is all the server knows), carries ~100 KB per message through the
`bytea` table the extraction plan already calls out as the real storage problem (`44` §4.6), and the offline
outbox would have to hold a rendered bitmap.

### 2.2 The card is a snapshot; `sessionId` is only a way to open the real thing

The numbers are frozen when the card is sent. Rejected: a live reference that each client resolves on render —
a message the other person has already read would change when the sender later edits the workout, and the chat
service cannot read workout data anyway (the tables are the monolith's, `44` §2.4). `sessionId` (the
monolith's workout-session id) is carried **only** as the target of the tap.

### 2.3 The server stores what the sender said; it never verifies it, and nobody may read it as data

A card is a claim made by one participant to another, exactly like the text "I benched 100 today". The chat
service validates its *shape and bounds* (§3) but not its truth, and no feature may count, rank or aggregate
card payloads. The verified view of a session is the trainer API behind the tap — authorization lives where the
data lives (`TrainerAccessService.requireActiveClient`), so a forged `sessionId` opens a 404, never someone
else's session.

### 2.4 Shape: one `card` with a `kind` and a typed sub-object, stored as JSON text

```json
{ "kind": "PR", "sessionId": 481, "occurredAt": "2026-10-03T07:12:00Z",
  "workout": null,
  "pr": { "exerciseName": "Bench press", "prType": "MAX_WEIGHT", "value": 102.5,
          "previousValue": 100, "weightKg": 102.5, "reps": 3 } }
```

Exactly the sub-object that matches `kind` is present. Rejected: **per-field columns** — fourteen nullable
columns and a migration for every future kind; **`jsonb`** — never queried, and Hibernate's JSON mapping is one
more moving part for no read benefit; **a polymorphic Jackson type** — this module runs Jackson 3 for MVC and
Jackson 2 for its own mapper (`SecurityConfig`), and a type-info annotation read by two majors is a bug waiting
to be found in production. Storage is one `text` column (`card_data`) holding the validated, re-serialised
object plus a `card_kind` column the database can check and an index-free filter can use later.

Adding a kind later = an enum value, a sub-object, a validator branch. No migration.

### 2.5 One card per message, exclusive with an image

A message is text, **or** an image (+ caption), **or** a card (+ caption), or a tombstone. Rejected: a workout
card carrying its records inside it, or several cards in one message — the sheet shares a record on its own
precisely so each record is a message the trainer can react to. The multipart (image) endpoint takes no card.

### 2.6 Sending resolves the session id best-effort and never blocks on it

The success sheet appears the moment a workout finishes, before the outbox has necessarily created the session
on the server, so `serverId` can still be null. The share action asks the sync engine to flush (bounded wait),
re-reads the id, and **sends either way**: with the id the card is tappable for the trainer, without it
(offline) it is a complete static card. Rejected: blocking the send until the id exists — the one thing a chat
send must never do is wait on a different feature.

### 2.7 Who may share, and who may open

Any participant may share *their own* sessions (a trainer logs workouts too). The card is tappable when it
carries a session id **and** either the tapper sent it (their own session, looked up locally by server id) or the
sender is the tapper's *client* — which the mobile app reads straight off the conversation's peer role, no role
provider needed. For a trainer's card in a client's thread there is nothing the client can open — it renders static. The
chat service decides none of this; the clients do, from data they already hold.

### 2.8 A new by-id read for the trainer's session view

The trainer's Workouts tab pages sessions 20 at a time and its detail sheet reads from that loaded list, so a
card pointing at a six-month-old session would open a blank sheet. The monolith gains
`GET /api/v1/trainer/clients/{clientId}/workout-sessions/{sessionId}` — same response type as the list rows,
same access check, 404 for a session that is not that client's — and the controller adopts the fetched row.

### 2.9 Unknown kinds degrade, they don't crash

A client that meets a `kind` it does not know renders a plain "update the app to see this card" bubble and
still shows the caption. (The app is unreleased, so there is no compatibility obligation — but the parse is
one `switch` default, and the alternative is a thread that throws.)

## 3. Contract

Chat service (`/api/v1/chat`, unchanged paths):

| Endpoint | Change |
|---|---|
| `POST /conversations/{id}/messages` (JSON) | `SendMessageRequest` gains optional `card`; `body` is no longer `@NotBlank` — *body or card* is required, checked in the service (400 `InvalidMessageBody` as today) |
| `MessageResponse` (list, send, SSE `message` frame, conversation `lastMessage`) | gains `card` (null for text and image) |
| `POST …/messages` multipart | unchanged — no card |
| `DELETE /messages/{id}` | tombstone also clears `card_kind` / `card_data` |

`MessageCard` bounds (validated server-side, 400 on violation): `kind` required; `occurredAt` required, not more
than a day in the future; the matching sub-object required, the other absent; strings ≤ 120 chars, trimmed,
non-blank where required; `durationSeconds` 0–604 800; `volumeKg` 0–10 000 000; `distanceMeters` 0–1 000 000;
counts 0–10 000; `value` / `weightKg` 0–10 000; `reps` 0–10 000; `sessionId` positive. The enum values are
`WORKOUT|PR`, `STRENGTH|CARDIO`, `MAX_WEIGHT|REPS_AT_WEIGHT|ESTIMATED_ONE_RM` — the app's `PrType` names.

Schema (chat service, `V1001__chat_message_cards.sql`):
`chat_messages.card_kind varchar(16)`, `chat_messages.card_data text`, both null or both set; `card_kind` checked
against the known values; `card_data` ≤ 4 000 chars; `chat_messages_content_present` re-created so a message
may be a card alone.

Monolith: `GET /api/v1/trainer/clients/{clientId}/workout-sessions/{sessionId}` → `WorkoutSessionResponse`.

Mobile local DB (schema 46): `chat_messages.card_json text null`, `chat_conversations.last_message_card_kind
text null`.

## 4. UI spec

- **Card** (`chat/presentation/widgets/chat_card_view.dart`): a `LifeyCard` that *replaces* the text bubble on
  both sides; own cards keep a primary hairline so the sides still read (the olive own-side fill would put every
  number on a tint the metric colours were never contrast-checked against). Header row: a tinted 36 dp icon holder (strength dumbbell in the workout colour, cardio icon in the
  cardio colour, trophy in the record colour) + the kind label ("Workout" / "Personal record") as an overline.
  Title 17/700 (session name or exercise). Then the numbers: workout → duration · volume (or distance) ·
  exercises, plus a "🏆 3 records" chip when any; PR → the big new value (28/800, tabular figures) with the
  unit, "+2.5 kg" in the improvement colour when `previousValue` is known, "× 3 reps" for the other kinds.
  Footer: the date. A chevron shows only when the card is tappable. Pending/failed state and the tick marks
  are the bubble's own, unchanged.
- **Share sheet** (`share_to_chat_sheet.dart`, `showLifeySheet`): the card preview, a one-line caption field,
  the thread picker (avatar + name rows) only when there are several, and a primary "Send" button. Sending
  closes the sheet and shows a snackbar "Sent to {name}" with an action "Open chat".
- **Entry points**: success sheet — a secondary "Share with your trainer" button above "Continue" (workout
  card) and a share icon on each record row (PR card); finished strength session and cardio summary — a share
  action in the header.
- **Preview text** (conversation list, notification): "🏋️ Workout" / "🏆 Record" — `lastMessageCardKind` drives
  it; the caption follows after a "·" like the image marker does.
- **Web**: a read-only card tile in `MessageBubble`, same fields, `next-intl` strings.
- All strings through ARB / `next-intl`, EN and HU, both in the same change.

## 5. Order of work

Four milestones, each a thing you can look at. The smallest worth using is **M2** (send and see a card in the
thread); M3 adds the open-the-session payoff, M4 the second client.

| Step | Surface | What | Verification |
|---|---|---|---|
| **S1** | chat service | V1001, entity, `MessageCard` + validator, send path, mapper, tombstone, metrics, push text | unit + real-Postgres (`ChatFlowIntegrationTest`) |
| **S2** | backend | by-id trainer session read | controller + service tests |
| **S3** | mobile data | `ChatCard` model, Drift v46, repository send / deliver / flush / retry / preview | repository tests, outbox replay test |
| **S4** | mobile UI | card bubble, list preview, share sheet, the entry points, l10n | widget tests, `flutter analyze`, emulator walk |
| **S5** | mobile UI | tap to open (trainer + owner), by-id adoption in the controller | widget + controller tests |
| **S6** | web | types, bubble tile, list preview, i18n | vitest + tsc + eslint |
| **S7** | docs | Postman, `REMAINING-WORK`, `77` §6, docs README, chat docs | — |

## 6. Non-goals (deferred)

- Cards for other things (a meal, a weight entry, a program) — the `kind` enum is built to grow, nothing more.
- Searching card contents in the thread search (the server matches on `body` only).
- Web "open the session" from a card — the web's client detail page has no per-session route; a link is a
  separate step.
- Editing a sent card, reacting to one, or attaching a picture to one.
- Sharing from the watch.
- Any statistic over cards (§2.3).

## 7. Edge cases

- **No open thread** → no share action. **Archived thread** → not a target (readable, not writable).
- **Several threads** → the picker; the one with the newest activity (the first in the list) is preselected.
- **Session deleted after sharing** → the trainer's tap answers 404; the sheet says "This workout is no longer
  available" and the card stays readable as a snapshot.
- **Not yet synced and offline** → a static card; never an error.
- **Tombstoned card** → both columns cleared, the bubble shows the standard "message deleted" text.
- **Replay with the same `clientMessageId`** → the stored message, whatever card the replay carried.
- **A card with a caption** → both render; the caption sits under the tile.
- **Locale** → numbers formatted by the reader, never by the sender; `occurredAt` is UTC on the wire.
- **Units** → kilograms and metres on the wire; display follows what the rest of the app does for strength
  (kg) and the unit setting for cardio distance.
- **Empty optional numbers** (a template-less workout has no name; a manual cardio log has no volume) → the
  tile drops the line, it never shows 0.

## 8. Test plan

- **Chat service unit**: validator (each bound, wrong sub-object, both sub-objects), `ChatServiceImpl` (card-only
  send, body-or-card rule, replay idempotency, rate limit applies, tombstone clears the card),
  `ChatNotificationServiceImplTest` (card push text, never blank, HU/EN, caption), mapper (card round-trips
  through JSON text, `Instant` stays ISO).
- **Chat service real Postgres**: V1001 applies on top of V1000, a card-only message passes the new check, a
  half-set pair (`card_kind` without `card_data`) is rejected, the old text-only and image rows are untouched.
- **Backend**: controller 200 / 404 / forbidden for a non-client, service rejects a foreign session id.
- **Mobile**: `ChatCard` parse / serialise round-trip incl. unknown kind; repository — card send writes a
  pending row with `card_json`, `_deliver` posts the card, **`flushPending` and `retry` replay a card-only
  row** (the condition that skips rows today), the server echo replaces the pending row, the list preview
  carries the kind; widget tests for each card, tappable and static, dark / light, HU / EN.
- **Web**: bubble renders each kind and the fallback; `thread.ts` grouping unaffected.

## Suggested PR split

One PR is fine (the pieces only make sense together), but the commits follow S1–S7, and S1+S2 are a clean
"backend only" cut if review wants it smaller: the contract change is additive (`card` is null for every
existing message), so they can ship ahead of the clients.

## Risk checkpoints where a failure would be silent

1. **`flushPending` / `retry` skip rows with `body == null && attachmentLocalPath == null`.** A card-only row
   matches that condition, so a card written offline would sit `pending` forever with no error. The condition
   must learn about `card_json`; a test replays a card-only row.
2. **A card message has no `body`.** Everything that treats "no body" as "deleted" — the conversation preview
   (`lastMessagePreview == null`), the push body, the web bubble, the mobile bubble — would show a deleted or
   empty message. Each needs the card to count as content; each has a test.
3. **The tombstone must clear the card.** `deleteMessage` clears the body and the picture today; a card left in
   `card_data` would keep the workout details readable in the database and in any client that cached it.
4. **The database check and the service rule must agree.** `chat_messages_content_present` is the last line of
   defence; the service's "body or image or card" and the constraint are tested against each other on real
   Postgres.
5. **Nothing may read `card_data` as truth** (§2.3) — noted here so a later "records leaderboard" idea starts
   with this paragraph, not with a query.
6. **`MessageResponse` is a positional record built in several places** (mapper, tests, the SSE payload).
   Adding a field changes every constructor call; a missed call site is a compile error on the Java side but a
   silently `undefined` field on the web side — `types.ts` is updated in the same step as the service.

## 9. Step log

- **S1 (chat service) — done.** `V1001__chat_message_cards.sql` (`card_kind`, `card_data`, the all-or-nothing check, the re-created content check), `dto/MessageCard` (kind + typed `workout` / `pr` sub-records, bean-validation bounds), `MessageCards` (cross-field rules, trim, the JSON text format on this module's Jackson 2 mapper with ISO instants), `SendMessageRequest.card` with `body` optional, `MessageResponse.card`, the tombstone clearing the card, push markers ("🏋️ Shared a workout" / "🏆 Shared a record", HU), metric kind `card`. Verified against real Postgres in `ChatFlowIntegrationTest` (card-only message, caption, replay, wrong shape → 400 with no row, delete clears the columns, the table's checks agree with the service rule). Two fixes found on the way: `ChatTypingThrottle` decided by `Instant` equality (failed on Windows' coarse clock; now `compute()` + a flag) and `ChatMetricsTest` learning the third series.
- **S2 (backend) — done.** `GET /api/v1/trainer/clients/{clientId}/workout-sessions/{sessionId}` → `WorkoutSessionService.findByIdForUser` (not-deleted, started, that user's; everything else is a 404). Controller + service tests incl. the 403 that never reaches the service.
- **S3 (mobile data) — done.** `chat/domain/chat_card.dart` (sealed `WorkoutChatCard` / `PrChatCard` / `UnknownChatCard` that keeps its raw JSON, `withSessionId`), Drift schema 46 (`chat_messages.card_json`, `chat_conversations.last_message_card_kind`), `ChatRepository.send(card:)` serialising once and replaying the same text, the preview kind, the tombstone clearing the cached card. **`flushPending` / `retry` skipped rows with no body and no picture** — exactly a card-only row — so a card written offline would never have left; `_hasNothingToReplay` now asks about the card too, with a test that replays one.
- **S4 (mobile UI) — done.** `ChatCardView` (+ `ChatCardText`, one source for what is seen and what is spoken), the thread bubble, the list preview, EN + HU keys. Sharing: `chat_share.dart` (`chatShareTargetsProvider` = open threads newest-first, then trainers with no thread yet, archived never; `ChatShareService`, which resolves the session id at send time with a bounded wait and sends either way), `share_to_chat_sheet.dart` (card preview, note, a picker only for several people), `share_to_chat_buttons.dart` (hidden — not disabled — with nobody to send to), and the entry points: the workout-success sheet (the workout, and a share icon on each record row; opt-in through `WorkoutShareConfig`, so the sheet is unchanged where it is not given), the finished strength session's header, the cardio summary's header. `pollSessionServerId` is the injected-lookup wait.
- **S5 (open) — done.** `canOpenChatCard` / `openChatCard`: the owner opens their own session by server id, a trainer opens the client's through the new `ClientSessionsController.openById` (the row is *adopted* into a list kept apart from the paged sessions, so it never shows out of order and a comment written on it shows on it); a 404 says "no longer available". A client cannot open a card from their trainer.
- **S6 (web) — done.** `MessageCardResponse` types, `card.ts` (pure rules, tested), `ChatCardTile`, the bubble, the list preview, `applyDeletion` clearing the card; EN + HU. Read-only — the web has no per-session page to open.
- **S7 (docs) — done.** Postman (*Send message with a result card*, *Client workout session by id*), `devops/chat-operations.md` (the `card` meter series), `REMAINING-WORK`, `77` §6, `78` §6, the docs README.

### Where the build differs from the plan above

- The card replaces the bubble on both sides instead of sitting in an olive own-side one (§4 / §1.3 text updated).
- The preselected target is the newest thread, not a remembered "last used" — nothing stores the last choice (§7 updated).
- Opening is decided from the conversation's peer role (§2.7 updated); no role provider is consulted.
- The finished-session entry is a header icon on both screens rather than a button in the body.

### Verification

- **Chat service:** `./mvnw -B verify` → 218 tests, all green, including `ChatFlowIntegrationTest` against real Postgres 16 (V1000 + V1001; card-only message, caption, replay, wrong shape → 400 with no row, delete clears the columns, the table's checks agree with the service rule).
- **Monolith:** `./mvnw -B verify` (full suite, real Postgres) → 1,165 tests, 0 failures, 3 skipped, BUILD SUCCESS.
- **Mobile:** `flutter analyze` clean; the whole `flutter test` suite green (2,972 tests), incl. the repository's offline replay, the card in both themes and locales, the share sheet, the opt-in sheet buttons, the open rules and `openById`.
- **Web:** vitest 1,089 tests, `tsc --noEmit` and eslint clean.
- **Found on the way and fixed:** `ChatTypingThrottle` decided by `Instant` equality (two signals in one clock tick on Windows were both let through) → `compute()` + a flag; a `Future<int>` passed where `Future<int?>.timeout(onTimeout: () => null)` was called threw at runtime → re-typed with `then<int?>`.
- **Not verified (at build time):** an emulator or two-device walk and the web tile in a browser. The emulator walk was done afterwards — see below.

### Two-device emulator walk — 2026-10-07 (LIF-92)

Pixel 10 as the client and Pixel Tablet as the trainer, both debug builds against the local backend + the real `chat/` service (`CHAT_PUBLIC_BASE_URL=http://10.0.2.2:8081/api/v1`), a fresh trainer–client pair.

**Worked as designed:**
- The client finishes a free workout and taps the header share icon → "Share in chat" sheet with the card preview and a note field. Send → snackbar "Shared with <trainer>" + "Open chat", and the action opens the thread with the card in it. `chat_messages` holds `card_kind = WORKOUT` with the real `sessionId` (386) and the caption in `body`.
- The trainer's tablet got the card live (list preview "🏋️ Workout" with the unread dot, then the thread with both cards and the note). Tapping it opens the client's session (Bench Press 8 × 80.0 kg); "Add comment" saves, the card then shows "Your comment", and the client's session screen shows the "Trainer comment" block with the text and time. The read ticks on the client's cards turn green once the trainer opened the thread.
- A record: a heavier set earned two records, the finish sheet lists them with a share icon per row and a "Share in chat" button; the row icon opens a "Personal Record · Bench Press · 100 kg +20 kg · Heaviest set" preview. The card reached the trainer's thread (`card_kind = PR`, `sessionId` 387) and tapping it opened *that* session (8 × 100.0 kg, no comment), not the earlier one.

**Found, not fixed:**
- **Sharing while offline looks like a dead button.** With Wi-Fi and data off, Send in the share sheet does nothing visible: no spinner, the sheet stays open, nothing reaches the server. The failure is only visible after dismissing the sheet — the error snackbar "Can't reach the server. Is the backend running?" is behind the modal. `ChatShareService.share` "throws only when a thread has to be created and the server cannot be reached"; the thread existed server-side, but the client had not cached it in this walk (it was created by the first share), so the offline path fell into `openConversationWith`. If that reading is right, a first-ever share offline cannot queue; either way the error must be visible where the user is looking (inside the sheet).
- The trainer tablet's first tap into the comment field raised Android's own "Try out your stylus" dialog — a system feature of the tablet image, not the app.

**Not covered:** the web tile against a running chat service, a trainer sharing a card to a client (the "a client cannot open a card from their trainer" rule), iOS.
