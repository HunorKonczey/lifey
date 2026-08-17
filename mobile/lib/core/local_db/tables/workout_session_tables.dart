import 'package:drift/drift.dart';

import 'exercise_table.dart';

@DataClassName('WorkoutSessionRow')
class WorkoutSessions extends Table {
  @override
  String get tableName => 'workout_sessions';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();

  /// Null for a trainer-scheduled session that hasn't been started yet (see
  /// [scheduledFor]) — docs/personal_trainer/08-utemezett-edzesek-koncepcio.md.
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get finishedAt => dateTime().nullable()();

  /// Calendar day the trainer scheduled this session for; null for a normal
  /// (client-started) session. Non-null with [startedAt] null means
  /// "upcoming" (or "missed", once the date has passed). Stored as a
  /// midnight-local `DateTime` (no dedicated date-only column type in Drift).
  DateTimeColumn get scheduledFor => dateTime().nullable()();

  /// Optional wall-clock time ("HH:mm"), copied from the schedule's time of
  /// day; display/ordering only, stored as text since it has no time zone.
  TextColumn get scheduledTime => text().nullable()();

  /// The originating schedule's server id. Not a `.references()` FK — the
  /// schedule definition itself is never synced to the client, only its
  /// materialized session rows.
  IntColumn get scheduleId => integer().nullable()();

  /// Active energy burned (kcal), imported from Apple Health.
  RealColumn get activeCalories => real().nullable()();

  /// Average heart rate (bpm) over the workout, imported from Apple Health.
  RealColumn get averageHeartRate => real().nullable()();

  /// HKWorkout UUID this session was paired with, if imported from Apple Health.
  TextColumn get healthWorkoutId => text().nullable()();

  /// clientId of the template this session was started from, if any. Not a
  /// Drift `.references()` FK — deleting a template must not be blocked by
  /// (or cascade into) sessions that were started from it.
  TextColumn get templateClientId => text().nullable()();

  /// Snapshot of the template's name at the time this session was started,
  /// so the session still shows what it was called even if the template is
  /// later renamed or deleted.
  TextColumn get templateName => text().nullable()();

  /// Difficulty rating (1-10, RPE-style — how hard the workout was, not a
  /// general mood rating), captured after finishing. Null until rated.
  IntColumn get rpe => integer().nullable()();

  /// Optional free-text note captured alongside [rpe].
  TextColumn get feedbackNote => text().nullable()();

  /// The trainer's single editable comment on this session; null when
  /// uncommented. Server-owned — this app's create/update payload never
  /// sends it (see `WorkoutSessionRepository._payload`).
  TextColumn get trainerComment => text().nullable()();

  /// When [trainerComment] was last written; null when uncommented.
  DateTimeColumn get trainerCommentAt => dateTime().nullable()();

  /// STRENGTH (the original, set-based workout) or CARDIO — see
  /// docs/cardio/51-cardio-overview-plan.md D-C.1. Defaults to STRENGTH so a
  /// pre-cardio row (and any client build that doesn't send it) keeps
  /// behaving exactly as before — mirrors the backend's V66 column default.
  TextColumn get sessionKind => text().withDefault(const Constant('STRENGTH'))();

  /// Non-null exactly when [sessionKind] is `'CARDIO'` — see
  /// `features/workouts/domain/activity_type.dart` for the code list.
  TextColumn get activityType => text().nullable()();

  /// Time actually spent moving, in seconds — the wall-clock span minus
  /// pauses and auto-pause gaps (docs/cardio/56 D-C3.3). Null for a STRENGTH
  /// session, where the wall-clock span already is the workout.
  IntColumn get movingSeconds => integer().nullable()();

  /// Epoch-ms checkpoint for the **live, running** `CardioSessionScreen`
  /// (docs/cardio/59-cardio-implementation-plan.md C2.1) — non-null exactly
  /// while a cardio session is actively moving (not paused, not finished):
  /// `movingSeconds` holds the total accumulated *before* this checkpoint,
  /// and the current total is `movingSeconds + (now - movingSinceEpochMs)`.
  /// Cleared (null) on pause and on finish, where the elapsed interval gets
  /// folded into `movingSeconds` instead. The same epoch-checkpoint idea as
  /// the rest timer's `restEndsAtEpochMs` — a wall-clock anchor the UI ticks
  /// against, rather than a counter that needs a write every second.
  ///
  /// **Client-only — never synced.** The server has no matching field and
  /// `WorkoutSessionRepository._payload()` never includes it; a pull must
  /// never touch this column either (see `pull_engine.dart`'s
  /// `_upsertWorkoutSession`, which simply omits it from the write). A
  /// second device has no use for "is *this device's screen* mid-tick" —
  /// only the synced `movingSeconds` total matters once the session ends.
  IntColumn get movingSinceEpochMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {clientId};
}

/// Cardio metrics for a CARDIO-kind [WorkoutSessions] row (docs/cardio/52
/// §2.2) — one row per cardio session, 1:1 keyed directly by
/// [sessionClientId] rather than its own `clientId`, since it's always
/// created/replaced/deleted alongside its session (see
/// `WorkoutSessionRepository._replaceCardio`).
///
/// Named `CardioDetails` (matching the backend entity/table name) rather
/// than the domain-layer value object, which is called `CardioMetrics` to
/// avoid colliding with this class in files that import both.
@DataClassName('CardioDetailsRow')
class CardioDetails extends Table {
  @override
  String get tableName => 'cardio_details';

  TextColumn get sessionClientId => text().references(WorkoutSessions, #clientId)();

  // DISTANCE + MACHINE
  RealColumn get distanceMeters => real().nullable()();
  RealColumn get elevationGainMeters => real().nullable()();
  RealColumn get elevationLossMeters => real().nullable()();
  RealColumn get maxAltitudeMeters => real().nullable()();
  IntColumn get steps => integer().nullable()();

  /// Steps/min for running, rpm for the indoor bike.
  RealColumn get avgCadence => real().nullable()();
  RealColumn get maxCadence => real().nullable()();

  // Best efforts (docs/cardio/60 C6.1–C6.3) — the fastest continuous 1/5/10
  // km inside the session, in seconds. Null (never 0) when the session has no
  // trail or is shorter than the window.
  IntColumn get best1kSeconds => integer().nullable()();
  IntColumn get best5kSeconds => integer().nullable()();
  IntColumn get best10kSeconds => integer().nullable()();

  // MACHINE
  RealColumn get avgWatts => real().nullable()();
  RealColumn get maxWatts => real().nullable()();
  IntColumn get resistanceLevel => integer().nullable()();

  /// The machine's own displayed calorie count — never auto-summed into
  /// daily active calories (docs/cardio/51 Q4).
  RealColumn get deviceCalories => real().nullable()();

  // Shared physiological
  RealColumn get maxHeartRate => real().nullable()();
  IntColumn get hrZone1Seconds => integer().nullable()();
  IntColumn get hrZone2Seconds => integer().nullable()();
  IntColumn get hrZone3Seconds => integer().nullable()();
  IntColumn get hrZone4Seconds => integer().nullable()();
  IntColumn get hrZone5Seconds => integer().nullable()();

  // GAME
  /// Subjective 1-5 intensity (docs/cardio/51 §3.4).
  IntColumn get intensity => integer().nullable()();

  /// `INDOOR` or `OUTDOOR` — drives GPS and the watch's activity locationType.
  TextColumn get venue => text().nullable()();

  /// Free-text format code, e.g. `5V5`, `SMALL_SIDED`, `PRACTICE`.
  TextColumn get gameFormat => text().nullable()();

  /// Basketball: points. Football: goals.
  IntColumn get scorePoints => integer().nullable()();
  IntColumn get scoreAssists => integer().nullable()();
  IntColumn get scoreRebounds => integer().nullable()();

  // Provenance (docs/cardio/51 R8) — a manual override always wins.
  TextColumn get distanceSource => text().nullable()();
  TextColumn get caloriesSource => text().nullable()();

  // Route (docs/cardio/54) — encoded, simplified polyline; raw GPS points
  // never leave the phone (that's CardioTrackPoints, added in C4a).
  TextColumn get routePolyline => text().nullable()();
  IntColumn get routePointCount => integer().nullable()();

  @override
  Set<Column> get primaryKey => {sessionClientId};
}

/// Per-km/lap splits for a DISTANCE-family cardio session (docs/cardio/52
/// §2.3) — computed client-side at close time, never derived server-side, so
/// the server has nothing to disagree with; a session's split list is always
/// replaced in full, same as [ExerciseSets] for a session's set list.
@DataClassName('CardioSplitRow')
class CardioSplits extends Table {
  @override
  String get tableName => 'cardio_splits';

  TextColumn get clientId => text()();
  TextColumn get sessionClientId => text().references(WorkoutSessions, #clientId)();

  /// 0-based position within the session's split list.
  IntColumn get splitIndex => integer()();

  /// Usually exactly 1000 (one km); the last split of a run is shorter.
  RealColumn get distanceMeters => real()();
  IntColumn get durationSeconds => integer()();

  /// Net elevation change over the split; null when no altitude data was available.
  RealColumn get elevationDeltaM => real().nullable()();
  RealColumn get avgHeartRate => real().nullable()();

  @override
  Set<Column> get primaryKey => {clientId};
}

/// Raw GPS fixes for a DISTANCE-family cardio session
/// (docs/cardio/54-cardio-gps-route-plan.md §4.1, C4a.3) — every incoming fix
/// is written here immediately, not buffered in memory, so a killed app
/// loses at most one point. **Never synced** (D-C1.2: raw points never leave
/// the phone — only the closing polyline, C4a.6, goes to the server) and
/// never read by the outbox. Deleted alongside its session
/// (`WorkoutSessionRepository.delete`, `entity_sync_config.dart`'s
/// `_cleanupWorkoutSessionChildren`), and independently pruned after 90 days
/// by a maintenance job once the polyline it fed is safely on the server
/// (C4a.6, §5 point 5) — this table is never expected to grow unbounded.
@DataClassName('CardioTrackPointRow')
class CardioTrackPoints extends Table {
  @override
  String get tableName => 'cardio_track_points';

  TextColumn get sessionClientId => text().references(WorkoutSessions, #clientId)();

  /// 0-based, monotonically increasing per session — the recording order.
  /// Not derived from [recordedAt]: GPS timestamps aren't guaranteed
  /// strictly increasing (a fix can repeat or arrive slightly out of order),
  /// so a separate, caller-assigned sequence is the only reliable ordering.
  IntColumn get seq => integer()();

  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get altitude => real().nullable()();
  RealColumn get accuracy => real().nullable()();
  RealColumn get speed => real().nullable()();
  DateTimeColumn get recordedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {sessionClientId, seq};
}

/// Exercises planned for a session (quick-add defaults) — independent of how
/// many [ExerciseSets] have been logged for them. Mirrors the backend's
/// `workout_session_exercises` snapshot table.
@DataClassName('WorkoutSessionExerciseRow')
class WorkoutSessionExercises extends Table {
  @override
  String get tableName => 'workout_session_exercises';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get sessionClientId => text().references(WorkoutSessions, #clientId)();
  TextColumn get exerciseClientId => text().references(Exercises, #clientId)();

  /// Target number of sets for this exercise in this session, null if not set.
  IntColumn get targetSets => integer().nullable()();

  @override
  Set<Column> get primaryKey => {clientId};
}

@DataClassName('ExerciseSetRow')
class ExerciseSets extends Table {
  @override
  String get tableName => 'exercise_sets';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get sessionClientId => text().references(WorkoutSessions, #clientId)();
  TextColumn get exerciseClientId => text().references(Exercises, #clientId)();
  IntColumn get reps => integer()();
  RealColumn get weight => real()();

  /// The instant this set was logged — used to compute rest time between
  /// consecutive sets. Backfilled from the owning session's `startedAt` for
  /// rows that predate this column (see AppDatabase's schema v6 migration).
  DateTimeColumn get performedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {clientId};
}
