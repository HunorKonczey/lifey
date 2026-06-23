# 15 – Set timestamps & rest time

Status: proposed
Author: planning doc (implement in 3 prompts, in order)
Scope: workout session sets (`exercise_sets`) — backend + mobile

## 1. What we're building

1. **Each set gets a timestamp** (`performedAt`) — the instant the set was logged.
   It is generated **client-side** at the moment a set is added (`DateTime.now()`),
   because that is the real-time signal we need for rest tracking.
2. **Double-tap a set → log a brand-new set.** In the log-session screen, double
   tapping a set card adds a new set that duplicates the tapped one (same
   exercise / reps / weight) with a fresh `performedAt = now`. This is the fast
   "I just did another set of the same thing" gesture, and it's what makes rest
   time meaningful between consecutive sets.
   > Interpretation note: the original request ("create a brand-new one") is
   > read here as *duplicate the tapped set with a new timestamp*. If you
   > actually want it to open an empty add-set sheet instead, only Prompt 3's
   > `onDoubleTap` body changes.
3. **Rest time in the set list.** Each set (except the first in its order) shows
   the gap to the previous set as **minutes + seconds** (e.g. `1:30` / "1 min
   30 s") — i.e. the rest taken before it.
4. **Backfill old sets.** Existing sets have no timestamp, so on both the backend
   (Flyway) and the local DB (Drift migration) they are filled with **their
   workout session's `startedAt`**, giving every historical set a sane,
   non-null value.

## 2. Why the timestamp must round-trip (key constraint)

Sets are **not** individually stable rows. On every save the whole session
aggregate is wiped and rebuilt:

- Mobile: `WorkoutSessionRepository.update` deletes all `exercise_sets` for the
  session and reinserts them with **new** clientIds (`workout_session_repository.dart:133`).
- Backend: `replaceSets` does `session.getSets().clear()` then recreates each set
  (`WorkoutSessionServiceImpl.java:99`).
- Pull: `PullEngine._pullWorkoutSessions` deletes and reinserts sets from the
  server response (`pull_engine.dart:312`).

So a set has no durable identity — its data is only preserved by being **sent in
the request and returned in the response**. `performedAt` therefore has to live
in `ExerciseSetRequest`, `ExerciseSetResponse`, the payload, and the local
column. A weight-entry-style "local-only `recordedAt`" approach would be lost on
the very next autosave. This is the single most important thing to get right.

Timestamp convention: follow the project's `timestamptz` choice from
`V12__meal_date_time_timestamptz.sql` — store UTC, serialize ISO-8601 UTC like
`startedAt` already does (`workout_session_repository.dart:201`).

## 3. Ordering

Rest time is the delta between **consecutive sets in time order**. Today sets
have no defined order (JPA collection / insertion order). Add explicit ordering
by `performedAt`:

- Backend: `@OrderBy("performedAt ASC")` on `WorkoutSession.sets` (or order in the
  mapper) so the response is time-ordered.
- Mobile: sort each session's sets by `performedAt` before building the domain
  list and before rendering, so the rest deltas are computed against the real
  previous set.

---

## Prompt 1 — Backend: `performedAt` column, DTOs, migration + backfill

```
Read these files first:
- backend/src/main/java/com/lifey/workout/session/ExerciseSet.java
- backend/src/main/java/com/lifey/workout/session/WorkoutSession.java
- backend/src/main/java/com/lifey/workout/session/dto/ExerciseSetRequest.java
- backend/src/main/java/com/lifey/workout/session/dto/ExerciseSetResponse.java
- backend/src/main/java/com/lifey/workout/session/WorkoutSessionMapper.java
- backend/src/main/java/com/lifey/workout/session/WorkoutSessionServiceImpl.java
- backend/src/main/resources/db/migration/V12__meal_date_time_timestamptz.sql (for the timestamptz convention)
- the workout_sessions table definition in V1__init.sql / V8 (to confirm started_at's column name and type)

Add a per-set timestamp `performedAt` to workout session sets:

1. ExerciseSet entity: add a non-null timestamp field `performedAt` mapped to a
   `performed_at` column, using the same Java type the codebase uses for
   timestamptz columns (match WorkoutSession.startedAt — likely Instant or
   OffsetDateTime; use whatever startedAt uses).
2. ExerciseSetRequest: add `@NotNull <timestamp> performedAt`.
3. ExerciseSetResponse: add `performedAt` and populate it in WorkoutSessionMapper.
4. WorkoutSessionServiceImpl.replaceSets: set performedAt from the request item.
5. Order the session's sets by performedAt ascending so responses are
   time-ordered (e.g. @OrderBy("performedAt ASC") on the WorkoutSession.sets
   collection, or sort in the mapper).
6. New Flyway migration V14__exercise_set_performed_at.sql:
   - add `performed_at timestamptz` (nullable first),
   - backfill every existing row from its session's started_at
     (UPDATE exercise_sets es SET performed_at = ws.started_at FROM
      workout_sessions ws WHERE es.workout_session_id = ws.id),
   - then ALTER the column to NOT NULL.
   Verify the actual table/column names against the existing migrations before
   writing the SQL; never edit an applied migration.
7. Update/extend WorkoutSession controller/service tests so create + update
   round-trip performedAt, and findAll returns sets ordered by performedAt.

Java 24, Maven, constructor injection, Service interface + Impl already exist —
don't add frameworks. Keep the existing request validation style.
```

---

## Prompt 2 — Mobile data + sync: carry `performedAt` through the local stack

```
Read these files first:
- mobile/lib/core/local_db/tables/workout_session_tables.dart
- mobile/lib/core/local_db/app_database.dart (for schemaVersion + the migration strategy)
- mobile/lib/features/workouts/domain/workout_session.dart
- mobile/lib/features/workouts/data/workout_session_repository.dart
- mobile/lib/core/sync/pull_engine.dart (the _pullWorkoutSessions method)

Thread a per-set `performedAt` DateTime through the offline-first stack so it
survives the wipe-and-reinsert that every save/pull does:

1. ExerciseSets Drift table: add `DateTimeColumn get performedAt => dateTime()()`.
   Bump the database schemaVersion and add a migration step that adds the column
   and backfills existing local rows from their session's startedAt
   (UPDATE exercise_sets SET performed_at = (SELECT started_at FROM
    workout_sessions ws WHERE ws.client_id = exercise_sets.session_client_id)).
   Follow the existing migration pattern in app_database.dart. Regenerate Drift
   code with `dart run build_runner build`.
2. domain workout_session.dart: add `final DateTime performedAt` to ExerciseSet.
3. data workout_session_repository.dart:
   - add `performedAt` to ExerciseSetInput,
   - _insertChildren: write set.performedAt into the row,
   - _payload: include `'performedAt': s.performedAt.toUtc().toIso8601String()`
     in each set map (mirror how startedAt is serialized),
   - watchAll: read performedAt into the domain ExerciseSet, and sort each
     session's sets by performedAt ascending before returning.
4. pull_engine.dart _pullWorkoutSessions: read performedAt from each set's JSON
   (DateTime.parse(setJson['performedAt'] as String)) and write it into the
   ExerciseSetsCompanion.insert.

Don't touch the UI yet. Keep the four-layer conventions and the never-edit-
generated-files rule (regenerate, don't hand-edit *.g.dart).
```

---

## Prompt 3 — Mobile UI: double-tap to duplicate + rest-time display

```
Read these files first:
- mobile/lib/features/workouts/presentation/log_session_screen.dart
- mobile/lib/features/workouts/data/workout_session_repository.dart (ExerciseSetInput now has performedAt)
- mobile/lib/features/workouts/domain/workout_session.dart (ExerciseSet now has performedAt)
- mobile/lib/l10n/app_en.arb and app_hu.arb

Update the log-session screen so sets carry a timestamp, can be duplicated by
double tap, and show rest time:

1. Change the in-memory `_sets` record type to include `DateTime performedAt`
   (i.e. `({Exercise exercise, int reps, double weight, DateTime performedAt})`).
   - initState: load performedAt from each loaded set (set.performedAt).
   - _addSet: stamp `performedAt: DateTime.now()` on the new set.
   - _persist: pass performedAt into each ExerciseSetInput.
2. Sort `_sets` by performedAt ascending wherever they're rendered so rest deltas
   are computed against the real previous set.
3. Double-tap to duplicate: wrap each set's ListTile so it has an onDoubleTap
   (e.g. InkWell, keeping the Card). On double tap, append a new _sets entry that
   copies the tapped set's exercise/reps/weight with performedAt = DateTime.now(),
   keep its exercise planned, then call _autoSave() — same pattern as _addSet.
4. Rest time: for each set after the first (in performedAt order), compute the
   gap to the previous set and show it formatted as minutes + seconds (e.g.
   "1:30"). The first set shows no rest (or a dash). Render it on the card, e.g.
   as a second subtitle line or a small leading badge.
5. Add localization keys for the rest label to app_en.arb and app_hu.arb (e.g.
   restTimeLabel with minutes/seconds placeholders) and use AppLocalizations —
   no hardcoded strings, matching the rest of this screen. Regenerate l10n if the
   project requires it.

Keep the existing remove (X) button, autosave behavior, and the reps×weight
line. Don't call the network directly — go through the controller/repository as
today.
```

---

## 4. Order of work

Prompts are linearly dependent — do them in order:

1. **Prompt 1 (backend)** establishes the wire contract (`performedAt` in
   request/response) and migrates existing data.
2. **Prompt 2 (mobile data/sync)** makes the local stack store and round-trip it.
3. **Prompt 3 (mobile UI)** adds the double-tap gesture and the rest-time display.

After all three: a fresh set is stamped on creation, double-tap logs the next set
instantly, the list shows rest between consecutive sets, and every pre-existing
set reads back with its session's start time.
```
