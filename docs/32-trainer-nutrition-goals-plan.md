# Trainer-Set Nutrition Goals Plan (Roadmap #17)

Goal: the trainer can **edit** (not just view) a client's daily nutrition
goals — calories, protein, carbs, fat — and the client is notified of the
change via push.

Dependency (#8, push infrastructure) is shipped: `PushService.sendToUser`,
per-type opt-out booleans on `UserSettings`, the mobile notification
settings screen, and `PushTapHandler` routing — all walked twice already
(workout reminder, docs/30; trainer comment, docs/31).

## Current state

Backend:

* Nutrition goals live on `UserSettings` (`dailyCalorieGoal`,
  `dailyProteinGoal`, `dailyCarbsGoal`, `dailyFatGoal` — all nullable
  Integers). Rows are created lazily on first access
  (`SettingsServiceImpl.getOrCreate`).
* The trainer already **reads** them:
  `GET /api/v1/trainer/clients/{clientId}/nutrition-goals` on
  `TrainerClientDataController` returns `ClientNutritionGoalsResponse`
  (the four fields), guarded by `requireActiveClient`.
* Push + per-type preference pattern established twice:
  `workoutReminderEnabled` (V52–V54) and `trainerCommentPushEnabled`
  (V56), both checked at send time with "missing row counts as enabled",
  both localized via the client's `UserSettings.language`.
* `SessionCommentServiceImpl` is the direct template for the new service:
  trainer guard → mutate → conditional `pushService.sendToUser` with
  localized copy + `type` data payload.
* Latest Flyway migration: **V56**.

Web:

* `ClientNutritionTab` (trainer's client detail, "Nutrition" tab) already
  renders the goals in the sticky daily-summary panel (kcal headline +
  three `MacroRow` progress bars) via
  `trainerApi.clientNutritionGoals` /
  `queryKeys.trainerClientData.nutritionGoals(clientId)`. The natural
  place for editing is that same panel.

Mobile:

* Settings are a synced singleton: `SettingsRepository.save` writes the
  local Drift row and enqueues a **full** `user_settings` payload on the
  outbox; `PullEngine._pullSettings` overwrites the local row from
  `GET /settings` unless a pending outbox op exists. Drift schema is
  **v25**.
* Everything that displays goals (dashboard, macros tab, remaining-budget
  view, home-screen widget snapshot) reads them from the local settings
  row — so a trainer-set goal reaches every client surface through the
  existing settings pull with **zero display work**.
* `PushTapHandler` routes on `data['type']` (tab-level only);
  the notification settings screen takes new toggle rows cheaply
  (docs/30 M5 plumbing, walked again in docs/31 M3).

## Design decisions

**Trainer writes the same four `user_settings` columns the client owns.**
No new table, no shadow "trainer goals" that need reconciling. The roadmap
item is "edit the client's goals", and the client's goals *are* these
columns. Consequence: the mobile app needs no display changes at all — the
next settings pull delivers the new values everywhere.

**Full-replace of the four nutrition fields; water and step goals
excluded.** The write endpoint mirrors the existing read endpoint's shape
(`ClientNutritionGoalsResponse`). Nulls are allowed and mean "clear this
goal" — same semantics the client's own settings PUT already has. Water
and steps stay client-only (the read endpoint already draws that product
line; nothing in #17 asks to move it).

**Whole-row last-write-wins is accepted, per-field merge is not built.**
The settings sync model is already last-write-wins between the client's
own devices; the trainer becomes one more writer. There is a real race
(see Edge cases: a pending offline `user_settings` outbox op carries the
old goals and clobbers the trainer's edit on drain), but it requires the
client to change *any* setting in the narrow window while unsynced, and
the trainer sees current values on next tab load, so the failure is
visible and re-doable, not silent data corruption. The proper fix (goals
as their own sync resource, or PATCH semantics on `/settings`) is
deferred until it hurts.

**Push on actual change only.** Compare the four values before/after;
saving identical numbers must not notify. Unlike the comment (null →
non-null), *every* real change notifies — a goal change affects the
client's daily targets immediately, and repeat edits are legitimate
updates, not typo fixes.

**Opt-out preference, same shape as the previous two.** New
`UserSettings.trainerGoalsPushEnabled` (default `true`), checked at send
time, toggled on the mobile notification settings screen. This is the
third server-side boolean — still cheaper than building the generalized
per-type preference framework (docs/30's trigger was "more remote types";
revisit at the fourth).

**No audit columns (who set the goals, when).** The push is the
notification; the settings row keeps no authorship. If "changed by your
trainer on {date}" attribution is ever wanted in the app, that's a
`goals_set_by`/`goals_set_at` pair added later — same deferral as the
comment's attribution UI.

## Backend plan

### B1 — `trainerGoalsPushEnabled` preference

* Flyway `V57__user_settings_trainer_goals_push.sql`:
  `alter table user_settings add column trainer_goals_push_enabled
  boolean not null default true;`
* `UserSettings`: new boolean field, default `true` (opt-out — same
  justification as the previous two: the trainer relationship is
  something the client accepted).
* `SettingsRequest` (`@NotNull Boolean`), `SettingsResponse`,
  `SettingsMapper`: carry the field through the existing `/settings`
  round-trip, exactly like `trainerCommentPushEnabled`.

### B2 — Trainer goals endpoint

On `TrainerClientDataController` (it owns the surface and already exposes
the read side):

* `PUT /api/v1/trainer/clients/{clientId}/nutrition-goals` — body
  `ClientNutritionGoalsRequest` in `trainer/dto`: the four
  `@PositiveOrZero Integer` fields, all nullable (null clears that goal).
  Returns the updated `ClientNutritionGoalsResponse`.

Service logic in a new interface+impl pair
`trainer/service/ClientNutritionGoalsService` + Impl (the
`SessionCommentService` pattern — it spans trainer access and settings
data, so the trainer package is the right home):

* Guard: `requireActiveClient(trainerId, clientId)`.
* Read the old values (via `SettingsService.forUser`, which lazily
  creates the row — a trainer can set goals before the client ever opened
  the settings screen), write the new ones, detect change.
* Writing goes through a small addition to `SettingsService`, e.g.
  `updateNutritionGoalsForUser(Long userId, Integer calories,
  Integer protein, Integer carbs, Integer fat)` reusing the existing
  `getOrCreate(userId)` — the settings package keeps ownership of its
  entity; the trainer package doesn't touch `UserSettingsRepository`
  for writes. (`SessionCommentServiceImpl` reads the settings repo for
  the push gate; keep doing that here.)

### B3 — Push on change

In `ClientNutritionGoalsServiceImpl`, after a real change persists
(old tuple ≠ new tuple):

* Preference gate: skip when `trainerGoalsPushEnabled` is `false`;
  missing settings row counts as enabled (moot here — B2 just created
  the row — but keep the idiom).
* `pushService.sendToUser(clientId, message)` — async, never throws.
* Copy localized by the client's `UserSettings.language` (EN fallback).
  EN: title "Your trainer updated your nutrition goals", body = compact
  new-values summary, e.g. "2200 kcal · protein 160 g · carbs 220 g ·
  fat 70 g" (cleared goals omitted; all cleared → "Goals cleared").
  HU: "Az edződ frissítette a táplálkozási céljaidat" + same summary.
* Data payload: `type=nutrition_goals` — tab-level deep-linking,
  consistent with `scheduled_workout` / `trainer_comment`.

### B4 — Backend tests

* Endpoint/service (extend `TrainerClientDataControllerTest`, new
  `ClientNutritionGoalsServiceImplTest` mirroring the comment tests):
  happy-path update (values persisted, response correct), lazy row
  creation for a client with no settings row, nulls clear goals,
  403/404 for a non-client / revoked relationship, validation
  (negative values rejected).
* Push behavior (mock `PushService`): sent on change with the right
  payload + localized copy, **not** sent when values are identical,
  skipped when `trainerGoalsPushEnabled=false`.
* Settings round-trip: `SettingsControllerTest` /
  `SettingsServiceImplTest` extended for the new boolean (same cases as
  `trainerCommentPushEnabled` got).

## Web plan

### W1 — API + types

* `features/trainer/types.ts`: `ClientNutritionGoalsRequest` type (four
  nullable numbers) — the response type already exists.
* `features/trainer/api.ts`: `updateClientNutritionGoals(clientId,
  goals)`; React Query mutation invalidating
  `queryKeys.trainerClientData.nutritionGoals(clientId)` so the summary
  panel refreshes in place.

### W2 — Edit UI in `ClientNutritionTab`

In the sticky daily-summary panel (which already renders the goals):

* An `edit` icon affordance in the panel header switches the panel (or
  opens a small dialog — implementer's choice, panel-inline preferred)
  to four numeric inputs: kcal, protein g, carbs g, fat g. Empty input =
  cleared goal.
* Save/cancel; pending spinner on the mutation; error toast on failure —
  matching existing admin mutation patterns (the comment composer from
  docs/31 W2 is the reference).
* Client-side validation mirrors the API: non-negative integers.
* No confirm dialog — the edit is visible immediately in the same panel
  and re-editable; it's not destructive the way delete-comment is.

### W3 — i18n + web tests

* New `admin.clientDetail` keys (EN + HU): edit-goals label, field
  labels/placeholders, save/cancel, "goals updated" toast, error toast.
* vitest/component: panel renders read mode with goals, edit mode opens,
  save calls the mutation with the entered values (and `null` for
  cleared fields), cancel restores read mode without a call.

## Mobile plan

No display work — goals already flow from the settings pull to the
dashboard, macros tab, remaining-budget view and widget snapshot.

### M1 — `trainerGoalsPushEnabled` plumbing

The exact path `trainerCommentPushEnabled` walked (docs/31 M3):

* Dart `UserSettings` model: new boolean (`copyWith`/`fromJson`/`toJson`
  — `toJson` matters: the backend `SettingsRequest` marks it `@NotNull`,
  so the outbox payload must carry it).
* Drift `settings_table.dart`: new boolean column, default `true`;
  schema **v26** migration (`m.addColumn`).
* `SettingsRepository`: companion + row↔domain mapping.
* `PullEngine._pullSettings`: map the new field.

### M2 — Push tap routing + settings toggle

* `PushTapHandler`: `type == nutrition_goals` → navigate to the
  nutrition tab (tab-level, same altitude as the existing two types;
  the resume-triggered sync pulls the new goals so the tab shows them).
* Notification settings screen: new "Nutrition goal changes"
  `SwitchListTile` backed by `trainerGoalsPushEnabled`, included in
  `NotificationSettingsState.anyEnabled` / `setAllEnabled`. New arb keys
  (EN + HU) for label + subtitle.

### M3 — Mobile tests

* `NotificationSettingsState`: the new toggle participates in
  `anyEnabled`/`setAllEnabled` (extend the existing state tests).
* `PullEngine` settings mapping test extended for the new boolean, if
  the existing pull tests make that cheap.
* Manual device pass: trainer edits goals on web → push arrives, tap
  lands on the nutrition tab, dashboard/macros show the new goals after
  sync; toggle off → no push but goals still update; saving identical
  values → no push.

## Non-goals (deferred)

* Per-field merge / conflict resolution for settings — whole-row
  last-write-wins stays (see Design decisions). Fix path: goals as their
  own sync resource or PATCH semantics on `/settings`.
* Editing water or step goals from the trainer surface.
* Goal *suggestion* for the trainer (running `GoalCalculator` on the
  client's biometrics) — nice later; the trainer types numbers for now.
* Audit trail / attribution ("set by your trainer on …") in the client
  app — the push is the only notice.
* Goal history / change log.
* Locking the client out of editing their own goals — the client keeps
  full control; the trainer is a second writer, not an owner.
* In-app (non-push) notification or unread badge for the change.

## Edge cases

* **Pending offline settings op clobbers the trainer's edit** — the
  client changed any setting offline (or within the sync window), the
  queued full payload carries the old goals, drain overwrites the
  trainer's values. Accepted (see Design decisions): the window is
  short (60s foreground timer / resume / connectivity triggers), the
  trainer sees current values on next tab load and can re-apply. The
  reverse ordering (trainer writes *after* the drain) wins cleanly.
* **Client has no settings row yet** — `getOrCreate(userId)` creates it
  with defaults; the trainer's goals land on the fresh row. Push gate
  reads the row that now exists.
* **Client edits their own goals right back** — allowed by design; the
  trainer's tab shows whatever is current. No ping-pong push: only the
  trainer endpoint notifies, the client's own PUT never does.
* **Trainer saves unchanged values** — no push (tuple comparison), write
  is a harmless no-op.
* **Clearing goals** — nulls persist, mobile surfaces already handle
  null goals (they predate any goal being set); push body says the goals
  were cleared.
* **Two trainers, one client** — both may write; last write wins with no
  attribution. Same acceptance as the comment overwrite in docs/31.
* **Trainer revoked** — `requireActiveClient` blocks the write; goals
  already set persist (client's data, client keeps it).
* **Push disabled / no device** — the change still lands via the next
  settings pull and is visible on the dashboard; push is best-effort.
* **Client mid-day when goals change** — remaining-budget and dashboard
  recompute against the new goals immediately after the pull; already-
  logged meals are unaffected. That's the intended behavior, not a bug.
* **App not released** — no backward-compat concern for the new column,
  request field (`@NotNull` in `SettingsRequest` would break old mobile
  builds — irrelevant per project memory) or endpoint.

## Test plan summary

Backend: B4 (service/controller tests with mock `PushService`, change
vs no-change push semantics, settings round-trip for the new boolean).
Web: W3 (vitest for read/edit mode + mutation wiring). Mobile: M3
(settings-state tests, pull mapping, manual device pass for the push
round-trip).

## Suggested PR split

1. **Backend — preference column + trainer endpoint + push** (B1–B4,
   V57): independently mergeable; existing clients ignore the new
   response field (mobile must ship before the `@NotNull` request field
   matters — non-issue pre-release).
2. **Web — goals editor in `ClientNutritionTab`** (W1–W3): depends on
   PR 1 where the web dev points.
3. **Mobile — preference plumbing + push routing + toggle** (M1–M3,
   Drift v26): depends on PR 1; independent of PR 2.

Rough effort: small backend (one migration, one endpoint, one push call —
all on existing rails), small web (edit mode on an existing panel),
small mobile (no display work; one boolean walked through the usual
settings plumbing plus a router case).
