# Post-Workout Feedback (RPE + Note) — Implementation Plan

Detailed plan for roadmap item #4 (see
[05-improvement-roadmap.md](05-improvement-roadmap.md)): capture a difficulty
rating and optional note when a workout session finishes, and surface it to
the trainer.

## Scope

* Session-level RPE (Rate of Perceived Exertion), 1–10, measuring
  **difficulty** ("how hard was this workout"), not general mood/wellbeing
* Optional free-text note ("felt strong today", "shoulder was sore", ...)
* Captured right after finishing a session; editable later
* A gentle nudge for sessions left unrated (see "Nudge for Unrated
  Sessions" below) — never a blocking prompt or push notification
* Read-only for the trainer on the web admin — no trainer-side editing or
  commenting in this phase (that's roadmap item #13, separate)

## Data Model

Both fields are nullable — no backfill needed, same pattern as the Apple
Health fields (`V15__workout_session_health_fields.sql`).

New Flyway migration `V51__workout_session_feedback.sql`:

```sql
ALTER TABLE workout_sessions ADD COLUMN rpe SMALLINT;
ALTER TABLE workout_sessions ADD COLUMN feedback_note TEXT;
ALTER TABLE workout_sessions ADD CONSTRAINT workout_sessions_rpe_range
    CHECK (rpe IS NULL OR (rpe >= 1 AND rpe <= 10));
```

`rpe` and `feedback_note` are plain scalar columns on `WorkoutSession`, so
normal Hibernate dirty-checking bumps `updatedAt` on their own — no special
handling needed like the child-collection case already called out in
`WorkoutSession.java`'s class Javadoc.

## Backend Changes

* `WorkoutSession.java` — add `Integer rpe`, `String feedbackNote`
* `WorkoutSessionRequest.java` — add `@Min(1) @Max(10) Integer rpe`,
  `String feedbackNote` (both optional, no `@NotNull`)
* `WorkoutSessionResponse.java` — add `rpe`, `feedbackNote`
* `WorkoutSessionMapper.java` — map both fields in `toResponse`
* `WorkoutSessionServiceImpl.java` — set both fields in `create()` and
  `update()`

No new endpoint. The existing `PUT /workout-sessions/{id}` (full-replace,
already used for "finish workout") carries the new fields. Trainer
visibility is free: `TrainerClientDataController.workoutSessions` already
returns `WorkoutSessionResponse` via
`WorkoutSessionService.findPageForUser`.

## Mobile (Flutter)

### Local storage

* `core/local_db/tables/workout_session_tables.dart` — add
  `IntColumn get rpe => integer().nullable()()` and
  `TextColumn get feedbackNote => text().nullable()()` to `WorkoutSessions`
* `app_database.dart` — bump `schemaVersion` 22 → 23, add:
  ```dart
  // V23: post-workout RPE (1-10) + optional note, captured after finishing.
  if (from < 23) {
    await m.addColumn(workoutSessions, workoutSessions.rpe);
    await m.addColumn(workoutSessions, workoutSessions.feedbackNote);
  }
  ```

### Domain / data / sync

* `domain/workout_session.dart` — add `final int? rpe;` and
  `final String? feedbackNote;`
* `data/workout_session_repository.dart`:
  * `create()` / `update()` gain optional `int? rpe, String? feedbackNote`
    params, written into the `WorkoutSessionsCompanion` and included in
    `_payload()` when non-null
  * `_toDomain()` maps `row.rpe` / `row.feedbackNote`
* `core/sync/pull_engine.dart`'s `_upsertWorkoutSession` — map
  `json['rpe']` / `json['feedbackNote']` into the companion, same pattern
  as `activeCalories`/`healthWorkoutId`
* `application/workout_session_controller.dart` — thread `rpe` /
  `feedbackNote` through `logSession()` / `updateSession()`

### UI

* New `presentation/widgets/post_workout_feedback_sheet.dart` — modal
  bottom sheet: 1–10 difficulty selector (chip row, anchored "Very easy" /
  "Maximal effort" — classic RPE scale wording), optional multiline note
  field, Save/Skip actions. Fully skippable — matches the app's
  low-friction design philosophy, no forced step.
* `log_session_screen.dart`:
  * add `int? _rpe`, `String? _feedbackNote` state, initialized from
    `widget.session` in `initState`
  * show the feedback sheet as the first step of `_finishWorkout()`
    (before `_persistFinished()`), await the result into state
  * `_persist()` passes `_rpe` / `_feedbackNote` into `logSession()` /
    `updateSession()` — no extra network round-trip, it rides the same
    save that already happens on finish
  * add an inline "How hard was it?" section, visible once
    `_finishedAt != null`, showing the current rating/note and reopening
    the same sheet to edit — reuses the screen's existing
    `_autoSave()`/`_dirty` machinery, so edits made later while reviewing
    a past session save the same way every other field on this screen
    does. When unrated, this section itself doubles as part of the nudge
    (see below) — it renders as an obvious empty state ("Rate this
    workout") rather than being hidden.
* `l10n/app_en.arb` + `app_hu.arb` — new strings: sheet title, difficulty
  scale anchor labels ("Very easy" … "Maximal effort"), note field hint,
  Save/Skip, inline section label/empty-state, dashboard nudge chip text

### Nudge for Unrated Sessions

Gentle, non-blocking, no push notification — a small affordance on
surfaces the user already visits right after a workout:

* `dashboard/domain/recent_workout.dart` — add `final int? rpe;` to
  `RecentWorkout`
* `dashboard/application/dashboard_controller.dart` — populate it from the
  session's `rpe` when building the recent-workouts list
* `dashboard/presentation/dashboard_screen.dart` (the recent-workout tile,
  around the `_RecentWorkoutTile`/`data.recentWorkouts.take(3)` code) — for
  a **finished, unrated** session, show a small tappable chip (e.g. "Rate
  this workout") on its tile; tapping opens
  `post_workout_feedback_sheet.dart` directly and saves via the same
  `updateSession()` path
* No dismiss/snooze state needed: once rated, `rpe` is non-null and the
  chip simply stops rendering — nothing to track or expire
* Scope the chip to recent sessions only (e.g. `startedAt` within the last
  2–3 days) so old unrated history doesn't clutter the dashboard once this
  feature ships and the backlog of pre-existing sessions is all
  technically "unrated"

## Trainer (Web Admin)

* `web/src/features/workouts/types.ts` — add `rpe: number | null` and
  `feedbackNote: string | null` to `WorkoutSessionResponse`
* `web/src/features/trainer/components/ClientWorkoutsTab.tsx` — render an
  RPE badge (e.g. colored 1–10 pill, next to the existing `templateName`
  badge or under the `sessionMeta` line) and the note text, when present,
  in the expanded session row
* Add the corresponding label(s) to the `admin.clientDetail` i18n
  namespace (English + Hungarian messages files)

## Flow Summary

1. User taps "Finish workout" → feedback sheet appears (skippable) →
   difficulty rating + note captured into screen state
2. Existing finish flow continues unchanged (Apple Health pairing dialogs,
   etc.); the session save that already happens includes the new fields
3. Existing success dialog shown as today
4. If skipped: the next time the user lands on the dashboard, the
   session's recent-workout tile shows a small "Rate this workout" chip
   until it's rated
5. Reopening a finished session later shows an editable RPE/note block
   (empty-state prompt if unrated); edits autosave like any other field on
   the screen
6. Trainer's client detail → Workouts tab → expanded session row shows the
   RPE badge and note

## Compatibility

* All new fields optional/nullable on both the request DTO and the local
  schema — no breaking change, no backfill
* The app isn't released yet, so no coordinated rollout or back-compat
  shim is needed — but the nullable/additive approach costs nothing extra
  either way

## Rough Effort

* Backend: ~1–2h (migration + DTO/entity/service)
* Mobile: ~1–1.5 days (drift migration, repo/controller threading, new
  sheet, inline edit section, dashboard nudge chip, l10n)
* Trainer web: ~1–2h (type + render)

## Resolved Decisions

* **RPE semantics**: difficulty ("how hard was this workout"), 1 = very
  easy, 10 = maximal effort — not a general mood/wellbeing rating
* **Unrated sessions**: get a gentle nudge (dashboard recent-workout tile
  chip, see "Nudge for Unrated Sessions" above) rather than staying
  silently skippable forever or requiring a forced prompt
