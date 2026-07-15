# 39 – Rest Timer

Status: done (all 5 prompts implemented)
Scope: roadmap item #1 (docs/05-improvement-roadmap.md) — backend + mobile
Depends on: docs/15-set-rest-time-plan.md (`performedAt` / `doneAt`, already done)

## 1. What we're building

1. **Auto-start countdown after logging a set.** Marking a set done already
   stamps `SetRow.doneAt = now` — that stamp *is* the timer start. The pinned
   banner on the log-session screen changes from the current count-**up**
   ("Rest 1:23") to a count-**down** from the configured duration, with
   progress, a **+15 s** button and a **Skip** button. When it reaches zero it
   flips to an "overtime" count-up so the user still sees how long they've
   actually rested.
2. **Configurable duration, two levels.**
   - Global default: `defaultRestSeconds` on the synced `UserSettings`
     (default **90 s**), plus a `restTimerEnabled` master toggle (default on).
   - Per-exercise override: nullable `defaultRestSeconds` on the `Exercise`
     entity (the user-owned catalog), editable in the exercise create/edit
     sheet. Resolution: `exercise.defaultRestSeconds ?? settings.defaultRestSeconds`.
3. **Local notification when the rest ends** — a new `rest_timer` channel on
   the existing `NotificationService`, scheduledat `doneAt + duration` every
   time a set is logged, canceled/rescheduled whenever the timer target
   changes. Fires even if the app is backgrounded or the phone is locked (the
   common case mid-workout).
4. **Countdown visible in the session screen** — the reworked banner (point 1)
   plus, optionally (M5), a native countdown in the iOS Live Activity /
   Android ongoing notification.

When `restTimerEnabled` is off, the banner keeps today's plain count-up
behaviour and no notification is scheduled — the feature degrades to the
current state, it never disappears.

## 2. Key design decisions

### 2.1 The timer is fully derived state — no timer object

`LogSessionScreen` already ticks `_now` every second and already computes
`_lastDoneAt()` from the blocks. The rest timer needs nothing more:

```
restEndsAt = lastDoneAt + effectiveRestDuration(blockOfLastDoneSet) + userAdjustment
remaining  = restEndsAt - now        // ≤ 0 → overtime count-up
```

Because `doneAt` is persisted (as `performedAt`) and everything else is
recomputed on build, the countdown survives rebuilds, screen re-entry, app
resume, even process death — a resumed session shows the correct remaining
(or overtime) value with zero extra state. This mirrors the PR-flags
"fully derived, can never go stale" pattern (docs/38-personal-records-plan.md).

Only two ephemeral fields exist, both keyed to the `doneAt` they apply to and
implicitly reset when a newer set is logged:

- `_restAdjustment` (`Duration`) — accumulated +15 s taps (also allows a
  future −15 s without redesign).
- `_restSkippedAt` (`DateTime?`) — the `doneAt` whose rest was skipped; while
  it equals the current `lastDoneAt`, the banner hides and no countdown runs.

### 2.2 Where the durations live: synced, not device-local

Both settings go to the backend (the app is unreleased — no compatibility
concerns, see memory note):

- **Global**: `user_settings.rest_timer_enabled` (bool, default `true`) and
  `user_settings.default_rest_seconds` (int, default `90`). Same shape as
  `workoutReminderEnabled` — an account-level training preference, not a
  per-device notification schedule, so the `WeighInReminderPreferences`
  device-local precedent does *not* apply.
- **Per-exercise**: `exercises.default_rest_seconds` (int, nullable). The
  exercise catalog is already a user-owned synced entity with a full
  create/update outbox path (`ExerciseRepository`), so the override rides
  the existing plumbing and follows the user across devices.

### 2.3 Notification scheduling and exactness

- New fixed notification id `4` (`_restTimerNotificationId`) and a new
  Android channel `rest_timer` (default importance, sound + vibration on —
  unlike the silent `workout_session` channel). Re-firing with the same id
  replaces any previous rest notification, which is exactly the semantics we
  want ("only the latest rest matters").
- iOS: `zonedSchedule` is exact — nothing special needed. Foreground
  presentation is on by default (banner + sound), which is fine.
- Android: the default `inexactAllowWhileIdle` used by the weigh-in reminder
  can drift by many minutes — useless for a 90-second timer. Use
  `AndroidScheduleMode.exactAllowWhileIdle`, declare
  `SCHEDULE_EXACT_ALARM` in the manifest, check
  `canScheduleExactNotifications()` and call `requestExactAlarmsPermission()`
  once (from the settings toggle flow, not mid-workout); if the user denies
  it, fall back to `inexactAllowWhileIdle` — the in-app countdown still works
  perfectly, only the background nudge gets fuzzy.
- **Schedule** whenever a *new* `doneAt` is stamped (both `_handleRowMarkDone`
  and the `doneAt ??= now` path in `_handleRowEdit`) and on +15 s
  (reschedule to the new target).
- **Cancel / reschedule** when:
  - a newer set is logged (same id → the new schedule replaces it),
  - the latest done set is reopened (`_handleRowReopen`) or deleted → recompute
    `lastDoneAt`; if a previous done set becomes latest and its rest end is
    still in the future, reschedule to it, otherwise cancel,
  - Skip is tapped → cancel,
  - the session finishes (`_persistFinished`) → cancel,
  - the timer is disabled in settings → cancel on next interaction (and the
    settings toggle itself cancels defensively).
  Leaving the log-session screen does **not** cancel — the session is still
  running and the user still wants the nudge (same reasoning as the ongoing
  session notifier surviving navigation).
- If the app is killed mid-rest the notification still fires — correct, the
  rest really did end. The existing `WorkoutResumePrompt` orphan sweep is the
  natural place to also `cancelRestTimer()` when *no* in-progress session
  exists on app start.
- In-foreground completion: the banner flips to overtime and fires a
  `HapticFeedback.mediumImpact()` once per rest (guard with a "haptic played
  for this `doneAt`" field), matching the PR haptic convention. The system
  banner may also appear — acceptable and consistent on both platforms.

### 2.4 Duration lookup in the screen

`build()` already watches `exerciseControllerProvider` for name resolution —
extend that same map to expose `defaultRestSeconds`, and watch
`settingsControllerProvider` for the global values. Handlers
(`_handleRowMarkDone` etc.) read them via `ref.read` at stamp time to compute
the notification target; the banner recomputes from watched state, so a
mid-workout settings change is picked up immediately.

## 3. UI spec

### 3.1 Rest banner (log_session_screen.dart, `_RestBanner`)

Replaces the current 50 px count-up banner; same pinned position under the
top bar. Visible while the session is running (`_finishedAt == null`), at
least one set is done, and the current rest wasn't skipped.

Timer enabled, remaining > 0:
```
[hourglass] Rest      ▓▓▓▓▓▓▓░░░░░░░   1:12   [+15 s] [Skip ✕]
```
- Remaining as `m:ss`, tabular figures, `scheme.primary` — same type style as
  today.
- Thin linear progress (elapsed/total) between label and time — reuse theme
  colors, no new tokens.
- `+15 s` bumps `_restAdjustment` and reschedules the notification.
- Skip sets `_restSkippedAt = lastDoneAt`, cancels the notification, hides
  the banner until the next set.

Remaining ≤ 0 (overtime): progress bar full, time flips to a count-up of the
overage (e.g. `+0:23`) in a warning tint (`0xFFD66B5A`, the existing
destructive accent), no +15 s button. This preserves the "how long did I
actually rest" information the old banner gave.

Timer disabled: exactly today's banner (plain count-up), no buttons.

Banner height grows to ~64 px — `restBannerHeight` and the derived
`contentTop` in `build()` must follow.

### 3.2 Settings screen

New "Workout" section on `settings_screen.dart` (above or below the
notification entry, wherever it reads best):

- **Rest timer** toggle → `restTimerEnabled` (optimistic flip with rollback,
  same shape as `setWorkoutReminderEnabled`). Turning it on runs the Android
  exact-alarm permission check (2.3).
- **Default rest duration** row showing the current value (`1:30`), tap →
  bottom-sheet picker with preset chips (0:30, 0:45, 1:00, 1:30, 2:00, 2:30,
  3:00, 4:00, 5:00) — presets keep the UI simple and cover real training use;
  no free-text seconds field.

### 3.3 Per-exercise override

The exercise create/edit sheet (`add_exercise_sheet.dart` / wherever the
catalog edit flow lives in `exercises_tab.dart` / `exercise_detail_screen.dart`)
gets an optional "Rest between sets" field using the same preset picker, plus
a "Use default" (null) choice. Shown on the exercise detail screen when set.

## 4. Order of work

Prompts are linearly dependent except M5, which is optional polish.

---

## Prompt 1 — Backend: settings + exercise columns

```
Read these files first:
- backend/src/main/java/com/lifey/settings/ (entity, DTOs, service, mapper — find the UserSettings entity and its request/response)
- backend/src/main/java/com/lifey/workout/exercise/ (Exercise entity, ExerciseRequest/ExerciseResponse, mapper, service)
- backend/src/main/resources/db/migration/ (list it to find the next V number; never edit an applied migration)

Add rest-timer configuration:

1. UserSettings entity: `restTimerEnabled` (boolean, not null, default true)
   and `defaultRestSeconds` (int, not null, default 90). Thread through the
   settings request/response DTOs and mapper exactly like
   workoutReminderEnabled. Validate defaultRestSeconds with @Min(15) @Max(600).
2. Exercise entity: nullable `defaultRestSeconds` (Integer). Thread through
   ExerciseRequest/ExerciseResponse/mapper/service. Validate the same range
   when present.
3. One Flyway migration V<next>__rest_timer.sql:
   - ALTER user_settings ADD rest_timer_enabled boolean NOT NULL DEFAULT true;
   - ALTER user_settings ADD default_rest_seconds integer NOT NULL DEFAULT 90;
   - ALTER exercises ADD default_rest_seconds integer;
   Verify actual table/column names against existing migrations first.
4. Extend the existing settings + exercise controller/service tests so both
   fields round-trip on create/update and defaults apply when absent from the
   request (settings PUT without the fields must not reset them — match how
   the other boolean toggles handle partial payloads).

Java 24, Maven, constructor injection, no new frameworks.
```

---

## Prompt 2 — Mobile data: sync both settings through the offline stack

```
Read these files first:
- mobile/lib/features/settings/domain/user_settings.dart
- mobile/lib/features/settings/data/settings_repository.dart
- mobile/lib/features/workouts/domain/exercise.dart
- mobile/lib/features/workouts/data/exercise_repository.dart
- mobile/lib/core/local_db/ (the settings + exercises table definitions, app_database.dart for schemaVersion + migration strategy)
- mobile/lib/core/sync/pull_engine.dart (the settings and exercises pull paths)

Carry restTimerEnabled / defaultRestSeconds (settings) and the per-exercise
defaultRestSeconds override through the offline-first stack:

1. UserSettings domain: add `bool restTimerEnabled` (default true) and
   `int defaultRestSeconds` (default 90) — constructor, defaults ctor,
   copyWith, fromJson (with `?? true` / `?? 90` fallbacks), toJson. Mirror
   workoutReminderEnabled exactly.
2. Exercise domain: add nullable `int? defaultRestSeconds`.
3. Drift: add the columns to the local settings and exercises tables, bump
   schemaVersion, add migration steps with backfill defaults (true / 90 /
   NULL) following the existing pattern in app_database.dart. Regenerate with
   `dart run build_runner build` — never hand-edit *.g.dart.
4. SettingsRepository: persist + serialize the two new fields wherever the
   existing settings fields are read/written (local row ↔ domain ↔ outbox
   payload).
5. ExerciseRepository: add defaultRestSeconds to create/update signatures,
   the Drift writes, the outbox payloads, and _toDomain.
6. pull_engine.dart: read the new fields from the settings and exercise JSON
   into the local rows.
7. Update/extend the affected repository/sync tests so both fields round-trip
   local → payload → pull.

No UI in this prompt. Four-layer conventions as per mobile/CLAUDE.md.
```

---

## Prompt 3 — Mobile UI: countdown banner, settings section, exercise field

```
Read these files first:
- mobile/lib/features/workouts/presentation/log_session_screen.dart (esp. _RestBanner, _lastDoneAt, the _now ticker, restBannerHeight/contentTop math)
- mobile/lib/features/workouts/presentation/widgets/exercise_session_card.dart (SetRow/ExerciseBlock)
- mobile/lib/features/settings/presentation/settings_screen.dart
- mobile/lib/features/settings/application/settings_controller.dart
- mobile/lib/features/workouts/presentation/widgets/add_exercise_sheet.dart and the exercise edit flow (exercises_tab.dart / exercise_detail_screen.dart)
- mobile/lib/l10n/app_en.arb and app_hu.arb

Build the visible rest timer per docs/39-rest-timer-plan.md §2.1 and §3:

1. LogSessionScreen derived state: helper that returns the current rest
   status (idle / counting {remaining, total} / overtime {overage}) computed
   from _lastDoneAt(), the last-done set's block, the exercise catalog's
   defaultRestSeconds, the watched UserSettings, _restAdjustment and
   _restSkippedAt. Reset _restAdjustment/_restSkippedAt whenever lastDoneAt
   changes (compare against a remembered value).
2. Rework _RestBanner per §3.1: countdown + progress + "+15 s" + Skip,
   overtime count-up state, plain count-up when restTimerEnabled is false.
   Update restBannerHeight/contentTop for the new height.
3. One-shot haptic (HapticFeedback.mediumImpact) when a rest first crosses
   into overtime while the screen is visible.
4. Settings screen: "Workout" section with the rest-timer toggle and the
   default-duration preset picker per §3.2, saved via
   settingsControllerProvider (optimistic flip with rollback, same shape as
   the notification toggles).
5. Exercise create/edit sheet + detail screen: optional "Rest between sets"
   preset picker (nullable = use default), wired through
   ExerciseRepository.create/update.
6. l10n (app_en.arb + app_hu.arb, then regenerate): banner labels (+15 s,
   skip), overtime label, settings section/row titles, duration formatting,
   exercise field label. No hardcoded strings.

Keep the existing autosave flow untouched — the timer is display-only here;
notifications come in the next prompt.
```

---

## Prompt 4 — Mobile: rest-end local notification

```
Read these files first:
- mobile/lib/core/notifications/notification_service.dart (channels, ids, zonedSchedule + timezone init, weigh-in reminder as the scheduling reference)
- mobile/lib/features/workouts/presentation/log_session_screen.dart (_handleRowMarkDone, _handleRowEdit, _handleRowReopen, _handleRowDelete, _persistFinished, and the +15 s / Skip handlers from Prompt 3)
- mobile/lib/features/workouts/application/workout_resume_prompt.dart (the endAll orphan sweep)
- mobile/android/app/src/main/AndroidManifest.xml
- mobile/lib/l10n/app_en.arb and app_hu.arb

Fire a local notification when the rest ends, per docs/39-rest-timer-plan.md §2.3:

1. NotificationService: new `rest_timer` channel (default importance, sound +
   vibration), fixed id 4, and two methods:
   - scheduleRestEnd({required DateTime endsAt, required String title,
     required String body}) → zonedSchedule at endsAt;
     Android exactAllowWhileIdle when canScheduleExactNotifications() allows
     it, else inexactAllowWhileIdle; iOS default Darwin details.
   - cancelRestEnd().
   Reuse _ensureTimezoneInitialized and _ensureAndroidChannel.
2. AndroidManifest: add SCHEDULE_EXACT_ALARM. Request exact-alarm permission
   (requestExactAlarmsPermission) from the settings toggle flow when the user
   enables the rest timer — never mid-workout.
3. LogSessionScreen wiring (all no-ops while restTimerEnabled is false):
   - schedule on every newly stamped doneAt (mark-done AND the doneAt ??= now
     branch of _handleRowEdit) at doneAt + effective duration,
   - reschedule on +15 s,
   - cancel on Skip and in _persistFinished,
   - on reopen/delete of the latest done set: recompute — reschedule to the
     new latest set's rest end if still in the future, else cancel.
4. WorkoutResumePrompt: in the no-in-progress-session sweep that calls
   endAll(), also cancelRestEnd().
5. l10n: notification title/body ("Rest over — next set!" style) in en + hu.
6. Tests where the service seams allow (NotificationService is static —
   follow whatever pattern existing weigh-in reminder tests use; if none,
   cover the screen-level recompute logic instead).
```

---

## Prompt 5 (optional) — Native countdown in Live Activity / ongoing notification

```
Read these files first:
- mobile/lib/core/workout_session_notifier/workout_session_notifier_service.dart
- docs/24-ios-widget-live-activity-plan.md and docs/25-android-widget-ongoing-notification-plan.md
- the iOS Swift ContentState the MethodChannel mirrors (ios/, WorkoutActivityAttributes)

Show the rest countdown natively while the app is backgrounded:

1. WorkoutSessionState: add nullable `restEndsAtEpochMs` (null when the timer
   is disabled/skipped/expired). Populate it in LogSessionScreen._sessionState.
2. Android branch: while restEndsAtEpochMs is in the future, render the
   chronometer as a countdown to it (when = restEndsAtEpochMs,
   chronometerCountDown: true); otherwise keep the current count-up-from-
   last-set behaviour.
3. iOS: extend the ContentState + Live Activity layout with a
   Text(timerInterval:) countdown to restEndsAt, falling back to the current
   elapsed display when nil. Keep the Dart↔Swift key names in sync.

Purely additive — skip this prompt entirely if effort is constrained; the
in-app banner + notification already cover the feature.
```

---

## 5. After implementation

- Mark roadmap item #1 as `(DONE, plan: 39-rest-timer-plan.md)` in
  docs/05-improvement-roadmap.md.
- Manual test checklist:
  - set logged → countdown starts at the right duration (global vs. exercise
    override), notification fires locked/backgrounded on both platforms,
  - +15 s moves both the banner and the notification,
  - Skip hides the banner and no notification fires,
  - logging the next set before the timer ends replaces the schedule (no
    double notification),
  - reopening the only done set cancels everything,
  - finishing the session cancels the pending notification,
  - toggle off → old count-up banner, no scheduling,
  - kill the app mid-rest → notification still fires; reopening the session
    shows the correct derived overtime.
