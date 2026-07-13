# Session Feedback Loop Plan (Roadmap #13)

Goal: close the loop between a client's post-workout feedback and the
trainer's reaction — the minimal viable communication feature, explicitly
**not** a chat.

1. **Trainer sees client RPE + notes per session** (depends on #4) —
   **already done**: `ClientWorkoutsTab` on the web admin renders the RPE
   chip and the feedback note on each session (shipped alongside #4/#12).
   Nothing left to build for this bullet.
2. **Trainer can comment on a session; client receives a push** (depends
   on #8) — this plan. One comment per session per direction: the client's
   channel is the existing RPE + `feedbackNote`, the trainer's channel is a
   new single, editable comment on the session.

Both dependencies are shipped: #4 (RPE, V51) and #8 (push infrastructure,
V52–V54, `PushService.sendToUser`, notification settings screen).

## Current state

Backend:

* `WorkoutSession` already carries the client→trainer direction: `rpe`
  (1–10) + `feedbackNote`, exposed in `WorkoutSessionResponse`, delivered
  to the trainer via `TrainerClientDataController.workoutSessions()`
  (guarded by `TrainerAccessService.requireActiveClient`).
* Push is a solved problem: `PushService.sendToUser(userId, PushMessage)`
  fans out APNs/FCM, never throws, prunes invalid tokens. Localized copy +
  data payload pattern established by `WorkoutReminderJob`
  (docs/30-push-notifications-plan.md B3).
* Per-type push preference pattern established by
  `UserSettings.workoutReminderEnabled` (B3b): a boolean column, carried by
  the existing `/settings` round-trip, surfaced as a switch on the mobile
  notification settings screen.
* Latest Flyway migration: **V54**.

Web:

* `ClientWorkoutsTab` (trainer's client detail, "Workouts" tab) lists the
  client's sessions with an expandable card — RPE chip in the header,
  `feedbackNote` in the expanded body. The natural place for the comment
  composer is that expanded body, right under the feedback note.
* API layer: `features/trainer/api.ts` + React Query
  (`queryKeys.trainerClients…`), i18n via `messages/en.json` / `hu.json`.

Mobile:

* Offline-first: sessions live in Drift (`workout_session_tables.dart`,
  schema **v24**), delta-synced. Only the parent `WorkoutSession` is
  delta-synced; `PullEngine` already maps `rpe` / `feedbackNote` from the
  pull JSON — a new scalar field follows the exact same path.
* Push tap handling (`PushTapHandler`) routes on `data['type']`
  (tab-level navigation, per docs/30 M3).
* Notification settings screen (docs/30 M5) is built and was explicitly
  designed to take the trainer-comment switch as its next row ("first
  consumer of `PushService` after this lands").

## Design decisions

**One editable comment per session, stored on `workout_sessions`.** Not a
`session_comments` table. Rationale:

* The roadmap says "minimal viable communication — no full chat". One
  comment (trainer) answering one note (client) per session is exactly
  that; threads are the explicit non-goal.
* A scalar column on the session rides the **existing delta sync for
  free**: the trainer's write bumps `updatedAt`, the client's next pull
  picks it up, `PullEngine` maps one more field. A separate table would
  need a new sync resource or fetch-on-view on mobile — real cost for no
  MVP value.
* Upgrade path stays open: if threads are ever needed, migrate the column
  into the first row of a `session_comments` table.

**The comment is trainer-owned, never client-writable.** It is *not* added
to `WorkoutSessionRequest`; the client-facing create/update path must never
touch it (this also means an offline client edit pushed later cannot
clobber a comment written in the meantime). Only the trainer endpoint
writes it.

**Push on comment creation only, not on edits.** A trainer fixing a typo
must not re-notify. Creation = the comment transitions null → non-null.

**Opt-out preference, same shape as the workout reminder.** New
`UserSettings.trainerCommentPushEnabled` (default `true`), checked at send
time on the backend, toggled from the existing notification settings
screen. No new preference framework — docs/30 says the trigger to
generalize is "more remote types", and two booleans isn't that yet.

**Commenter id is stored, attribution UI is not built.** A client can have
two trainers; `trainer_comment_by` records who wrote it (audit +
future-proofing), but the mobile UI just says "Trainer comment" — showing
names/avatars is deferred.

## Backend plan

### B1 — Schema + entity

Flyway `V55__workout_session_trainer_comment.sql`:

```sql
alter table workout_sessions add column trainer_comment text;
alter table workout_sessions add column trainer_comment_at timestamptz;
alter table workout_sessions add column trainer_comment_by bigint references users(id);
```

`WorkoutSession` gains the three fields (`String trainerComment`,
`Instant trainerCommentAt`, `Long trainerCommentBy` — plain `Long`, not a
JPA relation, same reasoning as `scheduleId`: the workout package must not
depend on trainer/user internals it doesn't need).

`WorkoutSessionResponse` + `WorkoutSessionMapper`: add `trainerComment` and
`trainerCommentAt` (the `by` id stays server-side for now — nothing renders
it). `WorkoutSessionRequest` is **deliberately untouched**; verify the
update path in `WorkoutSessionServiceImpl` cannot null the new fields
(it maps request fields explicitly, so an absent field is safe — add a test
pinning that).

### B2 — Trainer comment endpoint

On `TrainerClientDataController` (it already owns the
`/api/v1/trainer/clients/{clientId}/…` surface and the
`requireActiveClient` guard), or a sibling controller if it reads better:

* `PUT /api/v1/trainer/clients/{clientId}/workout-sessions/{sessionId}/comment`
  — body `{ "comment": "..." }` (`@NotBlank`, length-capped, e.g. 2000).
  Upsert semantics: create or edit. Sets `trainerComment`,
  `trainerCommentAt = now`, `trainerCommentBy = current trainer`. Returns
  the updated `WorkoutSessionResponse`.
* `DELETE …/comment` — clears all three fields.

Guards, in order: `requireActiveClient(trainerId, clientId)`, then the
session must belong to `clientId` and be non-deleted (404 otherwise —
reuse `ResourceNotFoundException`).

Service logic lives in a new interface+impl pair (per backend convention),
e.g. `trainer/service/SessionCommentService` + Impl — it spans trainer
access and workout data, so the trainer package (which already imports
workout services) is the right home. It calls into
`WorkoutSessionRepository` directly or via a small addition to
`WorkoutSessionService` (`findOwnedBy(sessionId, userId)`), implementer's
choice — keep the trainer→workout dependency direction that
`TrainerClientDataController` already established.

Note on sync: setting a scalar on the session makes Hibernate
dirty-checking bump `updatedAt` normally (the docs/16 "child-only edit"
caveat doesn't apply — this *is* a parent scalar). The client's next delta
pull therefore carries the comment with zero sync-side work.

### B3 — Push on comment creation

In `SessionCommentServiceImpl`, after a null → non-null transition
persists:

* Preference gate: skip when the client's
  `UserSettings.trainerCommentPushEnabled` is `false`; missing
  `user_settings` row counts as enabled (same rule as the reminder job).
* `pushService.sendToUser(clientId, message)` — already async, never
  throws, so the comment save can't fail because of push.
* Copy localized by the client's `UserSettings` language (same
  resolve-with-EN-fallback as `WorkoutReminderJob`). EN: title
  "New comment from your trainer", body = comment text truncated to ~120
  chars (session/template name prefixed when present, e.g. "Push day: Nice
  pace, add weight next time"). HU equivalent.
* Data payload: `type=trainer_comment`, `sessionId` — enough for tab-level
  deep-linking, consistent with `scheduled_workout`.

### B3b — `trainerCommentPushEnabled` preference

* `UserSettings` + `SettingsRequest`/`SettingsResponse` + `SettingsMapper`:
  new boolean, default `true` (opt-out — same justification as the workout
  reminder: the trainer relationship is something the client accepted, the
  OS permission prompt is the real consent gate).
* Flyway `V56__user_settings_trainer_comment_push.sql`:
  `alter table user_settings add column trainer_comment_push_enabled
  boolean not null default true;`

### B4 — Backend tests

* Endpoint/service: happy-path create (fields set, `updatedAt` bumped),
  edit (no second push), delete (fields cleared), 404 for another
  trainer's client / another client's session / deleted session,
  length-cap validation.
* Push behavior (mock `PushService`): sent on create with the right
  payload + localized copy, **not** sent on edit, skipped when
  `trainerCommentPushEnabled=false`, sent when the settings row is absent.
* Pin the invariant that the client-facing session update
  (`WorkoutSessionServiceImpl.update`) leaves `trainerComment*` untouched.
* Repository via Testcontainers where a query is added.

## Web plan

### W1 — API + types

* `features/workouts/types.ts` (shared `WorkoutSessionResponse` shape):
  add `trainerComment: string | null`, `trainerCommentAt: string | null`.
* `features/trainer/api.ts`: `putSessionComment(clientId, sessionId,
  comment)` and `deleteSessionComment(clientId, sessionId)`; React Query
  mutations invalidating the client-workout-sessions query key so the tab
  refreshes in place.

### W2 — Comment UI in `ClientWorkoutsTab`

In the expanded session body, under the existing feedback-note block:

* **Existing comment** → rendered as a distinct "Your comment" block
  (visually differentiated from the client's italic note — e.g. tinted
  container with an `edit`/`delete` affordance) + relative timestamp from
  `trainerCommentAt`.
* **No comment** → a compact "Add comment" affordance expanding to a
  textarea + save button (length counter against the same 2000 cap).
* Optimistic-ish UX via the mutation's pending state (spinner on save);
  error toast on failure, matching existing admin mutation patterns.
* Deleting asks for a lightweight confirm (it also, conceptually, "unsends"
  the context of the push the client already got — the confirm is enough).

### W3 — i18n + web tests

* New `admin.clientDetail` keys (EN + HU): add/save/edit/delete labels,
  placeholder ("Give feedback on this session…"), "commented {ago}",
  confirm text.
* vitest/component: comment block renders when present, composer when
  absent, save calls the mutation with trimmed text, delete confirm flow.

## Mobile plan

### M1 — Model + local DB + sync

* `WorkoutSession` (domain): `trainerComment`, `trainerCommentAt` fields.
* Drift `workout_session_tables.dart`: two nullable columns; schema
  **v25** migration (`m.addColumn` × 2, mirroring the v23 rpe migration).
* `PullEngine`: map `trainerComment` / `trainerCommentAt` next to the
  existing `rpe`/`feedbackNote` lines.
* Repository row↔domain mapping updated. The outbox/push direction sends
  `WorkoutSessionRequest`-shaped JSON which does not include the field —
  nothing to do there (and that's load-bearing: see B1).

### M2 — Display on the session

Where a finished session's details are shown (the sessions tab's session
card / detail — same surface that shows the client's own RPE/note):

* A "Trainer comment" block: icon + comment text + relative time. Shown
  only when non-null; zero layout impact otherwise.
* No unread state, no reply affordance — the push *is* the notification,
  the block is the persistent record.
* New arb keys (EN + HU): "Trainer comment" label.

### M3 — Push tap routing + settings toggle

* `PushTapHandler`: `type == trainer_comment` → navigate to the workouts
  tab (tab-level, same altitude as `scheduled_workout`; occurrence-level
  deep links stay a non-goal per docs/30).
* Notification settings screen: new "Trainer comments" `SwitchListTile`
  backed by the new `UserSettings.trainerCommentPushEnabled` — the exact
  plumbing the workout-reminder toggle already walked: Dart `UserSettings`
  model (`copyWith`/`fromJson`/`toJson`), Drift settings column (part of
  the same v25 migration), `SettingsRepository` row mapping,
  `PullEngine._pullSettings` mapping, master-switch (`setAllEnabled`)
  inclusion. New arb keys (EN + HU) for label + subtitle.

### M4 — Mobile tests

* `PullEngine` mapping test (comment fields land in the row), if the
  existing pull tests make that cheap.
* Widget test: session card/detail renders the trainer-comment block only
  when present.
* `NotificationSettingsState`: the new toggle participates in
  `anyEnabled`/`setAllEnabled` (extend the existing 7 state tests).
* Manual device pass: trainer comments on web → push arrives on device,
  tap lands on workouts tab, comment visible on the session after sync;
  toggle off → no push; edit on web → no second push, text updates after
  next pull.

## Non-goals (deferred)

* Threads, replies, or any second message per direction — the client
  "replies" by training again and rating it. If real back-and-forth is
  ever needed, that's a chat feature and a `session_comments` table.
* Client reactions ("👍 seen") / read receipts — trainer gets no delivery
  or seen state.
* Unread badges on mobile — push is the only attention mechanism.
* Commenter attribution UI (name/avatar) — the id is stored, rendering it
  can come with a future multi-trainer polish pass.
* Comment on meals / weight / anything non-session.
* Web-admin push or in-app notification for the *trainer* when a client
  submits RPE — the compliance overview + workout tab already surface it.
* Email fallback when the client has no push device registered.

## Edge cases

* **Client offline when commented** — the comment lands via the next
  delta pull (connectivity restore / app resume / 60s timer). The push may
  arrive on a device that hasn't synced yet; tapping opens the workouts
  tab and the sync-on-resume fetches the comment. Acceptable ordering.
* **Offline client edit races the comment** — client edits the session
  offline after the trainer commented, pushes later: the request carries
  no `trainerComment`, the backend update doesn't touch it, and the
  response/next pull returns both the edit and the comment. No clobber
  (pinned by a B4 test).
* **Two trainers, one client** — both may comment; the single field means
  the second overwrites the first (with `trainerCommentBy` updated).
  Accepted for MVP: same-client multi-trainer is rare, and the field
  records who wrote the surviving comment. Overwrite by a *different*
  trainer is a create-like transition for that trainer but **not** a
  null → non-null transition — no new push. Acceptable.
* **Comment on an upcoming (not yet started) session** — allowed; nothing
  in the guard requires `finishedAt`. The push copy stays generic enough
  ("New comment from your trainer") to read fine as pre-workout
  instructions. Blocking it would add a rule with no user benefit.
* **Session soft-deleted after the comment** — the comment disappears
  with the session everywhere (both read paths filter `deletedAt`);
  the already-sent push then dead-ends on the workouts tab. Fine.
* **Trainer revoked after commenting** — the comment persists (historical
  record, same as schedules); the guard only applies at write time, so a
  revoked trainer can no longer edit/delete it.
* **No push device / permission denied** — `sendToUser` no-ops per
  device; the comment still syncs and renders. Push is best-effort by
  design.
* **Very long comment** — 2000-char cap at the API; push body truncated
  to ~120 chars, full text in the app.
* **App not released** — no backward-compat concern for the new columns,
  response fields, or endpoint (per project memory).

## Test plan summary

Backend: B4 (service/controller unit tests with mock `PushService`,
Testcontainers where repository work exists, the no-clobber invariant).
Web: W3 (vitest/component for composer + render states). Mobile: M4
(pull mapping, widget render, settings-state tests, manual device pass
for the push round-trip).

## Suggested PR split

1. **Backend — comment fields + trainer endpoint + push** (B1–B4, V55 +
   V56): independently mergeable; existing clients ignore the new
   response fields.
2. **Web — comment composer in `ClientWorkoutsTab`** (W1–W3): depends on
   PR 1 being deployed where the web dev points.
3. **Mobile — sync + display + push routing + settings toggle** (M1–M4,
   Drift v25): depends on PR 1; independent of PR 2.

Rough effort: small backend (two migrations, one endpoint, one push
call — all on existing rails), small web (one component + mutation),
medium-small mobile (the usual offline-first field plumbing walked
twice recently by rpe and workoutReminderEnabled).
